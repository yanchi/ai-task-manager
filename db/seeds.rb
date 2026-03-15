# デモ用シードデータ
# bin/rails db:seed で実行

puts "Creating demo user..."
user = User.find_or_create_by!(email: "demo@example.com") do |u|
  u.password = "password"
  u.password_confirmation = "password"
end

puts "Creating sample tasks..."

[
  {
    title: "週次レポートを作成する",
    description: "先週の進捗をまとめて上司に提出する",
    priority: :high,
    due_date: Date.today + 2,
    completed: false
  },
  {
    title: "ミーティングの議事録を整理する",
    description: "昨日のプロジェクト会議の内容をNotionにまとめる",
    priority: :medium,
    due_date: Date.today + 1,
    completed: false
  },
  {
    title: "コードレビューを実施する",
    priority: :high,
    due_date: Date.today,
    completed: false
  },
  {
    title: "テスト環境のセットアップ",
    description: "Docker環境でテストが動くようにする",
    priority: :medium,
    completed: true
  }
].each do |task_attrs|
  task = user.tasks.create!(task_attrs)
  puts "  Created: #{task.title}"
end

puts "Seed completed!"
