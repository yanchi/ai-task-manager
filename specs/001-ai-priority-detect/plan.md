# Implementation Plan: AI 優先度自動判定

**Branch**: `001-ai-priority-detect` | **Date**: 2026-03-15 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/001-ai-priority-detect/spec.md`

## Summary

タスク作成・更新時に Anthropic Claude API を使ってタイトル・説明から優先度（high/medium/low）を
自動推論する。`tasks` テーブルに `priority_manually_set` フラグを追加し、ユーザーの手動設定を
AI 再推論が上書きしないよう制御する。既存の `TaskCompletionService` に `call_priority` / `call_combined` メソッドを
追加して実装する（新規サービスクラスは作成しない）。補完と優先度推論が両方必要な場合は `call_combined` で1回の API 呼び出しに統合。

## Technical Context

**Language/Version**: Ruby 3.3.0 / Rails 8.0.x
**Primary Dependencies**: anthropic gem 0.4.x, Devise 4.9.x, Stimulus.js + Turbo (Hotwire)
**Storage**: PostgreSQL 16（tasks テーブルにカラム追加）
**Testing**: Minitest 5.25
**Target Platform**: Docker Compose（開発）/ さくら VPS Ubuntu 22.04（本番）
**Project Type**: Web application (Rails MVC)
**Performance Goals**: タスク作成の所要時間増加 5 秒未満（`call_combined` で1回のAPI呼び出し・タイムアウト4秒）
**Constraints**: 同期処理のみ（非同期ジョブ不使用）、フォールバック値「中」
**Scale/Scope**: 個人利用ポートフォリオ、数十〜数百タスク程度

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 原則 | 判定 | 根拠 |
|------|------|------|
| I. AI Integration as First-Class Feature | ✅ PASS | `call_priority` / `call_combined` を `TaskCompletionService` に集約。モデル・コントローラーに API ロジックを持ち込まない |
| II. User Data Isolation (NON-NEGOTIABLE) | ✅ PASS | 認可ロジック変更なし。既存の `current_user.tasks.find` を維持 |
| III. Simplicity & MVP | ✅ PASS | 新規サービスクラス作成なし。既存 `TaskCompletionService` にメソッド追加のみ |
| IV. Security & Injection Prevention | ✅ PASS | タイトルは既存サニタイズ処理（truncate + 制御文字除去）を再利用 |
| V. Test Coverage for Critical Paths | ✅ PASS | `call_priority` / `call_combined` のユニットテスト、コントローラーテスト（手動フラグ）を追加必須 |

**Post-Design Re-check**: `priority_manually_set` カラム追加はスキーマ変更のため、
Constitution の Quality Gates「スキーマ変更: Rails マイグレーションを必ず作成」に従いマイグレーションファイルを作成する。

## Project Structure

### Documentation (this feature)

```text
specs/001-ai-priority-detect/
├── plan.md              # This file
├── research.md          # Phase 0 output ✅
├── data-model.md        # Phase 1 output ✅
├── quickstart.md        # Phase 1 output ✅
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source Code (変更対象ファイル)

```text
app/
├── models/
│   └── task.rb                         # コールバック修正
├── services/
│   └── task_completion_service.rb      # call_priority / call_combined メソッド追加
├── controllers/
│   └── tasks_controller.rb             # update アクションに手動フラグ検出追加
└── views/tasks/
    └── _form.html.erb                  # priority select に include_blank 追加

db/migrate/
└── YYYYMMDD_add_priority_manually_set_to_tasks.rb   # 新規マイグレーション

test/
├── models/task_test.rb                 # AI 推論コールバックテスト追加
├── services/task_completion_service_test.rb  # call_priority / call_combined テスト追加
└── controllers/tasks_controller_test.rb      # 手動フラグ動作テスト追加
```

**Structure Decision**: 既存の Rails MVC 構造に最小限の変更を加える。新規ファイルはマイグレーションのみ。

## Complexity Tracking

> Constitution Check 違反なし。記録不要。
