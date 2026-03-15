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
- `after_create`: `!priority_manually_set` かつタイトル3文字以上の場合のみ推論（priority は enum default で常に medium が入るため nil にはならない。フォームで未選択時は空文字を送信→コントローラで `:priority` パラメータを除外して AI 推論対象にする）
- `after_update`: タイトル変更 かつ `!priority_manually_set` の場合のみ再推論

### 3. TaskCompletionService 拡張

`app/services/task_completion_service.rb` に `call_priority` メソッドを追加:
- Claude に優先度推論用プロンプトを送信
- `"high"` / `"medium"` / `"low"` を返す
- 3 秒タイムアウト + エラー時 `"medium"` フォールバック

### 4. TasksController 更新

`update` アクションで優先度変更検出を追加:
- `task_params[:priority]` が現在値と異なる場合 → `priority_manually_set = true` を付加

### 5. フォーム更新

`app/views/tasks/_form.html.erb` の priority select に `include_blank` を追加:
- 新規作成フォーム: 初期値を空（未選択）にする

### 6. テスト追加

- `test/models/task_test.rb`: AI 推論コールバックのテスト
- `test/services/task_completion_service_test.rb`: `call_priority` メソッドのテスト
- `test/controllers/tasks_controller_test.rb`: 手動設定フラグの動作テスト

## 動作確認手順

```bash
# サーバー起動
docker compose up

# タスク作成（優先度未選択）→ AI が自動設定されることを確認
# タスク編集でタイトル変更 → AI-set の場合のみ再推論されることを確認
# 手動で優先度変更後にタイトル変更 → 再推論されないことを確認
```
