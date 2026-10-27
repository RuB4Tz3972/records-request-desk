/* Records Request Desk — lógica de la interfaz.
   Los textos finales, el .eml y los datos compartidos los arma el servidor en Python (server.py). */
"use strict";

const $ = (sel, el = document) => el.querySelector(sel);
const $$ = (sel, el = document) => [...el.querySelectorAll(sel)];

const ICONS = { email: "ti-mail", form: "ti-world", pending: "ti-hourglass" };
const METHODS = { email: "Correo", form: "Formulario web", pending: "Por definir" };
const STATE_LABELS = { FL: "Florida", GA: "Georgia", "Federal/State": "Estatal / Federal" };
const VIEWS = ["nueva", "jurisdicciones", "plantilla", "feedback"];
const STORE = "rrd.request.v1";
const SAMPLE = {
  streets: "NW 10th Ave & NW 21st Terrace & NW 21st St",
  limits: "NW 22nd St and NW 18th St",
  jurisdiction: "City of Miami",
};

const emptyRequest = () => ({ streets: [], limitA: "", limitB: "", selected: [], sent: [], step: 1 });

const S = {
  jurisdictions: [],
  template: "",
  defaultTemplate: "",
  subjectFormat: "Utility Records Request – {name}",
  feedbackTypes: [],
  req: loadRequest(),
  map: null, // { file, url }
  requests: [], // solicitudes armadas por el servidor (paso 3)
  previewId: null,
  filter: "all",
  editing: null,
  openMsgs: new Set(),
};

// ---------- utilidades ----------

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
}

function debounce(fn, ms) {
  let t;
  return (...args) => { clearTimeout(t); t = setTimeout(() => fn(...args), ms); };
}

function plural(n, one, many) { return `${n} ${n === 1 ? one : many}`; }

function storage(action, key, value) {
  try {
    if (action === "get") return localStorage.getItem(key);
    localStorage.setItem(key, value);
  } catch { /* el navegador puede bloquear el almacenamiento: la app sigue funcionando */ }
  return null;
}

function loadRequest() {
  try { return { ...emptyRequest(), ...JSON.parse(storage("get", STORE) || "{}") }; }
  catch { return emptyRequest(); }
}

function saveRequest() { storage("set", STORE, JSON.stringify(S.req)); }

async function api(path, options = {}) {
  const isJson = typeof options.body === "string";
  const res = await fetch(path, { ...options, headers: isJson ? { "Content-Type": "application/json" } : {} });
  if (!res.ok) {
    let message = "Algo salió mal. Intenta de nuevo.";
    try { message = (await res.json()).error || message; } catch { /* respuesta sin JSON */ }
    throw new Error(message);
  }
  return res;
}
const getJSON = async (path) => (await api(path)).json();
const sendJSON = async (path, method, data) => (await api(path, { method, body: JSON.stringify(data) })).json();

let toastTimer;
function toast(message, icon = "ti-check") {
  const el = $("#toast");
  el.innerHTML = `<i class="ti ${icon}"></i><span>${esc(message)}</span>`;
  el.classList.add("show");
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove("show"), 2600);
}

async function copyText(text, label) {
  let ok = false;
  try {
    // El portapapeles moderno solo existe en https o localhost; en la red de la oficina usamos el método clásico.
    if (navigator.clipboard && window.isSecureContext) { await navigator.clipboard.writeText(text); ok = true; }
  } catch { ok = false; }
  if (!ok) {
    const ta = Object.assign(document.createElement("textarea"), { value: text });
    ta.style.cssText = "position:fixed;opacity:0";
    document.body.append(ta);
    ta.select();
    ok = document.execCommand("copy");
    ta.remove();
  }
  toast(ok ? `${label} copiado` : "No se pudo copiar: selecciónalo y usa Ctrl+C", ok ? "ti-copy" : "ti-alert-triangle");
}

// Botón que pide un segundo clic para confirmar (sin ventanas emergentes).
function armed(button, label, action) {
  if (button.classList.contains("armed")) {
    button.classList.remove("armed");
    action();
    return;
  }
  const original = button.innerHTML;
  button.classList.add("armed");
  button.innerHTML = `<i class="ti ti-alert-triangle"></i>${label}`;
  setTimeout(() => {
    if (button.classList.contains("armed")) { button.classList.remove("armed"); button.innerHTML = original; }
  }, 3500);
}

function joinStreets(list) { return list.map((s) => s.trim()).filter(Boolean).join(" & "); }

function joinLimits(list) {
  const l = list.map((s) => s.trim()).filter(Boolean);
  return l.length <= 2 ? l.join(" and ") : `${l.slice(0, -1).join(", ")} and ${l.at(-1)}`;
}

function toggleIn(list, value, on) {
  const i = list.indexOf(value);
  if (on && i < 0) list.push(value);
  if (!on && i >= 0) list.splice(i, 1);
}

