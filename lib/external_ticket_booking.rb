# frozen_string_literal: true

# Proxy layer for external ticket booking API
# Follows SDK pattern for making external 3rd party requests
class ExternalTicketBooking
  class Error < StandardError; end

  attr_reader :http_client

  def initialize(base_url: nil, timeout: 30, headers: {})
    base_url ||= ENV.fetch("TICKET_BOOKING_API_URL", "https://api.ticketbooking.example.com")
    @http_client = HttpClient.new(base_url: base_url, timeout: timeout, headers: headers)
  end

  # Get available tickets
  # @return [Hash] Response containing available tickets
  # @raise [HttpClient::Error] If the request fails
  def get_tickets
    http_client.get("/ExternalTicketBooking/GetTickets")
  end

  # Reserve a ticket (optionally for a specific seat)
  # @param seat_code [String, nil] Optional seat code to reserve
  # @return [Hash] Response containing reservation details
  # @raise [HttpClient::Error] If the request fails
  def reserve_ticket(seat_code = nil)
    path = "/ExternalTicketBooking/ReserveTicket"
    path += "/#{seat_code}" if seat_code && !seat_code.to_s.strip.empty?

    http_client.post(path, body: nil)
  end

  # Purchase a ticket (optionally for a specific seat)
  # @param seat_code [String, nil] Optional seat code to purchase
  # @return [Hash] Response containing purchase details
  # @raise [HttpClient::Error] If the request fails
  def purchase_ticket(seat_code = nil)
    path = "/ExternalTicketBooking/PurchaseTicket"
    path += "/#{seat_code}" if seat_code && !seat_code.to_s.strip.empty?

    http_client.post(path, body: nil)
  end
end
