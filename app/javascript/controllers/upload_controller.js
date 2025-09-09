import { Controller } from "@hotwired/stimulus"

// Drag-and-drop + preview thumbnails for message attachments
export default class extends Controller {
  static targets = ["input", "previews", "textarea", "hint"]

  connect() {
    this.element.addEventListener('dragover', this.onDragOver)
    this.element.addEventListener('dragenter', this.onDragEnter)
    this.element.addEventListener('dragleave', this.onDragLeave)
    this.element.addEventListener('drop', (e) => this.onDrop(e))
    this.element.addEventListener('dragend', () => this.hideHint())
    this._hideTimer = null
  }

  disconnect() {
    this.element.removeEventListener('dragover', this.onDragOver)
  }

  onDragOver = (e) => {
    e.preventDefault()
    this.showHint()
  }

  onDragEnter = (e) => {
    e.preventDefault()
    this.showHint()
  }

  onDragLeave = (e) => {
    if (!this.element.contains(e.relatedTarget)) this.hideHint()
  }

  onDrop(e) {
    e.preventDefault()
    this.hideHint()
    if (!this.hasInputTarget) return
    const files = Array.from(e.dataTransfer.files || [])
    if (files.length === 0) return
    const dt = new DataTransfer()
    ;[...(this.inputTarget.files || []), ...files].forEach(f => dt.items.add(f))
    this.inputTarget.files = dt.files
    this.renderPreviews()
  }

  change() {
    this.renderPreviews()
  }

  renderPreviews() {
    if (!this.hasPreviewsTarget) return
    const files = Array.from(this.inputTarget.files || [])
    this.previewsTarget.innerHTML = ''
    files.forEach((file, idx) => {
      const wrap = document.createElement('div')
      wrap.className = 'relative'
      const btn = document.createElement('button')
      btn.type = 'button'
      btn.className = 'absolute -top-1 -right-1 bg-black/70 text-white rounded-full w-5 h-5 leading-5 text-xs'
      btn.textContent = '×'
      btn.addEventListener('click', () => this.removeAt(idx))
      const img = document.createElement('img')
      img.className = 'h-14 w-14 object-cover rounded border border-gray-200'
      img.src = URL.createObjectURL(file)
      wrap.appendChild(img)
      wrap.appendChild(btn)
      this.previewsTarget.appendChild(wrap)
    })
    if (this.hasTextareaTarget) this.textareaTarget.focus()
  }

  removeAt(idx) {
    const files = Array.from(this.inputTarget.files || [])
    files.splice(idx, 1)
    const dt = new DataTransfer()
    files.forEach(f => dt.items.add(f))
    this.inputTarget.files = dt.files
    this.renderPreviews()
  }

  showHint() {
    if (this.hasHintTarget) {
      this.hintTarget.classList.remove('hidden')
      clearTimeout(this._hideTimer)
      this._hideTimer = setTimeout(() => this.hideHint(), 800)
    }
  }

  hideHint() {
    if (this.hasHintTarget) this.hintTarget.classList.add('hidden')
    clearTimeout(this._hideTimer)
  }
}
