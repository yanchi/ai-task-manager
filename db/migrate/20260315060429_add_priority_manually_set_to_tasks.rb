class AddPriorityManuallySetToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :priority_manually_set, :boolean, default: false, null: false
  end
end
