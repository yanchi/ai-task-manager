source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.0"

# Core
gem "rails", "~> 8.0.0"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"
gem "jbuilder"

# 認証
gem "devise", "~> 4.9"

# Anthropic API（Claude）
gem "anthropic", "~> 0.3"

# ページネーション
gem "kaminari"

# 環境変数管理
gem "dotenv-rails", groups: [:development, :test]

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[windows jruby]

# Asset pipeline
gem "sprockets-rails"

# パフォーマンス
gem "bootsnap", require: false

group :development, :test do
  gem "debug", platforms: %i[mri windows]
  gem "minitest", "~> 5.25"
end

group :development do
  gem "web-console"
end

group :test do
  gem "capybara"
  gem "selenium-webdriver"
end
