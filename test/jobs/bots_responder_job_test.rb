require "test_helper"

class BotsResponderJobTest < ActiveJob::TestCase
  setup do
    Setting.set(:litellm_default_model, 'gpt-test')
    Setting.set(:litellm_host, 'http://localhost:4000')
    Setting.set(:litellm_api_key, 'test-key')
    @bot = Bot.create!(name: 'helper_bot', bot_type: 'ai', instructions: 'Be helpful.')
    @user = create_user(username: 'sarah')
    @channel = Channel.create!(name: 'general', description: 'General chat', channel_type: 'public', created_by: @user)
    @channel.add_member(@user)
    @message = @channel.messages.create!(user: @user, content: 'Hi @helper_bot', message_type: 'chat')
    clear_enqueued_jobs
  end

  teardown do
    Setting.where(key: 'litellm_default_model').delete_all
    Setting.where(key: 'litellm_host').delete_all
    Setting.where(key: 'litellm_api_key').delete_all
  end

  class FakeClient
    attr_reader :calls

    def initialize(response)
      @response = response
      @calls = []
    end

    def chat(messages:, model:)
      @calls << { messages: messages, model: model }
      @response
    end
  end

  test "creates bot response message" do
    client = FakeClient.new({ content: "Hello there!" })

    LiteLlm::Client.stub :new, ->(**_kwargs) { client } do
      perform_enqueued_jobs do
        Bots::ResponderJob.perform_now(@bot.id, @message.id, 'mention')
      end
    end

    response = @channel.messages.order(:created_at).last
    assert_equal @bot.identity_user, response.user
    assert_equal "Hello there!", response.content
    assert_equal 'bot', response.message_type
    assert_not_empty client.calls
    assert_equal 'gpt-test', client.calls.first[:model]
  end

  test "adds bot to public channels before responding" do
    client = FakeClient.new({ content: "Sure" })
    @channel.channel_memberships.where(user_id: @bot.identity_user_id).delete_all

    LiteLlm::Client.stub :new, ->(**_kwargs) { client } do
      Bots::ResponderJob.perform_now(@bot.id, @message.id, 'mention')
    end

    assert @channel.members.exists?(id: @bot.identity_user_id)
  end

  test "skips response when LiteLLM host missing" do
    Setting.where(key: 'litellm_host').delete_all

    client = FakeClient.new({ content: "This should not be used" })

    LiteLlm::Client.stub :new, ->(**_kwargs) { client } do
      Bots::ResponderJob.perform_now(@bot.id, @message.id, 'mention')
    end

    assert_equal 1, @channel.messages.count
  end

  test "does not respond inside private channel without membership" do
    private_channel = Channel.create!(name: 'secret', description: 'Private', channel_type: 'private', created_by: @user)
    private_channel.add_member(@user)
    message = private_channel.messages.create!(user: @user, content: 'Private hello', message_type: 'chat')

    client = FakeClient.new({ content: "Hidden" })

    LiteLlm::Client.stub :new, ->(**_kwargs) { client } do
      Bots::ResponderJob.perform_now(@bot.id, message.id, 'mention')
    end

    assert_equal 1, private_channel.messages.count
  end

  test "broadcasts typing indicators while responding" do
    client = FakeClient.new({ content: "Typing..." })
    broadcasts = []

    LiteLlm::Client.stub :new, ->(**_kwargs) { client } do
      ActionCable.server.stub :broadcast, ->(stream, payload) {
        broadcasts << [stream, payload]
        true
      } do
        Bots::ResponderJob.perform_now(@bot.id, @message.id, 'mention')
      end
    end

    typing_payloads = broadcasts.select { |stream, _| stream == "typing:#{@channel.id}" }.map(&:last)
    assert_equal 2, typing_payloads.size
    assert_equal [true, false], typing_payloads.map { |payload| payload[:typing] }
    assert_equal @bot.identity_user.username, typing_payloads.first[:username]
  end
end
