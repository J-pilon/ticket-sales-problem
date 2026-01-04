# frozen_string_literal: true

class PurchaseTicketJob < ApplicationJob
  queue_as :default

  # Retry on API errors with exponential backoff
  retry_on ExternalTicketBooking::Error, wait: :exponentially_longer, attempts: 5
  retry_on HttpClient::Error, wait: :exponentially_longer, attempts: 5

  # Discard on argument errors (these won't succeed on retry)
  discard_on ArgumentError

  def perform(event_code:, event_date:, price:, quantity:, user_email:, base_url: nil)
    booking = ExternalTicketBooking.new(base_url: base_url)
    booking.purchase_ticket(
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity
    )

    Rails.logger.info "Successfully purchased #{quantity} ticket(s) for event #{event_code}"

    # Send confirmation email after successful purchase
    send_confirmation_email(
      email: user_email,
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity
    )
  rescue ExternalTicketBooking::Error, HttpClient::Error => e
    Rails.logger.error "Failed to purchase ticket for event #{event_code}: #{e.message}"
    raise # Re-raise to trigger retry mechanism
  end

  private

  def send_confirmation_email(email:, event_code:, event_date:, price:, quantity:)
    return if email.blank?

    UserMailer.confirmation(
      email: email,
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity
    ).deliver_later
  rescue StandardError => e
    # Log email errors but don't fail the purchase
    Rails.logger.error "Failed to send confirmation email for event #{event_code}: #{e.message}"
  end
end
