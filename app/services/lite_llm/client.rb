require 'net/http'
require 'json'
require 'uri'

module LiteLlm
  class Error < StandardError; end
  class ConfigurationError < Error; end
  class RequestError < Error
    attr_reader :status, :body

    def initialize(message, status:, body: nil)
      super(message)
      @status = status
      @body = body
    end
  end

  class Client
    DEFAULT_TIMEOUT = 10

    def initialize(host: nil, api_key: nil, open_timeout: DEFAULT_TIMEOUT, read_timeout: DEFAULT_TIMEOUT)
      @host = (host || Setting.fetch('litellm_host', nil)).to_s.strip
      @api_key = api_key || Setting.fetch('litellm_api_key', nil)
      @open_timeout = open_timeout
      @read_timeout = read_timeout
      validate_configuration!
    end

    def models
      json = get('/v1/models')
      extract_models(json)
    end

    def chat(messages:, model:, temperature: nil, max_tokens: nil, response_format: nil)
      payload = {
        model: model,
        messages: messages,
      }
      payload[:temperature] = temperature if temperature
      payload[:max_tokens] = max_tokens if max_tokens
      payload[:response_format] = response_format if response_format

      json = post('/v1/chat/completions', payload)
      parse_choice(json)
    end

    private

    attr_reader :host, :api_key

    def validate_configuration!
      raise ConfigurationError, 'LiteLLM host is not configured' if host.blank?
      raise ConfigurationError, 'LiteLLM API key is not configured' if api_key.blank?
      uri # trigger parse
    rescue URI::InvalidURIError
      raise ConfigurationError, 'LiteLLM host is invalid'
    end

    def uri(path = nil)
      base = host.end_with?('/') ? host : "#{host}/"
      if path
        URI.join(base, path.delete_prefix('/'))
      else
        URI.parse(base)
      end
    end

    def build_http(target_uri)
      http = Net::HTTP.new(target_uri.host, target_uri.port)
      http.use_ssl = target_uri.scheme == 'https'
      http.open_timeout = @open_timeout
      http.read_timeout = @read_timeout
      http
    end

    def get(path)
      target_uri = uri(path)
      request = Net::HTTP::Get.new(target_uri)
      execute(request, target_uri)
    end

    def post(path, payload)
      target_uri = uri(path)
      request = Net::HTTP::Post.new(target_uri)
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(payload)
      execute(request, target_uri)
    end

    def execute(request, target_uri)
      request['Authorization'] = "Bearer #{api_key}" if api_key.present?

      response = build_http(target_uri).request(request)
      parse_response(response)
    rescue Errno::ECONNREFUSED, SocketError => e
      raise RequestError.new("Failed to reach LiteLLM host: #{e.message}", status: nil)
    rescue Net::OpenTimeout, Net::ReadTimeout => e
      raise RequestError.new("LiteLLM request timed out: #{e.message}", status: nil)
    end

    def parse_response(response)
      body = response.body
      json_body = nil

      if body && !body.empty?
        begin
          json_body = JSON.parse(body)
        rescue JSON::ParserError
          json_body = body
        end
      end

      if response.is_a?(Net::HTTPSuccess)
        json_body
      else
        message = json_body.is_a?(Hash) ? json_body['error'] || json_body['message'] : response.message
        raise RequestError.new("LiteLLM request failed: #{message}", status: response.code.to_i, body: json_body)
      end
    end

    def extract_models(json)
      return [] unless json.is_a?(Hash)

      data = json['data']
      return [] unless data.is_a?(Array)

      data.filter_map do |entry|
        case entry
        when String
          entry
        when Hash
          entry['id'] || entry['model_id']
        end
      end.compact.uniq.sort
    end

    def parse_choice(json)
      return nil unless json.is_a?(Hash)
      choices = json['choices']
      return nil unless choices.is_a?(Array) && choices.first

      message = choices.first['message']
      return nil unless message.is_a?(Hash)

      {
        content: message['content'],
        role: message['role'] || 'assistant',
        raw: json
      }
    end
  end
end
