# Banco de pruebas de la interfaz

Carga el motor de Alfa de verdad (Lua 5.1 con lupa) sobre un cliente simulado que calcula anclas y tamaños, y recorre ventanas para encontrar errores sin abrir el juego. También dibuja maquetas PNG del acomodo real (con rellenos en lugar del arte y los íconos del juego).

Se usó para el selector de guías, el buscador y el diario de mazmorras.

```bash
python -I tools/build.py
.venv/Scripts/python -I tools/banco/run.py dist Alfa,Alfa_Guides,Alfa_Codex,Alfa_Nucleo,Alfa_Rutas,Alfa_Mazmorras tools/banco/shots.lua
```

- `mock.lua` y `api.lua`: el cliente simulado (marcos, texturas, fuentes y funciones del juego).
- `drive.lua`, `probe.lua`, `selftest.lua`: recorren y revisan las ventanas.
- `shots.lua`, `shots2.lua`: escenas que se dibujan; `render.py` las pasa a PNG.

Es una herramienta de apoyo, no un sustituto del juego: lo que el simulador no imita (API nuevas, valores secretos reales, contaminación) se verifica en el juego.
