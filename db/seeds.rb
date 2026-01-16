# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

# Create test users for load testing
# These users are used by the K6 performance test (k6/purchase_test.js)
puts "Creating load test users..."

10.times do |i|
  user_number = i + 1
  email = "loadtest#{user_number}@example.com"

  User.find_or_create_by!(email: email) do |user|
    user.password = "password123"
    user.password_confirmation = "password123"
  end

  puts "  Created/verified user: #{email}"
end

puts "Load test users created successfully!"
puts ""
puts "To run the K6 performance test:"
puts "  1. Ensure the Rails server is running: bin/dev"
puts "  2. Ensure the external ticket booking API is available"
puts "  3. Run: k6 run k6/purchase_test.js"
puts ""
puts "You can customize the test with environment variables:"
puts "  k6 run -e BASE_URL=http://localhost:3000 -e EVENT_CODE=YOUR-EVENT -e USER_COUNT=10 k6/purchase_test.js"
