/* Ranse design review - selection state, autosave, auto-reload */
(function () {
  const STORE_KEY = "ranse-design-review-v1";
  // Absolute URLs so saving works whether the page is opened via the local
  // server or straight from disk (file://).
  const SERVER = "http://localhost:7420";

  // ---------- state persistence (localStorage survives auto-reloads) ----------
  function collect() {
    const data = { savedAt: new Date().toISOString(), brief: {}, selections: {}, notes: {} };
    document.querySelectorAll("[data-q]").forEach((el) => {
      if (el.type === "checkbox") {
        const key = el.dataset.q;
        if (!data.brief[key]) data.brief[key] = [];
        if (el.checked) data.brief[key].push(el.value);
      } else if (el.type === "radio") {
        if (el.checked) data.brief[el.dataset.q] = el.value;
      } else {
        data.brief[el.dataset.q] = el.value;
      }
    });
    document.querySelectorAll("input[type=radio][data-screen]").forEach((el) => {
      if (el.checked) data.selections[el.dataset.screen] = el.value;
    });
    document.querySelectorAll("input[data-note]").forEach((el) => {
      if (el.value.trim()) data.notes[el.dataset.note] = el.value.trim();
    });
    return data;
  }

  function restore() {
    let data;
    try { data = JSON.parse(localStorage.getItem(STORE_KEY) || "null"); } catch { return; }
    if (!data) return;
    document.querySelectorAll("[data-q]").forEach((el) => {
      const v = data.brief[el.dataset.q];
      if (v === undefined) return;
      if (el.type === "checkbox") el.checked = Array.isArray(v) && v.includes(el.value);
      else if (el.type === "radio") el.checked = el.value === v;
      else el.value = v;
    });
    Object.entries(data.selections || {}).forEach(([screen, dir]) => {
      const el = document.querySelector(
        `input[type=radio][data-screen="${screen}"][value="${dir}"]`);
      if (el) el.checked = true;
    });
    Object.entries(data.notes || {}).forEach(([k, v]) => {
      const el = document.querySelector(`input[data-note="${k}"]`);
      if (el) el.value = v;
    });
  }

  function updateProgress() {
    const total = document.querySelectorAll("section[data-screen-section]").length;
    const done = new Set(
      [...document.querySelectorAll("input[type=radio][data-screen]:checked")]
        .map((el) => el.dataset.screen)).size;
    const el = document.getElementById("progress");
    if (el) el.innerHTML = `<b>${done}</b> of <b>${total}</b> screens decided`;
  }

  let saveTimer = null;
  function scheduleSave() {
    localStorage.setItem(STORE_KEY, JSON.stringify(collect()));
    updateProgress();
    clearTimeout(saveTimer);
    saveTimer = setTimeout(() => push(false), 1200);
  }

  function downloadFallback() {
    const blob = new Blob([JSON.stringify(collect(), null, 2)],
      { type: "application/json" });
    const a = document.createElement("a");
    a.href = URL.createObjectURL(blob);
    a.download = "design-feedback.json";
    a.click();
    URL.revokeObjectURL(a.href);
  }

  async function push(explicit) {
    const status = document.getElementById("savestatus");
    try {
      const res = await fetch(SERVER + "/save", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(collect()),
      });
      if (!res.ok) throw new Error("bad status");
      if (status) {
        status.textContent = explicit
          ? "Saved - tell Claude you're done"
          : "Autosaved " + new Date().toLocaleTimeString();
        status.classList.toggle("ok", explicit);
      }
    } catch {
      if (status) { status.textContent = "Server offline - kept locally"; status.classList.remove("ok"); }
      if (explicit) downloadFallback();
    }
  }

  // ---------- auto-reload when Claude edits the design files ----------
  let baseline = null;
  async function pollReload() {
    try {
      const res = await fetch(SERVER + "/mtime", { cache: "no-store" });
      const { mtime } = await res.json();
      if (baseline === null) baseline = mtime;
      else if (mtime > baseline) location.reload();
    } catch { /* server briefly down - keep polling */ }
  }

  // ---------- wire up ----------
  document.addEventListener("DOMContentLoaded", () => {
    restore();
    updateProgress();
    document.body.addEventListener("input", scheduleSave);
    document.body.addEventListener("change", scheduleSave);
    const btn = document.getElementById("savebtn");
    if (btn) btn.addEventListener("click", () => { localStorage.setItem(STORE_KEY, JSON.stringify(collect())); push(true); });
    setInterval(pollReload, 1500);
  });
})();
