require 'net/http'
require 'uri'
module MessagesHelper
  # Render a message body with lightweight Markdown and @mention highlighting.
  # Avoids external gems; keeps output sanitized.
  def render_message_body(text)
    return "" if text.blank?

    escaped = ERB::Util.html_escape(text.to_s)

    # Code blocks ``` ``` (multiline)
    escaped = escaped.gsub(/```\n?([\s\S]*?)\n?```/) do
      content = Regexp.last_match(1)
      "<pre class=\"hc-code\"><code>#{content}</code></pre>"
    end

    # Inline code `code`
    escaped = escaped.gsub(/`([^`]+)`/) { "<code class=\"hc-code-inline\">#{Regexp.last_match(1)}</code>" }

    # Bold **text**
    escaped = escaped.gsub(/\*\*([^*]+)\*\*/) { "<strong>#{Regexp.last_match(1)}</strong>" }

    # Italic *text* (naive; won’t conflict with bold after previous pass)
    escaped = escaped.gsub(/(?<!\*)\*([^*]+)\*(?!\*)/) { "<em>#{Regexp.last_match(1)}</em>" }

    # Links [text](url)
    escaped = escaped.gsub(/\[([^\]]+)\]\((https?:[^\s)]+)\)/) do
      label = Regexp.last_match(1)
      url   = Regexp.last_match(2)
      %(<a href="#{url}" target="_blank" rel="noopener" class="hc-link">#{label}</a>)
    end

    # Autolink bare URLs
    escaped = escaped.gsub(%r{(?<!href=")\bhttps?://[^\s<]+}) do |url|
      %(<a href="#{url}" target="_blank" rel="noopener" class="hc-link">#{url}</a>)
    end

    # Mentions @username (alphanumeric + underscore) → link to start DM
    escaped = escaped.gsub(/(^|\s)@([A-Za-z0-9_]{2,50})/) do
      prefix, name = Regexp.last_match(1), Regexp.last_match(2)
      href = start_dm_path(username: name) rescue "#"
      %(#{prefix}<a href="#{href}" class="hc-mention-link">@#{name}</a>)
    end

    # Preserve newlines
    escaped = escaped.gsub("\n", "<br>")

    allowed = %w[strong em a br pre code span]
    sanitize(escaped, tags: allowed, attributes: %w[href target rel class])
  end

  # Extract URLs from text for unfurling.
  def extract_urls(text)
    return [] if text.blank?
    text.scan(%r{https?://[^\s<]+}).uniq.first(2)
  end

  def render_link_previews(message)
    urls = extract_urls(message.content)
    return ''.html_safe if urls.blank?

    previews = urls.filter_map { |u| fetch_link_preview(u) }
    return ''.html_safe if previews.blank?

    content_tag :div, class: 'mt-2 space-y-2' do
      previews.map { |p|
        link_to p[:url], target: '_blank', rel: 'noopener', class: 'block border border-gray-200 rounded-md p-3 hover:border-gray-300 hover:shadow-sm transition' do
          (image_tag(p[:favicon], class: 'inline-block w-4 h-4 mr-2 align-text-bottom') if p[:favicon]).to_s.html_safe +
          content_tag(:span, p[:title].presence || p[:url], class: 'text-sm text-gray-800')
        end
      }.join.html_safe
    end
  end

  private

  def fetch_link_preview(url)
    return nil unless safe_http_url?(url)
    Rails.cache.fetch([:link_preview, url], expires_in: 12.hours) do
      begin
        uri = URI.parse(url)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.open_timeout = 2
        http.read_timeout = 2
        req = Net::HTTP::Get.new(uri)
        res = http.request(req)
        body = (res.body || '')[0, 100_000]
        title = body[/<title[^>]*>([^<]+)<\/title>/i, 1]&.strip
        {
          url: url,
          title: title,
          favicon: "#{uri.scheme}://#{uri.host}/favicon.ico"
        }
      rescue StandardError
        nil
      end
    end
  end

  def safe_http_url?(url)
    uri = URI.parse(url) rescue nil
    return false unless uri && %w[http https].include?(uri.scheme)
    host = uri.host.to_s
    return false if host =~ /(^|\.)localhost$/i
    return false if host =~ /(^|\.)local$/i
    return false if host =~ /^127\./
    return false if host =~ /^10\./
    return false if host =~ /^192\.168\./
    return false if host =~ /^172\.(1[6-9]|2[0-9]|3[0-1])\./
    true
  end
end
