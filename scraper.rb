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
require 'mechanize'
require 'scraperwiki'

URL      = 'https://online-price-watch.consumer.org.hk/opw/pricedrop/60'
MIN_DROP = 20
VEG_KEY  = %w[菜 蘋果 橙 梨 蕉 椰 番茄 薯 蛋 米 奶 肉 雞 魚]

agent = Mechanize.new
page  = agent.get(URL)

page.at('table.price-table').search('tbody tr').each do |tr|
  cells = tr.search('td').map(&:text).map(&:strip)
  next if cells.size < 7

  product, spec, drop_txt, min_price, max_price, store_low, store_high = cells[0..6]
  drop_pct = drop_txt.delete('▼%').to_i
  next if drop_pct < MIN_DROP
  next unless VEG_KEY.any? { |k| product.include?(k) }

  ScraperWiki.save_sqlite(['date', 'product', 'store_low'], {
    date:       Date.today.to_s,
    product:    product,
    spec:       spec,
    drop_pct:   drop_pct,
    min_price:  min_price,
    max_price:  max_price,
    store_low:  store_low,
    store_high: store_high
  })
end
