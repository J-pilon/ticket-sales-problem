# frozen_string_literal: true

class UserMailer < ApplicationMailer
  # Subject can be set in your I18n file at config/locales/en.yml
  # with the following lookup:
  #
  #   en.user_mailer.confirmation.subject
  #
  def confirmation(email:, event_code:, event_date:, price:, quantity:)
    @event_code = event_code
    @event_date = event_date
    @price = price
    @quantity = quantity
    @total_price = price * quantity

    mail(
      to: email,
      subject: "Ticket Purchase Confirmation - #{event_code}"
    )
  end
end
