class TaskCompletionService
  DEFAULT_MESSAGE = "AI補完を利用できませんでした。手動で詳細を入力してください。"
  MODEL = "claude-haiku-4-5-20251001"
  MAX_TOKENS = 300

  SYSTEM_PROMPT =
    "あなたはタスク管理アシスタントです。\n" \
    "タスク名を受け取り、以下の形式で詳細を補完してください。\n" \
    "- 概要：タスクの目的（1文）\n" \
    "- 手順：具体的な手順（3〜5項目）\n" \
    "- ポイント：作業時の注意点（1〜2項目）\n" \
    "出力は日本語で、200文字以内にまとめてください。"

  def initialize(task, title = nil)
    @task = task
    @title = title || task&.title
  end

  # タスク保存時に呼び出される（タスクに結果を保存）
  def call
    return unless @task && @title.present?
    return unless api_key_configured?

    suggestion = fetch_suggestion(@title)
    @task.update_columns(ai_suggestion: suggestion, updated_at: Time.current)
    suggestion
  rescue Anthropic::Error => e
    Rails.logger.error "Anthropic API error: #{e.message}"
    @task.update_column(:ai_suggestion, DEFAULT_MESSAGE)
    DEFAULT_MESSAGE
  rescue => e
    Rails.logger.error "TaskCompletionService error: #{e.message}"
    @task.update_column(:ai_suggestion, DEFAULT_MESSAGE)
    DEFAULT_MESSAGE
  end

  # Ajax リクエスト時に呼び出される（タスク保存なし）
  def call_with_title
    return DEFAULT_MESSAGE unless @title.present?
    return DEFAULT_MESSAGE unless api_key_configured?

    fetch_suggestion(@title)
  rescue => e
    Rails.logger.error "TaskCompletionService (title only) error: #{e.message}"
    DEFAULT_MESSAGE
  end

  private

  def fetch_suggestion(title)
    client = Anthropic::Client.new(access_token: ENV["ANTHROPIC_API_KEY"])

    safe_title = title.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(100)

    response = client.messages(
      parameters: {
        model: MODEL,
        max_tokens: MAX_TOKENS,
        system: SYSTEM_PROMPT,
        messages: [
          {
            role: "user",
            content: "タスク名: 【#{safe_title}】\n上記タスクの詳細を補完してください。"
          }
        ]
      }
    )

    response.dig("content", 0, "text") || DEFAULT_MESSAGE
  end

  def api_key_configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
