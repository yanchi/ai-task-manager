# frozen_string_literal: true

# Devise の設定ファイル
# 必要に応じてカスタマイズしてください

Devise.setup do |config|
  # メーラーの送信元アドレス
  config.mailer_sender = "no-reply@ai-task-manager.example.com"

  # ORM の設定
  require "devise/orm/active_record"

  # 大文字小文字を区別しない認証
  config.case_insensitive_keys = [:email]
  config.strip_whitespace_keys = [:email]

  # HTTP 認証
  config.http_authenticatable_on_xhr = false

  # パスワードの最小文字数
  config.password_length = 6..128

  # メールアドレスのバリデーション正規表現
  config.email_regexp = /\A[^@\s]+@[^@\s]+\.[^@\s]+\z/

  # タイムアウト設定（秒）
  config.timeout_in = 30.minutes

  # Remember Me の有効期限
  config.remember_for = 2.weeks

  # ログインに必要な試行回数（Lockable 使用時）
  # config.maximum_attempts = 20

  # ナビゲーションフォーマット
  config.navigational_formats = ["*/*", :html, :turbo_stream]

  # サインアウト後のリダイレクト先
  # config.sign_out_via = :delete
end
