# frozen_string_literal: true

# Proxy layer for external ticket booking API
class ExternalTicketBooking
  class Error < StandardError; end

  attr_reader :http_client

  def initialize(base_url: nil, timeout: 30, headers: {})
    base_url ||= ENV.fetch("TICKET_BOOKING_API_URL", "https://api.ticketbooking.example.com")
    @http_client = HttpClient.new(base_url: base_url, timeout: timeout, headers: headers)
  end

  def get_tickets(event_code: nil, event_date: nil)
    params = {}
    params[:eventCode] = event_code if event_code
    params[:eventDate] = format_event_date_for_query(event_date) if event_date

    http_client.get("/ExternalTicketBooking/GetTickets", params: params)
  end

  def reserve_ticket(event_code:, event_date:, price: nil, quantity: nil, client_id: nil, seat_code: nil)
    validate_reserve_params(event_code, event_date, price, quantity)

    path = "/ExternalTicketBooking/ReserveTicket"
    path += "/#{seat_code}" if seat_code && !seat_code.to_s.strip.empty?

    body = build_reserve_request_body(
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity,
      client_id: client_id,
      seat_code: seat_code
    )

    http_client.post(path, body: body)
  end

  def purchase_ticket(event_code:, event_date:, price:, quantity:, client_id: nil, seat_code: nil)
    validate_purchase_params(event_code, event_date, price, quantity)

    path = "/ExternalTicketBooking/PurchaseTicket"
    path += "/#{seat_code}" if seat_code && !seat_code.to_s.strip.empty?

    body = build_request_body(
      event_code: event_code,
      event_date: event_date,
      price: price,
      quantity: quantity,
      client_id: client_id,
      seat_code: seat_code
    )

    http_client.post(path, body: body)
  end

  private

  def validate_reserve_params(event_code, event_date, price, quantity)
    raise ArgumentError, "event_code is required" if event_code.nil? || event_code.to_s.strip.empty?
    raise ArgumentError, "event_date is required" if event_date.nil?

    quantity_int = quantity.to_i if quantity
    if quantity_int && quantity_int > 0
      raise ArgumentError, "price is required when quantity > 0" if price.nil?
      raise ArgumentError, "quantity must be greater than 0" if quantity_int <= 0
    end
  end

  def validate_purchase_params(event_code, event_date, price, quantity)
    raise ArgumentError, "event_code is required" if event_code.nil? || event_code.to_s.strip.empty?
    raise ArgumentError, "event_date is required" if event_date.nil?
    raise ArgumentError, "price is required" if price.nil?
    raise ArgumentError, "quantity is required and must be greater than 0" if quantity.nil? || quantity.to_i <= 0
  end

  def build_reserve_request_body(event_code:, event_date:, price: nil, quantity: nil, client_id: nil, seat_code: nil)
    body = {
      eventCode: event_code.to_s,
      eventDate: format_event_date(event_date)
    }

    quantity_int = quantity.to_i if quantity
    if quantity_int && quantity_int > 0
      body[:quantity] = quantity_int
      body[:price] = price.to_f if price
    end

    body[:clientId] = client_id.to_s if client_id
    body[:seatCode] = seat_code.to_s if seat_code

    body
  end

  def build_request_body(event_code:, event_date:, price:, quantity: nil, client_id: nil, seat_code: nil)
    body = {
      eventCode: event_code.to_s,
      eventDate: format_event_date(event_date),
      price: price.to_f
    }

    body[:quantity] = quantity.to_i if quantity
    body[:clientId] = client_id.to_s if client_id
    body[:seatCode] = seat_code.to_s if seat_code

    body
  end

  def format_event_date(event_date)
    case event_date
    when String
      event_date
    when Date, DateTime, Time
      event_date.strftime("%Y-%m-%dT%H:%M:%S")
    else
      raise ArgumentError, "event_date must be a String, Date, DateTime, or Time"
    end
  end

  def format_event_date_for_query(event_date)
    case event_date
    when String
      # If it's already in YYYY-MM-DD format, use it; otherwise try to parse
      event_date.match?(/^\d{4}-\d{2}-\d{2}$/) ? event_date : Date.parse(event_date).strftime("%Y-%m-%d")
    when Date
      event_date.strftime("%Y-%m-%d")
    when DateTime, Time
      event_date.to_date.strftime("%Y-%m-%d")
    else
      raise ArgumentError, "event_date must be a String, Date, DateTime, or Time"
    end
  end
end
