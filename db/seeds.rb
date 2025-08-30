# frozen_string_literal: true

require 'csv'
require 'json'

puts "🌱 Starting database seeding..."

# Clear existing data
puts "🧹 Clearing existing data..."
puts "  - Destroying #{Segment.count} segments..."
Segment.destroy_all

puts "  - Destroying #{PermittedRoute.count} permitted routes..."
PermittedRoute.destroy_all

puts "✅ All existing data cleared."

# Load Segments from CSV
puts "\n📄 Loading segments from CSV..."
segments_file = Rails.root.join('db', 'segments.csv')

if File.exist?(segments_file)
  segments_data = []

  CSV.foreach(segments_file, headers: false) do |row|
    # Column order: :airline, :segment_number, :origin_iata, :destination_iata, :std, :sta
    airline, segment_number, origin_iata, destination_iata, std_str, sta_str = row

    # Parse datetime strings
    std = DateTime.parse(std_str) if std_str
    sta = DateTime.parse(sta_str) if sta_str

    segments_data << {
      airline: airline,
      segment_number: segment_number,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      std: std,
      sta: sta
    }
  end

  # Bulk insert segments
  puts "  - Creating #{segments_data.size} segment records..."

  ActiveRecord::Base.transaction do
    segments_data.each_slice(100) do |batch|
      Segment.create!(batch)
      print "."
    end
  end

  puts "\n✅ Successfully loaded #{Segment.count} segments."
else
  puts "❌ segments.csv file not found at #{segments_file}"
end

# Load PermittedRoutes from CSV
puts "\n📄 Loading permitted routes from CSV..."
routes_file = Rails.root.join('db', 'permitted_routes.csv')

if File.exist?(routes_file)
  routes_data = []

  # Read the CSV manually to debug parsing issues
  File.readlines(routes_file).each_with_index do |line, index|
    next if line.strip.empty?

    # Split on commas but handle quoted fields properly
    parts = line.strip.split(',')

    # The last field contains the JSON array which might have been quoted
    if parts.length >= 5
      # Reassemble if the JSON was split across multiple parts due to commas inside quotes
      carrier = parts[0]
      origin_iata = parts[1]
      destination_iata = parts[2]
      direct_str = parts[3]
      transfer_codes_str = parts[4..-1].join(',') # Join remaining parts in case JSON had commas

      # Convert string boolean to actual boolean
      direct = direct_str == 'true'

      # Parse JSON array string for transfer_iata_codes
      transfer_iata_codes = begin
        if transfer_codes_str && !transfer_codes_str.empty?
          # Remove outer quotes if they exist
          cleaned_str = transfer_codes_str.strip.gsub(/\A"(.*)"\z/, '\1')
          JSON.parse(cleaned_str)
        else
          []
        end
      rescue JSON::ParserError => e
        puts "    ⚠️  Row #{index + 1} JSON parse error for '#{transfer_codes_str}': #{e.message}. Using empty array."
        []
      end
    else
      puts "    ⚠️  Row #{index + 1} has unexpected format: #{line.strip}"
      next
    end

    routes_data << {
      carrier: carrier,
      origin_iata: origin_iata,
      destination_iata: destination_iata,
      direct: direct,
      transfer_iata_codes: transfer_iata_codes || []
    }
  end

  # Bulk insert permitted routes
  puts "  - Creating #{routes_data.size} permitted route records..."

  ActiveRecord::Base.transaction do
    routes_data.each_slice(50) do |batch|
      PermittedRoute.create!(batch)
      print "."
    end
  end

  puts "\n✅ Successfully loaded #{PermittedRoute.count} permitted routes."
else
  puts "❌ permitted_routes.csv file not found at #{routes_file}"
end

# Final summary
puts "\n🎉 Database seeding completed!"
puts "📊 Final counts:"
puts "  - Segments: #{Segment.count}"
puts "  - Permitted Routes: #{PermittedRoute.count}"
