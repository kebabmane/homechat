require "test_helper"

class Api::V1::TwoFactorControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = create_user(username: "twofa_user", password: "password123")
    @token = ApiToken.create!(name: "2FA Test Token - #{SecureRandom.hex(4)}", user: @user, scopes: nil)
    @raw_token = @token.token
    @auth_headers = { "Authorization" => "Bearer #{@raw_token}" }
  end

  # -------------------------
  # GET /api/v1/2fa/status
  # -------------------------

  test "status returns disabled when 2FA not set up" do
    get api_v1_2fa_status_path, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal false, json["enabled"]
    assert json.key?("available")
  end

  test "status returns enabled when 2FA is active" do
    @user.otp_secret = ROTP::Base32.random_base32
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ "AAAAAAAA" ]
    @user.save!

    get api_v1_2fa_status_path, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["enabled"]
  end

  test "status requires authentication" do
    get api_v1_2fa_status_path

    assert_response :unauthorized
  end

  # -------------------------
  # POST /api/v1/2fa/setup
  # -------------------------

  test "setup generates a secret and provisioning URI" do
    post api_v1_2fa_setup_path, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["secret"].present?
    assert json["provisioning_uri"].present?
    assert_match /otpauth:\/\/totp\//, json["provisioning_uri"]
  end

  test "setup saves otp_secret to user" do
    post api_v1_2fa_setup_path, headers: @auth_headers

    assert_response :success
    @user.reload
    assert @user.otp_secret.present?
  end

  test "setup returns error when 2FA already enabled" do
    @user.otp_secret = ROTP::Base32.random_base32
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ "AAAAAAAA" ]
    @user.save!

    post api_v1_2fa_setup_path, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "setup requires authentication" do
    post api_v1_2fa_setup_path

    assert_response :unauthorized
  end

  # -------------------------
  # POST /api/v1/2fa/verify
  # -------------------------

  test "verify enables 2FA with valid OTP code" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.save!

    totp = ROTP::TOTP.new(secret)
    valid_code = totp.now

    post api_v1_2fa_verify_path, params: { code: valid_code }, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["backup_codes"].present?
    assert_equal 10, json["backup_codes"].length

    @user.reload
    assert @user.two_factor_enabled?
  end

  test "verify returns error for blank code" do
    @user.otp_secret = ROTP::Base32.random_base32
    @user.save!

    post api_v1_2fa_verify_path, params: { code: "" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "verify returns error when no secret set up" do
    post api_v1_2fa_verify_path, params: { code: "123456" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /setup/i, json["error"]
  end

  test "verify returns error for invalid OTP code" do
    @user.otp_secret = ROTP::Base32.random_base32
    @user.save!

    post api_v1_2fa_verify_path, params: { code: "000000" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /invalid/i, json["error"]
  end

  test "verify requires authentication" do
    post api_v1_2fa_verify_path, params: { code: "123456" }

    assert_response :unauthorized
  end

  # -------------------------
  # POST /api/v1/2fa/disable
  # -------------------------

  test "disable turns off 2FA with valid password and OTP" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("TESTCODE") ]
    @user.save!

    totp = ROTP::TOTP.new(secret)
    valid_code = totp.now

    post api_v1_2fa_disable_path,
         params: { password: "password123", code: valid_code },
         headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]

    @user.reload
    assert_not @user.two_factor_enabled?
  end

  test "disable returns error for blank password or code" do
    post api_v1_2fa_disable_path, params: { password: "", code: "" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "disable returns error for wrong password" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("TESTCODE") ]
    @user.save!

    totp = ROTP::TOTP.new(secret)
    valid_code = totp.now

    post api_v1_2fa_disable_path,
         params: { password: "wrongpassword", code: valid_code },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /invalid password/i, json["error"]
  end

  test "disable requires authentication" do
    post api_v1_2fa_disable_path, params: { password: "password123", code: "123456" }

    assert_response :unauthorized
  end

  # -------------------------
  # GET /api/v1/2fa/backup_codes
  # -------------------------

  test "backup_codes returns remaining count with valid OTP" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("TESTCODE") ]
    @user.save!

    totp = ROTP::TOTP.new(secret)
    valid_code = totp.now

    get api_v1_2fa_backup_codes_path, params: { code: valid_code }, headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal true, json["success"]
    assert_equal 1, json["remaining_count"]
    assert_not json.key?("backup_codes")
  end

  test "backup_codes returns error for blank code" do
    get api_v1_2fa_backup_codes_path, params: { code: "" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "backup_codes returns error for invalid OTP" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("TESTCODE") ]
    @user.save!

    get api_v1_2fa_backup_codes_path, params: { code: "000000" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /invalid/i, json["error"]
  end

  test "backup_codes requires authentication" do
    get api_v1_2fa_backup_codes_path, params: { code: "123456" }

    assert_response :unauthorized
  end

  # -------------------------
  # POST /api/v1/2fa/regenerate_backup_codes
  # -------------------------

  test "regenerate_backup_codes returns new codes with valid OTP" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("OLDCODE1") ]
    @user.save!

    totp = ROTP::TOTP.new(secret)
    valid_code = totp.now

    post api_v1_2fa_regenerate_backup_codes_path,
         params: { code: valid_code },
         headers: @auth_headers

    assert_response :success
    json = JSON.parse(response.body)
    assert json["success"]
    assert json["backup_codes"].present?
    assert_equal 10, json["backup_codes"].length
  end

  test "regenerate_backup_codes returns error for blank code" do
    post api_v1_2fa_regenerate_backup_codes_path, params: { code: "" }, headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert json["error"].present?
  end

  test "regenerate_backup_codes returns error for invalid OTP" do
    secret = ROTP::Base32.random_base32
    @user.otp_secret = secret
    @user.otp_required_for_login = true
    @user.otp_backup_codes = [ BCrypt::Password.create("TESTCODE") ]
    @user.save!

    post api_v1_2fa_regenerate_backup_codes_path,
         params: { code: "000000" },
         headers: @auth_headers

    assert_response :unprocessable_entity
    json = JSON.parse(response.body)
    assert_match /invalid/i, json["error"]
  end

  test "regenerate_backup_codes requires authentication" do
    post api_v1_2fa_regenerate_backup_codes_path, params: { code: "123456" }

    assert_response :unauthorized
  end
end
