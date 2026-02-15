import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sidebar", "mobileSidebar", "overlay", "link"]

  connect() {
    this.observeSections()
    this.handleInitialHash()
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  observeSections() {
    const options = {
      rootMargin: '-80px 0px -80% 0px',
      threshold: 0
    }

    this.observer = new IntersectionObserver((entries) => {
      entries.forEach(entry => {
        if (entry.isIntersecting) {
          this.setActiveLink(entry.target.id)
        }
      })
    }, options)

    // Observe all sections with IDs
    document.querySelectorAll('section[id], h2[id], h3[id]').forEach(section => {
      this.observer.observe(section)
    })
  }

  handleInitialHash() {
    if (window.location.hash) {
      const id = window.location.hash.slice(1)
      this.setActiveLink(id)
    }
  }

  setActiveLink(sectionId) {
    this.linkTargets.forEach(link => {
      const linkSection = link.dataset.section
      if (linkSection === sectionId) {
        link.classList.add('active')
      } else {
        link.classList.remove('active')
      }
    })
  }

  toggleMobile() {
    const isHidden = this.mobileSidebarTarget.classList.contains('hidden')

    if (isHidden) {
      this.mobileSidebarTarget.classList.remove('hidden')
      this.overlayTarget.classList.remove('hidden')
      document.body.style.overflow = 'hidden'
    } else {
      this.closeMobile()
    }
  }

  closeMobile() {
    this.mobileSidebarTarget.classList.add('hidden')
    this.overlayTarget.classList.add('hidden')
    document.body.style.overflow = ''
  }
}
