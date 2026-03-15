class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.references :user, null: false, foreign_key: true
      t.string  :title,         null: false
      t.text    :description
      t.text    :ai_suggestion
      t.date    :due_date
      t.integer :priority,      null: false, default: 1
      t.boolean :completed,     null: false, default: false

      t.timestamps
    end

    add_index :tasks, [:user_id, :created_at]
    add_index :tasks, [:user_id, :completed]
    add_index :tasks, [:user_id, :priority]
  end
end
