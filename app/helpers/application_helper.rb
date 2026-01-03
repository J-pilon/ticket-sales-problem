module ApplicationHelper
  def format_event_date(date_string)
    return "Date not available" if date_string.nil?

    begin
      # Parse ISO 8601 datetime string
      datetime = Time.parse(date_string.to_s)
      # Format as "February 1, 2026 at 10:32 PM"
      datetime.strftime("%B %-d, %Y at %-l:%M %p")
    rescue ArgumentError
      date_string.to_s
    end
  end
end
