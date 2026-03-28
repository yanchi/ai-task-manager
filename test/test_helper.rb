ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  fixtures :all

  # テスト実行時は実 API を呼ばないよう API キーを無効化する
  # （Task のコールバック経由で TaskCompletionService が動くため）
  setup { ENV.delete("ANTHROPIC_API_KEY") }

  # 環境変数を一時的に差し替えるヘルパー（スタブ内で API キーを有効化する際にも使用）
  def with_env(vars)
    original = vars.keys.each_with_object({}) { |k, h| h[k] = ENV[k.to_s] }
    vars.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k.to_s) : ENV[k.to_s] = v }
  end

  # Anthropic::Client をスタブして AI 推論の API 呼び出しを差し替えるヘルパー
  # responses: Array of strings (各 messages 呼び出しに順番に返す)
  def stub_anthropic_calls(*responses)
    call_index = 0
    stub_client = Object.new
    stub_client.define_singleton_method(:messages) do |**_|
      text = responses[call_index] || "medium"
      call_index += 1
      { "content" => [{ "text" => text }] }
    end
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, ->(_) { stub_client }) do
        yield
      end
    end
  end
  # 提案と優先度を1回の combined API 呼び出しとしてスタブする
  def stub_anthropic_combined_response(suggestion, priority)
    json_text = { "suggestion" => suggestion, "priority" => priority }.to_json
    mock_client = Minitest::Mock.new
    mock_client.expect(:messages, { "content" => [{ "text" => json_text }] }) do |_params|
      true
    end
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, ->(_) { mock_client }) do
        yield
      end
    end
  ensure
    mock_client.verify
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
