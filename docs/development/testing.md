# Testing Guide

This guide covers running and writing tests for HomeChat.

## Test Overview

HomeChat uses Rails' built-in testing framework with additional tools:

| Type | Location | Purpose |
|------|----------|---------|
| Unit | `test/models/` | Model validations and logic |
| Controller | `test/controllers/` | Request/response testing |
| Integration | `test/integration/` | Multi-step workflows |
| System | `test/system/` | Browser-based testing |

## Running Tests

### All Tests

```bash
bin/rails test
```

### Specific Test Types

```bash
# Model tests
bin/rails test:models

# Controller tests
bin/rails test:controllers

# Integration tests
bin/rails test:integration

# System tests (requires browser)
bin/rails test:system
```

### Single Test File

```bash
bin/rails test test/models/user_test.rb
```

### Single Test Method

```bash
bin/rails test test/models/user_test.rb:15
```

### With Verbose Output

```bash
bin/rails test -v
```

## Test Coverage

### Generate Coverage Report

```bash
COVERAGE=true bin/rails test
```

Coverage report is generated at `coverage/index.html`.

### Current Coverage

| Area | Coverage |
|------|----------|
| Overall | ~24% |
| Models | ~40% |
| Controllers | ~20% |
| Helpers | ~10% |

**Goal**: Improve coverage to 80%+ for critical paths.

## Writing Tests

### Model Tests

Test validations, associations, and business logic:

```ruby
# test/models/user_test.rb
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "requires username" do
    user = User.new(password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "can't be blank"
  end

  test "username must be unique" do
    existing = users(:admin)
    user = User.new(username: existing.username, password: "password123")
    assert_not user.valid?
    assert_includes user.errors[:username], "has already been taken"
  end

  test "first user becomes admin" do
    User.delete_all
    user = User.create!(username: "first", password: "password123")
    assert_equal "admin", user.role
  end

  test "authenticate with correct password" do
    user = users(:regular)
    assert user.authenticate("password")
  end

  test "reject incorrect password" do
    user = users(:regular)
    assert_not user.authenticate("wrong")
  end
end
```

### Controller Tests

Test request handling and responses:

```ruby
# test/controllers/api/v1/messages_controller_test.rb
require "test_helper"

class Api::V1::MessagesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @token = api_tokens(:valid)
    @channel = channels(:general)
  end

  test "create message with valid token" do
    post api_v1_messages_path,
      params: { message: { content: "Hello", channel_id: @channel.id } },
      headers: { "Authorization" => "Bearer #{@token.raw_token}" }

    assert_response :created
    assert_equal "Hello", JSON.parse(response.body)["content"]
  end

  test "reject without token" do
    post api_v1_messages_path,
      params: { message: { content: "Hello", channel_id: @channel.id } }

    assert_response :unauthorized
  end

  test "reject with invalid token" do
    post api_v1_messages_path,
      params: { message: { content: "Hello", channel_id: @channel.id } },
      headers: { "Authorization" => "Bearer invalid_token" }

    assert_response :unauthorized
  end
end
```

### Integration Tests

Test multi-step workflows:

```ruby
# test/integration/user_signup_test.rb
require "test_helper"

class UserSignupTest < ActionDispatch::IntegrationTest
  test "complete signup flow" do
    # Visit signup page
    get signup_path
    assert_response :success

    # Submit signup form
    post users_path, params: {
      user: { username: "newuser", password: "password123" }
    }
    assert_response :redirect
    follow_redirect!

    # Verify logged in
    assert_select "nav", text: /newuser/
  end

  test "signup disabled when setting is off" do
    Setting.set("allow_signups", "false")

    get signup_path
    assert_response :redirect
    assert_redirected_to login_path
  end
end
```

### System Tests

Test with real browser interaction:

