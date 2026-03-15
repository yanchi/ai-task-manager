require "test_helper"

class TaskTest < ActiveSupport::TestCase
  setup do
    @user = users(:alice)
  end

  # バリデーション
  test "タイトルが必須" do
    task = @user.tasks.build(priority: :medium)
    assert_not task.valid?
    assert_includes task.errors[:title], "を入力してください"
  end

  test "タイトルが255文字以内" do
    task = @user.tasks.build(title: "a" * 256, priority: :medium)
    assert_not task.valid?
  end

  test "タイトルが255文字ならOK" do
    task = @user.tasks.build(title: "a" * 255, priority: :medium)
    assert task.valid?
  end

  test "説明が2000文字を超えるとNG" do
    task = @user.tasks.build(title: "テスト", description: "a" * 2001, priority: :medium)
    assert_not task.valid?
  end

  test "正常なタスクは有効" do
    task = @user.tasks.build(title: "テストタスク", priority: :medium)
    assert task.valid?
  end

  # スコープ
  test "completedスコープは完了済みのみ返す" do
    completed = Task.completed
    assert completed.all?(&:completed?)
    assert_includes completed, tasks(:done_task)
    assert_not_includes completed, tasks(:shopping)
  end

  test "pendingスコープは未完了のみ返す" do
    pending = Task.pending
    assert pending.none?(&:completed?)
    assert_includes pending, tasks(:shopping)
    assert_not_includes pending, tasks(:done_task)
  end

  # 優先度 enum
  test "priorityのenumが正しく定義されている" do
    task = tasks(:shopping)
    assert task.medium?
    task.high!
    assert task.high?
  end

  # AI 優先度推論ロジック（US1）
  test "優先度未選択・タイトル3文字以上はAI推論対象になる" do
    task = @user.tasks.build(title: "テストタスク")
    assert task.send(:needs_priority_inference?)
  end

  test "タイトルが2文字以下はAI推論対象外" do
    task = @user.tasks.build(title: "ab")
    assert_not task.send(:needs_priority_inference?)
  end

  test "priority_manually_set=trueはAI推論対象外" do
    task = @user.tasks.build(title: "テストタスク", priority_manually_set: true)
    assert_not task.send(:needs_priority_inference?)
  end

  test "AI推論成功時にpriorityが更新される" do
    stub_anthropic_combined_response("AI補完テスト", "high") do
      task = @user.tasks.create!(title: "緊急バグ修正")
      assert_equal "high", task.reload.priority
    end
  end

  test "AI推論エラー時もタスク作成は成功する" do
    with_env("ANTHROPIC_API_KEY" => "test-key") do
      Anthropic::Client.stub(:new, ->(_) { raise "API Error" }) do
        assert_difference "Task.count", 1 do
          assert_nothing_raised { @user.tasks.create!(title: "テストタスク") }
        end
      end
    end
  end

  # タイトル変更時の再推論（US3）
  test "AI設定タスクのタイトル変更でshould_reinfer_priorityがtrue" do
    task = @user.tasks.create!(title: "元のタスク", priority_manually_set: false)
    task.title = "変更後のタスク"
    task.save!
    assert task.send(:should_reinfer_priority?)
  end

  test "AI設定タスクのタイトル変更でpriorityが再推論される" do
    task = @user.tasks.create!(title: "元のタスク", priority_manually_set: false)
    stub_anthropic_combined_response("更新後の提案", "high") do
      task.update!(title: "緊急対応タスク")
      assert_equal "high", task.reload.priority
    end
  end

  test "手動設定タスクのタイトル変更でshould_reinfer_priorityがfalse" do
    task = @user.tasks.create!(title: "元のタスク", priority_manually_set: true)
    task.title = "変更後のタスク"
    task.save!
    assert_not task.send(:should_reinfer_priority?)
  end

  # アソシエーション
  test "ユーザーを削除するとタスクも削除される" do
    user = User.create!(email: "temp@example.com", password: "password")
    user.tasks.create!(title: "一時タスク", priority: :medium)
    assert_difference "Task.count", -1 do
      user.destroy
    end
  end
end
