module PurchaseTicket
  class Service
    attr_accessor :event, :quantity, :user

    def initialize(event, quantity, user)
      @event, @quantity, @user = event, quantity, user
    end

    def self.perform(event, quantity, user)
      instance = new(event, quantity, user)
      instance.perform
    end

    def perform
      return if @event.nil? || @user.nil?

      create_purchase_record
      perform_ticket_purchase
    end

    private

    def create_purchase_record
      return if missing_event_details?

      @purchase_record = PurchaseRecord.create!(
        event_code: event_code,
        user_email: user.email,
        quantity: quantity,
        price: price,
        status: "pending"
      )
    end

    def perform_ticket_purchase
      return if missing_event_details?
      return unless @purchase_record

      PurchaseTicketJob.perform_later(
        purchase_record_id: @purchase_record.id,
        event_code: event_code,
        event_date: event_date,
        price: price,
        quantity: quantity,
        user_email: current_user.email,
        base_url: ticket_booking_base_url
      )
    end

    def missing_event_details?
      return true if event_code.empty?
      return true if event_date.empty?
      return true if user.email.empty?
      return true if quantity.empty?
      return true if price.empty?

      false
    end

    def event_code
      @event["eventCode"] || @event[:eventCode]
    end

    def event_date
      @event["eventDate"] || @event[:eventDate]
    end

    def price
      @event["price"] || @event[:price]
    end

    def ticket_booking_base_url
      ENV.fetch("TICKET_BOOKING_API_URL", "http://localhost:3001")
    end
  end
end
