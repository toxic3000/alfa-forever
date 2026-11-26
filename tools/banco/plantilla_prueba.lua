-- Prueba de la {VERSION}: {TEMA}.
--
-- Qué reportó el jugador (con sus palabras) y qué se revisa aquí. Un error del
-- juego real va primero aquí (que falle con el código de antes) y luego se
-- arregla: así nunca vuelve. Ayudantes: tools/banco/comun.lua.
PRUEBA_AREA("{VERSION} {TEMA}")
PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit

PASO("lo que hace el jugador", function()
  -- Haz lo que hizo el jugador (abrir, clicar, pelear, pescar, cambiar de zona)...
  TIEMPO(1)
  -- ...y revisa lo que debía pasar.
  REVISA(true, "lo que salió mal, dicho como lo vería el jugador")
end)

-- Siempre al final: nada de Alfa se queda tapando el ratón.
PASO("el ratón sigue siendo del jugador", function() TIEMPO(5) RATON_LIMPIO("al final") end)

PRUEBA_FIN()
