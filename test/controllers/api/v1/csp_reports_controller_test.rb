require "test_helper"

class Api::V1::CspReportsControllerTest < ActionDispatch::IntegrationTest
  test "accepts valid csp reports without authentication" do
    log_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)

    Rails.stub(:logger, logger) do
      post "/api/v1/csp_reports",
           params: {
             "csp-report" => {
               "document-uri" => "https://chat.example.test/",
               "violated-directive" => "script-src",
               "blocked-uri" => "inline",
               "source-file" => "https://chat.example.test/assets/app.js",
               "line-number" => 42,
               "script-sample" => "sensitive inline sample"
             }
           }.to_json,
           headers: { "CONTENT_TYPE" => "application/csp-report" }
    end

    assert_response :no_content
    assert_includes log_output.string, "script-src"
    assert_not_includes log_output.string, "script-sample"
  end

  test "ignores malformed reports" do
    log_output = StringIO.new
    logger = ActiveSupport::Logger.new(log_output)

    Rails.stub(:logger, logger) do
      post "/api/v1/csp_reports",
           params: "{not-json",
           headers: { "CONTENT_TYPE" => "application/csp-report" }
    end

    assert_response :no_content
    assert_not_includes log_output.string, "[CSP Report] Parse error"
  end
end
