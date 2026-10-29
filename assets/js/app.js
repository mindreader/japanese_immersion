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

// Recently looked-up words (see JapaneseWeb.RecentWords). Kept in
// localStorage so the list survives disconnects, back buttons and restarts.
// Stored newest first; a repeat lookup moves the word back to the front.
const RecentWords = {
  key: "recent-jpdb-lookups",
  max: 30,

  load() {
    try {
      const words = JSON.parse(localStorage.getItem(this.key) || "[]");
      return Array.isArray(words) ? words.filter((w) => typeof w === "string") : [];
    } catch (_e) {
      return [];
    }
  },

  record(word) {
    word = (word || "").trim();
    if (!word) return;
    const words = [word, ...this.load().filter((w) => w !== word)].slice(0, this.max);
    try {
      localStorage.setItem(this.key, JSON.stringify(words));
    } catch (_e) {
      // Storage full or disabled (private mode): the lookup still works.
    }
  }
};

const openJpdb = (text) => {
  RecentWords.record(text);
  window.open(
    `https://jpdb.io/search?q=${encodeURIComponent(text)}`,
    '_blank',
    'noopener,noreferrer'
  );
};

Hooks.RecentWords = {
  mounted() {
    this.list = this.el.querySelector('[data-role="list"]');
    this.empty = this.el.querySelector('[data-role="empty"]');
    this.jpdb = this.el.querySelector('[data-role="jpdb"]');
    this.selected = "";

    this.isOpen = () => !this.el.classList.contains("hidden");

    this.setSelected = (text) => {
      this.selected = text;
      this.jpdb.disabled = !text;
    };

    // Shown oldest to newest, opened scrolled to the bottom: the newest
    // words sit right above the Okay/JPDB buttons. The list is built when
    // the dialog opens and left alone while it is open: a re-lookup is
    // saved (so the word is at the bottom next time) but the rows don't
    // reshuffle under your finger.
    this.open = () => {
      const words = RecentWords.load().reverse();
      this.list.replaceChildren(...words.map((word) => {
        const li = document.createElement("li");
        li.className = "py-2";
        li.textContent = word;
        return li;
      }));
      this.empty.classList.toggle("hidden", words.length > 0);
      this.setSelected("");
      this.el.classList.remove("hidden");
      this.list.scrollTop = this.list.scrollHeight;
    };

    this.close = () => {
      this.el.classList.add("hidden");
      this.setSelected("");
    };

    // Only a selection inside the list counts. An empty selection is
    // ignored rather than clearing: on mobile, tapping JPDB can collapse the
    // selection before the click lands.
    this.onSelectionChange = () => {
      if (!this.isOpen()) return;
      const sel = window.getSelection();
      const text = sel ? sel.toString().trim() : "";
      if (text && sel.rangeCount > 0 &&
          this.list.contains(sel.getRangeAt(0).commonAncestorContainer)) {
        this.setSelected(text);
      }
    };

    this.onClick = (e) => {
      const role = e.target.dataset && e.target.dataset.role;
      if (role === "close" || role === "backdrop") {
        this.close();
      } else if (e.target.closest('[data-role="jpdb"]') && this.selected) {
        openJpdb(this.selected);
      }
    };

    this.onKeydown = (e) => {
      if (e.key === "Escape" && this.isOpen()) this.close();
    };

    this.el.addEventListener("recent-words:open", this.open);
    this.el.addEventListener("click", this.onClick);
    document.addEventListener("selectionchange", this.onSelectionChange);
    window.addEventListener("keydown", this.onKeydown);
  },

  destroyed() {
    document.removeEventListener("selectionchange", this.onSelectionChange);
    window.removeEventListener("keydown", this.onKeydown);
  }
};

// Japanese text currently selected inside `root` (within a .tr-ja line), or
// "" if the selection is empty or elsewhere.
const japaneseSelection = (root) => {
  const selection = window.getSelection();
  const text = selection ? selection.toString().trim() : "";
  if (!text || selection.rangeCount === 0) return "";

  let node = selection.getRangeAt(0).commonAncestorContainer;
  while (node && node !== root) {
    if (node.classList && node.classList.contains("tr-ja")) return text;
    node = node.parentElement;
  }
  return "";
};

