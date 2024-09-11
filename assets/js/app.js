let Hooks = {}

Hooks.TimestampWidthHook = {
  mounted() {
    const canvas = document.createElement('canvas');
    const context = canvas.getContext('2d');
    context.font = '16px ui-sans-serif, system-ui, sans-serif, "Apple Color Emoji", "Segoe UI Emoji", "Segoe UI Symbol", "Noto Color Emoji"'; // Set the font to match your text

    const textWidth = context.measureText('10:05:56.863').width;

    const leftPadding = parseFloat(getComputedStyle(this.el).paddingLeft);
    const rightPadding = parseFloat(getComputedStyle(this.el).paddingRight);

    window.el = this.el;
    const width = textWidth + leftPadding + rightPadding;
    this.el.style.width = `${width}px`;
  }
}

Hooks.TextExpand = {
  expandBtn: null,
  maxHeightPx: 150,
  expanded: false,

  mounted() {
    const rrect = this.el.getBoundingClientRect();

    this.expandBtn = this.el.getElementsByClassName('expand-button')[0];
    this.expandBtn.style.visibility = 'hidden';
    this.expandBtn.addEventListener('click', () => {
      this.toggleExpand();
    });

    this.el.style.overflow = 'hidden';
    this.el.style.maxHeight = `${this.maxHeightPx}px`;
    this.el.style.position = 'relative';

    if (rrect.height >= this.maxHeightPx) {
      console.log('should be visible!')
      this.expandBtn.style.visibility = 'visible';
    }
  },

  toggleExpand() {
    this.expanded = !this.expanded;
    if (this.expanded) {
      this.el.style.maxHeight = '';
      this.expandBtn.innerText = 'collapse';
    } else {
      this.el.style.maxHeight = `${this.maxHeightPx}px`;
      this.expandBtn.innerText = 'expand';
    }
  }
}


let socketPath = document.querySelector("html").getAttribute("phx-socket") || "/live"
let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveView.LiveSocket(socketPath, Phoenix.Socket, {
  hooks: Hooks,
  params: (_liveViewName) => {
    return {
      _csrf_token: csrfToken,
      // Pass the most recent refresh data to the LiveView in `connect_params`
      // refresh_data: loadRefreshData(),
    };
  },
})


const socket = liveSocket.socket
const originalOnConnError = socket.onConnError
let fallbackToLongPoll = true

socket.onOpen(() => {
  fallbackToLongPoll = false
})

socket.onConnError = (...args) => {
  if (fallbackToLongPoll) {
    // No longer fallback to longpoll
    fallbackToLongPoll = false
    // close the socket with an error code
    socket.disconnect(null, 3000)
    // fall back to long poll
    socket.transport = Phoenix.LongPoll
    // reopen
    socket.connect()
  } else {
    originalOnConnError.apply(socket, args)
  }
}

// Show progress bar on live navigation and form submits
// window.addEventListener("phx:page-loading-start", info => NProgress.start())
// window.addEventListener("phx:page-loading-stop", info => NProgress.done())

// connect if there are any LiveViews on the page
liveSocket.connect()

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)
window.liveSocket = liveSocket
