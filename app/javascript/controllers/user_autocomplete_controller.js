import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "hiddenInput"]
  static values = { url: String }

  connect() {
    this.selectedIndex = -1
    this.users = []
    this.debounceTimer = null
  }

  disconnect() {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }

  search() {
    const query = this.inputTarget.value.trim()

    // Clear previous timer
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }

    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    // Debounce the search
    this.debounceTimer = setTimeout(() => {
      this.performSearch(query)
    }, 200)
  }

  async performSearch(query) {
    try {
      const response = await fetch(`${this.urlValue}?q=${encodeURIComponent(query)}`)
      this.users = await response.json()
      this.showResults()
    } catch (error) {
      console.error('Search failed:', error)
      this.hideDropdown()
    }
  }

  showResults() {
    if (this.users.length === 0) {
      this.hideDropdown()
      return
    }

    this.selectedIndex = -1
    let html = ''

    this.users.forEach((user, index) => {
      const onlineIndicator = user.is_online
        ? '<span class="w-2 h-2 rounded-full bg-green-500 flex-shrink-0"></span>'
        : '<span class="w-2 h-2 rounded-full bg-gray-300 flex-shrink-0"></span>'

      html += `
        <div class="flex items-center gap-3 px-3 py-2 hover:bg-gray-50 cursor-pointer" data-index="${index}">
          <div class="w-8 h-8 bg-gray-200 rounded-full flex items-center justify-center text-sm font-semibold text-gray-700 flex-shrink-0">
            ${user.username.charAt(0).toUpperCase()}
          </div>
          <div class="flex-1 min-w-0">
            <div class="flex items-center gap-2">
              <span class="font-medium text-gray-900">${user.username}</span>
              ${onlineIndicator}
            </div>
          </div>
        </div>
      `
    })

    this.dropdownTarget.innerHTML = html
    this.dropdownTarget.classList.remove('hidden')

    // Add click listeners
    this.dropdownTarget.querySelectorAll('[data-index]').forEach(item => {
      item.addEventListener('click', (e) => {
        e.preventDefault()
        const index = parseInt(item.dataset.index)
        this.selectUser(index)
      })
    })
  }

  hideDropdown() {
    this.dropdownTarget.classList.add('hidden')
    this.selectedIndex = -1
  }

  handleKeydown(event) {
    if (!this.dropdownTarget.classList.contains('hidden')) {
      switch (event.key) {
        case 'ArrowDown':
          event.preventDefault()
          this.selectedIndex = Math.min(this.selectedIndex + 1, this.users.length - 1)
          this.updateSelection()
          break
        case 'ArrowUp':
          event.preventDefault()
          this.selectedIndex = Math.max(this.selectedIndex - 1, -1)
          this.updateSelection()
          break
        case 'Enter':
          event.preventDefault()
          if (this.selectedIndex >= 0) {
            this.selectUser(this.selectedIndex)
          }
          break
        case 'Escape':
          this.hideDropdown()
          break
      }
    }
  }

  updateSelection() {
    const items = this.dropdownTarget.querySelectorAll('[data-index]')
    items.forEach((item, index) => {
      if (index === this.selectedIndex) {
        item.classList.add('bg-blue-50')
        item.classList.remove('hover:bg-gray-50')
      } else {
        item.classList.remove('bg-blue-50')
        item.classList.add('hover:bg-gray-50')
      }
    })
  }

  selectUser(index) {
    const user = this.users[index]
    this.inputTarget.value = user.username
    if (this.hasHiddenInputTarget) {
      this.hiddenInputTarget.value = user.username
    }
    this.hideDropdown()
  }

  // Hide dropdown when clicking outside
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }
}