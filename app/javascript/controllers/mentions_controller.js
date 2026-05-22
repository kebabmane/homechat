import { Controller } from "@hotwired/stimulus"

// Adds @mention suggestions to a textarea.
export default class extends Controller {
  static targets = ["textarea", "menu"]
  static values = { users: Array }

  connect() {
    this.hideMenu()
    this._selectedIndex = -1
  }

  onInput(event) {
    const caret = this.textareaTarget.selectionStart
    const upto = this.textareaTarget.value.slice(0, caret)
    const match = upto.match(/(^|\s)@(\w{0,50})$/)
    if (!match) { this.hideMenu(); return }
    const q = match[2].toLowerCase()
    const list = (this.usersValue || []).filter(u => u.toLowerCase().startsWith(q)).slice(0, 6)
    if (list.length === 0) { this.hideMenu(); return }
    this._selectedIndex = -1
    this.renderMenu(list)
  }

  renderMenu(list) {
    this.menuTarget.innerHTML = list.map((u, i) => `
      <button type="button" data-index="${i}" class="mentions-item block w-full text-left px-3 py-1.5 text-sm hover:bg-gray-100 focus:bg-gray-100 focus:outline-none" data-action="click->mentions#pick" role="option" aria-selected="false">@${u}</button>
    `).join("")
    this.menuTarget.classList.remove("hidden")
    this.menuTarget.setAttribute("role", "listbox")
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
    // Enter should accept the currently selected (or first) suggestion
    event.preventDefault()
    event.stopPropagation()
    const idx = this._selectedIndex >= 0 ? this._selectedIndex : 0
    const selected = this.menuTarget.querySelector(`button[data-index='${idx}']`)
    if (selected) selected.click()
  }

  navigate(event) {
    if (this.menuTarget.classList.contains("hidden")) return
    const items = this.menuTarget.querySelectorAll("button[role='option']")
    if (items.length === 0) return

    if (event.key === "ArrowDown") {
      event.preventDefault()
      this._selectedIndex = (this._selectedIndex + 1) % items.length
      this._highlight(items)
    } else if (event.key === "ArrowUp") {
      event.preventDefault()
      this._selectedIndex = (this._selectedIndex - 1 + items.length) % items.length
      this._highlight(items)
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.hideMenu()
      this.textareaTarget.focus()
    }
  }

  _highlight(items) {
    items.forEach((item, i) => {
      const active = i === this._selectedIndex
      item.classList.toggle("bg-blue-50", active)
      item.classList.toggle("text-blue-700", active)
      item.setAttribute("aria-selected", active ? "true" : "false")
      if (active) item.scrollIntoView({ block: "nearest" })
    })
  }

  hideMenu() {
    this.menuTarget.classList.add("hidden")
    this._selectedIndex = -1
  }

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

