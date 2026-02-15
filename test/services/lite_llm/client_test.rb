require "test_helper"
require "webmock/minitest"

class LiteLlm::ClientTest < ActiveSupport::TestCase
  def setup
    # Set up settings for LiteLLM
    Setting.find_or_create_by!(key: "litellm_host") do |s|
      s.value = "http://localhost:4000"
    end
    Setting.find_or_create_by!(key: "litellm_api_key") do |s|
      s.value = "test-api-key"
    end

    @client = LiteLlm::Client.new(
      host: "http://localhost:4000",
      api_key: "test-api-key"
    )
  end

  def teardown
    WebMock.reset!
  end

  test "raises ConfigurationError when host is blank" do
    assert_raises(LiteLlm::ConfigurationError) do
      LiteLlm::Client.new(host: "", api_key: "key")
    end
  end

  test "raises ConfigurationError when api_key is blank" do
    assert_raises(LiteLlm::ConfigurationError) do
      LiteLlm::Client.new(host: "http://localhost:4000", api_key: "")
    end
  end

  test "raises ConfigurationError when host is invalid URI" do
    assert_raises(LiteLlm::ConfigurationError) do
      LiteLlm::Client.new(host: "not a valid uri ://", api_key: "key")
    end
  end

  test "models returns list of available models" do
    stub_request(:get, "http://localhost:4000/v1/models")
      .to_return(
        status: 200,
        body: {
          data: [
            { id: "gpt-4" },
            { id: "gpt-3.5-turbo" },
            { id: "claude-3-opus" }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    models = @client.models

    assert_includes models, "gpt-4"
    assert_includes models, "gpt-3.5-turbo"
    assert_includes models, "claude-3-opus"
  end

  test "models returns empty array when data is missing" do
    stub_request(:get, "http://localhost:4000/v1/models")
      .to_return(
        status: 200,
        body: {}.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    models = @client.models

    assert_equal [], models
  end

  test "models handles string model IDs" do
    stub_request(:get, "http://localhost:4000/v1/models")
      .to_return(
        status: 200,
        body: { data: ["model-1", "model-2"] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    models = @client.models

    assert_includes models, "model-1"
    assert_includes models, "model-2"
  end

  test "chat sends correct request and parses response" do
    stub_request(:post, "http://localhost:4000/v1/chat/completions")
      .with(
        body: hash_including(
          model: "gpt-4",
          messages: [{ role: "user", content: "Hello" }]
        ),
        headers: { "Authorization" => "Bearer test-api-key" }
      )
      .to_return(
        status: 200,
        body: {
          choices: [
            {
              message: {
                role: "assistant",
                content: "Hello! How can I help you?"
              }
            }
          ]
        }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.chat(
      messages: [{ role: "user", content: "Hello" }],
      model: "gpt-4"
    )

    assert_equal "Hello! How can I help you?", result[:content]
    assert_equal "assistant", result[:role]
  end

  test "chat includes optional parameters when provided" do
    stub_request(:post, "http://localhost:4000/v1/chat/completions")
      .with(
        body: hash_including(
          model: "gpt-4",
          temperature: 0.7,
          max_tokens: 100
        )
      )
      .to_return(
        status: 200,
        body: { choices: [{ message: { content: "Response" } }] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    @client.chat(
      messages: [{ role: "user", content: "Test" }],
      model: "gpt-4",
      temperature: 0.7,
      max_tokens: 100
    )

    assert_requested(:post, "http://localhost:4000/v1/chat/completions")
  end

  test "chat returns nil for empty choices" do
    stub_request(:post, "http://localhost:4000/v1/chat/completions")
      .to_return(
        status: 200,
        body: { choices: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    result = @client.chat(
      messages: [{ role: "user", content: "Test" }],
      model: "gpt-4"
    )

    assert_nil result
  end

  test "raises RequestError on HTTP error" do
    stub_request(:post, "http://localhost:4000/v1/chat/completions")
      .to_return(
        status: 500,
        body: { error: "Internal server error" }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    error = assert_raises(LiteLlm::RequestError) do
      @client.chat(
        messages: [{ role: "user", content: "Test" }],
        model: "gpt-4"
      )
    end

    assert_equal 500, error.status
  end

  test "raises RequestError on connection refused" do
    stub_request(:get, "http://localhost:4000/v1/models")
      .to_raise(Errno::ECONNREFUSED)

    error = assert_raises(LiteLlm::RequestError) do
      @client.models
    end

    assert_match /Failed to reach/, error.message
  end

  test "raises RequestError on timeout" do
    stub_request(:get, "http://localhost:4000/v1/models")
      .to_timeout

    error = assert_raises(LiteLlm::RequestError) do
      @client.models
    end

    assert_match /timed out/, error.message
  end

  test "handles trailing slash in host" do
    client = LiteLlm::Client.new(
      host: "http://localhost:4000/",
      api_key: "test-api-key"
    )

    stub_request(:get, "http://localhost:4000/v1/models")
      .to_return(
        status: 200,
        body: { data: [] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    assert_nothing_raised do
      client.models
    end
  end
end
