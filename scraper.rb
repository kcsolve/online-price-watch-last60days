require 'scraperwiki'
require 'mechanize'
require 'date'  # Required for Date.today

# Initialize the scraper
agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
agent.user_agent_alias = 'Windows Chrome'

begin
  # Read in a page
  page = agent.get("https://online-price-watch.consumer.org.hk/opw/pricedrop/60")

  # Find the price table
  price_table = page.at('#price-table-tbody')
  if price_table.nil?
    puts "Could not find price table"
    exit 1
  end

# Process each row
price_table.search('tr').each do |tr|
  cells = tr.search('td.can-click').map(&:text).map(&:strip)
  next if cells.size < 4
  
  brand, product_name, price_drop, drop_pct = cells
  
  # Extract current price
  price_match = price_drop.match(/\$\s*(\d+\.?\d*)/)
  next unless price_match
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
  
  # Save data to 'data' table (required by Morph.io)
  record = {
    'name' => "#{brand} - #{product_name}",  # Primary key
    'date' => Date.today.to_s,
    'store' => store_name,
    'current_price' => current_price,
    'original_price' => original_price.round(2),
    'drop_pct' => drop_pct
  }
  
  # Save to 'data' table with 'name' as primary key
  ScraperWiki.save_sqlite(['name'], record)
end

rescue => e
  puts "Error occurred: #{e.message}"
  puts e.backtrace
  exit 1
end