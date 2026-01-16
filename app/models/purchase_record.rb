# frozen_string_literal: true

class PurchaseRecord < ApplicationRecord
  STATUSES = %w[pending completed failed].freeze

  validates :event_code, :user_email, :status, presence: true
  validates :status, inclusion: { in: STATUSES }

  scope :pending, -> { where(status: "pending") }
  scope :completed, -> { where(status: "completed") }
  scope :failed, -> { where(status: "failed") }
  scope :recent, -> { where("created_at > ?", 10.minutes.ago) }

  def self.stats(since: 10.minutes.ago)
    records = where("created_at > ?", since)
    {
      total: records.count,
      pending: records.pending.count,
      completed: records.completed.count,
      failed: records.failed.count,
      api_success: records.where(api_success: true).count,
      email_sent: records.where(email_sent: true).count
    }
  end
end
