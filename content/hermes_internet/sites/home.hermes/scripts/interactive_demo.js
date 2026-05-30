(() => {
  const status = document.getElementById("demo-status");
  const counterValue = document.getElementById("counter-value");
  const incrementBtn = document.getElementById("increment-btn");
  const themeBtn = document.getElementById("theme-btn");
  const typedInput = document.getElementById("typed-input");
  const typedText = document.getElementById("typed-text");
  const lastKey = document.getElementById("last-key");
  const channelState = document.getElementById("channel-state");

  if (!status || !counterValue || !incrementBtn || !themeBtn || !typedInput || !typedText || !lastKey || !channelState) {
    return;
  }

  const state = {
    clickCount: 0,
    typedText: "",
    lastKey: "",
    lastAction: "init",
    connected: false,
  };

  const render = () => {
    counterValue.textContent = String(state.clickCount);
    typedText.textContent = state.typedText === "" ? "(none)" : state.typedText;
    lastKey.textContent = state.lastKey === "" ? "(none)" : state.lastKey;
    channelState.textContent = state.connected ? "connected" : "disconnected";
  };

  const publishState = () => {
    if (window.ipc && typeof window.ipc.postMessage === "function") {
      state.connected = true;
    }
    const payload = {
      source: "hermes_interactive",
      type: "browser_test_state",
      click_count: state.clickCount,
      typed_text: state.typedText,
      last_key: state.lastKey,
      last_action: state.lastAction,
      connected: state.connected,
    };
    if (state.connected) {
      window.ipc.postMessage(JSON.stringify(payload));
    }
    render();
  };

  const applyKey = (key) => {
    state.lastAction = "key";
    state.lastKey = key;
    publishState();
  };

  const applyType = (text) => {
    state.lastAction = "type";
    state.typedText += text;
    typedInput.value = state.typedText;
    publishState();
  };

  const applyClick = () => {
    state.lastAction = "click";
    state.clickCount += 1;
    publishState();
  };

  status.textContent = "Local JavaScript loaded successfully.";

  incrementBtn.addEventListener("click", (event) => {
    event.preventDefault();
    applyClick();
  });

  themeBtn.addEventListener("click", (event) => {
    event.preventDefault();
    document.body.classList.toggle("js-glow");
  });

  typedInput.addEventListener("input", () => {
    state.lastAction = "type";
    state.typedText = typedInput.value;
    publishState();
  });

  typedInput.addEventListener("keydown", (event) => {
    applyKey(event.key);
  });

  window.addEventListener("keydown", (event) => {
    applyKey(event.key);
  });

  const coerceTestInputMessage = (event) => {
    const raw = event && (event.detail !== undefined ? event.detail : event.data);
    if (!raw) {
      return null;
    }
    if (typeof raw === "string") {
      try {
        return JSON.parse(raw);
      } catch (_err) {
        return null;
      }
    }
    if (typeof raw === "object") {
      return raw;
    }
    return null;
  };

  const handleTestInputMessage = (event) => {
    const data = coerceTestInputMessage(event);
    if (!data || data.type !== "browser_test_input" || data.source !== "hermes_os") {
      return;
    }
    const action = data.action;
    const payload = data.payload || {};
    if (action === "key") {
      applyKey(String(payload.key || ""));
      return;
    }
    if (action === "type") {
      applyType(String(payload.text || ""));
      return;
    }
    if (action === "click" && String(payload.target || "increment") === "increment") {
      applyClick();
    }
  };

  window.addEventListener("message", handleTestInputMessage);
  document.addEventListener("message", handleTestInputMessage);

  publishState();
})();
