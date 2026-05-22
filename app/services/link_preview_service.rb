require "digest"
require "ipaddr"
require "net/http"
require "resolv"
require "uri"

class LinkPreviewService
  CACHE_TTL = 12.hours
  LOCK_TTL = 30.seconds
  MAX_URLS = 2
  BODY_LIMIT = 100_000
  CACHE_NAMESPACE = "link_preview:v1".freeze
  LOCK_NAMESPACE = "link_preview:lock:v1".freeze

  class << self
    def extract_urls(text)
      return [] if text.blank?

      text.scan(%r{https?://[^\s<]+})
          .map { |url| url.sub(/[.,)\]]+\z/, "") }
          .uniq
          .first(MAX_URLS)
    end

    def cached_preview(url)
      return nil unless safe_http_url?(url)

      Rails.cache.read(cache_key(url))
    end

    def fetch_and_cache(url)
      return nil unless safe_http_url?(url)

      cached = Rails.cache.read(cache_key(url))
      return cached if cached.present?

      lock_acquired = Rails.cache.write(lock_key(url), true, expires_in: LOCK_TTL, unless_exist: true)
      return nil unless lock_acquired

      begin
        preview = build_preview(url)
        Rails.cache.write(cache_key(url), preview, expires_in: CACHE_TTL) if preview.present?
        preview
      ensure
        Rails.cache.delete(lock_key(url))
      end
    rescue StandardError => e
      Rails.logger.debug("LinkPreviewService fetch failed for [url redacted]: #{e.class}")
      nil
    end

    private

    def build_preview(url)
      uri = URI.parse(url)

      # Resolve once and connect via IP to prevent DNS rebinding TOCTOU.
      # The Host header preserves virtual hosting and SNI.
      resolved_ips = Resolv.getaddresses(uri.host)
      return nil if resolved_ips.empty? || resolved_ips.any? { |addr| private_ip?(addr) }

      http = Net::HTTP.new(resolved_ips.first, uri.port)
      if uri.scheme == "https"
        http.use_ssl = true
        http.verify_mode = OpenSSL::SSL::VERIFY_PEER
      end

      http.open_timeout = 2
      http.read_timeout = 2

      req = Net::HTTP::Get.new(uri.request_uri)
      req["Host"] = uri.host
      res = http.request(req)
      body = (res.body || "")[0, BODY_LIMIT]

      og_title = body[/<meta\s+property=["']og:title["']\s+content=["']([^"']+)["'][^>]*>/i, 1]
      og_desc = body[/<meta\s+property=["']og:description["']\s+content=["']([^"']+)["'][^>]*>/i, 1]
      og_image = body[/<meta\s+property=["']og:image["']\s+content=["']([^"']+)["'][^>]*>/i, 1]
      title = (og_title || body[/<title[^>]*>([^<]+)<\/title>/i, 1])&.strip

      {
        url: url,
        title: title,
        description: og_desc&.strip,
        favicon: "#{uri.scheme}://#{uri.host}/favicon.ico",
        image: absolutize_url(og_image, uri)
      }
    rescue StandardError
      nil
    end

    def safe_http_url?(url)
      uri = URI.parse(url) rescue nil
      return false unless uri && %w[http https].include?(uri.scheme)

      host = uri.host.to_s
      return false if host =~ /(^|\.)localhost$/i
      return false if host =~ /(^|\.)local$/i

      if (ip = IPAddr.new(host) rescue nil)
        return false if private_ip?(ip.to_s) || ip.multicast? || ip.to_i.zero?
      end

      true
    end

    def private_ip?(addr)
      ip = IPAddr.new(addr) rescue nil
      return true unless ip

      ip.private? || ip.loopback? || ip.link_local?
    end

    def absolutize_url(candidate, base_uri)
      return nil if candidate.blank?

      uri = URI.parse(candidate)
      uri = base_uri.merge(uri) if uri.relative?
      return nil unless %w[http https].include?(uri.scheme)
      return nil unless safe_http_url?(uri.to_s)

      uri.to_s
    rescue StandardError
      nil
    end

    def cache_key(url)
      "#{CACHE_NAMESPACE}:#{Digest::SHA256.hexdigest(url)}"
    end

    def lock_key(url)
      "#{LOCK_NAMESPACE}:#{Digest::SHA256.hexdigest(url)}"
    end
  end
end
