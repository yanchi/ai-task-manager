import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "title", "preview", "suggestionText", "loading", "icon",
    "useButton", "description", "aiSuggestion"
  ]

  connect() {
    this.debounceTimer = null
    this.abortController = null
  }

  onTitleInput() {
    clearTimeout(this.debounceTimer)
    this.aiSuggestionTarget.value = ""
    const title = this.titleTarget.value.trim()

    if (title.length < 3) {
      this.previewTarget.style.display = "none"
      return
    }

    this.debounceTimer = setTimeout(() => this.#fetchAndShow(title), 1000)
  }

  async onSubmit(event) {
    const title = this.titleTarget.value.trim()
    if (title.length < 3 || this.aiSuggestionTarget.value) return

    event.preventDefault()
    clearTimeout(this.debounceTimer)
    await this.#fetchAndShow(title)
    this.element.requestSubmit()
  }

  usesuggestion() {
    if (!this.hasDescriptionTarget) return
    this.descriptionTarget.value = this.suggestionTextTarget.textContent
    this.usebuttonTarget.textContent = "コピーしました"
    this.usebuttonTarget.classList.replace("btn-outline-primary", "btn-success")
    setTimeout(() => {
      this.usebuttonTarget.innerHTML = '<i class="bi bi-clipboard-check me-1"></i>説明に使用する'
      this.usebuttonTarget.classList.replace("btn-success", "btn-outline-primary")
    }, 2000)
  }

  // private

  async #fetchAndShow(title) {
    this.previewTarget.style.display = "block"
    this.loadingTarget.style.display = "inline-block"
    this.iconTarget.style.display = "none"
    this.suggestionTextTarget.textContent = "AI が分析中..."

    if (this.abortController) this.abortController.abort()
    this.abortController = new AbortController()

    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      const response = await fetch("/tasks/ai_suggest", {
        method: "POST",
        headers: { "Content-Type": "application/json", "X-CSRF-Token": csrfToken },
        body: JSON.stringify({ title }),
        signal: this.abortController.signal
      })
      const data = await response.json()

      this.loadingTarget.style.display = "none"
      this.iconTarget.style.display = "inline-block"

      if (data.suggestion) {
        this.suggestionTextTarget.textContent = data.suggestion
        this.aiSuggestionTarget.value = data.suggestion
        this.useButtonTarget.style.display = "inline-block"
      } else {
        this.suggestionTextTarget.textContent = data.error || "AI補完を利用できませんでした。"
        this.useButtonTarget.style.display = "none"
      }
    } catch (error) {
      if (error.name === "AbortError") return
      this.loadingTarget.style.display = "none"
      this.iconTarget.style.display = "inline-block"
      this.suggestionTextTarget.textContent = "通信エラーが発生しました。"
    }
  }
}
