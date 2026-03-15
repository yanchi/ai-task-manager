# Data Model: AI 優先度自動判定

**Date**: 2026-03-15
**Branch**: `001-ai-priority-detect`

## 変更対象: tasks テーブル

### 追加カラム

| カラム名 | 型 | デフォルト | NULL | 説明 |
|---------|---|----------|------|------|
| `priority_manually_set` | boolean | false | NOT NULL | ユーザーが手動で優先度を設定したかどうか |

### マイグレーション

```ruby
add_column :tasks, :priority_manually_set, :boolean, default: false, null: false
```

### 既存カラム（参考）

| カラム名 | 型 | 説明 |
|---------|---|------|
| `priority` | integer | 0=低, 1=中, 2=高 (enum) |
| `title` | string | タスクタイトル |
| `description` | text | タスク説明 |
| `ai_suggestion` | text | AI 補完テキスト |

## 状態遷移: priority_manually_set フラグ

```
[新規作成 - 優先度未選択]
  → priority_manually_set = false
  → AI 推論を実行 → priority セット

[新規作成 - 優先度手動選択]
  → priority_manually_set = true
  → AI 推論をスキップ

[更新 - 優先度変更なし + タイトル変更]
  → priority_manually_set = false の場合: AI 再推論を実行
  → priority_manually_set = true の場合: 何もしない

[更新 - 優先度を手動変更]
  → priority_manually_set = true に更新
  → 以降タイトル変更でも AI 再推論しない
```

## TaskCompletionService 拡張

`call_priority(title, description)` メソッドを追加:
- 入力: タイトル（サニタイズ済み）、説明（任意）
- 出力: `"high"` / `"medium"` / `"low"` のいずれか
- エラー時: `"medium"` を返す（フォールバック）
- タイムアウト: 3 秒
