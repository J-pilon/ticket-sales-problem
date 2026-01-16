# frozen_string_literal: true

module Retryable
  extend ActiveSupport::Concern

  MAX_ATTEMPTS = 5

  included do
    retry_on ExternalTicketBooking::Error, wait: :exponentially_longer, attempts: MAX_ATTEMPTS
    retry_on HttpClient::Error, wait: :exponentially_longer, attempts: MAX_ATTEMPTS
    discard_on ArgumentError
  end

  def with_retry_tracking(record:, context: nil)
    yield
  rescue ExternalTicketBooking::Error, HttpClient::Error => e
    log_retry_error(e, context: context)
    mark_as_failed_on_final_attempt(record, e)
    raise
  end

  private

  def log_retry_error(error, context: nil)
    message = "Retryable error"
    message = "#{message} (#{context})" if context.present?
    message = "#{message}: #{error.message}"
    Rails.logger.error message
  end

  def mark_as_failed_on_final_attempt(record, error)
    return unless final_attempt?

    record&.update!(
      status: "failed",
      error_message: error.message,
      completed_at: Time.current
    )
  end

  def final_attempt?
    executions >= MAX_ATTEMPTS
  end
end
