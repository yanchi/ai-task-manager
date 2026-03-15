# Research: AI 優先度自動判定

**Date**: 2026-03-15
**Branch**: `001-ai-priority-detect`

## Decision 1: 優先度推論ロジックの配置

**Decision**: `TaskCompletionService` に `call_priority` メソッドを追加し、単一サービスクラスに集約する

**Rationale**: Constitution III（Simplicity & MVP）は「新しいサービスクラスは 2 つ以上の具体的ユースケースが存在するまで作成しない」と定める。`TaskPriorityService` を別クラスにすることも考えられるが、現時点では 1 つのユースケースのみ（優先度推論）のため新クラス作成は違反。既存の `TaskCompletionService` に責務を追加することで Constitution III に準拠する。

**Alternatives considered**:
- `TaskPriorityService` を新規作成 → Constitution III 違反（1 ユースケースのみ）
- モデルコールバックに直接 API 呼び出し → Constitution I 違反（API ロジックはサービス層に集約）

---

## Decision 2: 手動/AI 設定の区別方法

**Decision**: `tasks` テーブルに `priority_manually_set:boolean default:false` カラムを追加するマイグレーションを作成する

**Rationale**: FR-007 の要件を最小限のスキーマ変更で実装できる。boolean フラグはシンプルで Rails の `update_columns` で容易に操作でき、既存コードへの影響が最小。

**Alternatives considered**:
- `priority_source: enum(ai, manual)` → boolean で十分な情報量のため過剰
- フォームの隠しフィールドのみで管理 → DB に永続化されないため FR-007 を満たせない

---

## Decision 3: 更新時の手動変更検出方法

**Decision**: コントローラーの `update` アクションで `task_params[:priority].present? && task_params[:priority] != @task.priority` を評価し、優先度変更があれば `priority_manually_set=true` をパラメータに追加してから更新する

**Rationale**: フォームの隠しフィールドやイベントリスナーを追加せず、サーバーサイドのみで判定できる。シンプルかつ確実。

**Alternatives considered**:
- Stimulus で隠しフィールド `priority_touched` を送信 → フロントエンド変更が増える、Constitution III に反する可能性
- 全更新時に常に手動フラグを立てる → FR-006（タイトル変更時の再推論）が機能しなくなる

---

## Decision 4: 新規作成フォームの優先度フィールド初期値

**Decision**: `_form.html.erb` の `select` タグに `include_blank: "優先度を選択（任意）"` を追加し、未選択を nil として送信する

**Rationale**: Rails の `collection_select` / `select` はデフォルトで空オプションを含められる。nil が送信された場合に AI 推論を発火する判定が明確になる。

**Alternatives considered**:
- JavaScript で動的に空オプションを挿入 → サーバーサイドで完結できるため不要
