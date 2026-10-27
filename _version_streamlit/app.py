"""Records Request Desk — asistente paso a paso para solicitar utility records.

Ejecutar:  uv run streamlit run app.py
"""

from __future__ import annotations

from html import escape
from urllib.parse import quote

import streamlit as st

import records_core as core

NEW = "__new__"
ICONS = {"email": "✉️", "form": "🌐", "pending": "⏳"}

st.set_page_config(page_title="Records Request Desk", page_icon="📮", layout="centered")

st.markdown(
    """
<style>
/* Colores de la compañía: cambia --brand* aquí y primaryColor en .streamlit/config.toml */
:root{--ink:#2b2420;--soft:#6e625a;--faint:#a0948b;--brand:#d9620b;--brand-dark:#a8480a;
  --brand-soft:#fde6d2;--card:#fffbf6;--line:#e8d9c8;--todo:#f3ece5;--todo-ink:#8c7f75}
[data-testid="stMainBlockContainer"]{max-width:900px;padding-top:2.2rem}
.hero{background:linear-gradient(135deg,#c0520a 0%,#dc650e 60%,#ea771b 100%);color:#fff;
  border-radius:18px;padding:22px 26px 20px;margin-bottom:6px}
.hero .eyebrow{font-family:"IBM Plex Mono",monospace;font-size:11px;letter-spacing:.12em;
  text-transform:uppercase;opacity:.85}
.hero .title{font-size:28px;font-weight:700;margin:.15rem 0 .25rem;letter-spacing:-.01em}
.hero p{margin:0;font-size:14.5px;font-weight:500}
.stepper{display:flex;align-items:center;gap:10px;margin:2px 2px 8px}
.stepper .s{display:flex;align-items:center;gap:8px;font-size:13.5px;color:var(--faint);
  font-weight:500;white-space:nowrap}
.stepper .dot{width:26px;height:26px;border-radius:50%;display:grid;place-items:center;
  font-size:12.5px;font-weight:700;border:2px solid var(--line);background:var(--card);
  color:var(--faint)}
.stepper .s.done{color:var(--brand-dark)}
.stepper .s.done .dot{background:var(--brand);border-color:var(--brand);color:#fff}
.stepper .s.now{color:var(--ink);font-weight:600}
.stepper .s.now .dot{border-color:var(--brand);color:var(--brand-dark)}
.stepper .bar{flex:1;height:2px;background:var(--line);border-radius:2px;min-width:16px}
.stepper .bar.done{background:var(--brand)}
@media (max-width:520px){.stepper .s:not(.now) .lbl{display:none}}
.step-head{display:flex;gap:12px;align-items:flex-start;margin-bottom:4px}
.step-head .badge{flex:none;width:30px;height:30px;border-radius:9px;display:grid;
  place-items:center;font-weight:700;background:var(--brand-soft);color:var(--brand-dark)}
.step-head .badge.done{background:var(--brand);color:#fff}
.step-title{font-size:17px;font-weight:700;line-height:1.25}
.step-hint{font-size:13px;color:var(--soft);margin-top:2px}
.preview{background:#fff;border:1px dashed var(--line);border-radius:12px;padding:10px 14px 2px;
  font-size:14px;line-height:1.65;color:var(--soft)}
.preview .lbl{font-size:11px;letter-spacing:.08em;text-transform:uppercase;color:var(--faint);
  font-weight:600;margin-bottom:4px}
.preview mark{background:var(--brand-soft);color:var(--brand-dark);padding:1px 6px;
  border-radius:5px;font-weight:600}
.preview mark.todo{background:var(--todo);color:var(--todo-ink);font-weight:500;
  border:1px dashed var(--line)}
.howto{display:flex;flex-wrap:wrap;gap:6px;margin:2px 0 12px}
.howto span{background:var(--brand-soft);color:var(--brand-dark);border-radius:100px;
  padding:3px 11px;font-size:12.5px;font-weight:500}
.legend{font-size:12.5px;color:var(--soft)}
[class*="st-key-card"]{background:var(--card);border-radius:16px !important;
  box-shadow:0 1px 2px rgba(60,40,20,.05),0 12px 26px -18px rgba(60,40,20,.3)}
</style>
""",
    unsafe_allow_html=True,
)


# ---------- piezas de interfaz ----------

