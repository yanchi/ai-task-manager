# Cowork 引き継ぎドキュメント
## AI タスク管理アプリ 開発プロジェクト

---

## あなたへのお願い

このドキュメントは claude.ai でのやり取りを引き継いだものです。
以下の内容を把握した上で、開発作業を一緒に進めてください。

---

## 1. プロジェクト概要

**アプリ名：** AI タスク管理アプリ  
**目的：** Ruby on Rails × Anthropic API（Claude）を使ったポートフォリオ作品  
**コンセプト：** タスク名を入力するだけで AI が詳細・手順を自動補完するタスク管理 Web アプリ

---

## 2. 技術スタック（決定済み）

| カテゴリ | 技術 | バージョン |
|----------|------|-----------|
| バックエンド | Ruby on Rails | 8.0 |
| データベース | PostgreSQL | 16 |
| 認証 | Devise | 4.x |
| AI API | Anthropic API（Claude Haiku 3.5） | latest |
| 環境構築 | Docker / Docker Compose | latest |
| Web サーバー | Nginx + Puma | - |
| インフラ | さくらの VPS（Ubuntu 22.04） | - |
| SSL | Let's Encrypt（Certbot） | - |

---

## 3. 実装フェーズ（決定済み）

### Phase 1 ── 基本 CRUD（まずここから）
- [ ] Docker で Rails 開発環境を構築
- [ ] `rails new` でプロジェクト作成
- [ ] Devise でユーザー認証
- [ ] タスクの CRUD（作成・編集・削除・一覧）
- [ ] 完了フラグの切り替え

### Phase 2 ── AI タスク補完（コア機能・デモの中心）
- [ ] Anthropic API との連携
- [ ] `TaskCompletionService` の実装
- [ ] タスク名 → AI が詳細・手順を自動生成
- [ ] `ai_suggestion` カラムに補完結果を保存

### Phase 3 以降（今後の展望 / README に記載済み）
- AI タスク整理アシスト（優先度自動判定）
- 音声入力 → タスク変換（Whisper API）
- 遅延アラート・進捗予測

---

## 4. DB 設計（決定済み）

### users テーブル
| カラム | 型 | 備考 |
|--------|-----|------|
| id | bigint | PK |
| email | string | NOT NULL, UNIQUE |
| encrypted_password | string | Devise 管理 |
| created_at / updated_at | datetime | - |

### tasks テーブル
| カラム | 型 | 備考 |
|--------|-----|------|
| id | bigint | PK |
| user_id | bigint | FK → users.id |
| title | string | NOT NULL（ユーザーが入力） |
| description | text | ユーザーが編集可能 |
| ai_suggestion | text | AI 生成結果を別保存 |
| due_date | date | 締切日 |
| priority | integer | 0=低, 1=中, 2=高（default: 1） |
| completed | boolean | default: false |
| created_at / updated_at | datetime | - |

---

## 5. AI 補完の仕組み（設計済み）

- 呼び出しタイミング：タスク保存時（POST /tasks, PATCH /tasks/:id）
- モデル：`claude-haiku-4-5-20251001`
- max_tokens：300
- エラー時：デフォルトメッセージを表示し保存は継続

### プロンプト設計

```
system:
  あなたはタスク管理アシスタントです。
  タスク名を受け取り、以下の形式で詳細を補完してください。
  - 概要：タスクの目的（1文）
  - 手順：具体的な手順（3〜5項目）
  - ポイント：作業時の注意点（1〜2項目）
  出力は日本語で、200文字以内にまとめてください。

user: "{{ task_title }}" というタスクの詳細を補完してください。
```

---

## 6. ルーティング（設計済み）

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /tasks | タスク一覧 |
| GET | /tasks/new | タスク作成フォーム |
| POST | /tasks | タスク作成（AI 補完含む） |
| GET | /tasks/:id/edit | タスク編集フォーム |
| PATCH | /tasks/:id | タスク更新 |
| DELETE | /tasks/:id | タスク削除 |
| PATCH | /tasks/:id/toggle | 完了フラグ切り替え |
| POST | /tasks/ai_suggest | AI 補完のみ実行（Ajax） |

---

## 7. 作業ディレクトリ

```
~/work/ai-task-manager/
```

このディレクトリを Cowork のワークスペースとして使用してください。

---

## 8. 最初にやること（Phase 1 スタート）

以下の順で進めてください：

1. `~/work/ai-task-manager/` ディレクトリを作成
2. `Dockerfile` と `docker-compose.yml` を作成
3. `docker compose run web rails new . --force --database=postgresql --skip-bundle` を実行
4. `database.yml` を Docker 環境用に設定
5. `docker compose up --build` で起動確認
6. `rails db:create` でデータベース作成

---

## 9. 参考ファイル（claude.ai で作成済み）

以下のファイルは別途ダウンロード済みです。プロジェクトルートに配置してください：

- `README.md` → プロジェクトルート（`~/work/ai-task-manager/README.md`）
- `architecture_design.docx` → 設計資料として参照用

---

## 10. ユーザー情報

- Rails 経験：初学者（チュートリアル程度）
- ゴール：コア機能（Phase 1 + Phase 2）を実装してデモできる状態にする
- デプロイ先：さくらの VPS（Ubuntu 22.04）
- Anthropic API キー：別途用意済み（`.env` に設定する）
