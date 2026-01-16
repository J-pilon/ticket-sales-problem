# frozen_string_literal: true

class PurchaseTicketJob < ApplicationJob
  include Retryable

  queue_as :default

  def perform(purchase_record_id:, event_code:, event_date:, price:, quantity:, user_email:, base_url: nil)
    record = PurchaseRecord.find_by(id: purchase_record_id)

    with_retry_tracking(record: record, context: "event #{event_code}") do
      # Call external API
      booking = ExternalTicketBooking.new(base_url: base_url)
      booking.purchase_ticket(
        event_code: event_code,
        event_date: event_date,
        price: price,
        quantity: quantity
      )

      # Mark API as successful
      record&.update!(api_success: true)
      Rails.logger.info "Successfully purchased #{quantity} ticket(s) for event #{event_code}"

      # Send confirmation email
      email_sent = send_confirmation_email(
        email: user_email,
        event_code: event_code,
        event_date: event_date,
        price: price,
        quantity: quantity
      )

      # Mark job as completed
      record&.update!(
        status: "completed",
        email_sent: email_sent,
        completed_at: Time.current
      )
    end
  end

  private

  def send_confirmation_email(email:, event_code:, event_date:, price:, quantity:)
    return false if email.blank?

    UserMailer.confirmation(
      email: email,
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity
    ).deliver_later

    true
  rescue StandardError => e
    # Log email errors but don't fail the purchase
    Rails.logger.error "Failed to send confirmation email for event #{event_code}: #{e.message}"
    false
  end
end
