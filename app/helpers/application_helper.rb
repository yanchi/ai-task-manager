module ApplicationHelper
  # 優先度に応じた Bootstrap カラークラスを返す
  def priority_badge_class(priority)
    case priority.to_s
    when "high"   then "danger"
    when "medium" then "warning"
    when "low"    then "secondary"
    else "secondary"
    end
  end

  # 優先度の日本語ラベル
  def priority_label(priority)
    { "high" => "高", "medium" => "中", "low" => "低" }[priority.to_s] || priority.to_s
  end
end
