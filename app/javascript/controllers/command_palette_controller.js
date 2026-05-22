import { Controller } from "@hotwired/stimulus"

// Command Palette - Quick channel/action switcher
// Triggered by Cmd+K / Ctrl+K
export default class extends Controller {
  static targets = ["modal", "backdrop", "input", "results", "item"]
  static values = {
    channels: Array,
    recentKey: { type: String, default: "homechat_recent_channels" }
  }

  connect() {
    this._selectedIndex = 0
    this._filteredItems = []
    this._previouslyFocused = null

    this._onKeydown = this.handleGlobalKeydown.bind(this)
    window.addEventListener("keydown", this._onKeydown)

    // Load recent channels from localStorage
    this._recentChannels = this.loadRecentChannels()
  }

  disconnect() {
    window.removeEventListener("keydown", this._onKeydown)
  }

  handleGlobalKeydown(event) {
    // Cmd+K or Ctrl+K to open
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open()
      return
    }

    // Escape to close
    if (event.key === "Escape" && this.isOpen()) {
      event.preventDefault()
      this.close()
    }
  }

  handleInputKeydown(event) {
    switch (event.key) {
      case "ArrowDown":
        event.preventDefault()
        this.selectNext()
        break
      case "ArrowUp":
        event.preventDefault()
        this.selectPrevious()
        break
      case "Enter":
        event.preventDefault()
        this.activateSelected()
        break
      case "Escape":
        event.preventDefault()
        this.close()
        break
    }
  }

  open() {
    if (!this.hasModalTarget) return

    this._previouslyFocused = document.activeElement instanceof HTMLElement ? document.activeElement : null
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.remove("hidden")
    }

    // Focus input and select all text
    if (this.hasInputTarget) {
      this.inputTarget.value = ""
      this.inputTarget.setAttribute("aria-expanded", "true")
      this.inputTarget.removeAttribute("aria-activedescendant")
      this.inputTarget.focus()
    }

    // Show initial results (recent + all channels)
    this.updateResults("")

    // Prevent body scroll
    document.body.classList.add("overflow-hidden")
  }

  close() {
    if (!this.hasModalTarget) return

    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    if (this.hasBackdropTarget) {
      this.backdropTarget.classList.add("hidden")
    }

    // Restore body scroll
    document.body.classList.remove("overflow-hidden")

    // Reset state
    this._selectedIndex = 0
    if (this.hasInputTarget) {
      this.inputTarget.setAttribute("aria-expanded", "false")
      this.inputTarget.removeAttribute("aria-activedescendant")
    }
    if (this._previouslyFocused && typeof this._previouslyFocused.focus === "function") {
      this._previouslyFocused.focus()
    }
  }

  isOpen() {
    return this.hasModalTarget && !this.modalTarget.classList.contains("hidden")
  }

  search(event) {
    const query = event.target.value.trim().toLowerCase()
    this.updateResults(query)
  }

  updateResults(query) {
    if (!this.hasResultsTarget) return

    const channels = this.channelsValue || []
    let items = []

    if (!query) {
      // No query: show recent channels first, then all channels
      const recentIds = this._recentChannels.map(r => r.id)
      const recentItems = this._recentChannels.map(ch => ({
        ...ch,
        section: "Recent"
      }))

      const otherItems = channels
        .filter(ch => !recentIds.includes(ch.id))
        .slice(0, 10)
        .map(ch => ({ ...ch, section: "Channels" }))

      items = [...recentItems, ...otherItems]
    } else {
      // Fuzzy search channels
      items = channels
        .map(ch => ({
          ...ch,
          score: this.fuzzyScore(ch.name.toLowerCase(), query)
        }))
        .filter(ch => ch.score > 0)
        .sort((a, b) => b.score - a.score)
        .slice(0, 12)
        .map(ch => ({ ...ch, section: "Channels" }))
    }

    this._filteredItems = items
    this._selectedIndex = 0
    this.renderResults(items)
  }

  fuzzyScore(text, query) {
    // Simple fuzzy matching - returns score based on match quality
    if (text === query) return 100
    if (text.startsWith(query)) return 80
    if (text.includes(query)) return 60

    // Character-by-character fuzzy match
    let score = 0
    let queryIndex = 0
    for (let i = 0; i < text.length && queryIndex < query.length; i++) {
      if (text[i] === query[queryIndex]) {
        score += 10
        queryIndex++
      }
    }
    return queryIndex === query.length ? score : 0
  }

  renderResults(items) {
    if (!this.hasResultsTarget) return

    if (items.length === 0) {
      if (this.hasInputTarget) {
        this.inputTarget.removeAttribute("aria-activedescendant")
      }
      this.resultsTarget.innerHTML = `
        <div class="px-4 py-8 text-center text-gray-500 text-sm">
          No channels found
        </div>
      `
      return
    }

    let currentSection = ""
    let html = ""

    items.forEach((item, index) => {
      // Section header
      if (item.section !== currentSection) {
        currentSection = item.section
        html += `
          <div class="px-3 py-2 text-xs font-semibold text-gray-500 uppercase tracking-wider bg-gray-50" role="presentation">
            ${currentSection}
          </div>
        `
      }

      const isSelected = index === this._selectedIndex
      const icon = item.type === "private"
        ? `<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M5 9V7a5 5 0 0110 0v2a2 2 0 012 2v5a2 2 0 01-2 2H5a2 2 0 01-2-2v-5a2 2 0 012-2zm8-2v2H7V7a3 3 0 016 0z" clip-rule="evenodd"></path></svg>`
        : item.type === "dm"
        ? `<svg class="w-4 h-4 text-gray-400" fill="currentColor" viewBox="0 0 20 20"><path d="M10 9a3 3 0 100-6 3 3 0 000 6zm-7 9a7 7 0 1114 0H3z"></path></svg>`
        : `<span class="text-gray-400 font-semibold">#</span>`

      html += `
        <button type="button"
                class="w-full flex items-center gap-3 px-4 py-2.5 text-left transition-colors ${isSelected ? 'bg-blue-50 text-blue-900' : 'text-gray-700 hover:bg-gray-50'}"
                data-command-palette-target="item"
                data-action="click->command-palette#selectItem mouseenter->command-palette#hoverItem"
                data-index="${index}"
                data-url="${item.url}"
                id="command-palette-option-${index}"
                role="option"
                aria-selected="${isSelected}">
          ${icon}
          <span class="flex-1 truncate font-medium">${this.escapeHtml(item.name)}</span>
          ${isSelected ? '<span class="text-xs text-gray-400">↵</span>' : ''}
        </button>
      `
    })

    this.resultsTarget.innerHTML = html
  }

  selectNext() {
    if (this._filteredItems.length === 0) return
    this._selectedIndex = (this._selectedIndex + 1) % this._filteredItems.length
    this.updateSelection()
  }

  selectPrevious() {
    if (this._filteredItems.length === 0) return
    this._selectedIndex = (this._selectedIndex - 1 + this._filteredItems.length) % this._filteredItems.length
    this.updateSelection()
  }

  updateSelection() {
    this.itemTargets.forEach((item, index) => {
      const isSelected = index === this._selectedIndex
      item.classList.toggle("bg-blue-50", isSelected)
      item.classList.toggle("text-blue-900", isSelected)
      item.classList.toggle("text-gray-700", !isSelected)
      item.classList.toggle("hover:bg-gray-50", !isSelected)
      item.setAttribute("aria-selected", isSelected.toString())

      // Update enter hint
      const hint = item.querySelector(".text-xs.text-gray-400")
      if (hint) hint.remove()
      if (isSelected) {
        item.insertAdjacentHTML("beforeend", '<span class="text-xs text-gray-400">↵</span>')
      }
    })

    // Scroll selected into view
    const selectedItem = this.itemTargets[this._selectedIndex]
    if (selectedItem) {
      if (this.hasInputTarget) {
        this.inputTarget.setAttribute("aria-activedescendant", selectedItem.id)
      }
      selectedItem.scrollIntoView({ block: "nearest" })
    }
  }

  hoverItem(event) {
    const index = parseInt(event.currentTarget.dataset.index, 10)
    if (!isNaN(index)) {
      this._selectedIndex = index
      this.updateSelection()
    }
  }

  selectItem(event) {
    const url = event.currentTarget.dataset.url
    if (url) {
      this.navigateTo(url)
    }
  }

  activateSelected() {
    const item = this._filteredItems[this._selectedIndex]
    if (item?.url) {
      this.navigateTo(item.url)
    }
  }

  navigateTo(url) {
    // Save to recent channels
    const item = this._filteredItems[this._selectedIndex]
    if (item) {
      this.saveRecentChannel(item)
    }

    this.close()

    // Use Turbo if available for SPA-like navigation
    if (window.Turbo) {
      window.Turbo.visit(url)
    } else {
      window.location.href = url
    }
  }

  loadRecentChannels() {
    try {
      const data = localStorage.getItem(this.recentKeyValue)
      return data ? JSON.parse(data).slice(0, 5) : []
    } catch {
      return []
    }
  }

  saveRecentChannel(channel) {
    try {
      let recent = this.loadRecentChannels()
      // Remove if already exists
      recent = recent.filter(r => r.id !== channel.id)
      // Add to front
      recent.unshift({ id: channel.id, name: channel.name, url: channel.url, type: channel.type })
      // Keep only 5
      recent = recent.slice(0, 5)
      localStorage.setItem(this.recentKeyValue, JSON.stringify(recent))
      this._recentChannels = recent
    } catch {
      // localStorage unavailable
    }
  }

  escapeHtml(text) {
    const div = document.createElement("div")
    div.textContent = text
    return div.innerHTML
  }
}
