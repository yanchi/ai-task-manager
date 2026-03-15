# Anthropic API の初期設定
# 環境変数 ANTHROPIC_API_KEY が設定されているか確認

if Rails.env.production? || Rails.env.development?
  unless ENV["ANTHROPIC_API_KEY"].present?
    Rails.logger.warn "WARNING: ANTHROPIC_API_KEY is not set. AI suggestion feature will be disabled."
  end
end