def step_head(n: int, title: str, hint: str, done: bool) -> None:
    st.markdown(
        f'<div class="step-head"><span class="badge {"done" if done else ""}">'
        f'{"✓" if done else n}</span><div><div class="step-title">{title}</div>'
        f'<div class="step-hint">{hint}</div></div></div>',
        unsafe_allow_html=True,
    )


def stepper(states: list[bool]) -> None:
    labels = ["Proyecto", "Jurisdicciones", "Enviar"]
    current = next((i for i, done in enumerate(states) if not done), None)
    parts = []
    for i, (label, done) in enumerate(zip(labels, states)):
        cls = "done" if done else "now" if i == current else ""
        if i:
            parts.append(f'<div class="bar {"done" if states[i - 1] else ""}"></div>')
        parts.append(
            f'<div class="s {cls}"><span class="dot">{"✓" if done else i + 1}</span>'
            f'<span class="lbl">{label}</span></div>'
        )
    st.markdown(f'<div class="stepper">{"".join(parts)}</div>', unsafe_allow_html=True)


def howto(steps: list[str]) -> None:
    chips = "".join(f"<span>{i} · {s}</span>" for i, s in enumerate(steps, 1))
    st.markdown(f'<div class="howto">{chips}</div>', unsafe_allow_html=True)


def kv(label: str, value: str) -> None:
    st.caption(label)
    st.code(value or "—", language=None, wrap_lines=True)


def preview(template: str, streets: str, limits: str, jurisdiction: str) -> None:
    """Muestra los párrafos con datos variables, resaltando lo lleno y lo que falta."""
    fills = {
        "[STREETS]": (streets, "calles del paso 1"),
        "[LIMITS]": (limits, "límites del paso 1"),
        "[JURISDICTION]": (jurisdiction, "jurisdicción del paso 2"),
    }
    paragraphs = []
    for p in template.split("\n\n"):
        if not any(t in p for t in fills):
            continue
        html = escape(p)
        for token, (value, missing) in fills.items():
            mark = f"<mark>{escape(value)}</mark>" if value else f'<mark class="todo">{missing}</mark>'
            html = html.replace(token, mark)
        paragraphs.append(f"<p>{html}</p>")
    st.markdown(
        f'<div class="preview"><div class="lbl">Así va quedando tu texto</div>{"".join(paragraphs)}</div>',
        unsafe_allow_html=True,
    )


# ---------- estado y callbacks ----------

for key, value in {
    "along": "",
    "limit_a": "",
    "limit_b": "",
    "selected": [],
    "template": core.load_template(),
    "edit_target": NEW,
    "upload_n": 0,
}.items():
    st.session_state.setdefault(key, value)

ss = st.session_state


def reset_request() -> None:
    ss.along = ss.limit_a = ss.limit_b = ""
    ss.selected = []
    for key in [k for k in ss.keys() if k.startswith("sent_")]:
        del ss[key]
    ss.upload_n += 1  # una key nueva vacía el campo del mapa


def reset_template() -> None:
    ss.template = core.DEFAULT_TEMPLATE


def save_template() -> None:
    missing = core.missing_tokens(ss.template)
    if missing:
        st.toast(f"Falta {', '.join(missing)} en la plantilla — no se guardó.", icon="⚠️")
        return
    core.save_template(ss.template)
    st.toast("Plantilla guardada para todos", icon="✅")


def save_jurisdiction(target: str) -> None:
    items = core.load_jurisdictions()
    name = ss[f"f_name_{target}"].strip()
    if not name:
        st.toast("Escribe el nombre de la jurisdicción.", icon="⚠️")
        return
    if target == NEW:
        taken = {j["id"] for j in items}
        jid, n = core.slugify(name), 2
        while jid in taken:
            jid, n = f"{core.slugify(name)}-{n}", n + 1
        order = max((j.get("order", 0) for j in items), default=0) + 1
    else:
        jid = target
        order = next(j.get("order", 0) for j in items if j["id"] == target)

    fields = []
    for line in ss[f"f_fields_{target}"].splitlines():
        label, sep, value = line.partition(":")
        if sep and label.strip():
            fields.append({"label": label.strip(), "value": value.strip()})

    core.save_jurisdiction({
        "id": jid,
        "name": name,
        "state": ss[f"f_state_{target}"],
        "method": ss[f"f_method_{target}"],
        "emails": [e.strip() for e in ss[f"f_emails_{target}"].splitlines() if e.strip()],
        "form_url": ss[f"f_url_{target}"].strip(),
        "notes": ss[f"f_notes_{target}"].strip(),
        "form_note": ss[f"f_formnote_{target}"].strip(),
        "form_fields": fields,
        "order": order,
    })
    ss.edit_target = jid
    st.toast(f"“{name}” guardada", icon="✅")


