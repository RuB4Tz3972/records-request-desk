"""Lógica sin interfaz: jurisdicciones, plantilla del draft y borrador de correo (.eml)."""

from __future__ import annotations

import csv
import difflib
import json
import re
from datetime import datetime
from email import policy
from email.message import EmailMessage
from email.utils import make_msgid
from html import escape
from io import BytesIO
from pathlib import Path
from urllib.parse import quote

DATA_DIR = Path(__file__).parent / "data"
JURISDICTIONS_FILE = DATA_DIR / "jurisdictions.json"
SETTINGS_FILE = DATA_DIR / "settings.json"
FEEDBACK_FILE = DATA_DIR / "feedback.csv"
FEEDBACK_TYPES = ["💡 Idea o mejora", "🐞 Algo no funciona", "🏛️ Falta una jurisdicción"]

DEFAULT_TEMPLATE = (
    "Good afternoon,\n\n"
    "Hope you're well.\n\n"
    "We are designing a project to install fiber optic cable along [STREETS], "
    "between [LIMITS] (see picture below).\n\n"
    "We would like to confirm if there are utility records, GIS maps, and As-built "
    "records of [JURISDICTION] within the limits of our project.\n\n"
    "We will really appreciate your help with this information.\n\n"
    "Thanks in advance,"
)

TOKENS = ("[STREETS]", "[LIMITS]", "[JURISDICTION]")

METHOD_LABELS = {"email": "Correo", "form": "Formulario / portal", "pending": "Pendiente"}
STATE_OPTIONS = {"FL": "Florida", "GA": "Georgia", "Federal/State": "Estatal / Federal (FDOT, GDOT…)"}


# ---------- persistencia (JSON local) ----------

def _read_json(path: Path, default):
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (FileNotFoundError, json.JSONDecodeError):
        return default


def _write_json(path: Path, data) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")


def load_jurisdictions() -> list[dict]:
    items = _read_json(JURISDICTIONS_FILE, [])
    return sorted(items, key=lambda j: (j.get("order", 999), j["name"].lower()))


def save_jurisdiction(record: dict) -> None:
    items = [j for j in load_jurisdictions() if j["id"] != record["id"]]
    items.append(record)
    _write_json(JURISDICTIONS_FILE, items)


def delete_jurisdiction(jid: str) -> None:
    _write_json(JURISDICTIONS_FILE, [j for j in load_jurisdictions() if j["id"] != jid])


def load_template() -> str:
    return _read_json(SETTINGS_FILE, {}).get("draft_template") or DEFAULT_TEMPLATE


def save_template(text: str) -> None:
    settings = _read_json(SETTINGS_FILE, {})
    settings["draft_template"] = text
    _write_json(SETTINGS_FILE, settings)


def add_feedback(name: str, kind: str, message: str) -> None:
    """Agrega un comentario al CSV (utf-8-sig para que Excel lea bien los acentos)."""
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    is_new = not FEEDBACK_FILE.exists()
    with FEEDBACK_FILE.open("a", newline="", encoding="utf-8-sig") as f:
        writer = csv.writer(f)
        if is_new:
            writer.writerow(["Fecha", "Nombre", "Tipo", "Comentario"])
        writer.writerow([datetime.now().strftime("%Y-%m-%d %H:%M"), name or "Anónimo", kind, message])


def load_feedback() -> list[dict]:
    try:
        with FEEDBACK_FILE.open(newline="", encoding="utf-8-sig") as f:
            return list(csv.DictReader(f))
    except FileNotFoundError:
        return []


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "jurisdiccion"


def new_id(name: str, items: list[dict]) -> str:
    taken = {j["id"] for j in items}
    jid, n = slugify(name), 2
    while jid in taken:
        jid, n = f"{slugify(name)}-{n}", n + 1
    return jid


def find_jurisdiction(items: list[dict], name: str) -> dict | None:
    """Empareja el nombre sugerido por la IA con una jurisdicción guardada."""
    if not name:
        return None
    key = name.strip().lower()
    for j in items:
        if key in (j["name"].lower(), j["id"]):
            return j
    names = [j["name"].lower() for j in items]
    match = difflib.get_close_matches(key, names, n=1, cutoff=0.8)
    return next((j for j in items if j["name"].lower() == match[0]), None) if match else None


# ---------- texto ----------

