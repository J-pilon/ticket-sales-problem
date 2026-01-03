class User < ApplicationRecord
  has_secure_password

  before_save :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: -> { new_record? || !password.nil? }

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end
end