const byId = (id) => S.jurisdictions.find((j) => j.id === id);
const selected = () => S.jurisdictions.filter((j) => S.req.selected.includes(j.id));

function hostOf(url) {
  try { return new URL(url).hostname; } catch { return url || "Sin link"; }
}

function contactOf(j) {
  if (j.method === "email") return (j.emails || []).join(", ") || "Sin correo";
  if (j.method === "form") return hostOf(j.form_url);
  return j.notes || "Proceso por definir";
}

function setCount(id, n) { $(`#${id}`).textContent = n ? String(n) : ""; }

// Resalta en el texto lo que se llena solo; lo que falta queda punteado.
function highlight(template, values) {
  const fills = [
    ["[STREETS]", values.streets, "calles del paso 1"],
    ["[LIMITS]", values.limits, "límites del paso 1"],
    ["[JURISDICTION]", values.jurisdiction, "jurisdicción del paso 2"],
  ];
  return template.split(/\n{2,}/).map((p) => {
    let html = esc(p);
    for (const [token, value, missing] of fills) {
      html = html.split(token).join(value ? `<mark>${esc(value)}</mark>` : `<mark class="todo">${missing}</mark>`);
    }
    return `<p>${html.replace(/\n/g, "<br>")}</p>`;
  }).join("");
}

// ---------- navegación ----------

