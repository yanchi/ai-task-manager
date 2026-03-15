# テスト実行時に CSS ビルドをスキップする
if Rails.env.test?
  Rake::Task["css:build"].clear if Rake::Task.task_defined?("css:build")
  task "css:build" do
    # テスト環境では CSS ビルドをスキップ
  end
end