def send_feedback() -> None:
    if not ss.fb_msg.strip():
        st.toast("Escribe tu comentario antes de enviarlo.", icon="⚠️")
        return
    core.add_feedback(ss.fb_name.strip(), ss.fb_kind, ss.fb_msg.strip())
    st.toast("¡Gracias! Tu comentario quedó registrado.", icon="🙌")


def delete_jurisdiction(target: str) -> None:
    core.delete_jurisdiction(target)
    ss.selected = [i for i in ss.selected if i != target]
    ss.edit_target = NEW
    st.toast("Jurisdicción eliminada", icon="🗑️")


items = core.load_jurisdictions()
by_id = {j["id"]: j for j in items}
ss.selected = [i for i in ss.selected if i in by_id]

streets = core.join_streets(ss.along.splitlines())
limits = core.join_limits([ss.limit_a, ss.limit_b])
selected = [by_id[i] for i in ss.selected]
sent = [j for j in selected if ss.get(f"sent_{j['id']}")]
done = [
    bool(streets and ss.limit_a.strip() and ss.limit_b.strip()),
    bool(selected),
    bool(selected) and len(sent) == len(selected),
]

# ---------- encabezado ----------

st.markdown(
    '<div class="hero"><div class="eyebrow">Utility Coordination · FL / GA</div>'
    '<div class="title">Records Request Desk</div>'
    "<p>Arma tu solicitud de utility records en 3 pasos: describe el tramo, elige las "
    "jurisdicciones y envía cada solicitud ya redactada.</p></div>",
    unsafe_allow_html=True,
)

tab_new, tab_juris, tab_tpl, tab_fb = st.tabs(
    ["📝 Nueva solicitud", "🏛️ Jurisdicciones", "✏️ Plantilla", "💬 Feedback"]
)

# ---------- pestaña: nueva solicitud ----------


def render_form_fields(j: dict, body: str) -> None:
    if not (j.get("form_note") or j.get("form_fields")):
        return
    st.markdown("**Formulario adicional**")
    if j.get("form_note"):
        st.info(j["form_note"])
    lines = []
    for f in j.get("form_fields", []):
        value = core.fill(f["value"], streets, limits, j["name"], draft=body)
        kv(f["label"], value)
        lines.append(f"{f['label']}: {value}")
    if lines:
        with st.expander("Ver todos los campos juntos"):
            st.code("\n".join(lines), language=None, wrap_lines=True)


def render_request(j: dict) -> None:
    body = core.fill(ss.template, streets, limits, j["name"])
    map_file = ss.get(f"map_{ss.upload_n}")

    if j["method"] == "email":
        to = j.get("emails", [])
        subject = core.email_subject(j["name"])
        howto(
            ["Descarga el borrador", "Ábrelo en Outlook", "Revisa y envía"]
            if map_file
            else ["Descarga el borrador", "Ábrelo en Outlook", "Pega el mapa debajo", "Envía"]
        )
        if not to:
            st.warning("Esta jurisdicción no tiene correos configurados (pestaña Jurisdicciones).")
        eml = core.build_eml(
            to,
            subject,
            body,
            map_file.getvalue() if map_file else None,
            map_file.name if map_file else "map.png",
            map_file.type if map_file else "image/png",
        )
        c1, c2 = st.columns(2)
        c1.download_button(
            "⬇️ Descargar borrador (.eml)",
            data=eml,
            file_name=core.safe_filename(f"{subject} - {streets}") + ".eml",
            mime="message/rfc822",
            type="primary",
            width="stretch",
            key=f"eml_{j['id']}",
        )
        c2.link_button(
            "✉️ Abrir en mi correo",
            f"mailto:{','.join(to)}?subject={quote(subject)}&body={quote(body)}",
            width="stretch",
        )
        kv("Para", ", ".join(to))
        kv("Asunto", subject)
        kv("Mensaje", body)
    elif j["method"] == "form":
        howto(["Abre el formulario", "Copia el texto de abajo", "Pégalo en la descripción",
               "Adjunta el mapa y envía"])
        st.link_button(f"🌐 Abrir formulario de {j['name']}", j.get("form_url") or "#",
                       type="primary")
        if j.get("notes"):
            st.caption(j["notes"])
        kv("Texto para pegar en el formulario", body)
    else:
        st.warning(
            "⏳ **Proceso aún no definido.** "
            + (j.get("notes") or "Documéntalo en la pestaña Jurisdicciones cuando lo conozcas.")
        )

    if j["method"] != "pending":
        render_form_fields(j, body)
    st.divider()
    st.checkbox("✅ Ya envié esta solicitud", key=f"sent_{j['id']}")


