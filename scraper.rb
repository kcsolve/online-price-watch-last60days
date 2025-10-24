# This is a template for a Ruby scraper on morph.io (https://morph.io)
# including some code snippets below that you should find helpful

# require 'scraperwiki'
# require 'mechanize'
#
# agent = Mechanize.new
#
# # Read in a page
# page = agent.get("http://foo.com")
#
# # Find something on the page using css selectors
# p page.at('div.content')
#
# # Write out to the sqlite database using scraperwiki library
# ScraperWiki.save_sqlite(["name"], {"name" => "susan", "occupation" => "software developer"})
#
# # An arbitrary query against the database
# ScraperWiki.select("* from data where 'name'='peter'")

# You don't have to do things with the Mechanize or ScraperWiki libraries.
# You can use whatever gems you want: https://morph.io/documentation/ruby
# All that matters is that your final data is written to an SQLite database
# called "data.sqlite" in the current working directory which has at least a table
# called "data".

#!/usr/bin/env ruby
# -*- encoding: utf-8 -*-

# 判斷運行環境
MORPH_ENV = !ENV['MORPH_URL'].nil?

# 根據環境加載所需的 gems
if MORPH_ENV
  require 'scraperwiki'
else
  require 'sqlite3'
end

require 'mechanize'
require 'date'
require 'openssl'
require 'json'
require 'logger'

# 設置日誌
LOGGER = Logger.new(STDOUT)
LOGGER.level = ENV['DEBUG'] ? Logger::DEBUG : Logger::INFO

URL = 'https://online-price-watch.consumer.org.hk/opw/pricedrop/60'

