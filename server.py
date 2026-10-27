"""Records Request Desk — servidor web (Flask + Waitress).

Ejecutar:  uv run python server.py   (o con el acceso directo del escritorio)
"""

from __future__ import annotations

import json
import os
import socket
import threading
from pathlib import Path
from urllib.parse import quote

from flask import Flask, Response, request

import records_core as core

PORT = int(os.environ.get("RECORDS_PORT", "8501"))
WEB_DIR = Path(__file__).parent / "web"

app = Flask(__name__, static_folder=str(WEB_DIR), static_url_path="")
app.config["SEND_FILE_MAX_AGE_DEFAULT"] = 0  # así el equipo ve los cambios al recargar
write_lock = threading.Lock()


def error(message: str, status: int = 400):
    return {"error": message}, status


@app.get("/")
def index():
    return app.send_static_file("index.html")


@app.get("/api/health")
def health():
    return {"ok": True}


@app.get("/api/bootstrap")
def bootstrap():
    return {
        "jurisdictions": core.load_jurisdictions(),
        "template": core.load_template(),
        "default_template": core.DEFAULT_TEMPLATE,
        "subject_format": core.email_subject("{name}"),
        "states": core.STATE_OPTIONS,
        "methods": core.METHOD_LABELS,
        "feedback_types": core.FEEDBACK_TYPES,
        "feedback_count": len(core.load_feedback()),
    }


# ---------- jurisdicciones ----------

@app.post("/api/jurisdictions")
def save_jurisdiction():
    data = request.get_json(silent=True) or {}
    name = str(data.get("name", "")).strip()
    if not name:
        return error("Escribe el nombre de la jurisdicción.")
    if data.get("method") not in core.METHOD_LABELS or data.get("state") not in core.STATE_OPTIONS:
        return error("Elige el estado y el método de solicitud.")

    with write_lock:
        items = core.load_jurisdictions()
        current = next((j for j in items if j["id"] == data.get("id")), None)
        record = {
            "id": current["id"] if current else core.new_id(name, items),
            "name": name,
            "state": data["state"],
            "method": data["method"],
            "emails": [str(e).strip() for e in data.get("emails", []) if str(e).strip()],
            "form_url": str(data.get("form_url", "")).strip(),
            "notes": str(data.get("notes", "")).strip(),
            "form_note": str(data.get("form_note", "")).strip(),
            "form_fields": [
                {"label": str(f.get("label", "")).strip(), "value": str(f.get("value", "")).strip()}
                for f in data.get("form_fields", [])
                if str(f.get("label", "")).strip()
            ],
            "order": current.get("order", 0) if current
            else max((j.get("order", 0) for j in items), default=0) + 1,
        }
        core.save_jurisdiction(record)
    return {"jurisdiction": record, "jurisdictions": core.load_jurisdictions()}


@app.delete("/api/jurisdictions/<jid>")
def delete_jurisdiction(jid: str):
    with write_lock:
        core.delete_jurisdiction(jid)
    return {"jurisdictions": core.load_jurisdictions()}


# ---------- plantilla ----------

@app.put("/api/template")
def save_template():
    text = str((request.get_json(silent=True) or {}).get("template", ""))
    missing = core.missing_tokens(text)
    if missing:
        return error(f"Falta {', '.join(missing)} en el texto. Sin eso no se puede llenar solo.")
    with write_lock:
        core.save_template(text)
    return {"template": text}


# ---------- solicitudes ----------

def _request_args(data: dict) -> tuple[str, str]:
    streets = core.join_streets([str(s) for s in data.get("streets", [])])
    limits = core.join_limits([str(s) for s in data.get("limits", [])])
    return streets, limits


@app.post("/api/requests")
def build_requests():
    data = request.get_json(silent=True) or {}
    streets, limits = _request_args(data)
    template = core.load_template()
    by_id = {j["id"]: j for j in core.load_jurisdictions()}
    return {
        "requests": [
            core.build_request(by_id[jid], template, streets, limits)
            for jid in data.get("ids", [])
            if jid in by_id
        ]
    }


@app.post("/api/eml")
def download_eml():
    data = json.loads(request.form.get("payload", "{}"))
    j = next((j for j in core.load_jurisdictions() if j["id"] == data.get("id")), None)
    if not j:
        return error("Esa jurisdicción ya no existe.", 404)
    streets, limits = _request_args(data)
    req = core.build_request(j, core.load_template(), streets, limits)

    image = request.files.get("map")
    eml = core.build_eml(
        req["to"],
        req["subject"],
        req["body"],
        image.read() if image else None,
        image.filename if image else "map.png",
        image.mimetype if image else "image/png",
    )
    filename = core.safe_filename(f"{req['subject']} - {streets}") + ".eml"
    return Response(
        eml,
        mimetype="message/rfc822",
        headers={
            "Content-Disposition": f"attachment; filename*=UTF-8''{quote(filename)}",
            "X-Filename": quote(filename),
        },
    )


# ---------- feedback ----------

@app.get("/api/feedback")
def list_feedback():
    return {"feedback": core.load_feedback()[::-1]}


@app.post("/api/feedback")
def add_feedback():
    data = request.get_json(silent=True) or {}
    message = str(data.get("message", "")).strip()
    if not message:
        return error("Escribe tu comentario antes de enviarlo.")
    kind = data.get("kind") if data.get("kind") in core.FEEDBACK_TYPES else core.FEEDBACK_TYPES[0]
    with write_lock:
        core.add_feedback(str(data.get("name", "")).strip(), kind, message)
    return {"feedback": core.load_feedback()[::-1]}


if __name__ == "__main__":
    from waitress import serve

    team_url = f"http://{socket.gethostname()}:{PORT}"
    # Lo lee el instalador de accesos directos de los compañeros (carpeta compartida en Dropbox).
    (core.DATA_DIR / "servidor.txt").write_text(team_url + "\n", encoding="utf-8")
    print("Records Request Desk está listo.")
    print(f"  En esta PC:      http://localhost:{PORT}")
    print(f"  Para el equipo:  {team_url}")
    serve(app, host="0.0.0.0", port=PORT, threads=8)
