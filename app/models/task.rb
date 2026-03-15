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
  after_create :run_ai_on_create
  after_update :run_ai_on_update

  private

  def run_ai_on_create
    service = TaskCompletionService.new(self)
    service.call unless ai_suggestion?
    service.call_priority if needs_priority_inference?
  rescue => e
    Rails.logger.error "AI callback failed on create for task #{id}: #{e.message}"
  end

  def run_ai_on_update
    service = TaskCompletionService.new(self)
    service.call if saved_change_to_title?
    service.call_priority if should_reinfer_priority?
  rescue => e
    Rails.logger.error "AI callback failed on update for task #{id}: #{e.message}"
  end

  def needs_priority_inference?
    !priority_manually_set? && title.present? && title.length >= 3
  end

  def should_reinfer_priority?
    saved_change_to_title? && !priority_manually_set?
  end
end
