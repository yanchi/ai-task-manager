# Tasks: AI 優先度自動判定

**Input**: Design documents from `/specs/001-ai-priority-detect/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Organization**: タスクはユーザーストーリー単位でグループ化。Constitution V に基づきテストタスクを含む。

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 並列実行可能（異なるファイル、未完了タスクへの依存なし）
- **[Story]**: 対応するユーザーストーリー（US1/US2/US3）

---

## Phase 1: Setup（マイグレーション作成）

**Purpose**: スキーマ変更の準備。全ユーザーストーリーの前提条件。

- [x] T001 `priority_manually_set` カラム追加マイグレーションファイルを作成する `db/migrate/20260315060429_add_priority_manually_set_to_tasks.rb` (boolean, default: false, null: false)

---

## Phase 2: Foundational（基盤実装）

**Purpose**: 全ユーザーストーリーが依存する共通コンポーネント。Phase 1 完了後に実施。

**⚠️ CRITICAL**: このフェーズ完了まで US1〜US3 の実装は開始しない

- [x] T002 Docker コンテナ内でマイグレーションを実行する `docker compose exec web rails db:migrate`
- [x] T003 [P] `TaskCompletionService` に `call_priority` / `call_combined` メソッドを追加する `app/services/task_completion_service.rb`（入力サニタイズ・タイムアウト・フォールバック含む。`call_combined` は提案+優先度を1回のAPI呼び出しでJSON取得し2回呼び出しを廃止）
- [x] T004 [P] `call_priority` / `call_combined` のユニットテストを追加する `test/services/task_completion_service_test.rb`（Minitest::Mock で Anthropic::Client をスタブ、成功・タイムアウト・エラー・JSON不正のケース）

**Checkpoint**: `docker compose exec web rails test test/services/task_completion_service_test.rb` が全件パス

---

## Phase 3: User Story 1 - タスク作成時に優先度が自動設定される (Priority: P1) 🎯 MVP

**Goal**: 優先度未選択でタスクを作成すると AI が自動的に優先度をセットする

**Independent Test**: タイトルのみ入力して優先度を選択せずにタスク作成 → 優先度が high/medium/low のいずれかに自動設定されていること

### Implementation

- [x] T005 [US1] `Task` モデルの `after_create` コールバックを修正し、補完+優先度が両方必要な場合は `call_combined`、どちらか一方のみの場合は `call` / `call_priority` を呼び出す `app/models/task.rb`（priority は enum default で常に medium。nil チェック不要）
- [x] T006 [US1] 新規作成フォームの priority select に `include_blank: "優先度を選択（任意）"` を追加し、デフォルト未選択にする `app/views/tasks/_form.html.erb`

### Tests

- [x] T007 [P] [US1] `Task` モデルテストを追加する `test/models/task_test.rb`（優先度 nil で作成時に AI 推論が呼ばれること、AI エラー時に "medium" になること）
- [x] T008 [P] [US1] コントローラーテストを追加する `test/controllers/tasks_controller_test.rb`（優先度未選択の作成リクエストで priority が自動セットされること）

**Checkpoint**: タスク作成フォームで優先度を選択せずに保存 → 一覧画面で優先度が表示されること

---

## Phase 4: User Story 2 - 自動設定された優先度を手動で上書きできる (Priority: P2)

**Goal**: ユーザーが優先度を手動選択した場合、AI 推論が行われない・再上書きしない

**Independent Test**: 新規作成フォームで優先度を手動選択して保存 → AI 推論が発火せず選択値が保持されること

### Implementation

- [x] T009 [US2] `priority_manually_set` は strong parameters に含めず、サーバーサイドのみで制御する `app/controllers/tasks_controller.rb`（クライアントから任意の値を渡させないためセキュリティ上 strong params から除外）
- [x] T010 [US2] `create` アクションに手動選択検出を追加する `app/controllers/tasks_controller.rb`（`task_params[:priority].present?` なら `priority_manually_set: true` を付加してからビルド）

### Tests

- [x] T011 [P] [US2] コントローラーテストを追加する `test/controllers/tasks_controller_test.rb`（手動で優先度選択時に AI 推論がスキップされること）
- [x] T012 [P] [US2] コントローラーテストを追加する `test/controllers/tasks_controller_test.rb`（手動設定後に編集しても AI が優先度を再上書きしないこと）

**Checkpoint**: 新規作成フォームで優先度「高」を選択して保存 → AI 推論なしで「高」が保持されること

---

## Phase 5: User Story 3 - タイトル変更時に優先度が再推論される (Priority: P3)

**Goal**: AI 設定済みタスクのタイトルを変更すると優先度が再推論される。手動設定済みタスクは変更されない。

**Independent Test**: AI-set タスクのタイトルを変更して保存 → 優先度が新タイトルに基づいて更新されること

### Implementation

- [x] T013 [US3] `Task` モデルの `after_update` コールバックを修正し、タイトル変更時のみ実行。`!priority_manually_set` なら `call_combined`、手動設定済みなら `call`（提案のみ）を呼び出す `app/models/task.rb`
- [x] T014 [US3] `update` アクションに優先度変更検出を追加する `app/controllers/tasks_controller.rb`（`task_params[:priority]` が現在値と異なる場合に `priority_manually_set: true` を付加）

### Tests

- [x] T015 [P] [US3] `Task` モデルテストを追加する `test/models/task_test.rb`（AI-set タスクのタイトル変更で再推論が発火すること、手動-set タスクは再推論しないこと）
- [x] T016 [P] [US3] コントローラーテストを追加する `test/controllers/tasks_controller_test.rb`（手動設定済みタスクのタイトル変更で再推論しないこと）

**Checkpoint**: 全テスト通過 `docker compose exec web rails test`

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T017 quickstart.md の動作確認手順を Docker 内で実施し、3 つのユーザーストーリーが期待通り動作することを確認する
- [x] T018 [P] CLAUDE.md のテストセクションおよびAI統合の説明を更新し `call_priority` / `call_combined` を反映する `CLAUDE.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 依存なし - 即座に開始可能
- **Phase 2 (Foundational)**: Phase 1 完了後 - 全ユーザーストーリーをブロック
- **Phase 3 (US1)**: Phase 2 完了後に開始
- **Phase 4 (US2)**: Phase 2 完了後に開始（US1 と並列可能）
- **Phase 5 (US3)**: Phase 2 完了後に開始（US1/US2 と並列可能）
- **Phase 6 (Polish)**: 全ユーザーストーリー完了後

