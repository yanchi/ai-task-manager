class TasksController < ApplicationController
  before_action :set_task, only: [:show, :edit, :update, :destroy, :toggle]
  before_action :throttle_ai_suggest, only: :ai_suggest

  # GET /tasks
  def index
    @tasks = current_user.tasks
                         .order(created_at: :desc)
                         .page(params[:page]).per(20)

    # フィルタリング
    @tasks = @tasks.where(completed: params[:completed] == "true") if params[:completed].present?
    if params[:priority].present? && Task.priorities.key?(params[:priority])
      @tasks = @tasks.where(priority: params[:priority])
    end

    # 統計情報（1クエリで取得）
    counts = current_user.tasks.group(:completed).count
    @completed_count = counts[true] || 0
    @pending_count   = counts[false] || 0
    @total_count     = @completed_count + @pending_count
  end

  # GET /tasks/new
  def new
    @task = current_user.tasks.build
  end

  # POST /tasks
  def create
    p = normalize_priority_params(task_params)
    p = p.merge(priority_manually_set: true) if Task.priorities.key?(p[:priority])
    @task = current_user.tasks.build(p)

    if @task.save
      redirect_to tasks_path, notice: "タスクを作成しました。"
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /tasks/:id/edit
  def edit
  end

  # PATCH /tasks/:id
  def update
    p = normalize_priority_params(task_params)
    if Task.priorities.key?(p[:priority]) && Task.priorities[p[:priority]] != Task.priorities[@task.priority]
      p = p.merge(priority_manually_set: true)
    end

    if @task.update(p)
      redirect_to tasks_path, notice: "タスクを更新しました。"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /tasks/:id
  def destroy
    @task.destroy
    redirect_to tasks_path, notice: "タスクを削除しました。"
  end

  # PATCH /tasks/:id/toggle
  def toggle
    @task.update!(completed: !@task.completed)
    respond_to do |format|
      format.html { redirect_to tasks_path, notice: @task.completed ? "タスクを完了しました！" : "タスクを未完了に戻しました。" }
      format.turbo_stream do
        render turbo_stream: turbo_stream.replace(
          "task_#{@task.id}",
          partial: "tasks/task",
          locals: { task: @task }
        )
      end
    end
  end

  # POST /tasks/ai_suggest (Ajax)
  def ai_suggest
    title = params[:title]

    if title.blank?
      render json: { error: "タイトルを入力してください" }, status: :bad_request
      return
    end

    suggestion = TaskCompletionService.new(nil, title).call_with_title
    render json: { suggestion: suggestion }
  rescue => e
    Rails.logger.error "AI suggest error: #{e.message}"
    render json: { error: "AI補完に失敗しました。再度お試しください。" }, status: :internal_server_error
  end

  private

  def throttle_ai_suggest
    key = "ai_suggest:#{current_user.id}:#{Time.current.strftime('%Y%m%d%H%M')}"
    count = (Rails.cache.read(key) || 0) + 1
    Rails.cache.write(key, count, expires_in: 2.minutes)
    if count > 10
      render json: { error: "リクエストが多すぎます。しばらくしてから再試行してください。" }, status: :too_many_requests
    end
  end

  def set_task
    @task = current_user.tasks.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    redirect_to tasks_path, alert: "タスクが見つかりません。"
  end

  def task_params
    params.require(:task).permit(:title, :description, :ai_suggestion, :due_date, :priority, :completed)
  end

  # 不正な priority 値（空文字・無効値）を除外するサニタイズのみ行う
  def normalize_priority_params(p)
    Task.priorities.key?(p[:priority]) ? p : p.except(:priority)
  end
end
