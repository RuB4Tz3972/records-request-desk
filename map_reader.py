"""Lee una captura de mapa con Claude y devuelve las calles (along/between) y la jurisdicción.

En pausa: app.py no lo usa por ahora (requiere una clave de API de Anthropic).
"""

from __future__ import annotations

import base64
import io

import anthropic
from PIL import Image
from pydantic import BaseModel, Field

MODEL = "claude-opus-5-5"
EFFORT = "high"  # leer etiquetas pequeñas del mapa con cuidado vale la pena

# Límites de la API para imágenes: ~5 MB y 8000 px por lado.
MAX_BYTES = 4_500_000
MAX_SIDE = 7_900
SUPPORTED_TYPES = {"image/png", "image/jpeg", "image/webp", "image/gif"}


class MapReading(BaseModel):
    along: list[str] = Field(description="Project streets, in route order")
    between: list[str] = Field(description="Limit streets that bound the project segment")
    jurisdiction: str = Field(description="Agency whose records cover the project area")
    also_consider: list[str] = Field(description="Other agencies that may own facilities there")
    notes: str = Field(description="Short note in Spanish about anything uncertain, or empty")


PROMPT = """This is a screenshot of a map (usually Google Maps) prepared for a utility-records \
request for a fiber-optic project in Florida or Georgia.

Color convention on these maps:
- Project streets: a thick BLUE line that is also underlined/highlighted in GREEN. The fiber is \
installed along these streets. There can be more than one.
- Limit streets: highlighted ONLY in GREEN (no blue line). They bound the project segment \
("between A and B").
If the map uses different highlighting, apply the same idea: the emphasized route gives `along`, \
the cross streets marking its ends give `between`.

Fill the fields:
1. `along`: exact name of every project street, in the order the route follows them. Write them \
the way US engineering letters do, with the map's abbreviations (e.g. "NW 10th Ave", \
"NW 21st Terrace", "SW 8th St").
2. `between`: the limit streets, usually two. For a north-south route list them north to south; \
for an east-west route, west to east.
3. `jurisdiction`: the agency whose records cover the project area. Known jurisdictions: \
{known}. If one of them applies, return its name exactly as written there. Otherwise return the \
most likely city or county (e.g. "City of Hialeah"). Use map labels (city names, neighborhoods, \
ZIP codes, route shields) and your knowledge of the area. Prefer the city over the county when \
the project is inside city limits.
4. `also_consider`: other agencies that may also own facilities there (e.g. the county, or FDOT \
when a state road is involved). Empty list if none.
5. `notes`: one short sentence in Spanish about anything uncertain (an illegible label, ambiguous \
colors). Empty string if nothing.

If a label is hard to read, give your best reading and mention it in `notes`."""


class MapReadError(Exception):
    """Error con un mensaje listo para mostrar al usuario."""


def _prepare_image(data: bytes, media_type: str) -> tuple[bytes, str]:
    """Reduce la imagen solo si supera los límites de la API."""
    if media_type in SUPPORTED_TYPES and len(data) <= MAX_BYTES:
        with Image.open(io.BytesIO(data)) as img:
            if max(img.size) <= MAX_SIDE:
                return data, media_type

    with Image.open(io.BytesIO(data)) as img:
        img = img.convert("RGB")
        side = min(MAX_SIDE, max(img.size))
        while True:
            copy = img.copy()
            copy.thumbnail((side, side))
            buf = io.BytesIO()
            copy.save(buf, format="JPEG", quality=88)
            if buf.tell() <= MAX_BYTES:
                return buf.getvalue(), "image/jpeg"
            side = int(side * 0.8)


def read_map(
    image: bytes,
    media_type: str,
    known_jurisdictions: list[str],
    api_key: str | None = None,
) -> MapReading:
    data, media_type = _prepare_image(image, media_type)
    known = ", ".join(f'"{name}"' for name in known_jurisdictions) or "(none saved yet)"

    try:
        client = anthropic.Anthropic(api_key=api_key) if api_key else anthropic.Anthropic()
        response = client.beta.messages.parse(
            model=MODEL,
            max_tokens=16000,
            output_config={"effort": EFFORT},
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            output_format=MapReading,
            messages=[{
                "role": "user",
                "content": [
                    {
                        "type": "image",
                        "source": {
                            "type": "base64",
                            "media_type": media_type,
                            "data": base64.standard_b64encode(data).decode("ascii"),
                        },
                    },
                    {"type": "text", "text": PROMPT.format(known=known)},
                ],
            }],
        )
    except anthropic.AuthenticationError:
        raise MapReadError("La clave de API no es válida.")
    except anthropic.PermissionDeniedError:
        raise MapReadError("La clave de API no tiene permiso para usar este modelo.")
    except anthropic.RateLimitError:
        raise MapReadError("Límite de uso alcanzado. Espera un momento y vuelve a intentar.")
    except anthropic.BadRequestError as e:
        raise MapReadError(f"La API rechazó la solicitud: {e.message}")
    except anthropic.APIStatusError as e:
        raise MapReadError(f"Error del servicio ({e.status_code}). Intenta de nuevo en un rato.")
    except anthropic.APIConnectionError:
        raise MapReadError("No hay conexión con la API. Revisa tu internet.")
    except TypeError:
        # El SDK lanza TypeError cuando no encuentra ninguna credencial.
        raise MapReadError("No hay clave de API configurada (ver barra lateral).")

    if response.stop_reason == "refusal":
        raise MapReadError("El modelo no procesó esta imagen. Prueba con otra captura.")
    if response.parsed_output is None:
        raise MapReadError("No se pudo interpretar la respuesta. Intenta de nuevo.")
    return response.parsed_output
