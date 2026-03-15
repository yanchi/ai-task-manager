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

  # アソシエーション
  test "ユーザーを削除するとタスクも削除される" do
    user = User.create!(email: "temp@example.com", password: "password")
    user.tasks.create!(title: "一時タスク", priority: :medium)
    assert_difference "Task.count", -1 do
      user.destroy
    end
  end
end
