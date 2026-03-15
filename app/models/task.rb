class Task < ApplicationRecord
  belongs_to :user

  # Enum（優先度）
  enum :priority, { low: 0, medium: 1, high: 2 }, default: :medium

  # バリデーション
  validates :title, presence: true, length: { maximum: 255 }
  validates :description, length: { maximum: 2000 }, allow_blank: true
  validates :priority, inclusion: { in: priorities.keys }

  # スコープ
  scope :by_user, ->(user) { where(user: user) }
  scope :completed, -> { where(completed: true) }
  scope :pending, -> { where(completed: false) }
  scope :by_due_date, -> { order(due_date: :asc) }
  scope :by_priority, -> { order(priority: :desc) }
  scope :recent, -> { order(created_at: :desc) }

  # コールバック
  after_create :generate_ai_suggestion, unless: :ai_suggestion?
  after_update :generate_ai_suggestion, if: :saved_change_to_title?

  private

  def generate_ai_suggestion
    # バックグラウンドで AI 補完を実行（Sidekiq 未使用のためインライン実行）
    TaskCompletionService.new(self).call
  rescue => e
    Rails.logger.error "AI suggestion failed for task #{id}: #{e.message}"
  end
end
