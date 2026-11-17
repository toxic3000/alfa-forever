# Instalador de Alfa

`Instalar-Alfa.exe` es un asistente de 4 pasos para instalar o actualizar Alfa sin tocar carpetas a mano:

1. **Bienvenida**: revisa en GitHub cuál es la versión más nueva y si ya la tienes.
2. **Carpeta del juego**: encuentra WoW Forever solo (Battle.net, el registro y los discos). Si no lo encuentra, deja elegir la carpeta.
3. **Instalar**: espera a que WoW esté cerrado, descarga el zip de la última versión publicada, revisa su firma SHA-256 y reemplaza las carpetas de Alfa. Si algo falla, deja todo como estaba. Si Windows no deja escribir, pide permiso de administrador y sigue solo.
4. **Listo**: cómo empezar en el juego y el Discord de La Jauría.

No toca la carpeta WTF (los ajustes) ni los demás addons. Quita las carpetas de Alfa que ya no vengan en la versión nueva, pero solo si su TOC dice que son de Alfa.

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
```
