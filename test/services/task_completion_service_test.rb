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

  # call_priority（優先度推論・タスク保存あり）
  test "call_priority: API成功時にpriorityが更新される（high）" do
    stub_anthropic_priority_response("high") do
      TaskCompletionService.new(@task).call_priority
      assert_equal "high", @task.reload.priority
    end
  end

  test "call_priority: API成功時にpriorityが更新される（low）" do
    stub_anthropic_priority_response("low") do
      TaskCompletionService.new(@task).call_priority
      assert_equal "low", @task.reload.priority
    end
  end

  test "call_priority: APIがhigh/medium/low以外を返した場合はmediumにフォールバック" do
    stub_anthropic_priority_response("urgent") do
      TaskCompletionService.new(@task).call_priority
      assert_equal "medium", @task.reload.priority
    end
  end

  test "call_priority: タイムアウト時にタスクは壊れず既存のpriorityが維持される" do
    original_priority = @task.priority
    # クライアント生成は成功するが messages 呼び出し中にタイムアウトするクライアント
    timeout_client = Object.new
    timeout_client.define_singleton_method(:messages) { |**_| raise Timeout::Error }
    Anthropic::Client.stub(:new, timeout_client) do
      assert_nothing_raised { TaskCompletionService.new(@task).call_priority }
    end
    assert_equal original_priority, @task.reload.priority
  end

  test "fetch_suggestionタイムアウト後に@clientがnilにリセットされる" do
    # @client を非 nil に設定してからタイムアウトさせ、リセットを確認する
    timeout_client = Object.new
    timeout_client.define_singleton_method(:messages) { |**_| raise Timeout::Error }

    service = TaskCompletionService.new(@task)
    service.instance_variable_set(:@client, timeout_client)

    service.send(:fetch_suggestion, "テスト")

    assert_nil service.instance_variable_get(:@client)
  end

  test "fetch_priorityタイムアウト後に@clientがnilにリセットされる" do
    # @client を非 nil に設定してからタイムアウトさせ、リセットを確認する
    timeout_client = Object.new
    timeout_client.define_singleton_method(:messages) { |**_| raise Timeout::Error }

    service = TaskCompletionService.new(@task)
    service.instance_variable_set(:@client, timeout_client)

    service.send(:fetch_priority, "テスト", nil) rescue nil

    assert_nil service.instance_variable_get(:@client)
  end

  test "call_priority: APIキー未設定の場合は何もしない" do
    with_env("ANTHROPIC_API_KEY" => nil) do
      result = TaskCompletionService.new(@task).call_priority
      assert_nil result
    end
  end

  test "call_priority: タイトルが3文字未満の場合は何もしない" do
    @task.title = "ab"
    result = TaskCompletionService.new(@task).call_priority
    assert_nil result
  end

  # タイトルサニタイズ（プロンプトインジェクション対策）
  test "100文字を超えるタイトルは切り詰められる" do
    long_title = "あ" * 200
    stub_anthropic_response("提案") do |captured_messages|
      TaskCompletionService.new(nil, long_title).call_with_title
      content = captured_messages.first[:content]
      # プレフィックス(7) + safe_title(最大100) + サフィックス(20) = 最大127文字
      assert content.length <= 130
      # truncate が無効なら 200 文字のタイトル分だけで 227 文字超になる
      assert content.length < long_title.length
    end
  end

  private

  def stub_anthropic_response(text)
    captured = []
    mock_client = Minitest::Mock.new
    mock_client.expect(:messages, { "content" => [{ "text" => text }] }) do |params|
      captured << params[:parameters][:messages].first
      true
    end
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, mock_client) do
        yield captured
      end
    end
    mock_client.verify
  end

  def stub_anthropic_error
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, ->(_) { raise Anthropic::Error, "API error" }) do
        yield
      end
    end
  end

  def stub_anthropic_priority_response(priority_text)
    mock_client = Minitest::Mock.new
    mock_client.expect(:messages, { "content" => [{ "text" => priority_text }] }) do |_params|
      true
    end
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, mock_client) do
        yield
      end
    end
    mock_client.verify
  end
end