function route() {
  const name = (location.hash.match(/^#\/(\w+)/) || [])[1];
  const view = VIEWS.includes(name) ? name : "nueva";
  $$(".view").forEach((s) => { s.hidden = s.id !== `view-${view}`; });
  $$(".nav a").forEach((a) => a.classList.toggle("on", a.dataset.view === view));
  if (view === "feedback") loadFeedback();
  if (view === "plantilla") renderTemplatePreview();
}

// ---------- paso a paso ----------

function stepsDone() {
  const r = S.req;
  const sel = selected();
  return [
    r.streets.length > 0 && Boolean(r.limitA.trim()) && Boolean(r.limitB.trim()),
    sel.length > 0,
    sel.length > 0 && sel.every((j) => r.sent.includes(j.id)),
  ];
}

function goStep(n) {
  const done = stepsDone();
  if (n > 1 && !done[0]) return blockStep(1, "Agrega al menos una calle y los dos límites.");
  if (n > 2 && !done[1]) return blockStep(2, "Elige al menos una jurisdicción.");
  S.req.step = n;
  saveRequest();
  renderStep();
  if (n === 3) loadRequests();
  window.scrollTo({ top: 0, behavior: "smooth" });
}

function blockStep(step, message) {
  if (S.req.step !== step) { S.req.step = step; saveRequest(); renderStep(); }
  const hint = $(`#hint${step}`);
  hint.textContent = message;
  hint.classList.remove("shake");
  void hint.offsetWidth; // reinicia la animación
  hint.classList.add("shake");
}

function renderStep() {
  $$(".step").forEach((p) => { p.hidden = Number(p.dataset.step) !== S.req.step; });
  $("#work").classList.toggle("single", S.req.step === 3);
  renderStepper();
}

function renderStepper() {
  const done = stepsDone();
  const r = S.req;
  const sel = selected();
  const nSent = sel.filter((j) => r.sent.includes(j.id)).length;
  $$("#stepper li").forEach((li) => {
    const n = Number(li.dataset.step);
    const isDone = done[n - 1] && (n !== r.step || n === 3);
    li.classList.toggle("on", n === r.step);
    li.classList.toggle("done", isDone);
    $(".num", li).innerHTML = isDone ? '<i class="ti ti-check"></i>' : String(n);
  });
  $("#sum1").textContent = r.streets.length
    ? `${plural(r.streets.length, "calle", "calles")}${r.limitA.trim() && r.limitB.trim() ? " · 2 límites" : ""}`
    : "Calles y límites";
  $("#sum2").textContent = sel.length ? plural(sel.length, "jurisdicción", "jurisdicciones") : "A quién pedir";
  $("#sum3").textContent = sel.length ? `${nSent} de ${sel.length} enviadas` : "Correo o formulario";
}

const refreshRequests = debounce(() => loadRequests(), 250);

function changed() {
  saveRequest();
  renderChips();
  renderStepper();
  renderPreview();
  renderJGrid();
  renderSide();
  const done = stepsDone();
  if (done[0]) $("#hint1").textContent = "";
  if (done[1]) $("#hint2").textContent = "";
  if (S.req.step === 3) refreshRequests();
}

// ---------- paso 1: tramo ----------

function addStreets(text) {
  const parts = text.split(/\n|;|&/).map((s) => s.trim()).filter(Boolean);
  for (const p of parts) {
    if (!S.req.streets.some((s) => s.toLowerCase() === p.toLowerCase())) S.req.streets.push(p);
  }
  if (parts.length) changed();
}

function renderChips() {
  const box = $("#streetsBox");
  const input = $("#streetInput");
  $$(".chip", box).forEach((c) => c.remove());
  S.req.streets.forEach((street, i) => {
    const chip = document.createElement("span");
    chip.className = "chip";
    chip.innerHTML = `${esc(street)}<button type="button" aria-label="Quitar ${esc(street)}"><i class="ti ti-x"></i></button>`;
    chip.querySelector("button").addEventListener("click", () => { S.req.streets.splice(i, 1); changed(); input.focus(); });
    box.insertBefore(chip, input);
  });
  input.placeholder = S.req.streets.length ? "Agregar otra calle…" : "Escribe una calle y presiona Enter";
}

function setMap(file) {
  if (!file || !/^image\/(png|jpeg|webp)$/.test(file.type)) {
    toast("Usa una imagen PNG, JPG o WEBP.", "ti-photo-x");
    return;
  }
  if (S.map) URL.revokeObjectURL(S.map.url);
  S.map = { file, url: URL.createObjectURL(file) };
  renderMap();
  renderPreview();
  if (S.req.step === 3) renderRequests();
}

function clearMap() {
  if (S.map) URL.revokeObjectURL(S.map.url);
  S.map = null;
  renderMap();
  renderPreview();
  if (S.req.step === 3) renderRequests();
}

function renderMap() {
  $("#dropzone").classList.toggle("has", Boolean(S.map));
  if (S.map) {
    $("#mapThumb").src = S.map.url;
    $("#mapName").textContent = S.map.file.name;
  }
}

function renderPreview() {
  const sel = selected();
  if (!sel.some((j) => j.id === S.previewId)) S.previewId = sel[0]?.id ?? null;
  const j = byId(S.previewId);
  $("#previewTabs").innerHTML = sel.length > 1
    ? sel.map((x) => `<button type="button" data-pv="${esc(x.id)}" class="${x.id === S.previewId ? "on" : ""}">${esc(x.name)}</button>`).join("")
    : "";
  $("#pvTo").textContent = !j ? "Elige una jurisdicción en el paso 2"
    : j.method === "email" ? (j.emails.join(", ") || "Sin correo configurado")
    : j.method === "form" ? `Formulario web de ${j.name}` : "Proceso por definir";
  $("#pvSubject").textContent = S.subjectFormat.replace("{name}", j ? j.name : "…");
  $("#pvBody").innerHTML = highlight(S.template, {
    streets: joinStreets(S.req.streets),
    limits: joinLimits([S.req.limitA, S.req.limitB]),
    jurisdiction: j?.name || "",
  });
  const map = $("#pvMap");
  map.hidden = !S.map;
  if (S.map) map.src = S.map.url;
}

// ---------- paso 2: jurisdicciones ----------

function renderJGrid() {
  const q = $("#jSearch").value.trim().toLowerCase();
  const list = S.jurisdictions.filter((j) => !q || j.name.toLowerCase().includes(q));
  const cards = list.map((j) => {
    const on = S.req.selected.includes(j.id);
    return `<button type="button" class="jcard${on ? " on" : ""}" data-id="${esc(j.id)}" aria-pressed="${on}">
      <span class="check"><i class="ti ti-check"></i></span>
      <span class="m-icon m-${j.method}"><i class="ti ${ICONS[j.method]}"></i></span>
      <span class="jname">${esc(j.name)}</span>
      <span class="jmeta"><span class="badge">${esc(j.state)}</span>${METHODS[j.method]}</span>
      <span class="jcontact">${esc(contactOf(j))}</span>
    </button>`;
  }).join("");
  $("#jGrid").innerHTML = cards
    + `<button type="button" class="jcard add" data-add="1"><i class="ti ti-plus"></i><span>Agregar jurisdicción</span></button>`;
}

// ---------- paso 3: enviar ----------

let requestSeq = 0;

function requestPayload(ids) {
  return { streets: S.req.streets, limits: [S.req.limitA, S.req.limitB], ids };
}

async function loadRequests() {
  const ids = selected().map((j) => j.id);
  if (!ids.length) { S.requests = []; renderRequests(); return; }
  const seq = ++requestSeq;
  try {
    const data = await sendJSON("/api/requests", "POST", requestPayload(ids));
    if (seq === requestSeq) { S.requests = data.requests; renderRequests(); }
  } catch (e) {
    toast(e.message, "ti-alert-triangle");
  }
}

function box(value, key) {
  return `<div class="fbox"><pre>${esc(value)}</pre><button class="copy" type="button" data-copy="${esc(key)}" aria-label="Copiar" title="Copiar"><i class="ti ti-copy"></i></button></div>`;
}

function field(label, value, key) { return `<p class="flabel">${esc(label)}</p>${box(value, key)}`; }

function note(icon, html, dark = false) {
  return `<div class="note${dark ? " dark" : ""}"><i class="ti ${icon}"></i><div>${html}</div></div>`;
}

function requestCard(r) {
  const sent = S.req.sent.includes(r.id);
  let steps = [];
  let actions = "";
  let body = "";

  if (r.method === "email") {
    steps = S.map
      ? ["Toca «Abrir en Outlook»", "Abre el archivo descargado", "Revisa y envía"]
      : ["Toca «Abrir en Outlook»", "Abre el archivo descargado", "Pega el mapa debajo", "Envía"];
    actions = `<button class="btn primary" type="button" data-act="eml"><i class="ti ti-mail-opened"></i>Abrir en Outlook</button>
      <a class="btn ghost" href="${esc(r.mailto)}" title="Los enlaces de correo (mailto) no permiten imágenes"><i class="ti ti-mail"></i>Solo texto en mi correo</a>
      <p class="micro actions-tip"><b>Abrir en Outlook</b> trae todo: destinatario, asunto, texto${S.map ? " y el mapa" : ""}.
      Tip: en la descarga de Edge, clic derecho → «Abrir siempre archivos de este tipo», y Outlook se abrirá solo cada vez.</p>`;
    body = (r.to.length ? "" : note("ti-alert-triangle", "Esta jurisdicción no tiene correos. Agrégalos en Jurisdicciones."))
      + (S.map ? "" : note("ti-photo", "Agrega el mapa en el paso 1 y el borrador lo traerá dentro del correo."))
      + field("Para", r.to.join(", ") || "—", "to") + field("Asunto", r.subject, "subject");
  } else if (r.method === "form") {
    steps = ["Abre el formulario", "Copia el mensaje", "Pégalo en la descripción", "Adjunta el mapa y envía"];
    actions = `<a class="btn primary" href="${esc(r.form_url || "#")}" target="_blank" rel="noopener"><i class="ti ti-external-link"></i>Abrir formulario</a>
      <button class="btn ghost" type="button" data-copy="body"><i class="ti ti-copy"></i>Copiar mensaje</button>`;
    if (r.notes) body = note("ti-info-circle", esc(r.notes));
  } else {
    body = note("ti-hourglass", `<b>Proceso aún no definido.</b> ${esc(r.notes || "Documéntalo en Jurisdicciones cuando lo conozcas.")}`, true);
  }

  const open = r.method === "form" || S.openMsgs.has(r.id) ? " open" : "";
  const message = r.method === "pending" ? ""
    : `<details class="msg" data-id="${esc(r.id)}"${open}><summary><i class="ti ti-chevron-right chev"></i>${r.method === "form" ? "Mensaje para pegar" : "Ver mensaje completo"}</summary>${box(r.body, "body")}</details>`;

  const hasExtra = r.form_note || r.form_fields.length;
  const extra = !hasExtra ? "" : `<p class="flabel" style="margin-top:18px">Formulario adicional</p>
    ${r.form_note ? note("ti-file-text", esc(r.form_note)) : ""}
    ${r.form_fields.map((f, i) => field(f.label, f.value, `field:${i}`)).join("")}
    ${r.form_fields.length ? '<button class="btn ghost sm" type="button" data-copy="fields" style="margin-top:12px"><i class="ti ti-copy"></i>Copiar todos los campos</button>' : ""}`;

  const missing = r.missing.length ? note("ti-alert-triangle", "Faltan datos del paso 1: el texto todavía tiene huecos.") : "";

  return `<article class="rcard${sent ? " sent" : ""}" data-id="${esc(r.id)}">
    <header class="rcard-head">
      <span class="m-icon m-${r.method}"><i class="ti ${ICONS[r.method]}"></i></span>
      <div class="title"><b>${esc(r.name)}</b><small>${METHODS[r.method]} · ${esc(r.state)}</small></div>
      <label class="switch"><input type="checkbox" data-act="sent"${sent ? " checked" : ""}><span class="track"></span>${sent ? "Enviada" : "Marcar enviada"}</label>
    </header>
    <div class="rcard-body">
      ${missing}
      ${steps.length ? `<ol class="howto">${steps.map((s) => `<li>${s}</li>`).join("")}</ol>` : ""}
      ${actions ? `<div class="actions">${actions}</div>` : ""}
      ${body}${message}${extra}
    </div>
  </article>`;
}

function renderRequests() {
  const total = S.requests.length;
  const nSent = S.requests.filter((r) => S.req.sent.includes(r.id)).length;
  $("#progressText").textContent = total ? `${nSent} de ${total} enviadas` : "";
  $("#progressFill").style.width = total ? `${(nSent / total) * 100}%` : "0";
  $("#doneBanner").hidden = !(total && nSent === total);
  $$("#requestList details.msg").forEach((d) => (d.open ? S.openMsgs.add(d.dataset.id) : S.openMsgs.delete(d.dataset.id)));
  $("#requestList").innerHTML = S.requests.map(requestCard).join("");
}

async function downloadEml(r) {
  const form = new FormData();
  form.append("payload", JSON.stringify({ ...requestPayload([]), id: r.id }));
  if (S.map) form.append("map", S.map.file, S.map.file.name);
  try {
    const res = await api("/api/eml", { method: "POST", body: form });
    const name = decodeURIComponent(res.headers.get("X-Filename") || "records-request.eml");
    const url = URL.createObjectURL(await res.blob());
    const a = Object.assign(document.createElement("a"), { href: url, download: name });
    document.body.append(a);
    a.click();
    a.remove();
    setTimeout(() => URL.revokeObjectURL(url), 4000);
    toast("Listo: abre el archivo descargado y Outlook lo mostrará para enviar", "ti-mail-opened");
  } catch (e) {
    toast(e.message, "ti-alert-triangle");
  }
}

function copyFromRequest(r, key) {
  if (key.startsWith("field:")) {
    const f = r.form_fields[Number(key.slice(6))];
    return copyText(f.value, f.label);
  }
  const items = {
    to: [r.to.join(", "), "Destinatario"],
    subject: [r.subject, "Asunto"],
    body: [r.body, "Mensaje"],
    fields: [r.form_fields.map((f) => `${f.label}: ${f.value}`).join("\n"), "Campos"],
  };
  return copyText(...items[key]);
}

// ---------- tarjeta lateral ----------

function renderSide() {
  const r = S.req;
  const sel = selected();
  const card = $("#sideCard");
  if (!r.streets.length && !sel.length) {
    card.innerHTML = '<div class="k">Solicitud en curso</div><p class="empty">Aún no empiezas una. Arranca en <b>Nueva solicitud</b>.</p>';
    return;
  }
  const nSent = sel.filter((j) => r.sent.includes(j.id)).length;
  card.innerHTML = `<div class="k">Solicitud en curso</div>
    <div class="v">${esc(joinStreets(r.streets) || "Sin calles todavía")}</div>
    <div class="row"><span>Jurisdicciones</span><b>${sel.length}</b></div>
    <div class="row"><span>Enviadas</span><b>${nSent} de ${sel.length}</b></div>
    <div class="bar"><i style="width:${sel.length ? (nSent / sel.length) * 100 : 0}%"></i></div>`;
}

function resetRequest() {
  S.req = emptyRequest();
  S.requests = [];
  S.openMsgs.clear();
  $("#limitA").value = "";
  $("#limitB").value = "";
  $("#jSearch").value = "";
  clearMap();
  changed();
  renderStep();
  location.hash = "#/nueva";
  toast("Listo para una solicitud nueva", "ti-sparkles");
}

// ---------- directorio de jurisdicciones ----------

function renderJList() {
  const q = $("#jSearch2").value.trim().toLowerCase();
  const list = S.jurisdictions.filter((j) =>
    (S.filter === "all" || j.method === S.filter)
    && (!q || j.name.toLowerCase().includes(q) || contactOf(j).toLowerCase().includes(q)));
  $("#jList").innerHTML = list.length ? list.map((j) => `
    <button type="button" class="jitem" data-id="${esc(j.id)}">
      <span class="jitem-top"><span class="m-icon m-${j.method}"><i class="ti ${ICONS[j.method]}"></i></span><b>${esc(j.name)}</b><i class="ti ti-pencil edit"></i></span>
      <span class="jmeta"><span class="badge">${esc(j.state)}</span>${METHODS[j.method]}${j.form_fields?.length ? ` · ${plural(j.form_fields.length, "campo", "campos")} de formulario` : ""}</span>
      <span class="detail"><i class="ti ${j.method === "email" ? "ti-at" : j.method === "form" ? "ti-link" : "ti-notes"}"></i><span>${esc(contactOf(j))}</span></span>
    </button>`).join("")
    : '<div class="empty-state"><i class="ti ti-building-off"></i>No hay jurisdicciones que coincidan.</div>';
  setCount("countJ", S.jurisdictions.length);
}

function setSeg(container, value) {
  $$("button", $(container)).forEach((b) => b.classList.toggle("on", b.dataset.value === value));
}

function segValue(container) { return $(`${container} button.on`)?.dataset.value; }

function setMethod(method) {
  setSeg("#fMethod", method);
  $$("#jForm [data-show]").forEach((el) => { el.hidden = el.dataset.show !== method; });
}

function fieldRow(f = { label: "", value: "" }) {
  const row = document.createElement("div");
  row.className = "frow";
  row.innerHTML = `<input placeholder="Etiqueta" value="${esc(f.label)}" aria-label="Etiqueta del campo">
    <input placeholder="Valor" value="${esc(f.value)}" aria-label="Valor del campo">
    <button class="icon-btn" type="button" aria-label="Quitar campo"><i class="ti ti-x"></i></button>`;
  row.querySelector("button").addEventListener("click", () => row.remove());
  return row;
}

function openDrawer(j) {
  S.editing = j ? j.id : null;
  $("#drawerTitle").textContent = j ? `Editar ${j.name}` : "Nueva jurisdicción";
  $("#fName").value = j?.name || "";
  setSeg("#fState", j?.state || "FL");
  setMethod(j?.method || "email");
  $("#fEmails").value = (j?.emails || []).join("\n");
  $("#fUrl").value = j?.form_url || "";
  $("#fNotes").value = j?.notes || "";
  $("#fFormNote").value = j?.form_note || "";
  $("#fieldRows").replaceChildren(...(j?.form_fields || []).map(fieldRow));
  $("#fExtra").open = Boolean(j?.form_note || j?.form_fields?.length);
  $("#jError").textContent = "";
  const del = $("#btnDeleteJ");
  del.hidden = !j;
  del.classList.remove("armed");
  del.innerHTML = '<i class="ti ti-trash"></i><span>Eliminar</span>';
  $("#drawerBackdrop").hidden = false;
  $("#drawer").classList.add("open");
  $("#drawer").setAttribute("aria-hidden", "false");
  setTimeout(() => $("#fName").focus(), 220);
}

function closeDrawer() {
  $("#drawer").classList.remove("open");
  $("#drawer").setAttribute("aria-hidden", "true");
  $("#drawerBackdrop").hidden = true;
  S.editing = null;
}

function applyJurisdictions(list) {
  S.jurisdictions = list;
  const ids = new Set(list.map((j) => j.id));
  S.req.selected = S.req.selected.filter((id) => ids.has(id));
  S.req.sent = S.req.sent.filter((id) => ids.has(id));
  renderJList();
  changed();
}

async function saveJurisdiction() {
  const method = segValue("#fMethod");
  const data = {
    id: S.editing,
    name: $("#fName").value.trim(),
    state: segValue("#fState"),
    method,
    emails: $("#fEmails").value.split(/[\n,;]/).map((s) => s.trim()).filter(Boolean),
    form_url: $("#fUrl").value.trim(),
    notes: $("#fNotes").value.trim(),
    form_note: $("#fFormNote").value.trim(),
    form_fields: $$("#fieldRows .frow").map((row) => {
      const [label, value] = $$("input", row).map((i) => i.value.trim());
      return { label, value };
    }).filter((f) => f.label),
  };
  const err = $("#jError");
  if (!data.name) { err.textContent = "Escribe el nombre de la jurisdicción."; $("#fName").focus(); return; }
  if (method === "email" && !data.emails.length) { err.textContent = "Agrega al menos un correo."; $("#fEmails").focus(); return; }
  if (method === "form" && !/^https?:\/\//.test(data.form_url)) { err.textContent = "Pega el link completo del formulario (empieza con https://)."; $("#fUrl").focus(); return; }
  try {
    const res = await sendJSON("/api/jurisdictions", "POST", data);
    applyJurisdictions(res.jurisdictions);
    closeDrawer();
    toast(`“${res.jurisdiction.name}” guardada para todo el equipo`);
  } catch (e) {
    err.textContent = e.message;
  }
}

async function deleteJurisdiction() {
  const j = byId(S.editing);
  if (!j) return;
  try {
    const res = await (await api(`/api/jurisdictions/${encodeURIComponent(j.id)}`, { method: "DELETE" })).json();
    applyJurisdictions(res.jurisdictions);
    closeDrawer();
    toast(`“${j.name}” eliminada`, "ti-trash");
  } catch (e) {
    $("#jError").textContent = e.message;
  }
}

// ---------- plantilla ----------

function renderTemplatePreview() {
  $("#tplPreview").innerHTML = highlight($("#tplText").value, SAMPLE);
}

async function saveTemplate() {
  const hint = $("#tplHint");
  try {
    const res = await sendJSON("/api/template", "PUT", { template: $("#tplText").value });
    S.template = res.template;
    hint.textContent = "";
    renderPreview();
    if (S.req.step === 3) loadRequests();
    toast("Plantilla guardada para todo el equipo");
  } catch (e) {
    hint.textContent = e.message;
  }
}

// ---------- feedback ----------

function renderKinds() {
  $("#fbKinds").innerHTML = S.feedbackTypes.map((t, i) => {
    const [emoji, ...words] = t.split(" ");
    return `<button type="button" data-kind="${esc(t)}" class="${i === 0 ? "on" : ""}"><span>${emoji}</span>${esc(words.join(" "))}</button>`;
  }).join("");
}

async function loadFeedback() {
  try { renderFeedback((await getJSON("/api/feedback")).feedback); } catch { /* sin conexión: se intenta de nuevo al volver */ }
}

function renderFeedback(list) {
  setCount("countF", list.length);
  $("#fbTitle").textContent = list.length ? `Comentarios recibidos (${list.length})` : "Aún no hay comentarios";
  $("#fbList").innerHTML = list.length
    ? list.map((f) => `<article class="fb-item"><header><b>${esc(f.Tipo)} · ${esc(f.Nombre)}</b><span>${esc(f.Fecha)}</span></header><p>${esc(f.Comentario)}</p></article>`).join("")
    : '<div class="empty-state"><i class="ti ti-message-2"></i>Sé el primero en dejar una idea.</div>';
}

async function sendFeedback(e) {
  e.preventDefault();
  const message = $("#fbMsg").value.trim();
  const err = $("#fbError");
  if (!message) { err.textContent = "Escribe tu comentario antes de enviarlo."; $("#fbMsg").focus(); return; }
  err.textContent = "";
  const name = $("#fbName").value.trim();
  storage("set", "rrd.name", name);
  try {
    const res = await sendJSON("/api/feedback", "POST", { name, kind: $("#fbKinds button.on")?.dataset.kind, message });
    $("#fbMsg").value = "";
    renderFeedback(res.feedback);
    toast("¡Gracias! Tu comentario quedó guardado", "ti-heart");
  } catch (ex) {
    err.textContent = ex.message;
  }
}

// ---------- datos compartidos ----------

async function loadShared(quiet = false) {
  try {
    const data = await getJSON("/api/bootstrap");
    const editor = $("#tplText");
    // No pisar lo que alguien está editando en la pestaña Plantilla.
    if (!quiet || editor.value === S.template) editor.value = data.template;
    S.template = data.template;
    S.defaultTemplate = data.default_template;
    S.subjectFormat = data.subject_format;
    S.feedbackTypes = data.feedback_types;
    setCount("countF", data.feedback_count);
    if (!S.editing) applyJurisdictions(data.jurisdictions);
    renderTemplatePreview();
    return true;
  } catch {
    if (!quiet) toast("No se pudo conectar con la app. ¿Está encendida la PC principal?", "ti-plug-x");
    return false;
  }
}

// ---------- eventos ----------

function bindEvents() {
  window.addEventListener("hashchange", route);
  // Al volver a la ventana, trae lo que el equipo haya cambiado.
  window.addEventListener("focus", () => loadShared(true));

  $$("#stepper button").forEach((b) => b.addEventListener("click", () => goStep(Number(b.closest("li").dataset.step))));
  $$("[data-go]").forEach((b) => b.addEventListener("click", () => goStep(Number(b.dataset.go))));
  $("#btnReset").addEventListener("click", (e) => armed(e.currentTarget, "¿Seguro? Toca otra vez", resetRequest));
  $("#btnDoneReset").addEventListener("click", resetRequest);

  const input = $("#streetInput");
  $("#streetsBox").addEventListener("click", (e) => { if (e.target === e.currentTarget) input.focus(); });
  input.addEventListener("keydown", (e) => {
    if ((e.key === "Enter" || e.key === ",") && input.value.trim()) {
      e.preventDefault();
      addStreets(input.value);
      input.value = "";
    } else if (e.key === "Backspace" && !input.value && S.req.streets.length) {
      S.req.streets.pop();
      changed();
    }
  });
  input.addEventListener("paste", (e) => {
    const text = e.clipboardData?.getData("text") || "";
    if (/[\n&;]/.test(text)) { e.preventDefault(); addStreets(text); }
  });
  input.addEventListener("blur", () => { if (input.value.trim()) { addStreets(input.value); input.value = ""; } });

  $("#limitA").addEventListener("input", (e) => { S.req.limitA = e.target.value; changed(); });
  $("#limitB").addEventListener("input", (e) => { S.req.limitB = e.target.value; changed(); });
  $("#btnSwap").addEventListener("click", () => {
    [S.req.limitA, S.req.limitB] = [S.req.limitB, S.req.limitA];
    $("#limitA").value = S.req.limitA;
    $("#limitB").value = S.req.limitB;
    changed();
  });

  const dz = $("#dropzone");
  $("#mapInput").addEventListener("change", (e) => { setMap(e.target.files[0]); e.target.value = ""; });
  dz.addEventListener("dragover", (e) => { e.preventDefault(); dz.classList.add("over"); });
  dz.addEventListener("dragleave", () => dz.classList.remove("over"));
  dz.addEventListener("drop", (e) => { e.preventDefault(); dz.classList.remove("over"); setMap(e.dataTransfer.files[0]); });
  $("#btnMapRemove").addEventListener("click", (e) => { e.preventDefault(); e.stopPropagation(); clearMap(); });
  // Ctrl+V con una captura (Win+Shift+S) la agrega como mapa.
  document.addEventListener("paste", (e) => {
    if (!$("#view-nueva").hidden) {
      const item = [...(e.clipboardData?.items || [])].find((i) => i.kind === "file" && i.type.startsWith("image/"));
      if (item) {
        e.preventDefault();
        const f = item.getAsFile();
        setMap(new File([f], "mapa-proyecto.png", { type: f.type }));
        toast("Mapa pegado desde el portapapeles", "ti-clipboard-check");
      }
    }
  });

  $("#previewTabs").addEventListener("click", (e) => {
    const b = e.target.closest("[data-pv]");
    if (b) { S.previewId = b.dataset.pv; renderPreview(); }
  });

  $("#jSearch").addEventListener("input", renderJGrid);
  $("#jGrid").addEventListener("click", (e) => {
    const card = e.target.closest(".jcard");
    if (!card) return;
    if (card.dataset.add) { location.hash = "#/jurisdicciones"; openDrawer(null); return; }
    toggleIn(S.req.selected, card.dataset.id, !S.req.selected.includes(card.dataset.id));
    changed();
  });

  $("#requestList").addEventListener("click", (e) => {
    const card = e.target.closest(".rcard");
    const r = card && S.requests.find((x) => x.id === card.dataset.id);
    if (!r) return;
    const copyBtn = e.target.closest("[data-copy]");
    if (copyBtn) copyFromRequest(r, copyBtn.dataset.copy);
    else if (e.target.closest('[data-act="eml"]')) downloadEml(r);
  });
  $("#requestList").addEventListener("change", (e) => {
    if (!e.target.matches('[data-act="sent"]')) return;
    toggleIn(S.req.sent, e.target.closest(".rcard").dataset.id, e.target.checked);
    saveRequest();
    renderRequests();
    renderStepper();
    renderSide();
    if (stepsDone()[2]) toast("¡Todas enviadas! Buen trabajo", "ti-confetti");
  });

  $("#btnNewJ").addEventListener("click", () => openDrawer(null));
  $("#jSearch2").addEventListener("input", renderJList);
  $("#methodFilter").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (!b) return;
    S.filter = b.dataset.m;
    $$("#methodFilter button").forEach((x) => x.classList.toggle("on", x === b));
    renderJList();
  });
  $("#jList").addEventListener("click", (e) => {
    const item = e.target.closest(".jitem");
    if (item) openDrawer(byId(item.dataset.id));
  });

  $("#fState").innerHTML = Object.entries(STATE_LABELS)
    .map(([v, label]) => `<button type="button" data-value="${esc(v)}">${label}</button>`).join("");
  $("#fMethod").innerHTML = Object.entries(METHODS)
    .map(([v, label]) => `<button type="button" data-value="${v}"><i class="ti ${ICONS[v]}"></i>${label}</button>`).join("");
  $("#fState").addEventListener("click", (e) => { const b = e.target.closest("button"); if (b) setSeg("#fState", b.dataset.value); });
  $("#fMethod").addEventListener("click", (e) => { const b = e.target.closest("button"); if (b) setMethod(b.dataset.value); });
  $("#btnAddField").addEventListener("click", () => $("#fieldRows").append(fieldRow()));
  $("#btnSaveJ").addEventListener("click", saveJurisdiction);
  $("#jForm").addEventListener("submit", (e) => { e.preventDefault(); saveJurisdiction(); });
  $("#btnCancelJ").addEventListener("click", closeDrawer);
  $("#drawerClose").addEventListener("click", closeDrawer);
  $("#drawerBackdrop").addEventListener("click", closeDrawer);
  $("#btnDeleteJ").addEventListener("click", (e) => armed(e.currentTarget, "¿Seguro? Toca otra vez", deleteJurisdiction));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && $("#drawer").classList.contains("open")) closeDrawer(); });

  $("#tplText").addEventListener("input", () => { $("#tplHint").textContent = ""; renderTemplatePreview(); });
  $$(".token-bar [data-token]").forEach((b) => b.addEventListener("click", () => {
    const ta = $("#tplText");
    ta.setRangeText(b.dataset.token, ta.selectionStart, ta.selectionEnd, "end");
    ta.focus();
    renderTemplatePreview();
  }));
  $("#btnTplReset").addEventListener("click", () => {
    $("#tplText").value = S.defaultTemplate;
    renderTemplatePreview();
    $("#tplHint").textContent = "";
    toast("Texto original restaurado. Guarda para aplicarlo.", "ti-arrow-back-up");
  });
  $("#btnTplSave").addEventListener("click", saveTemplate);

  $("#fbKinds").addEventListener("click", (e) => {
    const b = e.target.closest("button");
    if (b) $$("#fbKinds button").forEach((x) => x.classList.toggle("on", x === b));
  });
  $("#fbForm").addEventListener("submit", sendFeedback);
  $("#fbMsg").addEventListener("input", () => { $("#fbError").textContent = ""; });
}

// ---------- inicio ----------

async function boot() {
  bindEvents();
  $("#limitA").value = S.req.limitA;
  $("#limitB").value = S.req.limitB;
  $("#fbName").value = storage("get", "rrd.name") || "";
  await loadShared();
  renderKinds();
  renderMap();
  renderStep();
  renderTemplatePreview();
  route();
  if (S.req.step === 3) loadRequests();
}

boot();
