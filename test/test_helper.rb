ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/mock"

class ActiveSupport::TestCase
  fixtures :all

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
    Anthropic::Client.stub(:new, ->(_) { stub_client }) do
      yield
    end
  end
end

class ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
end
