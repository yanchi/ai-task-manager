# Quickstart: AI 優先度自動判定

**Branch**: `001-ai-priority-detect`

## 実装ステップ概要

### 1. マイグレーション作成・実行

```bash
docker compose exec web rails generate migration AddPriorityManuallySetToTasks priority_manually_set:boolean
docker compose exec web rails db:migrate
```

### 2. Task モデル更新

`app/models/task.rb` のコールバックを修正:
- `after_create`: 提案・優先度が両方必要 → `call_combined`、どちらか一方のみ → `call` / `call_priority`（priority は enum default で常に medium。フォームで未選択時は空文字→コントローラで `:priority` を除外→AI 推論対象）
- `after_update`: タイトル変更時のみ実行。`!priority_manually_set` なら `call_combined`、手動設定済みなら `call`（提案のみ）

### 3. TaskCompletionService 拡張

`app/services/task_completion_service.rb` に以下のメソッドを追加:

- `call_priority`: 優先度のみを推論してタスクに保存（3秒タイムアウト）
- `call_combined`: 提案文と優先度を1回のAPI呼び出しで取得しタスクに保存（4秒タイムアウト・JSON形式で返却）
  - 補完と優先度推論が両方必要な場合（最多パス）に使用
  - API呼び出しを2回→1回に削減しレスポンスタイムを改善
- エラー時はフォールバック値（提案: DEFAULT_MESSAGE、優先度: `"medium"`）

### 4. TasksController 更新

`update` アクションで優先度変更検出を追加:
- `task_params[:priority]` が現在値と異なる場合 → `priority_manually_set = true` を付加

### 5. フォーム更新

`app/views/tasks/_form.html.erb` の priority select に `include_blank` を追加:
- 新規作成フォーム: 初期値を空（未選択）にする

### 6. テスト追加

- `test/models/task_test.rb`: AI 推論コールバックのテスト
- `test/services/task_completion_service_test.rb`: `call_priority` / `call_combined` メソッドのテスト
- `test/controllers/tasks_controller_test.rb`: 手動設定フラグの動作テスト

## 動作確認手順

```bash
# サーバー起動
docker compose up

# タスク作成（優先度未選択）→ AI が自動設定されることを確認
# タスク編集でタイトル変更 → AI-set の場合のみ再推論されることを確認
# 手動で優先度変更後にタイトル変更 → 再推論されないことを確認
```
