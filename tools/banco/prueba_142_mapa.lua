-- Prueba de la 1.4.2: limpiar el mapa de la M con un clic.
--
-- Toxic: «algunos íconos del mapa para algunas personas pueden ser muy
-- molestos; que se puedan quitar con un solo clic, en la opción de la M».
--   1. Junto a la lupa del mapa del juego hay un botón que DICE lo que hace:
--      «Limpiar mapa» (antes era un ícono sin texto que nadie veía).
--   2. Un clic esconde los íconos de Alfa que no son esenciales y el botón
--      pasa a «Ver todo»; otro clic los devuelve como estaban.
--   3. El botón cabe en su barra y nada tapa el ratón.
PRUEBA_AREA("1.4.2 mapa")
PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit
local Mu = NS_OF("Alfa_Mundo")
local MJ, Capas = Mu.MapaJuego, Mu.Capas

PASO("«Limpiar mapa» con un clic, y «Ver todo» para volver", function()
  if MJ and MJ.CrearBarra then MJ.CrearBarra() end
  local barra = rawget(_G, "AlfaMundoBotonesMapa")
  REVISA(barra and barra.Limpio, "no está la barra del mapa del juego")
  if not (barra and barra.Limpio) then return end
  local texto = function() return tostring(barra.Limpio.Texto and barra.Limpio.Texto:GetText() or "") end
  REVISA(texto() == "Limpiar mapa", "el botón no dice «Limpiar mapa» (era un ícono mudo): " .. texto())
  local antes = {}
  for _, g in ipairs(Capas.Grupos()) do for _, e in ipairs(g.capas) do antes[e.id] = Capas.Activa(e) end end
  barra.Limpio:Click()
  RUN_TIMERS(1)
  REVISA(Capas.Limpio(), "un clic no limpió el mapa")
  REVISA(Capas.CuantasOcultas() > 0, "el mapa limpio no escondió ningún tipo de ícono")
  REVISA(texto() == "Ver todo", "limpio, el botón no dice «Ver todo»: " .. texto())
  barra.Limpio:Click()
  RUN_TIMERS(1)
  REVISA(not Capas.Limpio() and texto() == "Limpiar mapa", "el segundo clic no devolvió el mapa")
  for _, g in ipairs(Capas.Grupos()) do
    for _, e in ipairs(g.capas) do
      REVISA(Capas.Activa(e) == antes[e.id], "la capa «" .. tostring(e.nombre) .. "» no volvió como estaba")
    end
  end
  -- El botón cabe en su barra.
  local bl, _, bw = barra:GetRect()
  local ll, _, lw = barra.Limpio:GetRect()
  local al, _, aw = barra.Abrir:GetRect()
  REVISA(ll >= bl - 0.5 and al + aw <= bl + bw + 0.5, "los botones se salen de su barra")
end)

PASO("Nada tapa el ratón", function() TIEMPO(3) RATON_LIMPIO("tras limpiar el mapa") end)

PRUEBA_FIN()