def join_streets(streets: list[str]) -> str:
    """'NW 10th Ave & NW 21st Terrace & NW 21st St'"""
    return " & ".join(s.strip() for s in streets if s.strip())


def join_limits(limits: list[str]) -> str:
    """'NW 22nd St and NW 18th St'"""
    limits = [s.strip() for s in limits if s.strip()]
    if len(limits) <= 2:
        return " and ".join(limits)
    return ", ".join(limits[:-1]) + " and " + limits[-1]


def fill(text: str, streets: str, limits: str, jurisdiction: str, draft: str = "") -> str:
    """Reemplaza los tokens; los vacíos se dejan visibles para que se note qué falta."""
    if draft:
        text = text.replace("[DRAFT]", draft)
    for token, value in zip(TOKENS, (streets, limits, jurisdiction)):
        if value.strip():
            text = text.replace(token, value.strip())
    return text


def missing_tokens(template: str) -> list[str]:
    return [t for t in TOKENS if t not in template]


def email_subject(jurisdiction: str) -> str:
    return f"Utility Records Request – {jurisdiction}"


def build_request(j: dict, template: str, streets: str, limits: str) -> dict:
    """Todo lo que la interfaz necesita para enviar la solicitud a una jurisdicción."""
    body = fill(template, streets, limits, j["name"])
    subject = email_subject(j["name"])
    to = j.get("emails", [])
    return {
        "id": j["id"],
        "name": j["name"],
        "state": j["state"],
        "method": j["method"],
        "to": to,
        "subject": subject,
        "body": body,
        "mailto": f"mailto:{','.join(to)}?subject={quote(subject)}&body={quote(body)}",
        "form_url": j.get("form_url", ""),
        "notes": j.get("notes", ""),
        "form_note": j.get("form_note", ""),
        "form_fields": [
            {"label": f["label"], "value": fill(f["value"], streets, limits, j["name"], draft=body)}
            for f in j.get("form_fields", [])
        ],
        "missing": [t for t in TOKENS if t in body],
    }


def safe_filename(text: str, limit: int = 80) -> str:
    return re.sub(r'[<>:"/\\|?*\n\r\t]+', " ", text).strip()[:limit].strip() or "records-request"


def build_eml(
    to: list[str],
    subject: str,
    body: str,
    image: bytes | None = None,
    image_name: str = "map.png",
    image_type: str = "image/png",
) -> bytes:
    """Borrador .eml que Outlook abre listo para enviar: destinatario, asunto, texto y mapa.

    Se arma como lo hace el propio Outlook: un solo cuerpo HTML y la imagen *dentro* del
    mensaje (multipart/related, disposición inline). Con texto plano + HTML alternativos, o
    con la imagen marcada como adjunto, Outlook clásico muestra el adjunto y pierde el texto.
    """
    msg = EmailMessage()
    msg["To"] = ", ".join(to)
    msg["Subject"] = subject
    msg["X-Unsent"] = "1"  # Outlook lo abre como borrador editable, no como correo recibido

    cid = make_msgid(domain="records.local") if image else None
    paragraphs = "".join(f"<p>{escape(p).replace(chr(10), '<br>')}</p>" for p in body.split("\n\n"))
    picture = ""
    if image:
        width = min(_image_width(image), 720)
        picture = (
            f'<p><img src="cid:{cid[1:-1]}" alt="Project map" width="{width}" '
            f'style="width:{width}px;max-width:100%"></p>'
        )
    html = (
        '<html><head><meta charset="utf-8"></head><body>'
        f'<div style="font-family:Calibri,Arial,sans-serif;font-size:11pt">{paragraphs}{picture}</div>'
        "</body></html>"
    )
    # base64 y no quoted-printable: Outlook mostraba los "=" de corte de línea dentro del texto.
    msg.set_content(html, subtype="html", cte="base64")

    if image:
        maintype, subtype = image_type.split("/", 1)
        msg.add_related(
            image, maintype=maintype, subtype=subtype, cid=cid, disposition="inline", filename=image_name
        )
        msg.set_param("type", "text/html")  # parámetro que pide el estándar de multipart/related
    return msg.as_bytes(policy=policy.SMTP)  # saltos de línea CRLF, como espera Outlook en Windows


def _image_width(image: bytes) -> int:
    try:
        from PIL import Image

        with Image.open(BytesIO(image)) as img:
            return img.width
    except Exception:
        return 720
