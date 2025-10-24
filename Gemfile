# It's easy to add more libraries or choose different versions. Any libraries
# specified here will be installed and made available to your morph.io scraper.
# Find out more: https://morph.io/documentation/ruby

source "https://rubygems.org"

# Specify Ruby version
ruby "2.6.10"

# Use versions compatible with Ruby 2.6
gem "rake", "~> 12.3.3"       # Compatible with Ruby 2.6
gem "sqlite3", "~> 1.3.13"    # Compatible with Ruby 2.6
gem "nokogiri", "~> 1.10.10"  # Compatible with Ruby 2.6
gem "mechanize", "~> 2.7.7"   # Compatible with Ruby 2.6

# Only include scraperwiki in Morph.io environment
if ENV['MORPH_URL']
  gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"
end
