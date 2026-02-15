require "test_helper"

class Bots::DispatcherTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    clear_enqueued_jobs
    Setting.set(:litellm_default_model, 'gpt-test')
    Setting.set(:litellm_api_key, 'test-key')
    @bot = Bot.create!(name: 'helper_bot', bot_type: 'ai', instructions: 'Be helpful.')
    @user = create_user(username: 'alice')
    @channel = Channel.create!(name: 'general', description: 'General chat', channel_type: 'public', created_by: @user)
    @channel.add_member(@user)
  end

  teardown do
    clear_enqueued_jobs
    Setting.where(key: 'litellm_default_model').delete_all
    Setting.where(key: 'litellm_api_key').delete_all
  end

  test "dispatches responder job when bot is mentioned" do
    message = nil
    assert_enqueued_jobs 1, only: Bots::ResponderJob do
      message = @channel.messages.create!(user: @user, content: 'Hey @helper_bot can you help?', message_type: 'chat')
    end

    job = enqueued_jobs.last
    assert_equal [@bot.id, message.id, 'mention'], job[:args]
  end

  test "dispatches responder job for direct messages with bot" do
    dm_channel = Channel.create!(name: 'dm-alice-helper_bot', channel_type: 'dm', created_by: @user)
    dm_channel.add_member(@user)
    dm_channel.add_member(@bot.identity_user)

    message = nil
    assert_enqueued_jobs 1, only: Bots::ResponderJob do
      message = dm_channel.messages.create!(user: @user, content: 'Hello there', message_type: 'chat')
    end

    job = enqueued_jobs.last
    assert_equal [@bot.id, message.id, 'direct_message'], job[:args]
  end

  test "does not enqueue when no ai bots active" do
    @bot.update!(active: false)

    assert_no_enqueued_jobs only: Bots::ResponderJob do
      @channel.messages.create!(user: @user, content: 'Ping @helper_bot', message_type: 'chat')
    end
  end

  test "ignores messages posted by bot identity" do
    @channel.add_member(@bot.identity_user)

    assert_no_enqueued_jobs only: Bots::ResponderJob do
      @channel.messages.create!(user: @bot.identity_user, content: 'Status update', message_type: 'bot')
    end
  end
end
