# frozen_string_literal: true

# HTTP client wrapper around Faraday for making external API requests
# Handles request/response processing, error handling, and logging
class HttpClient
  class Error < StandardError; end
  class ConnectionError < Error; end
  class TimeoutError < Error; end
  class BadRequestError < Error; end
  class UnauthorizedError < Error; end
  class NotFoundError < Error; end
  class ServerError < Error; end

  attr_reader :base_url, :timeout, :headers

  def initialize(base_url:, timeout: 30, headers: {})
    @base_url = base_url
    @timeout = timeout
    @headers = default_headers.merge(headers)
  end

  # Make a GET request
  # @param path [String] The path to request
  # @param params [Hash] Query parameters
  # @return [Hash] Parsed JSON response
  def get(path, params: {})
    request(:get, path, params: params)
  end

  # Make a POST request
  # @param path [String] The path to request
  # @param body [Hash] Request body (will be JSON encoded)
  # @return [Hash] Parsed JSON response
  def post(path, body: {})
    request(:post, path, body: body)
  end

  # Make a PUT request
  # @param path [String] The path to request
  # @param body [Hash] Request body (will be JSON encoded)
  # @return [Hash] Parsed JSON response
  def put(path, body: {})
    request(:put, path, body: body)
  end

  # Make a DELETE request
  # @param path [String] The path to request
  # @return [Hash] Parsed JSON response
  def delete(path)
    request(:delete, path)
  end

  private

  def request(method, path, params: nil, body: nil)
    url = "#{base_url}#{path}"
    response = connection.send(method) do |req|
      req.url url
      req.params = params if params
      req.body = body.to_json if body
      req.headers.merge!(headers)
    end

    handle_response(response)
  rescue Faraday::ConnectionFailed, Faraday::SSLError => e
    raise ConnectionError, "Connection failed: #{e.message}"
  rescue Faraday::TimeoutError => e
    raise TimeoutError, "Request timeout: #{e.message}"
  rescue Faraday::Error => e
    raise Error, "HTTP error: #{e.message}"
  end

  def connection
    @connection ||= Faraday.new do |conn|
      conn.request :json
      conn.response :json, content_type: /\bjson$/
      conn.adapter Faraday.default_adapter
      conn.options.timeout = timeout
    end
  end

  def handle_response(response)
    case response.status
    when 200..299
      response.body || {}
    when 400
      raise BadRequestError, "Bad request: #{response.body}"
    when 401
      raise UnauthorizedError, "Unauthorized: #{response.body}"
    when 404
      raise NotFoundError, "Not found: #{response.body}"
    when 500..599
      raise ServerError, "Server error (#{response.status}): #{response.body}"
    else
      raise Error, "Unexpected status #{response.status}: #{response.body}"
    end
  end

  def default_headers
    {
      "Content-Type" => "application/json",
      "Accept" => "application/json"
    }
  end
end
