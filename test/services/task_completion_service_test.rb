require "test_helper"

class TaskCompletionServiceTest < ActiveSupport::TestCase
  setup do
    @task = tasks(:shopping)
  end

  # call（タスク保存あり）
  test "APIキー未設定の場合は何もしない" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      result = TaskCompletionService.new(@task).call
      assert_nil result
      assert_nil @task.reload.ai_suggestion
    end
  end

  test "タイトルがnilの場合は何もしない" do
    task = Task.new
    result = TaskCompletionService.new(task, nil).call
    assert_nil result
  end

  test "API成功時はai_suggestionが更新される" do
    stub_anthropic_response("テスト提案") do
      TaskCompletionService.new(@task).call
      assert_equal "テスト提案", @task.reload.ai_suggestion
    end
  end

  test "APIエラー時はデフォルトメッセージが保存される" do
    stub_anthropic_error do
      TaskCompletionService.new(@task).call
      assert_equal TaskCompletionService::DEFAULT_MESSAGE, @task.reload.ai_suggestion
    end
  end

  # call_with_title（保存なし）
  test "call_with_titleはAPIキー未設定でデフォルトメッセージを返す" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      result = TaskCompletionService.new(nil, "テスト").call_with_title
      assert_equal TaskCompletionService::DEFAULT_MESSAGE, result
    end
  end

  test "call_with_titleはタイトルなしでデフォルトメッセージを返す" do
    result = TaskCompletionService.new(nil, "").call_with_title
    assert_equal TaskCompletionService::DEFAULT_MESSAGE, result
  end

  test "call_with_titleはAPI成功時に提案テキストを返す" do
    stub_anthropic_response("テスト提案") do
      result = TaskCompletionService.new(nil, "テストタスク").call_with_title
      assert_equal "テスト提案", result
    end
  end

  # タイトルサニタイズ（プロンプトインジェクション対策）
  test "100文字を超えるタイトルは切り詰められる" do
    long_title = "あ" * 200
    stub_anthropic_response("提案") do |captured_messages|
      TaskCompletionService.new(nil, long_title).call_with_title
      content = captured_messages.first[:content]
      assert content.length < long_title.length + 50
    end
  end

  private

  def with_env(vars)
    original = vars.keys.each_with_object({}) { |k, h| h[k] = ENV[k.to_s] }
    vars.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
  end

  def stub_anthropic_response(text)
    captured = []
    mock_client = Minitest::Mock.new
    mock_client.expect(:messages, { "content" => [{ "text" => text }] }) do |params|
      captured << params[:parameters][:messages].first
      true
    end
    Anthropic::Client.stub(:new, mock_client) do
      yield captured
    end
  end

  def stub_anthropic_error
    Anthropic::Client.stub(:new, ->(_) { raise Anthropic::Error, "API error" }) do
      yield
    end
  end
end
