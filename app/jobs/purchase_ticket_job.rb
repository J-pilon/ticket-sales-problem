# frozen_string_literal: true

class PurchaseTicketJob < ApplicationJob
  queue_as :default

  # Retry on API errors with exponential backoff
  retry_on ExternalTicketBooking::Error, wait: :exponentially_longer, attempts: 5
  retry_on HttpClient::Error, wait: :exponentially_longer, attempts: 5

  # Discard on argument errors (these won't succeed on retry)
  discard_on ArgumentError

  def perform(event_code:, event_date:, price:, quantity:, base_url: nil)
    booking = ExternalTicketBooking.new(base_url: base_url)
    booking.purchase_ticket(
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity
    )

    Rails.logger.info "Successfully purchased #{quantity} ticket(s) for event #{event_code}"
  rescue ExternalTicketBooking::Error, HttpClient::Error => e
    Rails.logger.error "Failed to purchase ticket for event #{event_code}: #{e.message}"
    raise # Re-raise to trigger retry mechanism
  end
end
