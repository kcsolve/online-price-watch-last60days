# It's easy to add more libraries or choose different versions. Any libraries
# specified here will be installed and made available to your morph.io scraper.
# Find out more: https://morph.io/documentation/ruby

source "https://rubygems.org"

# Specify exact Ruby version with all three digits
ruby "2.6.10", :engine => "ruby", :engine_version => "2.6.10"

# Use versions compatible with Ruby 2.6.10
gem "rake", "~> 12.3.3"       # Required for native extensions
gem "sqlite3", "~> 1.3.13"    # Last version compatible with Ruby 2.6
gem "nokogiri", "~> 1.10.10"  # Last version compatible with Ruby 2.6
gem "mechanize", "~> 2.7.7"   # Last version compatible with Ruby 2.6
gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"
