require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  def setup
    @user = create_user(username: "audit_log_user", password: "password123")
  end

  # -------------------------
  # AuditLog.log
  # -------------------------

  test "log creates a record with correct action and resource fields" do
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:user_created],
      resource: @user
    )

    assert_not_nil log
    assert_equal "user.created", log.action
    assert_equal "User", log.resource_type
    assert_equal @user.id, log.resource_id
  end

  test "log creates a record with user association" do
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:login_success],
      user: @user,
      resource: @user
    )

    assert_not_nil log
    assert_equal @user.id, log.user_id
  end

  test "log stores ip_address and user_agent" do
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:login_success],
      resource: @user,
      ip_address: "192.168.1.1",
      user_agent: "TestBrowser/1.0"
    )

    assert_equal "192.168.1.1", log.ip_address
    assert_equal "TestBrowser/1.0", log.user_agent
  end

  test "log redacts sensitive changes_made data" do
    changes = { "username" => [ "old_name", "new_name" ] }
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:user_updated],
      resource: @user,
      changes: changes
    )

    assert_not_nil log
    assert_equal({ "username" => "[REDACTED]" }, log.changes_made)
  end

  test "log stores metadata" do
    metadata = { "reason" => "test" }
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:user_updated],
      resource: @user,
      metadata: metadata
    )

    assert_equal metadata, log.metadata
  end

  test "log uses System as resource_type when resource is nil" do
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:settings_updated]
    )

    assert_not_nil log
    assert_equal "System", log.resource_type
    assert_nil log.resource_id
  end

  test "log truncates long user_agent to 500 chars" do
    long_agent = "A" * 600
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:login_success],
      resource: @user,
      user_agent: long_agent
    )

    assert log.user_agent.length <= 500
  end

  test "log rescues errors silently and returns nil" do
    # Simulate a DB error by providing an invalid action (nil violates presence validation)
    result = AuditLog.log(action: nil, resource: @user)

    assert_nil result
  end

  test "log persists the record to the database" do
    assert_difference("AuditLog.count", 1) do
      AuditLog.log(
        action: AuditLog::ACTIONS[:channel_created],
        resource: @user
      )
    end
  end

  # -------------------------
  # AuditLog.log_admin_action
  # -------------------------

  test "log_admin_action creates record with admin context" do
    admin = create_user(username: "audit_admin", role: "admin", password: "password123")

    request = Minitest::Mock.new
    request.expect :remote_ip, "10.0.0.1"
    request.expect :user_agent, "AdminBrowser/2.0"

    log = AuditLog.log_admin_action(
      action: AuditLog::ACTIONS[:user_role_changed],
      admin: admin,
      resource: @user,
      request: request
    )

    assert_not_nil log
    assert_equal admin.id, log.user_id
    assert_equal "User", log.resource_type
    assert_equal @user.id, log.resource_id
    assert_equal "10.0.0.1", log.ip_address
    assert_equal "AdminBrowser/2.0", log.user_agent

    request.verify
  end

  test "log_admin_action sets admin_action metadata flag" do
    admin = create_user(username: "audit_admin2", role: "admin", password: "password123")

    request = Minitest::Mock.new
    request.expect :remote_ip, "10.0.0.2"
    request.expect :user_agent, "AdminBrowser/3.0"

    log = AuditLog.log_admin_action(
      action: AuditLog::ACTIONS[:user_locked],
      admin: admin,
      resource: @user,
      request: request,
      metadata: { "note" => "suspicious activity" }
    )

    assert_not_nil log
    assert log.admin_action?, "Expected admin_action? to be true"

    request.verify
  end

  # -------------------------
  # Scopes
  # -------------------------

  test "recent scope orders by created_at descending" do
    older_log = AuditLog.log(action: AuditLog::ACTIONS[:login_success], resource: @user)
    travel 1.second do
      newer_log = AuditLog.log(action: AuditLog::ACTIONS[:logout], resource: @user)
      recent = AuditLog.recent.limit(2).to_a
      assert_equal newer_log.id, recent.first.id
      assert_equal older_log.id, recent.last.id
    end
  end

  test "for_user scope filters by user" do
    other_user = create_user(username: "audit_other_user", password: "password123")
    my_log = AuditLog.log(action: AuditLog::ACTIONS[:login_success], user: @user, resource: @user)
    AuditLog.log(action: AuditLog::ACTIONS[:login_success], user: other_user, resource: other_user)

    logs_for_user = AuditLog.for_user(@user)
    assert_includes logs_for_user.map(&:id), my_log.id
    logs_for_user.each { |l| assert_equal @user.id, l.user_id }
  end

  test "for_resource scope filters by resource type and id" do
    log = AuditLog.log(action: AuditLog::ACTIONS[:user_updated], resource: @user)

    results = AuditLog.for_resource("User", @user.id)
    assert_includes results.map(&:id), log.id
    results.each do |l|
      assert_equal "User", l.resource_type
      assert_equal @user.id, l.resource_id
    end
  end

  test "by_action scope filters by action string" do
    AuditLog.log(action: AuditLog::ACTIONS[:login_success], resource: @user)
    AuditLog.log(action: AuditLog::ACTIONS[:logout], resource: @user)

    results = AuditLog.by_action(AuditLog::ACTIONS[:login_success])
    assert results.all? { |l| l.action == "auth.login_success" }
  end

  test "since scope filters records after a given time" do
    old_log = travel_to(2.days.ago) do
      AuditLog.log(action: AuditLog::ACTIONS[:login_success], resource: @user)
    end
    new_log = AuditLog.log(action: AuditLog::ACTIONS[:logout], resource: @user)

    results = AuditLog.since(1.day.ago)
    assert_includes results.map(&:id), new_log.id
    assert_not_includes results.map(&:id), old_log.id
  end

  # -------------------------
  # Instance methods
  # -------------------------

  test "admin_action? returns false when metadata does not have admin_action flag" do
    log = AuditLog.log(action: AuditLog::ACTIONS[:login_success], resource: @user)
    assert_not log.admin_action?
  end

  test "admin_action? returns true when metadata has admin_action: true" do
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:user_role_changed],
      resource: @user,
      metadata: { "admin_action" => true }
    )
    assert log.admin_action?
  end

  test "changes_summary returns nil when changes_made is blank" do
    log = AuditLog.log(action: AuditLog::ACTIONS[:login_success], resource: @user)
    assert_nil log.changes_summary
  end

  test "changes_summary returns human-readable string for changes" do
    changes = { "username" => [ "old_name", "new_name" ] }
    log = AuditLog.log(
      action: AuditLog::ACTIONS[:user_updated],
      resource: @user,
      changes: changes
    )

    summary = log.changes_summary
    assert_not_nil summary
    assert_match /username/, summary
    assert_match /\[REDACTED\]/, summary
    assert_no_match /old_name/, summary
    assert_no_match /new_name/, summary
  end

  # -------------------------
  # Validations
  # -------------------------

  test "is invalid without action" do
    log = AuditLog.new(resource_type: "User")
    assert_not log.valid?
    assert_includes log.errors[:action], "can't be blank"
  end

  test "is invalid without resource_type" do
    log = AuditLog.new(action: "auth.login_success")
    assert_not log.valid?
    assert_includes log.errors[:resource_type], "can't be blank"
  end

  test "is valid with required fields" do
    log = AuditLog.new(action: "auth.login_success", resource_type: "User")
    assert log.valid?
  end
end
