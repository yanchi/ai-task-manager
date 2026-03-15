require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:alice)
    sign_in @user
  end

  # 認証
  test "未ログインはリダイレクト" do
    sign_out @user
    get tasks_path
    assert_redirected_to new_user_session_path
  end

  # index
  test "一覧が表示される" do
    get tasks_path
    assert_response :success
  end

  test "他ユーザーのタスクは表示されない" do
    get tasks_path
    assert_select "#task_#{tasks(:bob_task).id}", count: 0
  end

  test "priorityフィルターが有効なenumのみ通す" do
    get tasks_path, params: { priority: "invalid" }
    assert_response :success
  end

  test "priorityフィルターが機能する" do
    get tasks_path, params: { priority: "high" }
    assert_response :success
    assert_select "#task_#{tasks(:report).id}"
    assert_select "#task_#{tasks(:shopping).id}", count: 0
  end

  # new
  test "タスク作成フォームが表示される" do
    get new_task_path
    assert_response :success
  end

  # create
  test "正常なパラメータでタスクが作成される" do
    assert_difference "Task.count", 1 do
      post tasks_path, params: { task: { title: "新しいタスク", priority: "medium" } }
    end
    assert_redirected_to tasks_path
  end

  test "タイトルなしでは作成できない" do
    assert_no_difference "Task.count" do
      post tasks_path, params: { task: { title: "", priority: "medium" } }
    end
    assert_response :unprocessable_entity
  end

  test "ai_suggestionがパラメータにある場合そのまま保存される" do
    post tasks_path, params: {
      task: { title: "テスト", priority: "medium", ai_suggestion: "AI提案テスト" }
    }
    assert_equal "AI提案テスト", Task.order(created_at: :desc).first.ai_suggestion
  end

  test "他ユーザーのタスクは作成できない（自分のタスクとして作られる）" do
    post tasks_path, params: { task: { title: "テスト", priority: "medium" } }
    assert_equal @user, Task.order(created_at: :desc).first.user
  end

  # edit / update
  test "タスク編集フォームが表示される" do
    get edit_task_path(tasks(:shopping))
    assert_response :success
  end

  test "他ユーザーのタスクは編集できない" do
    get edit_task_path(tasks(:bob_task))
    assert_redirected_to tasks_path
  end

  test "タスクを更新できる" do
    patch task_path(tasks(:shopping)), params: {
      task: { title: "更新したタスク", priority: "high" }
    }
    assert_redirected_to tasks_path
    assert_equal "更新したタスク", tasks(:shopping).reload.title
  end

  test "他ユーザーのタスクは更新できない" do
    patch task_path(tasks(:bob_task)), params: {
      task: { title: "不正更新" }
    }
    assert_redirected_to tasks_path
    assert_not_equal "不正更新", tasks(:bob_task).reload.title
  end

  # destroy
  test "タスクを削除できる" do
    assert_difference "Task.count", -1 do
      delete task_path(tasks(:shopping))
    end
    assert_redirected_to tasks_path
  end

  test "他ユーザーのタスクは削除できない" do
    assert_no_difference "Task.count" do
      delete task_path(tasks(:bob_task))
    end
  end

  # toggle
  test "完了状態をトグルできる" do
    task = tasks(:shopping)
    assert_not task.completed?
    patch toggle_task_path(task)
    assert task.reload.completed?
  end

  test "優先度に空文字を送信してもタスクが作成される" do
    assert_difference "Task.count", 1 do
      post tasks_path, params: { task: { title: "新しいタスク", priority: "" } }
    end
    task = Task.order(created_at: :desc).first
    assert_not task.priority_manually_set
  end

  # AI 優先度自動設定（US1）
  test "優先度未選択でタスク作成するとpriority_manually_setがfalseになる" do
    post tasks_path, params: { task: { title: "新しいタスク" } }
    task = Task.order(created_at: :desc).first
    assert_not task.priority_manually_set
  end

  # 手動優先度設定（US2）
  test "手動で優先度を選択して作成するとpriority_manually_setがtrueになる" do
    post tasks_path, params: { task: { title: "手動タスク", priority: "high" } }
    task = Task.order(created_at: :desc).first
    assert task.priority_manually_set
    assert_equal "high", task.priority
  end

  test "手動で優先度を選択した場合は指定した優先度が保持される" do
    post tasks_path, params: { task: { title: "手動タスク", priority: "low" } }
    task = Task.order(created_at: :desc).first
    assert_equal "low", task.priority
  end

  test "更新時に空文字priorityを送信してもタスクが更新される" do
    patch task_path(tasks(:shopping)), params: { task: { title: tasks(:shopping).title, priority: "" } }
    assert_redirected_to tasks_path
  end

  test "更新時に優先度を変更するとpriority_manually_setがtrueになる" do
    task = tasks(:shopping)
    original_priority = task.priority
    new_priority = original_priority == "high" ? "low" : "high"
    patch task_path(task), params: { task: { title: task.title, priority: new_priority } }
    assert task.reload.priority_manually_set
  end

  # タイトル変更時の再推論（US3）
  test "手動設定済みタスクのタイトル変更後もpriority_manually_setがtrueのまま" do
    task = tasks(:shopping)
    task.update_columns(priority_manually_set: true, priority: Task.priorities["high"])
    patch task_path(task), params: { task: { title: "タイトル変更後", priority: task.priority } }
    assert task.reload.priority_manually_set
    assert_equal "high", task.reload.priority
  end

  test "AI設定タスクのタイトル変更でpriorityが再推論される" do
    task = tasks(:shopping)
    task.update_columns(priority_manually_set: false, priority: Task.priorities["medium"])
    stub_anthropic_calls("AI提案テキスト", "high") do
      patch task_path(task), params: { task: { title: "緊急対応タスク", priority: "" } }
    end
    assert_equal "high", task.reload.priority
    assert_not task.reload.priority_manually_set
  end

  # ai_suggest
  test "タイトルなしのai_suggestはエラーを返す" do
    post ai_suggest_tasks_path, params: { title: "" }, as: :json
    assert_response :bad_request
  end

  test "未ログインのai_suggestはリダイレクト" do
    sign_out @user
    post ai_suggest_tasks_path, params: { title: "テスト" }, as: :json
    assert_response :unauthorized
  end
end
