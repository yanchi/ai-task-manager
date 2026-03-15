require "timeout"

class TaskCompletionService
  DEFAULT_MESSAGE = "AI補完を利用できませんでした。手動で詳細を入力してください。"
  DEFAULT_PRIORITY = "medium"
  MODEL = "claude-haiku-4-5-20251001"
  MAX_TOKENS = 300
  PRIORITY_MAX_TOKENS = 10
  COMBINED_MAX_TOKENS = 400
  SUGGESTION_TIMEOUT_SECONDS = 4
  PRIORITY_TIMEOUT_SECONDS = 3
  COMBINED_TIMEOUT_SECONDS = 4

  PRIORITY_SYSTEM_PROMPT =
    "あなたはタスク管理アシスタントです。\n" \
    "タスク名と説明を受け取り、優先度を high / medium / low のいずれか1単語のみで答えてください。\n" \
    "他の文字は一切出力しないでください。"

  COMBINED_SYSTEM_PROMPT =
    "あなたはタスク管理アシスタントです。\n" \
    "タスク名を受け取り、以下のJSON形式のみで回答してください。改行や説明は不要です。\n" \
    '{"suggestion":"概要・手順・ポイントを含む200文字以内の日本語テキスト","priority":"high または medium または low"}' \
    "\n他の文字は一切出力しないでください。"

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
  rescue => e
    Rails.logger.error "TaskCompletionService error: #{e.message}"
    @task.update_column(:ai_suggestion, DEFAULT_MESSAGE)
    DEFAULT_MESSAGE
  end

  # タスク保存時に優先度を推論してタスクに保存する
  def call_priority
    return unless @task && @title.present? && @title.length >= 3
    return unless api_key_configured?

    priority = fetch_priority(@title, @task.description)
    @task.update_columns(priority: Task.priorities[priority], updated_at: Time.current)
    priority
  rescue => e
    Rails.logger.error "TaskCompletionService#call_priority error: #{e.message}"
    DEFAULT_PRIORITY
  end

  # 提案と優先度を1回のAPI呼び出しで取得してタスクに保存する
  def call_combined
    return unless @task && @title.present? && @title.length >= 3
    return unless api_key_configured?

    suggestion, priority = fetch_combined(@title, @task.description)
    @task.update_columns(
      ai_suggestion: suggestion,
      priority: Task.priorities[priority],
      updated_at: Time.current
    )
  rescue => e
    Rails.logger.error "TaskCompletionService#call_combined error: #{e.message}"
    # priority は更新しない（既存値を維持）。FR-005: 更新時の再推論失敗は既存値を維持する
    @task.update_columns(ai_suggestion: DEFAULT_MESSAGE, updated_at: Time.current) if @task.ai_suggestion.blank?
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

  def client
    @client ||= Anthropic::Client.new(access_token: ENV["ANTHROPIC_API_KEY"])
  end

  def fetch_suggestion(title)
    safe_title = title.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(100)

    Timeout.timeout(SUGGESTION_TIMEOUT_SECONDS) do
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
  rescue Timeout::Error
    @client = nil  # コネクションが破損している可能性があるためリセット
    Rails.logger.warn "TaskCompletionService#fetch_suggestion timed out"
    DEFAULT_MESSAGE
  end

  def fetch_priority(title, description)
    safe_title = title.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(100)
    content = "タスク名: 【#{safe_title}】"
    if description.present?
      safe_desc = description.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(200)
      content += "\n説明: #{safe_desc}"
    end

    Timeout.timeout(PRIORITY_TIMEOUT_SECONDS) do
      response = client.messages(
        parameters: {
          model: MODEL,
          max_tokens: PRIORITY_MAX_TOKENS,
          system: PRIORITY_SYSTEM_PROMPT,
          messages: [{ role: "user", content: content }]
        }
      )
      result = response.dig("content", 0, "text").to_s.strip.downcase
      %w[high medium low].include?(result) ? result : DEFAULT_PRIORITY
    end
  rescue Timeout::Error
    @client = nil  # コネクションが破損している可能性があるためリセット
    raise
  end

  def fetch_combined(title, description)
    safe_title = title.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(100)
    content = "タスク名: 【#{safe_title}】"
    if description.present?
      safe_desc = description.gsub(/[^\p{L}\p{N}\p{P}\s]/u, "").truncate(200)
      content += "\n説明: #{safe_desc}"
    end

    Timeout.timeout(COMBINED_TIMEOUT_SECONDS) do
      response = client.messages(
        parameters: {
          model: MODEL,
          max_tokens: COMBINED_MAX_TOKENS,
          system: COMBINED_SYSTEM_PROMPT,
          messages: [{ role: "user", content: content }]
        }
      )
      text = response.dig("content", 0, "text").to_s
      parsed = JSON.parse(text)
      suggestion = parsed["suggestion"].presence || DEFAULT_MESSAGE
      priority_raw = parsed["priority"].to_s.strip.downcase
      priority = %w[high medium low].include?(priority_raw) ? priority_raw : DEFAULT_PRIORITY
      [suggestion, priority]
    end
  rescue Timeout::Error
    @client = nil
    Rails.logger.warn "TaskCompletionService#fetch_combined timed out"
    raise
  rescue JSON::ParseError => e
    Rails.logger.warn "TaskCompletionService#fetch_combined invalid JSON response: #{e.message}"
    raise
  end

  def api_key_configured?
    ENV["ANTHROPIC_API_KEY"].present?
  end
end
