<!--
SYNC IMPACT REPORT
==================
Version change: [TEMPLATE] → 1.0.0 (initial ratification)
Modified principles: N/A (first fill from template)
Added sections:
  - Core Principles (5 principles defined)
  - Technology Stack Constraints
  - Development Workflow
  - Governance
Removed sections: none
Templates requiring updates:
  - .specify/templates/plan-template.md ✅ reviewed — "Constitution Check" section aligns with principles
  - .specify/templates/spec-template.md ✅ reviewed — FR/SC structure compatible
  - .specify/templates/tasks-template.md ✅ reviewed — phase structure compatible
  - .specify/templates/agent-file-template.md ✅ reviewed — no conflicting references
Follow-up TODOs: none
-->

# AI Task Manager Constitution

## Core Principles

### I. AI Integration as First-Class Feature

Anthropic Claude API の呼び出しは `TaskCompletionService` に集約し、コントローラー・モデルに
API ロジックを直接書いてはならない。

- API キー未設定・API エラー時は必ずフォールバックメッセージを返し、例外をユーザーに露出しない。
- ユーザー入力（タスクタイトル）は Claude へ渡す前にサニタイズ（長さ切り詰め・制御文字除去）を
  行わなければならない。
- レート制限はコントローラーの `before_action` で実装し、サービス層には持ち込まない。

**Rationale**: AI 機能はこのアプリの核心価値であり、品質・安全性の基準を他と分けて管理する必要がある。

### II. User Data Isolation (NON-NEGOTIABLE)

各ユーザーは自分のタスクのみ参照・操作できる。認可チェックの漏れはいかなる理由でも許容しない。

- コントローラーの `set_task` は必ず `current_user.tasks.find(...)` で取得し、
  `Task.find(...)` を直接使ってはならない。
- `before_action :authenticate_user!` は全アクションに適用されなければならない。
- テストでは他ユーザーのリソースへのアクセス拒否を必ず検証する。

**Rationale**: マルチテナント SaaS の基本要件。データ漏洩は致命的な信頼失墜につながる。

### III. Simplicity & MVP

現在の要件を満たす最もシンプルな実装を選ぶ。投機的な汎化・早期抽象化は禁止。

- 新しいサービスクラス・モジュールは少なくとも 2 つの具体的なユースケースが存在するまで作成しない。
- バックグラウンドジョブは非同期処理が明確に必要になるまで導入しない（現状は同期で可）。
- 新規 Docker サービスの追加は PR 説明で現在の具体的な必要性を示すこと。

**Rationale**: ポートフォリオプロジェクトとして、小さく保ち動かし続けることが保守性につながる。

### IV. Security & Injection Prevention

ユーザー入力は非信頼データとして扱い、XSS・SQLi・プロンプトインジェクションを防ぐ。

- ビューでユーザー由来の文字列を出力する際は ERB の自動エスケープに頼り、
  `raw` / `html_safe` の手動使用には明示的な正当化が必要。
- Claude へ渡すタイトルは `truncate(100)` + 特殊文字除去を必ず通す。
- シークレット（API キー、DB パスワード）は `.env` に置き、リポジトリにコミットしない。

**Rationale**: OWASP Top-10 準拠。Claude へのプロンプトインジェクションも同様に脅威として扱う。

### V. Test Coverage for Critical Paths

認証・認可・AI 統合の 3 領域はテストで保護しなければならない。

- コントローラーテストは「自分のリソース」「他人のリソース」「未ログイン」の 3 パターンを網羅する。
- `TaskCompletionService` のテストは Minitest::Mock で Anthropic::Client をスタブし、
  外部 API を呼ばない。
- モデルバリデーションのエラーメッセージは日本語 i18n の実際の文字列でアサートする。

**Rationale**: AI 呼び出しと認可は回帰しやすい。テストなしの変更は本番障害リスクが高い。

## Technology Stack Constraints

以下の技術選定は現フェーズで固定。変更には本 Constitution の改訂が必要。

| Layer | Technology | Version |
|-------|-----------|---------|
| Backend | Ruby on Rails | 8.0.x |
| Database | PostgreSQL | 16 |
| AI | Anthropic Claude (anthropic gem) | 0.4.x |
| Auth | Devise | 4.9.x |
| Frontend | Stimulus.js + Turbo (Hotwire) | Rails 8 同梱 |
| CSS | Bootstrap 5 (CDN) | 5.x |
| Container | Docker Compose | current stable |

- JavaScript バンドラーは使用しない（importmap-rails を使用）。
- バックグラウンドキューは現時点で導入しない（Solid Queue / Sidekiq は将来検討）。
- 環境変数は `.env` + `dotenv-rails` パターンを使用する。

## Development Workflow

### Change Process

1. 機能追加は `spec.md` でユーザーストーリーと受け入れ基準を定義する。
2. `plan.md` で技術的アプローチを定め、Constitution Check を通過してから実装を開始する。
3. `tasks.md` でタスクを依存順に実行する。
4. PR は関連する spec/plan を参照し、Constitution Check の遵守を確認すること。

### Quality Gates

- **マージ前**: `spec.md` の受け入れシナリオをすべて確認する。
- **AI 連携の変更**: `TaskCompletionService` のユニットテストをすべて通過させる。
- **認可ロジックの変更**: 他ユーザーリソースへのアクセス拒否テストを追加・更新する。
- **スキーマ変更**: Rails マイグレーションを必ず作成し、`db:rollback` できる形にする。

### Docker-First Development

すべてのローカル開発は Docker Compose 内で実行する。
`docker compose exec web` 経由でコマンドを実行し、ホスト上で直接 `rails` を動かすことは禁止。

## Governance

本 Constitution はすべての非公式な慣習・口頭合意に優先する。`CLAUDE.md` と競合する場合、
アーキテクチャ上の決定は本 Constitution が優先し、`CLAUDE.md` は AI アシスタントの
ワークフロー設定を管轄する。

### Amendment Procedure

1. このファイルを変更する PR を開き、変更理由を明記する。
2. セマンティックバージョニングに従ってバージョンを上げる:
   - **MAJOR**: 既存原則の削除または再定義。
   - **MINOR**: 新原則の追加または既存原則の大幅な拡張。
   - **PATCH**: 表現の明確化、誤字修正、意味に影響しない修正。
3. ファイル先頭の Sync Impact Report コメントを更新する。
4. 影響を受ける `.specify/templates/` ファイルに変更を反映する。
5. 少なくとも 1 件の明示的な承認を得てからマージする。

### Compliance

すべての PR とコードレビューは、変更が 5 つの Core Principles に違反しないことを確認しなければならない。
違反は先送りせずマージ前に解消する。

**Version**: 1.0.0 | **Ratified**: 2026-03-15 | **Last Amended**: 2026-03-15
