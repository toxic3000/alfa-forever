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

## Desde la 1.4.1

- `raton.lua` (se carga en todas las escenas): el **barrido del ratón**. `RATON_BARRIDO(momento)` lista los marcos de Alfa a la vista que toman el clic, el paso del ratón o la rueda sin dibujar nada (paredes invisibles) y recorre la pantalla punto por punto; `RATON_ARRIBA(x, y, que)` dice quién se queda con el ratón en un punto; `RATON_ADELANTAR(seg)` hace correr el tiempo (reloj del juego y OnUpdate) para que las animaciones terminen como en el juego.
- `mock.lua` imita al juego en lo que nos mordió en la 1.4.0: poner o enganchar `OnMouseDown`/`OnMouseUp`/`OnEnter`/`OnLeave`/`OnMouseWheel` prende el ratón del marco; un botón, deslizador, casilla o cuadro de texto nace tomándolo; `GetEffectiveAlpha` multiplica el de los padres; cada marco sabe de qué archivo salió (`_origen`).
- `comun.lua`: `PRUEBA_ENTRAR`, `PASO`, `REVISA`, `TIEMPO`, `RATON_LIMPIO`, `PRUEBA_FIN`. Una prueba nueva parte de `plantilla_prueba.lua` (`tools/nueva_version.py` la copia) y termina con `RATON_LIMPIO`.
- `prueba_141_raton.lua`: el barrido en 15 momentos de una sesión con ventanas del juego simuladas debajo (profesiones, Opciones > Audio, el chat). `prueba_botones.lua` y `prueba_140_dia.lua` terminan con el mismo barrido.