// Keyboard shortcuts on the story page view (PageLive.Show), so reading on
// a desktop doesn't need the mouse for every button. Keys are listed in
// `shortcuts`. The hook element's data-root is the story container that
// selections must be in, data-scroll the element j/k scroll. Ignored while
// typing, during IME composition, with Ctrl/Alt/Cmd held, and while a
// dialog is open; held-down keys only repeat where marked.
Hooks.StoryShortcuts = {
  mounted() {
    const root = () => document.querySelector(this.el.dataset.root);
    const scroller = () => document.querySelector(this.el.dataset.scroll);

    // vi-style j/k: a quarter of the visible text per press, about one
    // Japanese + English pair, a bit more than a mouse-wheel notch.
    // Smooth, but presses arriving while a scroll is still animating add to
    // where it was heading rather than to where it has got to (otherwise
    // each new smooth scroll restarts from the same spot and quick taps or
    // a held key barely move). A held key scrolls instantly.
    let target = null;
    let targetAt = 0;
    const scroll = (direction) => (e) => {
      const el = scroller();
      if (!el) return false;

      const animating = target !== null && performance.now() - targetAt < 400;
      const from = animating ? target : el.scrollTop;
      const max = el.scrollHeight - el.clientHeight;
      target = Math.min(max, Math.max(0, from + direction * Math.max(60, el.clientHeight / 4)));
      targetAt = performance.now();
      el.scrollTo({ top: target, behavior: e.repeat ? "auto" : "smooth" });
    };

    // key -> { run(event), repeat }. run returning false means "not
    // handled" (the key goes to the browser as usual). repeat: also fire
    // while the key is held down.
    const shortcuts = {
      // Toggle English
      e: { run: () => window.toggleVisibilityByClass("tr-eng") },
      // Look up the highlighted Japanese on JPDB ("dictionary")
      d: {
        run: () => {
          const text = japaneseSelection(root());
          if (!text) return false;
          openJpdb(text);
        }
      },
      // Scroll the text down / up
      j: { run: scroll(1), repeat: true },
      k: { run: scroll(-1), repeat: true }
    };

    const dialogOpen = () =>
      document.getElementById("explanation-modal") ||
      document.querySelector("#recent-words-modal:not(.hidden)");

    const typing = (target) =>
      target instanceof Element &&
      (target.closest("input, textarea, select, [contenteditable]:not([contenteditable=false])"));

    this.onKeydown = (e) => {
      if (e.ctrlKey || e.metaKey || e.altKey || e.isComposing) return;
      if (typing(e.target) || dialogOpen()) return;

      const shortcut = shortcuts[e.key.toLowerCase()];
      if (!shortcut || (e.repeat && !shortcut.repeat)) return;
      if (shortcut.run(e) !== false) e.preventDefault();
    };

    window.addEventListener("keydown", this.onKeydown);
  },

  destroyed() {
    window.removeEventListener("keydown", this.onKeydown);
  }
};

Hooks.TextSelection = {
  mounted() {
    this.selectedText = "";

    this.handleSelection = () => {
      const selectedText = japaneseSelection(this.el);
      if (selectedText) {
        this.selectedText = selectedText;
        this.pushEvent("text_selected", { text: selectedText });
        return;
      }

      // If no Japanese text selected, clear selection
      this.selectedText = "";
      this.pushEvent("clear_selection", {});
    };

    // Delegated click handler so it works even though the buttons are
    // rendered conditionally. The cached selection (this.selectedText) is the
    // source of truth at click time — avoids the race where a server round-trip
    // hasn't landed yet and the stale @selected_text would otherwise be used.
    this.handleActionClick = (e) => {
      const jpdb = e.target.closest('#jpdb-button');
      const explain = e.target.closest('#explain-button');
      if (!jpdb && !explain) return;

      e.preventDefault();
      const text = this.selectedText;
      if (!text) return;

      if (jpdb) {
        openJpdb(text);
      } else {
        this.pushEvent("start_explain", { text });
      }
    };

    this.el.addEventListener('mouseup', this.handleSelection);
    this.el.addEventListener('touchend', this.handleSelection);
    this.el.addEventListener('click', this.handleActionClick);

    // Also clear when clicking elsewhere (but not on modals or buttons)
    document.addEventListener('mousedown', (e) => {
      // Don't clear if clicking on a modal or its backdrop
      const clickedModal = e.target.closest('[id$="-modal"]') ||
                          e.target.closest('[phx-click*="close_"]') ||
                          e.target.closest('button[type="button"]');

      if (!this.el.contains(e.target) && !clickedModal) {
        this.selectedText = "";
        this.pushEvent("clear_selection", {});
      }
    });
  },

  destroyed() {
    this.el.removeEventListener('mouseup', this.handleSelection);
    this.el.removeEventListener('touchend', this.handleSelection);
    this.el.removeEventListener('click', this.handleActionClick);
  }
};

// The Explain dialog's follow-up box. With a mouse and keyboard, focus it so
// questions can be typed straight away. On a touch screen leave it alone:
// focusing would pop up the on-screen keyboard and scroll the dialog down to
// the box before the explanation has been read.
//
// When the dialog opens (data-scroll "false"), the modal's own focus-on-open
// lands on the heading once the dialog is visible; this follows it to the
// box, without scrolling, so the dialog stays at the top. (Focusing any
// earlier does nothing: the dialog is still hidden.) After an answer the
// dialog is already open, so focus directly, scrolling to the box, which
// brings the answer above it into view.
Hooks.FollowupFocus = {
  mounted() {
    if (!window.matchMedia("(hover: hover) and (pointer: fine)").matches) return;

    const opening = this.el.dataset.scroll !== "true";
    const focus = () => this.el.focus({ preventScroll: opening });
    const heading = document.getElementById("explanation-heading");

    if (!opening || !heading || document.activeElement === heading) {
      focus();
    } else {
      heading.addEventListener("focus", focus, { once: true });
    }
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

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  // No longPollFallbackMs: the app is only reached directly over Tailscale,
  // never through a proxy that blocks websockets. With the fallback on, a
  // phone waking from sleep (Tailscale tunnel still coming back) missed the
  // 2.5s window and switched to long-polling for the rest of the page's life.
  //
  // Reconnect quickly and keep trying every second, instead of Phoenix's
  // default backoff that reaches 5s between attempts after ~4s of failures,
  // so the page is back within about a second of the network returning.
  reconnectAfterMs: tries => [100, 250, 500][tries - 1] || 1000,
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