### User Story Dependencies

- **US1 (P1)**: Phase 2 完了後に独立して実装・テスト可能
- **US2 (P2)**: Phase 2 完了後に独立して実装・テスト可能（US1 の after_create コールバックとは別ファイル）
- **US3 (P3)**: Phase 2 完了後に独立して実装可能（after_update は after_create と共存）

### Within Each User Story

- Implementation → Tests の順（Constitution V の要件）
- モデル変更 → サービス変更 → コントローラー変更 → フォーム変更 の順

---

## Parallel Example: Phase 2

```bash
# T003 と T004 は異なるファイルを対象とするため並列実行可能:
Task T003: "add call_priority / call_combined to app/services/task_completion_service.rb"
Task T004: "add call_priority / call_combined tests to test/services/task_completion_service_test.rb"
```

---

## Implementation Strategy

### MVP First (User Story 1 のみ)

1. Phase 1: マイグレーション作成
2. Phase 2: `call_priority` / `call_combined` メソッド + テスト（T001〜T004）
3. Phase 3: US1 実装 + テスト（T005〜T008）
4. **STOP & VALIDATE**: `rails test` 全件パス、ブラウザで動作確認

### Incremental Delivery

1. Setup + Foundational → AI 推論サービス準備完了
2. US1 追加 → タスク作成時の自動優先度設定が動作
3. US2 追加 → 手動上書きが機能、AI 再上書きなし
4. US3 追加 → タイトル変更時の再推論が動作

---

## Notes

- [P] タスク = 異なるファイル、依存なし
- [US?] ラベル = spec.md のユーザーストーリーとの対応
- 全テストは `docker compose exec web rails test` で実行
- `Anthropic::Client` は Minitest::Mock でスタブ（外部 API 呼び出しなし）
- 各フェーズ完了後にコミットを推奨
