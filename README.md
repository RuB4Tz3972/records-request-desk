# Records Request Desk

Asistente paso a paso para pedir *utility records* a cada jurisdicción.
El servidor y toda la lógica están en Python (Flask); la interfaz es una página web propia.

## Abrir la app

Doble clic en el ícono **Records Request Desk** del escritorio. Se abre en su propia ventana, sin
comandos ni consola. Si la app no estaba encendida, aparece una pantalla de carga mientras arranca.

¿No tienes el ícono? Doble clic en **`Crear acceso directo.bat`** (en esta carpeta) y elige:

- **1 · Esta PC tiene la app**: para la PC principal de la oficina (o tu PC para pruebas).
  Te pregunta si quieres que la app se encienda sola al prender la PC.
- **2 · Me conecto a la app de la oficina**: para los compañeros. No instalan nada; el ícono abre la
  app que corre en la PC principal. La dirección se llena sola desde `data/servidor.txt`.

## Cómo se usa

**Nueva solicitud**

1. **Tramo**: escribe cada calle (*along*) y presiona Enter; luego los dos límites (*between*).
   Opcional: pega la captura del mapa con **Ctrl+V** (por ejemplo después de Win+Shift+S).
   A la derecha ves la carta en vivo: lo resaltado se llena solo.
2. **Jurisdicciones**: toca las tarjetas de una o varias. ✉ correo · 🌐 formulario web · ⏳ por definir.
3. **Enviar**: cada jurisdicción tiene su tarjeta con los pasos, el borrador **.eml** para Outlook
   (con el mapa incrustado), el botón al formulario y botones de copiar. Márcala como enviada al terminar.

**Jurisdicciones**: agrega o edita contactos en el panel lateral. **Plantilla**: cambia el texto base.
**Feedback**: el equipo deja ideas y errores; todo queda en `data/feedback.csv` (se abre en Excel).

## Instalar en la PC principal (una sola vez)

1. Copia esta carpeta a Dropbox, por ejemplo `Dropbox\Herramientas\RecordsRequestDesk`.
   No hace falta copiar `.venv` ni `_version_streamlit`.
2. Instala `uv` (PowerShell):

   ```bash
   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
   ```

3. Doble clic en `Crear acceso directo.bat` → opción **1** → responde **S** para que se encienda sola.
4. Abre el ícono. La primera vez tarda unos minutos (descarga Python y las librerías).
   Si Windows pregunta por el firewall, permite **Redes privadas**.

Los compañeros solo hacen: doble clic en `Crear acceso directo.bat` (desde Dropbox) → opción **2**.

## Si algo falla

- Abre `iniciar.bat`: arranca la app en una ventana de consola donde se ven los mensajes.
- Los registros del ícono están en `%LOCALAPPDATA%\RecordsRequestDesk\server-errores.log`.
- Al cambiar el código, cierra la app (Administrador de tareas → `python`) y vuelve a abrir el ícono.

## Archivos

| Archivo | Qué contiene |
|---|---|
| `server.py` | Servidor (Flask + Waitress) y la API que usa la interfaz |
| `records_core.py` | Plantilla, armado de cada solicitud, `.eml`, jurisdicciones y feedback |
| `web/` | Interfaz: `index.html`, `app.css` (colores en `:root`), `app.js` |
| `launcher/` | Ícono, pantalla de carga e instalador del acceso directo |
| `data/` | Jurisdicciones, plantilla, feedback y la dirección del servidor (compartidos por Dropbox) |
| `docs/` | Manual de usuario en Word para el equipo |
| `map_reader.py` | Lectura de mapas con Claude — en pausa, requiere clave de API |
| `_version_streamlit/` | La versión anterior en Streamlit, solo como referencia |
