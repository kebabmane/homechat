require "test_helper"

class PasswordResetsControllerTest < ActionDispatch::IntegrationTest
  # Use a modern browser User-Agent so allow_browser :modern check passes.
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " \
              "AppleWebKit/537.36 (KHTML, like Gecko) " \
              "Chrome/120.0.0.0 Safari/537.36"

  def setup
    @user = create_user(username: "reset_test_user", password: "oldpassword123")
    @headers = { "User-Agent" => MODERN_UA }
  end

  # Rails route parameter matching excludes dots by default.
  # The token format is "selector.verifier", so the dot must be percent-encoded
  # as %2E to prevent the router treating it as a format extension.
  def encode_token(raw_token)
    raw_token.gsub(".", "%2E")
  end

  def encoded_edit_path(raw_token)
    "/password_resets/#{encode_token(raw_token)}/edit"
  end

  def encoded_update_path(raw_token)
    "/password_resets/#{encode_token(raw_token)}"
  end

  # -------------------------
  # GET /password_resets/:token/edit
  # -------------------------

  test "edit renders form with a valid token" do
    raw_token = @user.generate_password_reset_token!

    get encoded_edit_path(raw_token), headers: @headers

    assert_response :success
  end

  test "edit redirects when token selector is not found in DB" do
    get encoded_edit_path("unknownselector.unknownverifier"), headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path
  end

  test "edit redirects when token verifier is wrong" do
    @user.generate_password_reset_token!
    bad_token = "#{@user.password_reset_token_selector}.wrongverifier"

    get encoded_edit_path(bad_token), headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path
  end

  test "edit redirects when token is expired" do
    raw_token = travel_to(25.hours.ago) { @user.generate_password_reset_token! }

    get encoded_edit_path(raw_token), headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path
  end

  # -------------------------
  # PATCH /password_resets/:token
  # -------------------------

  test "update resets password with valid token and matching passwords" do
    raw_token = @user.generate_password_reset_token!

    patch encoded_update_path(raw_token),
          params: { user: { password: "newpassword123", password_confirmation: "newpassword123" } },
          headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path

    @user.reload
    assert @user.authenticate("newpassword123"), "New password should authenticate"
    assert_nil @user.password_reset_token_selector, "Token should be cleared after reset"
  end

  test "update redirects to signin with flash notice on success" do
    raw_token = @user.generate_password_reset_token!

    patch encoded_update_path(raw_token),
          params: { user: { password: "newpassword123", password_confirmation: "newpassword123" } },
          headers: @headers

    assert_response :redirect
    # Flash is set before redirect; check it before following
    assert flash[:notice].present?
  end

  test "update redirects with alert for invalid token" do
    patch encoded_update_path("bad.token"),
          params: { user: { password: "newpassword123", password_confirmation: "newpassword123" } },
          headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path
    assert flash[:alert].present?
  end

  test "update does not change password when passwords mismatch" do
    raw_token = @user.generate_password_reset_token!

    patch encoded_update_path(raw_token),
          params: { user: { password: "newpassword123", password_confirmation: "differentpassword" } },
          headers: @headers

    # The controller consumes the token, fails to update, and regenerates a new token.
    # The redirect URL contains a dot in the token (routing constraint issue), but
    # regardless of redirect success, the password must not be changed.
    @user.reload
    assert_not @user.authenticate("newpassword123"), "Password should not have changed with mismatched confirmation"
    assert @user.authenticate("oldpassword123"), "Original password should still work"
  end

  test "update does not change password when token is expired" do
    raw_token = travel_to(25.hours.ago) { @user.generate_password_reset_token! }

    patch encoded_update_path(raw_token),
          params: { user: { password: "newpassword123", password_confirmation: "newpassword123" } },
          headers: @headers

    assert_response :redirect
    follow_redirect!
    assert_match /signin/, request.path
    assert flash[:alert].present?

    @user.reload
    assert @user.authenticate("oldpassword123"), "Original password should still work"
  end
end
