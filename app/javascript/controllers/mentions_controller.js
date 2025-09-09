import { Controller } from "@hotwired/stimulus"

// Adds @mention suggestions to a textarea.
export default class extends Controller {
  static targets = ["textarea", "menu"]
  static values = { users: Array }

  connect() {
    this.hideMenu()
  }

  onInput(event) {
    const caret = this.textareaTarget.selectionStart
    const upto = this.textareaTarget.value.slice(0, caret)
    const match = upto.match(/(^|\s)@(\w{0,50})$/)
    if (!match) { this.hideMenu(); return }
    const q = match[2].toLowerCase()
    const list = (this.usersValue || []).filter(u => u.toLowerCase().startsWith(q)).slice(0, 6)
    if (list.length === 0) { this.hideMenu(); return }
    this.renderMenu(list)
  }

  renderMenu(list) {
    this.menuTarget.innerHTML = list.map((u, i) => `
      <button type="button" data-index="${i}" class="block w-full text-left px-3 py-1 text-sm hover:bg-gray-100" data-action="click->mentions#pick">@${u}</button>
    `).join("")
    this.menuTarget.classList.remove("hidden")
  }

  pick(event) {
    const label = event.target.textContent.trim() // like @username
    this.replaceCurrentMention(label + ' ')
    this.hideMenu()
    this.textareaTarget.focus()
    event.preventDefault()
  }

  maybeAccept(event) {
    if (this.menuTarget.classList.contains("hidden")) return
    // Enter should accept the first suggestion
    event.preventDefault()
    event.stopPropagation()
    const first = this.menuTarget.querySelector("button[data-index='0']")
    if (first) first.click()
  }

  hideMenu() { this.menuTarget.classList.add("hidden") }

  replaceCurrentMention(text) {
    const ta = this.textareaTarget
    const caret = ta.selectionStart
    const upto = ta.value.slice(0, caret)
    const after = ta.value.slice(caret)
    const m = upto.match(/(^|\s)@(\w{0,50})$/)
    if (!m) return
    const start = upto.length - (m[2] ? m[2].length + 1 : 1)
    const before = ta.value.slice(0, start)
    ta.value = before + text + after
    const newCaret = (before + text).length
    ta.setSelectionRange(newCaret, newCaret)
  }
}

