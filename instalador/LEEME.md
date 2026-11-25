# Instalador de Alfa

`Instalar-Alfa.exe` es un asistente de 4 pasos para instalar o actualizar Alfa sin tocar carpetas a mano:

1. **Bienvenida**: revisa en GitHub cuál es la versión más nueva y si ya la tienes.
2. **Carpeta del juego**: encuentra WoW Forever solo (Battle.net, el registro y los discos). Si no lo encuentra, deja elegir la carpeta.
3. **Instalar**: espera a que WoW esté cerrado, descarga el zip de la última versión publicada, revisa su firma SHA-256 y reemplaza las carpetas de Alfa. Si algo falla, deja todo como estaba. Si Windows no deja escribir, pide permiso de administrador y sigue solo.
4. **Listo**: cómo empezar en el juego y el Discord de La Jauría.

No toca los ajustes ni los demás addons. Quita las carpetas de Alfa que ya no vengan en la versión nueva, pero solo si su TOC dice que son de Alfa. En WTF solo cambia una cosa: la palabra `enviado` de los reportes del buzón que ya mandó (ver **Buzón**).

Como siempre baja la última versión publicada, el mismo `.exe` sirve para actualizar.

## Enlace para compartir

**https://github.com/toxic3000/alfa-forever/releases/latest/download/Instalar-Alfa.exe**

Este enlace siempre apunta a la última versión publicada. Para que no se rompa, **cada versión publicada en GitHub debe llevar el `Alfa-<versión>.zip` y el `Instalar-Alfa.exe`** (ver `docs/VERSIONES.md`).

Windows puede mostrar "Windows protegió tu PC" porque el `.exe` no está firmado. Hay que dar clic en **Más información** y luego en **Ejecutar de todas formas**.

## Construir y probar

```bash
python -I instalador/construir.py                          # paquetes/Instalar-Alfa.exe (PyInstaller + Pillow)
python -I instalador/instalador.py                         # la ventana sin empaquetar
python -I instalador/instalador.py --sin-ventana --carpeta "D:\Prueba\_forever_" [--zip paquetes/Alfa-X.zip]
python -I instalador/instalador.py --capturas CARPETA      # fotos de cada pantalla para revisar el diseño
python -I instalador/instalador.py --solo-buzon            # solo manda los reportes pendientes (no instala)
python -I instalador/instalador.py --sin-buzon             # la ventana sin mandar reportes
python -I instalador/prueba_buzon.py                       # prueba del buzón (WTF falso; formulario y Discord falsos locales)
```

## Buzón: los reportes del juego le llegan solos a Toxic

El juego no deja que un addon mande nada a internet, así que Alfa guarda cada reporte que escribe el jugador en sus variables guardadas: `AlfaNucleoDB.buzon.pendientes` dentro de `WTF/Account/<cuenta>/SavedVariables/Alfa_Nucleo.lua` (lista con `id`, `fecha`, `version`, `tipo`, `texto` y `enviado`).

Cada vez que se abre el instalador (y otra vez al terminar de instalar, si al abrirlo el juego estaba abierto):

