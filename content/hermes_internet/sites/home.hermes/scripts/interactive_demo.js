(() => {
  const status = document.getElementById("demo-status");
  const counterValue = document.getElementById("counter-value");
  const incrementBtn = document.getElementById("increment-btn");
  const themeBtn = document.getElementById("theme-btn");

  if (!status || !counterValue || !incrementBtn || !themeBtn) {
    return;
  }

  let counter = 0;
  let glowEnabled = false;

  status.textContent = "Local JavaScript loaded successfully.";

  incrementBtn.addEventListener("click", (event) => {
    event.preventDefault();
    counter += 1;
    counterValue.textContent = String(counter);
  });

  themeBtn.addEventListener("click", (event) => {
    event.preventDefault();
    glowEnabled = !glowEnabled;
    document.body.classList.toggle("js-glow", glowEnabled);
  });
})();
