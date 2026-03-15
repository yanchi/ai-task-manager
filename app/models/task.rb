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
    if !ai_suggestion? && needs_priority_inference?
      service.call_combined
    elsif !ai_suggestion?
      service.call
    elsif needs_priority_inference?
      service.call_priority
    end
  rescue => e
    Rails.logger.error "AI callback failed on create for task #{id}: #{e.message}"
  end

  def run_ai_on_update
    return unless saved_change_to_title?
    service = TaskCompletionService.new(self)
    should_reinfer_priority? ? service.call_combined : service.call
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