1. Si **WoW está abierto, no hace nada** (el juego reescribe ese archivo al salir y se perdería la marca).
2. Busca en todas las cuentas de `WTF/Account/` los reportes con `enviado = false`.
3. Los manda al **formulario de Google de Toxic** (camino principal; las respuestas le llegan a su correo): `POST` a `.../formResponse` con el tipo (`Error`, `Mejora` o `Comentario`), el texto y la versión de Alfa. Desde la 1.4.0 el formulario ya no tiene la pregunta «Datos técnicos»: el texto lleva lo que escribió el jugador y, al final, tras la línea `— Datos de Alfa —`, `Código: <id>` del reporte, lo técnico y la fecha (todo en 1950 letras como mucho; nunca nombre ni reino). El texto que arma el addon (`**[Alfa] Tipo**`, lo del jugador y un bloque ``` con lo técnico) se separa solo; si no tiene esa forma, todo va a lo técnico. La URL y los 3 `entry.*` están en un solo lugar: `BUZON_FORMULARIO` en `instalador.py`. No es secreto: un formulario público.
4. **Extra opcional:** si el `.exe` trae webhook de Discord (`buzon_local.json`, abajo), también lo manda a #buzon-alfa como un recuadro, sin menciones (un `@everyone` dentro de un reporte no suena). Si Discord falla, no importa: lo que cuenta es el formulario.
5. Máximo **5 reportes por apertura**, cada texto recortado a **1950 letras**, 1,2 s entre envíos y, si piden esperar (429), espera lo que piden.
6. Los marca `enviado = true` en el archivo: hace una copia (`Alfa_Nucleo.lua.antes-del-buzon`), cambia solo la palabra `false` → `true` de esos reportes, vuelve a leer el resultado y comprueba que todo lo demás quedó idéntico. Si algo no cuadra (archivo dañado o que no se entiende, que cambió mientras mandaba, sin permiso), **no toca el archivo**.
7. En la ventana sale una línea: «Envié 2 reportes a Toxic. ¡Gracias por ayudar a la manada!».

Si no hay internet o el formulario falla, no pasa nada: se intenta la próxima vez. Para no repetir un reporte que se mandó pero no se pudo marcar, el instalador anota lo enviado en `%LOCALAPPDATA%\AlfaInstalador\buzon_enviados.json`.

Si un día Toxic cambia el formulario (otro formulario o preguntas nuevas): en el formulario, ⋮ > **Obtener enlace prellenado**, llena cada pregunta, copia el enlace y saca de ahí los `entry.<número>` de cada una; ponlos en `BUZON_FORMULARIO` (y la URL, cambiando `viewform` por `formResponse`). La pregunta del tipo debe tener exactamente las opciones `Error`, `Mejora` y `Comentario`.

### Discord (opcional): crear y guardar el webhook (solo Toxic)

1. En Discord: **#buzon-alfa** > ⚙️ **Editar canal** > **Integraciones** > **Webhooks** > **Nuevo webhook**. Ponle de nombre «Buzón de Alfa» y, si quieres, el logo de Alfa.
2. **Copiar URL del webhook**.
3. Crea el archivo `instalador/buzon_local.json` con esto (pegando tu URL):
   ```json
   {"webhook": "https://discord.com/api/webhooks/123.../abc..."}
   ```
4. `python -I instalador/construir.py`: debe decir «Buzón: el webhook de #buzon-alfa va dentro del .exe». Sin el archivo el `.exe` sale igual y solo manda al formulario.
5. Para probarlo antes de publicar: escribe un reporte en el juego, cierra WoW y corre `python -I instalador/instalador.py --solo-buzon` (sin empaquetar lee `buzon_local.json` directo).

`buzon_local.json` está en `.gitignore`: **nunca se sube a git**.

### El riesgo de cada camino (léelo)

- **Formulario:** su URL es pública; cualquiera puede mandarle respuestas falsas. Si llega spam, en el formulario se puede pedir iniciar sesión, cerrar las respuestas o hacer otro formulario y cambiar `BUZON_FORMULARIO`.
- **Webhook de Discord:** la URL va dentro de `Instalar-Alfa.exe`, que es público. Va disfrazada para que no se lea a simple vista, pero **no es una protección de verdad**: alguien con ganas puede sacarla del programa y usarla para mandar mensajes (spam) al canal. Un webhook solo puede escribir en #buzon-alfa; no puede leer el canal, ni tocar otros canales, ni el servidor. Si llega spam: **#buzon-alfa > Editar canal > Integraciones > Webhooks**, borra ese webhook y crea otro; pon la URL nueva en `buzon_local.json` y vuelve a construir y publicar el instalador. No hay que tocar el código.

## Marcador por bando (1.4.0)

Con el juego cerrado, después del buzón, el instalador junta lo que cada cuenta de la PC sabe de La Jauría (lo que contó en vivo de su bando y los lobos que oyó el censo, de los últimos 30 días) y deja en cada `Alfa_Nucleo.lua` el último número de cada bando en `AlfaNucleoDB.jauria.bandos[H|A]` con `fuente = "instalador"`, para que el marcador del juego enseñe también el otro lado. No manda nada a internet; copia de respaldo `.antes-del-marcador`. Prueba: `python -I instalador/prueba_marcador.py`.
