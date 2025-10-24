require 'scraperwiki'
require 'mechanize'
require 'logger'

# Initialize logger
LOGGER = Logger.new(STDOUT)
LOGGER.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO
LOGGER.formatter = proc do |severity, datetime, progname, msg|
  "#{datetime.strftime('%Y-%m-%d %H:%M:%S')} [#{severity}] #{msg}\n"
end

LOGGER.info "Initializing scraper..."

# Initialize the scraper
agent = Mechanize.new
agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
agent.user_agent_alias = 'Windows Chrome'

begin
  # Read in a page
  LOGGER.info "Fetching URL: https://online-price-watch.consumer.org.hk/opw/pricedrop/60"
  page = agent.get("https://online-price-watch.consumer.org.hk/opw/pricedrop/60")
  LOGGER.info "Page fetched successfully"

  # Find the price table
  LOGGER.debug "Looking for price table..."
  price_table = page.at('#price-table-tbody')
  if price_table.nil?
    LOGGER.error "Could not find price table"
    exit 1
  end
  LOGGER.info "Found price table"

# Process each row
LOGGER.info "Processing price table rows..."
rows_processed = 0
rows_saved = 0

price_table.search('tr').each do |tr|
  rows_processed += 1
  LOGGER.debug "Processing row #{rows_processed}..."
  
  cells = tr.search('td.can-click').map(&:text).map(&:strip)
  if cells.size < 4
    LOGGER.debug "Skipping row #{rows_processed}: insufficient cells (found #{cells.size}, expected 4)"
    next
  end
  
  brand, product_name, price_drop, drop_pct = cells
  LOGGER.debug "Found product: #{brand} - #{product_name}"
  
  # Extract current price
  price_match = price_drop.match(/\$\s*(\d+\.?\d*)/)
  unless price_match
    LOGGER.debug "Skipping row #{rows_processed}: no price found in '#{price_drop}'"
    next
  end
  current_price = price_match[1].to_f
  LOGGER.debug "Current price: $#{current_price}"
  
  # Calculate original price
  drop_pct = drop_pct.delete('%').to_f
  original_price = current_price / (1 - drop_pct/100)
  LOGGER.debug "Original price: $#{original_price.round(2)}, Drop: #{drop_pct}%"
  
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
  LOGGER.debug "Store: #{store_name} (#{store_code})"
  
  # Save data
  data = {
    'date' => Date.today.to_s,
    'product' => "#{brand} - #{product_name}",
    'store' => store_name,
    'current_price' => current_price,
    'original_price' => original_price.round(2),
    'drop_pct' => drop_pct
  }
  
  begin
    ScraperWiki.save_sqlite(['date', 'product', 'store'], data)
    rows_saved += 1
    LOGGER.debug "Saved data for: #{data['product']} at #{data['store']}"
  rescue => e
    LOGGER.error "Failed to save data for #{data['product']}: #{e.message}"
  end
end

LOGGER.info "Processing completed: #{rows_processed} rows processed, #{rows_saved} rows saved"

rescue => e
  LOGGER.error "Error occurred: #{e.message}"
  LOGGER.error e.backtrace.join("\n")
  exit 1
end