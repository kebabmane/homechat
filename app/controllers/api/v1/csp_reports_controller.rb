# 2.5: CSP violation report receiver.
#
# Browsers POST here when a Content-Security-Policy violation occurs.
# Reports are logged for monitoring; once no violations are seen,
# :unsafe_inline can be removed from script_src and report-only mode
# can be disabled to enforce the policy.
class Api::V1::CspReportsController < ApplicationController
  protect_from_forgery with: :null_session
  skip_before_action :verify_authenticity_token

  def create
    body = request.body.read
    report = JSON.parse(body)&.dig("csp-report") rescue nil

    if report.present?
      Rails.logger.warn "[CSP Violation] #{report.slice('document-uri', 'violated-directive', 'blocked-uri', 'source-file', 'line-number').to_json}"
    end

    head :no_content
  rescue => e
    Rails.logger.error "[CSP Report] Parse error: #{e.class}"
    head :no_content
  end
end
