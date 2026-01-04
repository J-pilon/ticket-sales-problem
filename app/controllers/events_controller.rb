# frozen_string_literal: true

class EventsController < ApplicationController
  def index
    @events = fetch_and_sort_events
  rescue ExternalTicketBooking::Error, HttpClient::Error => e
    @error = "Unable to load events: #{e.message}"
    @events = []
  end

  def show
    @event = fetch_event_by_code(params[:event_code])
    if @event.nil?
      redirect_to root_path, alert: "Event not found"
    end
  rescue ExternalTicketBooking::Error, HttpClient::Error => e
    @error = "Unable to load event details: #{e.message}"
    @event = nil
  end

  def purchase
    @event = fetch_event_by_code(params[:event_code])

    if @event.nil?
      redirect_to root_path, alert: "Event not found"
      return
    end

    event_code = @event["eventCode"] || @event[:eventCode]
    event_date = @event["eventDate"] || @event[:eventDate]
    price = @event["price"] || @event[:price]
    quantity = params[:quantity].to_i
    quantity = 1 if quantity <= 0 # Default to 1 ticket if not specified or invalid

    # Enqueue the purchase job to handle the API call asynchronously
    PurchaseTicketJob.perform_later(
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity,
      user_email: current_user.email,
      base_url: ticket_booking_base_url
    )

    redirect_to event_path(event_code), notice: "Ticket purchase request has been queued. You will receive confirmation shortly."
  end

  private

  def fetch_and_sort_events
    booking = ExternalTicketBooking.new(base_url: ticket_booking_base_url)
    events = booking.get_tickets

    # Ensure we have an array
    events = [ events ] unless events.is_a?(Array)

    # Sort by eventDate (upcoming first)
    events.sort_by do |event|
      parse_event_date(event["eventDate"] || event[:eventDate])
    end
  end

  def fetch_event_by_code(event_code)
    booking = ExternalTicketBooking.new(base_url: ticket_booking_base_url)
    events = booking.get_tickets(event_code: event_code)

    # Ensure we have an array
    events = [ events ] unless events.is_a?(Array)

    # Find the matching event
    events.find do |event|
      (event["eventCode"] || event[:eventCode]) == event_code
    end
  end

  def parse_event_date(date_string)
    return Time.current if date_string.nil?

    # Parse ISO 8601 datetime string
    Time.parse(date_string.to_s)
  rescue ArgumentError
    Time.current
  end

  def ticket_booking_base_url
    ENV.fetch("TICKET_BOOKING_API_URL", "http://localhost:3001")
  end
end
