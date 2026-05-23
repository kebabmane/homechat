require "test_helper"

class AccountLockableTest < ActiveSupport::TestCase
  test "register_failed_attempt increments counter" do
    user = create_user
    user.register_failed_attempt!
    assert_equal 1, user.failed_attempts
    assert_not_nil user.last_failed_at
  end

  test "locks account after max failed attempts" do
    user = create_user

    AccountLockable::MAX_FAILED_ATTEMPTS.times do
      user.register_failed_attempt!
      user.reload
    end

    assert user.locked?
    assert_not_nil user.locked_until
    assert user.locked_until > Time.current
  end

  test "find_for_authentication rejects locked user" do
    user = create_user
    user.lock_access!

    result = User.find_for_authentication(username: user.username)
    assert_nil result
  end

  test "find_for_authentication returns user when not locked" do
    user = create_user
    result = User.find_for_authentication(username: user.username)
    assert_equal user, result
  end

  test "clear_failed_attempts resets state" do
    user = create_user
    user.register_failed_attempt!
    user.lock_access!

    user.clear_failed_attempts!
    user.reload

    assert_equal 0, user.failed_attempts
    assert_nil user.locked_until
    assert_nil user.last_failed_at
  end

  test "remaining_attempts decreases with each failure" do
    user = create_user
    assert_equal 5, user.remaining_attempts

    user.register_failed_attempt!
    user.reload
    assert_equal 4, user.remaining_attempts
  end

  test "unlock_access clears lock state" do
    user = create_user
    user.lock_access!
    assert user.locked?

    user.unlock_access!
    user.reload
    assert_not user.locked?
    assert_equal 0, user.failed_attempts
  end

  test "lockout_remaining_time returns minutes until unlock" do
    user = create_user
    user.lock_access!
    assert user.lockout_remaining_time.is_a?(Integer)
    assert user.lockout_remaining_time > 0
  end

  test "failed attempts reset after inactivity period" do
    user = create_user
    user.register_failed_attempt!
    assert_equal 1, user.failed_attempts

    travel_to (AccountLockable::FAILED_ATTEMPT_RESET_AFTER + 1.minute).from_now do
      user.register_failed_attempt!
      assert_equal 1, user.failed_attempts # counter was reset before incrementing
    end
  end
end
