// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

// Hook to preserve scroll position in sessionStorage
let Hooks = {};

Hooks.TextSelection = {
  mounted() {
    this.handleSelection = () => {
      const selection = window.getSelection();
      const selectedText = selection.toString().trim();

      if (selectedText) {
        // Check if selection is within a tr-ja container
        const range = selection.getRangeAt(0);
        let container = range.commonAncestorContainer;

        // Walk up the DOM tree to find if we're inside a tr-ja element
        while (container && container !== this.el) {
          if (container.classList && container.classList.contains('tr-ja')) {
            // We're selecting Japanese text!
            this.pushEvent("text_selected", { text: selectedText });
            return;
          }
          container = container.parentElement;
        }
      }

      // If no Japanese text selected, clear selection
      this.pushEvent("clear_selection", {});
    };

    this.el.addEventListener('mouseup', this.handleSelection);
    this.el.addEventListener('touchend', this.handleSelection);

    // Also clear when clicking elsewhere (but not on modals or buttons)
    document.addEventListener('mousedown', (e) => {
      // Don't clear if clicking on a modal or its backdrop
      const clickedModal = e.target.closest('[id$="-modal"]') ||
                          e.target.closest('[phx-click*="close_"]') ||
                          e.target.closest('button[type="button"]');

      if (!this.el.contains(e.target) && !clickedModal) {
        this.pushEvent("clear_selection", {});
      }
    });
  },

  destroyed() {
    this.el.removeEventListener('mouseup', this.handleSelection);
    this.el.removeEventListener('touchend', this.handleSelection);
  }
};

Hooks.ScrollPosition = {
  mounted() {
    const key = `scroll-position:${window.location.pathname}`;
    const savedPosition = sessionStorage.getItem(key);

    if (savedPosition) {
      this.el.scrollTop = parseInt(savedPosition, 10);
    }

    this.handleScroll = () => {
      sessionStorage.setItem(key, this.el.scrollTop);
    };

    this.el.addEventListener('scroll', this.handleScroll);
  },

  updated() {
    // Restore scroll position after DOM updates (e.g., toggling translation)
    const key = `scroll-position:${window.location.pathname}`;
    const savedPosition = sessionStorage.getItem(key);

    if (savedPosition) {
      this.el.scrollTop = parseInt(savedPosition, 10);
    }
  },

  destroyed() {
    this.el.removeEventListener('scroll', this.handleScroll);
  }
};

Hooks.AudioPlayer = {
  mounted() {
    this.setupAudio();
  },

  updated() {
    this.setupAudio();
  },

  setupAudio() {
    // Set preservesPitch to maintain audio quality if user adjusts speed via browser controls
    this.el.preservesPitch = true;
    this.el.mozPreservesPitch = true; // Firefox
    this.el.webkitPreservesPitch = true; // Safari
  }
};

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

// Toggle visibility of all elements with a given class using visibility: hidden
window.toggleVisibilityByClass = function(className) {
  document.querySelectorAll('.' + className).forEach(el => {
    if (el.style.visibility === 'hidden') {
      el.style.visibility = '';
    } else {
      el.style.visibility = 'hidden';
    }
  });
};