# 數據庫操作類
class Database
  def initialize
    if MORPH_ENV
      LOGGER.info "Running in Morph.io environment"
    else
      LOGGER.info "Running in local environment"
      @db_path = 'data.sqlite'
      @db = SQLite3::Database.new(@db_path)
      init_database
    end
  end
  
  def init_database
    return if MORPH_ENV
    
    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT,
        product TEXT,
        brand TEXT,
        name TEXT,
        category TEXT,
        original_price REAL,
        current_price REAL,
        drop_pct REAL,
        store TEXT,
        store_code TEXT,
        is_lowest_price INTEGER,
        historical_lowest_price REAL,
        historical_lowest_date TEXT,
        UNIQUE(date, product, store)
      )
    SQL

    @db.execute <<-SQL
      CREATE TABLE IF NOT EXISTS price_history (
        product_id INTEGER,
        date TEXT,
        price REAL,
        store TEXT,
        FOREIGN KEY(product_id) REFERENCES products(id)
      )
    SQL
  end
  
  def save(data)
    if MORPH_ENV
      ScraperWiki.save_sqlite(['date', 'product', 'store'], data)
    else
      @db.execute(
        "INSERT OR REPLACE INTO products 
         (date, product, brand, name, category, original_price, current_price, drop_pct, 
          store, store_code, is_lowest_price, historical_lowest_price, historical_lowest_date) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        [
          data[:date],
          data[:product],
          data[:brand],
          data[:name],
          data[:category],
          data[:original_price],
          data[:current_price],
          data[:drop_pct],
          data[:store],
          data[:store_code],
          data[:is_lowest_price] || 0,
          data[:historical_lowest_price],
          data[:historical_lowest_date]
        ]
      )
      
      # Save to price history
      if data[:product_id]
        @db.execute(
          "INSERT INTO price_history (product_id, date, price, store) VALUES (?, ?, ?, ?)",
          [data[:product_id], data[:date], data[:current_price], data[:store]]
        )
      end
    end
  end
  
  def get_historical_price(product, store, from_date)
    return nil if MORPH_ENV
    
    @db.get_first_row(
      "SELECT MIN(ph.price) as lowest_price, ph.date
       FROM price_history ph
       JOIN products p ON ph.product_id = p.id
       WHERE p.product = ? AND p.store = ? AND ph.date >= ?
       GROUP BY ph.date
       ORDER BY ph.price ASC
       LIMIT 1",
      [product, store, from_date]
    )
  end
  
  def get_product_id(date, product, store)
    return nil if MORPH_ENV
    
    @db.get_first_value(
      "SELECT id FROM products WHERE date = ? AND product = ? AND store = ?",
      [date, product, store]
    )
  end
  
  def get_results(date)
    if MORPH_ENV
      ScraperWiki.select("
        SELECT category, product, store, current_price, original_price, drop_pct
        FROM swdata
        WHERE date = ?
        ORDER BY drop_pct DESC, category
      ", [date])
    else
      @db.execute("
        SELECT 
          category,
          product,
          store,
          current_price,
          original_price,
          drop_pct,
          historical_lowest_price,
          historical_lowest_date,
          CASE 
            WHEN historical_lowest_price IS NOT NULL THEN 
              ((current_price - historical_lowest_price) / historical_lowest_price * 100)
            ELSE NULL 
          END as price_vs_historical
        FROM products 
        WHERE date = ? AND is_lowest_price = 1
        ORDER BY drop_pct DESC, category
      ", [date])
    end
  end
end

# 初始化數據庫
DB = Database.new

# Store mapping
STORE_NAMES = {
  'blue' => '惠康',
  'yellow' => '百佳',
  'green' => 'Market Place',
  'red' => '屈臣氏',
  'lightgreen' => '萬寧',
  'orange' => 'AEON',
  'purple' => '大昌食品'
}

MIN_DROP = 20
VEG_KEY  = %w[菜 蘋果 橙 梨 蕉 椰 番茄 薯 蛋 米 奶 肉 雞 魚]

def process_row(tr)
  cells = tr.search('td.can-click').map(&:text).map(&:strip)
  LOGGER.debug "Found #{cells.size} cells: #{cells.inspect}"
  
  if cells.size < 4
    LOGGER.debug "Skipping row with insufficient cells"
    return
  end
  
  brand, product_name, price_drop, drop_pct = cells
  LOGGER.debug "Brand: #{brand}"
  LOGGER.debug "Product: #{product_name}"
  LOGGER.debug "Price drop: #{price_drop}"
  LOGGER.debug "Drop percentage: #{drop_pct}"
  
  drop_pct = drop_pct.delete('%').to_f  # Convert percentage to float
  LOGGER.debug "Converted drop percentage: #{drop_pct}"
  
  if drop_pct < MIN_DROP
    LOGGER.debug "Skipping: drop percentage #{drop_pct} is less than minimum #{MIN_DROP}"
    return
  end
  
  # Extract current price from the price drop cell
  price_match = price_drop.match(/\$\s*(\d+\.?\d*)/)
  unless price_match
    LOGGER.debug "No price found in: #{price_drop}"
    return
  end
  current_price = price_match[1].to_f
  LOGGER.debug "Current price: #{current_price}"
  
  # Calculate original price based on drop percentage
  drop_pct_float = drop_pct.to_f
  original_price = current_price / (1 - drop_pct_float/100)
  LOGGER.debug "Original price: #{original_price}"
  
  # Get store from the HTML class of the tag
  store_tag = tr.at('td[data-label="跌價"] .tag:not(:empty)')
  store_code = store_tag ? store_tag['class'].split('--').last : 'unknown'
  store_name = STORE_NAMES[store_code] || 'Unknown Store'
  LOGGER.debug "Store: #{store_name} (#{store_code})"
  
  # Determine product category
  category = VEG_KEY.find { |k| product_name.include?(k) || brand.include?(k) }
  
  unless category
    LOGGER.debug "Skipping: product does not match any keywords in #{VEG_KEY.join(', ')}"
    return
  end
  
  LOGGER.info "Product matches category: #{category}, checking historical prices..."
  
  # Get historical lowest price in the last 90 days
  three_months_ago = (Date.today - 90).to_s
  historical_data = DB.get_historical_price("#{brand} - #{product_name}", store_name, three_months_ago)
  
  historical_lowest_price = nil
  historical_lowest_date = nil
  
  if historical_data
    historical_lowest_price = historical_data[0]
    historical_lowest_date = historical_data[1]
    LOGGER.info "Found historical lowest price: $#{historical_lowest_price} on #{historical_lowest_date}"
  else
    LOGGER.info "No historical data found in the last 90 days"
  end
  
  # 準備數據
  data = {
    date: Date.today.to_s,
    product: "#{brand} - #{product_name}",
    brand: brand,
    name: product_name,
    category: category,
    original_price: original_price.round(2),
    current_price: current_price,
    drop_pct: drop_pct_float,
    store: store_name,
    store_code: store_code,
    is_lowest_price: 0,  # Will update this later
    historical_lowest_price: historical_lowest_price,
    historical_lowest_date: historical_lowest_date
  }

  # 保存數據
  if MORPH_ENV
    # Morph.io 需要的簡化數據結構
    morph_data = {
      date: data[:date],
      product: data[:product],
      store: data[:store],
      category: data[:category],
      current_price: data[:current_price],
      original_price: data[:original_price],
      drop_pct: data[:drop_pct]
    }
    DB.save(morph_data)
    LOGGER.debug "Saved to Morph.io: #{morph_data[:product]}"
  else
    # 獲取產品ID用於歷史記錄
    product_id = DB.get_product_id(Date.today.to_s, "#{brand} - #{product_name}", store_name)
    data[:product_id] = product_id if product_id
    
    DB.save(data)
    LOGGER.debug "Saved to local DB: #{data[:product]}"
  end
  
  # 顯示進度
  LOGGER.info "Processed: #{data[:product]} (#{data[:store]})"
end

def display_results
  LOGGER.info "\n分析價格數據..."
  results = DB.get_results(Date.today.to_s)
  
  puts "\n最值得購買的商品："
  
  if MORPH_ENV
    results.each do |row|
      puts "\n類別: #{row['category']}"
      puts "商品: #{row['product']}"
      puts "商店: #{row['store']}"
      puts "原價: $#{row['original_price'].round(2)}"
      puts "現價: $#{row['current_price']}"
      puts "折扣: #{row['drop_pct'].round(1)}%"
      puts "節省: $#{(row['original_price'] - row['current_price']).round(2)}"
      puts "-" * 50
    end
  else
    results.each do |category, product, store, current_price, original_price, drop_pct, historical_lowest, historical_date, price_vs_historical|
      puts "\n類別: #{category}"
      puts "商品: #{product}"
      puts "商店: #{store}"
      puts "原價: $#{original_price.round(2)}"
      puts "現價: $#{current_price}"
      puts "折扣: #{drop_pct.round(1)}%"
      puts "節省: $#{(original_price - current_price).round(2)}"
      
      if historical_lowest
        puts "90天最低價: $#{historical_lowest} (#{historical_date})"
        if price_vs_historical > 0
          puts "比歷史低價貴: #{price_vs_historical.round(1)}%"
        elsif price_vs_historical < 0
          puts "創90天新低價！低 #{price_vs_historical.abs.round(1)}%"
        else
          puts "持平歷史低價"
        end
      else
        puts "無90天內價格記錄"
      end
      
      puts "-" * 50
    end
  end
end

# 主程序
begin
  # 抓取和處理數據
  agent = Mechanize.new
  agent.verify_mode = OpenSSL::SSL::VERIFY_NONE
  agent.user_agent_alias = 'Windows Chrome'
  
  LOGGER.info "Fetching URL: #{URL}"
  page = agent.get(URL)
  LOGGER.info "Page fetched successfully"
  
  price_table = page.at('#price-table-tbody')
  if price_table.nil?
    LOGGER.error "Could not find price table"
    exit 1
  end
  
  price_table.search('tr').each do |tr|
    process_row(tr)
  end
  
  # 顯示結果
  display_results
rescue => e
  LOGGER.error "Error occurred: #{e.message}"
  LOGGER.error e.backtrace.join("\n")
  exit 1
end

