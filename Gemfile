# It's easy to add more libraries or choose different versions. Any libraries
# specified here will be installed and made available to your morph.io scraper.
# Find out more: https://morph.io/documentation/ruby

source "https://rubygems.org"

# Explicitly set Ruby version for Morph.io
raise "Ruby version must be 3.0.6" if RUBY_VERSION != "3.0.6"
ruby "3.0.6", engine: "ruby", engine_version: "3.0.6"

# Use older versions for better compatibility
gem "sqlite3", "~> 1.4.4"     # Compatible with Ruby 3.0
gem "nokogiri", "~> 1.13.10"  # Compatible with Ruby 3.0
gem "mechanize", "~> 2.8.5"   # Compatible with Ruby 3.0
gem "rake", "~> 13.0.0"       # Compatible with Ruby 3.0
gem "scraperwiki", git: "https://github.com/openaustralia/scraperwiki-ruby.git", branch: "morph_defaults"  # Required by Morph.io
