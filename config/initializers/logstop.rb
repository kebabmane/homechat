# frozen_string_literal: true

# Logstop filters sensitive data from logs:
# - Email addresses
# - Phone numbers
# - Credit card numbers
# - Social Security numbers
# - Passwords in URLs
# - IP addresses (enabled with ip: true)
#
# This complements Rails' filter_parameters which only filters
# request parameters, not arbitrary log messages.
#
# See: https://github.com/ankane/logstop

Logstop.guard(Rails.logger, ip: true)
