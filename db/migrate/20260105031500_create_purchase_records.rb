# frozen_string_literal: true

class CreatePurchaseRecords < ActiveRecord::Migration[7.2]
  def change
    create_table :purchase_records do |t|
      t.string :event_code, null: false
      t.string :user_email, null: false
      t.integer :quantity, default: 1
      t.decimal :price, precision: 10, scale: 2

      # Status tracking
      t.string :status, default: "pending", null: false # pending, completed, failed
      t.boolean :api_success, default: false
      t.boolean :email_sent, default: false
      t.text :error_message

      t.datetime :completed_at
      t.timestamps
    end

    add_index :purchase_records, :status
    add_index :purchase_records, :created_at
  end
end