with tab_new:
    stepper(done)

    with st.container(border=True, key="card_project"):
        step_head(1, "Describe el tramo del proyecto",
                  "Escribe las calles tal como aparecen en el mapa, p. ej. NW 10th Ave.", done[0])
        st.text_area(
            "Along — calles donde va la fibra (una por línea)",
            key="along",
            height=110,
            placeholder="NW 10th Ave\nNW 21st Terrace\nNW 21st St",
        )
        c1, c2 = st.columns(2)
        c1.text_input("Between — límite 1", key="limit_a", placeholder="NW 22nd St")
        c2.text_input("Between — límite 2", key="limit_b", placeholder="NW 18th St")
        preview(ss.template, streets, limits, " / ".join(j["name"] for j in selected))
        st.file_uploader(
            "Mapa del proyecto (opcional)",
            type=["png", "jpg", "jpeg", "webp"],
            key=f"map_{ss.upload_n}",
            help="Solo se inserta debajo del texto en el borrador .eml; no se analiza.",
        )

    with st.container(border=True, key="card_juris"):
        step_head(2, "Elige a quién pedir los records",
                  "Puedes elegir varias; cada una recibe su propia solicitud.", done[1])
        if items:
            st.pills(
                "Jurisdicciones",
                list(by_id),
                selection_mode="multi",
                key="selected",
                format_func=lambda i: f"{ICONS[by_id[i]['method']]} {by_id[i]['name']}",
                label_visibility="collapsed",
            )
            st.markdown(
                '<div class="legend">✉️ por correo &nbsp;·&nbsp; 🌐 formulario web '
                "&nbsp;·&nbsp; ⏳ proceso por definir</div>",
                unsafe_allow_html=True,
            )
        else:
            st.info("Aún no hay jurisdicciones. Agrégalas en la pestaña 🏛️ Jurisdicciones.")

    with st.container(border=True, key="card_send"):
        hint = (
            f"{len(sent)} de {len(selected)} enviadas. Sigue las indicaciones de cada pestaña."
            if selected
            else "Cuando completes los pasos 1 y 2, aquí aparecerá cada solicitud lista."
        )
        step_head(3, "Envía cada solicitud", hint, done[2])
        if selected:
            if not done[0]:
                st.warning("Te falta completar el paso 1: el texto aún tiene huecos.")
            tabs = st.tabs([f"{ICONS[j['method']]} {j['name']}" for j in selected])
            for tab, j in zip(tabs, selected):
                with tab:
                    render_request(j)
        if done[2]:
            st.success("¡Listo! Enviaste todas las solicitudes de este proyecto. 🎉")

    st.button("🧹 Empezar una solicitud nueva", on_click=reset_request)

# ---------- pestaña: jurisdicciones ----------

