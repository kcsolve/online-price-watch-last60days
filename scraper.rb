require 'mechanize'
require 'date'
require 'sqlite3'

# Initialize database
DB_PATH = 'data.sqlite'
db = SQLite3::Database.new(DB_PATH)

# Create tables if they don't exist
db.execute <<-SQL
  CREATE TABLE IF NOT EXISTS data (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    date TEXT,
    store TEXT,
    current_price REAL,
    original_price REAL,
    drop_pct REAL,
    UNIQUE(name, date, store)
  )
SQL

# Initialize the scraper
agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
agent.user_agent_alias = 'Windows Chrome'

begin
  puts "Fetching data from website..."
  page = agent.get("https://online-price-watch.consumer.org.hk/opw/pricedrop/60")

  # Find the price table
  price_table = page.at('#price-table-tbody')
  if price_table.nil?
    puts "Could not find price table"
    exit 1
  end
  puts "Found price table"

# Process each row
rows_processed = 0
rows_saved = 0

price_table.search('tr').each do |tr|
  rows_processed += 1
  cells = tr.search('td.can-click').map(&:text).map(&:strip)
  
  if cells.size < 4
    puts "Skipping row #{rows_processed}: insufficient cells"
    next
  end
  
  brand, product_name, price_drop, drop_pct = cells
  
  # Extract current price
  price_match = price_drop.match(/\$\s*(\d+\.?\d*)/)
  unless price_match
    puts "Skipping row #{rows_processed}: no price found"
    next
  end
  current_price = price_match[1].to_f
  
  # Calculate original price
  drop_pct = drop_pct.delete('%').to_f
  original_price = current_price / (1 - drop_pct/100)
  
  # Get store
  store_tag = tr.at('td[data-label="跌價"] .tag:not(:empty)')
  store_code = store_tag ? store_tag['class'].split('--').last : 'unknown'
  store_name = {
    'blue' => '惠康',
    'yellow' => '百佳',
    'green' => 'Market Place',
    'red' => '屈臣氏',
    'lightgreen' => '萬寧',
    'orange' => 'AEON',
    'purple' => '大昌食品'
  }[store_code] || 'Unknown Store'
  
  # Save data
  name = "#{brand} - #{product_name}"
  date = Date.today.to_s
  
  begin
    db.execute(
      "INSERT OR REPLACE INTO data (name, date, store, current_price, original_price, drop_pct) 
       VALUES (?, ?, ?, ?, ?, ?)",
      [name, date, store_name, current_price, original_price.round(2), drop_pct]
    )
    rows_saved += 1
    puts "Saved: #{name} at #{store_name}"
  rescue SQLite3::Exception => e
    puts "Error saving #{name}: #{e.message}"
  end
end

puts "\nProcessing completed:"
puts "- Rows processed: #{rows_processed}"
puts "- Rows saved: #{rows_saved}"

# Display results
puts "\nToday's price drops:"
db.execute("
  SELECT name, store, current_price, original_price, drop_pct
  FROM data
  WHERE date = ?
  ORDER BY drop_pct DESC
", [Date.today.to_s]).each do |row|
  name, store, current_price, original_price, drop_pct = row
  puts "\n商品: #{name}"
  puts "商店: #{store}"
  puts "原價: $#{original_price}"
  puts "現價: $#{current_price}"
  puts "折扣: #{drop_pct}%"
  puts "節省: $#{(original_price - current_price).round(2)}"
  puts "-" * 50
end

rescue => e
  puts "Error occurred: #{e.message}"
  puts e.backtrace
  exit 1
end