```ruby
# test/system/channels_test.rb
require "application_system_test_case"

class ChannelsTest < ApplicationSystemTestCase
  setup do
    @user = users(:regular)
    login_as(@user)
  end

  test "create new channel" do
    visit channels_path
    click_on "New Channel"

    fill_in "Name", with: "Test Channel"
    fill_in "Description", with: "A test channel"
    click_on "Create"

    assert_text "Test Channel"
    assert_text "A test channel"
  end

  test "send message in channel" do
    channel = channels(:general)
    visit channel_path(channel)

    fill_in "message_content", with: "Hello, world!"
    click_on "Send"

    assert_text "Hello, world!"
  end
end
```

## Test Fixtures

Fixtures provide test data in `test/fixtures/`:

```yaml
# test/fixtures/users.yml
admin:
  username: admin
  password_digest: <%= BCrypt::Password.create('password') %>
  role: admin

regular:
  username: regular
  password_digest: <%= BCrypt::Password.create('password') %>
  role: user

# test/fixtures/channels.yml
general:
  name: general
  description: General discussion
  channel_type: public
  created_by: admin

# test/fixtures/api_tokens.yml
valid:
  name: valid-token
  token_digest: <%= BCrypt::Password.create('test_token_secret') %>
  token_prefix: test_tok
  user: admin
  active: true
```

## Test Helpers

Create helpers in `test/test_helper.rb`:

```ruby
class ActiveSupport::TestCase
  # Login helper for integration tests
  def login_as(user, password: "password")
    post session_path, params: {
      username: user.username,
      password: password
    }
  end

  # API authentication helper
  def api_headers(token)
    { "Authorization" => "Bearer #{token.raw_token}" }
  end

  # Create message helper
  def create_message(channel:, user:, content: "Test message")
    Message.create!(
      channel: channel,
      user: user,
      content: content
    )
  end
end
```

## Mocking External Services

### WebMock for HTTP

```ruby
# test/test_helper.rb
require 'webmock/minitest'

# Disable external requests
WebMock.disable_net_connect!(allow_localhost: true)
```

```ruby
# In tests
test "sends push notification" do
  stub_request(:post, "https://fcm.googleapis.com/v1/projects/...")
    .to_return(status: 200, body: '{"name": "message-id"}')

  PushNotificationJob.perform_now(user, "Test message")

  assert_requested :post, "https://fcm.googleapis.com/v1/projects/..."
end
```

### Stub LiteLLM

```ruby
test "bot responds to mention" do
  stub_request(:post, "http://localhost:4000/chat/completions")
    .to_return(
      status: 200,
      body: { choices: [{ message: { content: "Bot response" } }] }.to_json
    )

  @bot.respond_to("Hello bot!")

  assert_equal "Bot response", @bot.last_response
end
```

## CI/CD Integration

### GitHub Actions

```yaml
# .github/workflows/test.yml
name: Test

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - uses: ruby/setup-ruby@v1
        with:
          ruby-version: '3.3'
          bundler-cache: true

      - name: Setup database
        run: bin/rails db:prepare

      - name: Run tests
        run: bin/rails test

      - name: Run system tests
        run: bin/rails test:system
```

## Testing Best Practices

### Do

- Test behavior, not implementation
- Use descriptive test names
- One assertion focus per test
- Clean up after tests
- Test edge cases and error conditions
- Mock external services

### Don't

- Test Rails/gem internals
- Share state between tests
- Use sleep or timing-dependent tests
- Test private methods directly
- Create unnecessary database records

### Priority Areas

Focus testing efforts on:

1. **Authentication/Authorization** — Security critical
2. **API endpoints** — Public interface
3. **Message handling** — Core functionality
4. **Bot interactions** — Complex logic
5. **Channel permissions** — Access control

## Debugging Tests

### Verbose Output

```bash
bin/rails test -v
```

### Debug in Test

```ruby
test "something complex" do
  # ... setup ...

  debugger  # Stops here in test

  # ... assertions ...
end
```

### View System Test Screenshots

Failed system tests save screenshots to `tmp/screenshots/`.

## Related Documentation

- [Development Setup](setup.md)
- [Contributing Guide](../../CONTRIBUTING.md)
- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