with tab_juris:
    st.caption(
        "Aquí está a quién se le pide y cómo. Los cambios se guardan para todos los que usan "
        "esta app."
    )
    st.dataframe(
        [
            {
                "": ICONS[j["method"]],
                "Jurisdicción": j["name"],
                "Estado": j["state"],
                "Método": core.METHOD_LABELS[j["method"]],
                "Contacto / link": ", ".join(j.get("emails", []))
                if j["method"] == "email"
                else (j.get("form_url") or j.get("notes") or "—"),
            }
            for j in items
        ],
        hide_index=True,
        width="stretch",
    )

    with st.container(border=True, key="card_editor"):
        if ss.edit_target not in by_id:
            ss.edit_target = NEW
        target = st.selectbox(
            "¿Qué quieres hacer?",
            [NEW, *by_id],
            key="edit_target",
            format_func=lambda i: "➕ Agregar una jurisdicción nueva" if i == NEW
            else f"✏️ Editar {by_id[i]['name']}",
        )
        rec = by_id.get(target, {})
        states, methods = list(core.STATE_OPTIONS), list(core.METHOD_LABELS)

        with st.form(f"jform-{target}", border=False):
            c1, c2 = st.columns(2)
            c1.text_input("Nombre", rec.get("name", ""), key=f"f_name_{target}",
                          placeholder="p. ej. Palm Beach County")
            c2.selectbox("Estado", states, index=states.index(rec.get("state", "FL")),
                         key=f"f_state_{target}", format_func=core.STATE_OPTIONS.get)
            st.radio("¿Cómo se piden los records?", methods,
                     index=methods.index(rec.get("method", "email")), key=f"f_method_{target}",
                     format_func=lambda m: f"{ICONS[m]} {core.METHOD_LABELS[m]}", horizontal=True)
            c1, c2 = st.columns(2)
            c1.text_area("Correo(s) — uno por línea", "\n".join(rec.get("emails", [])),
                         key=f"f_emails_{target}", height=100, help="Solo si es por correo.")
            c2.text_input("Link del formulario", rec.get("form_url", ""), key=f"f_url_{target}",
                          placeholder="https://…", help="Solo si es por formulario web.")
            st.text_area("Notas (opcional)", rec.get("notes", ""), key=f"f_notes_{target}",
                         height=70)
            with st.expander("Formulario o PDF adicional (opcional)"):
                st.text_area("Instrucciones", rec.get("form_note", ""),
                             key=f"f_formnote_{target}", height=70)
                st.text_area(
                    "Campos — uno por línea, con el formato Etiqueta: Valor",
                    "\n".join(f"{f['label']}: {f['value']}" for f in rec.get("form_fields", [])),
                    key=f"f_fields_{target}",
                    height=150,
                    help="Puedes usar [STREETS], [LIMITS], [JURISDICTION] y [DRAFT] "
                    "(el texto completo).",
                )
            st.form_submit_button("💾 Guardar", type="primary", on_click=save_jurisdiction,
                                  args=(target,))

        if target != NEW:
            confirm = st.checkbox(f"Quiero eliminar “{rec['name']}”", key=f"del_confirm_{target}")
            st.button("🗑️ Eliminar", disabled=not confirm, on_click=delete_jurisdiction,
                      args=(target,))

# ---------- pestaña: plantilla ----------

with tab_tpl:
    st.caption(
        "Este es el texto base de todas las solicitudes. Las marcas entre corchetes se "
        "reemplazan solas:"
    )
    st.markdown(
        "- **[STREETS]** → las calles del paso 1, unidas con “&”\n"
        "- **[LIMITS]** → los dos límites, unidos con “and”\n"
        "- **[JURISDICTION]** → el nombre de cada jurisdicción elegida"
    )
    st.text_area("Texto base", key="template", height=300, label_visibility="collapsed")
    c1, c2 = st.columns(2)
    c1.button("↩️ Restaurar texto original", on_click=reset_template, width="stretch")
    c2.button("💾 Guardar como predeterminada", on_click=save_template, type="primary",
              width="stretch")

# ---------- pestaña: feedback ----------

with tab_fb:
    st.caption(
        "¿Una idea, algo que no funciona o una jurisdicción que falta? Escríbelo aquí: "
        "todo queda guardado para la próxima versión."
    )
    with st.container(border=True, key="card_feedback"):
        with st.form("feedback", clear_on_submit=True, border=False):
            c1, c2 = st.columns([1, 2])
            c1.text_input("Tu nombre (opcional)", key="fb_name")
            c2.radio("Tipo", core.FEEDBACK_TYPES, key="fb_kind", horizontal=True)
            st.text_area(
                "Cuéntanos",
                key="fb_msg",
                height=120,
                placeholder="p. ej. Sería útil que el asunto incluya el número de proyecto…",
            )
            st.form_submit_button("📨 Enviar comentario", type="primary", on_click=send_feedback)

    feedback = core.load_feedback()
    if feedback:
        st.markdown(f"**Comentarios recibidos ({len(feedback)})**")
        st.dataframe(feedback[::-1], hide_index=True, width="stretch")
