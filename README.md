# AI タスク管理アプリ

Ruby on Rails × Anthropic API（Claude）を使ったポートフォリオ作品。
タスク名を入力するだけで AI が詳細・手順を自動補完するタスク管理 Web アプリ。

## 技術スタック

| カテゴリ | 技術 |
|----------|------|
| バックエンド | Ruby on Rails 8.0 |
| データベース | PostgreSQL 16 |
| 認証 | Devise 4.x |
| AI API | Anthropic Claude Haiku 3.5 |
| 環境構築 | Docker / Docker Compose |
| Web サーバー | Nginx + Puma |
| インフラ | さくらの VPS（Ubuntu 22.04） |

## セットアップ手順

### 1. リポジトリのクローン

```bash
git clone <リポジトリURL>
cd ai-task-manager
```

### 2. 環境変数の設定

```bash
cp .env.example .env
# .env を編集して ANTHROPIC_API_KEY を設定してください
```

### 3. Docker イメージのビルドと起動

```bash
# 初回セットアップ
docker compose build

# ビルド & 起動
docker compose up --build
```

### 4. データベースの作成とマイグレーション

```bash
# 別ターミナルで実行
docker compose exec web rails db:create
docker compose exec web rails db:migrate
docker compose exec web rails db:seed  # デモデータ投入（任意）
```

### 5. アクセス

ブラウザで http://localhost:3000 にアクセス

## 開発コマンド

```bash
# コンテナ起動
docker compose up

# コンテナ停止
docker compose down

# Rails コンソール
docker compose exec web rails console

# マイグレーション
docker compose exec web rails db:migrate

# ログ確認
docker compose logs -f web
```

## 機能

### Phase 1（実装済み）
- ユーザー認証（Devise）
- タスクの CRUD
- 完了フラグの切り替え
- タスクのフィルタリング（優先度・完了状態）

### Phase 2（実装済み）
- Anthropic API 連携（Claude Haiku）
- タスク作成・更新時に AI が詳細・手順を自動補完
- フォームでリアルタイム AI プレビュー（Ajax）

### Phase 3（今後）
- AI タスク整理アシスト（優先度自動判定）
- 音声入力 → タスク変換
- 遅延アラート・進捗予測

## デプロイ（さくらの VPS）

```bash
# Nginx + Puma 構成
# Let's Encrypt で SSL 対応
# 詳細は architecture_design.docx を参照
```
