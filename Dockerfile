FROM ruby:2.7.8-slim

# Install dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    libsqlite3-dev \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /app

# Copy Gemfile and install gems
COPY Gemfile* ./
RUN bundle install

# Copy the rest of the application
COPY . .

# Run the scraper
CMD ["ruby", "scraper.rb"]
