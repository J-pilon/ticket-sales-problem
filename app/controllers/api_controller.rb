# frozen_string_literal: true

class ApiController < ApplicationController
  skip_forgery_protection

  def purchase_stats
    since = params[:since].present? ? Time.parse(params[:since]) : 10.minutes.ago
    stats = PurchaseRecord.stats(since: since)

    render json: {
      stats: stats,
      since: since.iso8601,
      timestamp: Time.current.iso8601
    }
  end
end
