-- Prueba de la 1.4.1: el elevador con la voz de Alfa.
--
-- Toxic: «vi un mensaje del elevador; sigue siendo el estándar de Polestar.
-- Ya no quiero tener nada que ver con ese addon: modifícalo».
--   1. Un tramo de elevador tiene su tarjeta de Alfa (como el barco, el
--      zepelín y el tranvía): «Elevador hacia arriba», con su dibujo propio.
--   2. Su línea dice «Toma el elevador hacia arriba» (no «Toma el ascensor»).
--   3. Los textos del motor que se leen al viajar en elevador, en español,
--      dicen «elevador» con la voz de Alfa.
--   4. Cada transporte de la tarjeta tiene su dibujo en el build.
PRUEBA_AREA("1.4.1 viaje")
PRUEBA_ENTRAR()
local A = Alfa

local Arrow = A.Nav and A.Nav.arrow

PASO("El elevador tiene su tarjeta y su línea de Alfa", function()
  REVISA(type(Arrow) == "table" and Arrow.DatosTarjeta and Arrow.TextoViaje, "no encuentro la flecha")
  if not (Arrow and Arrow.DatosTarjeta) then return end
  local sube = { kind = "lift", side = "bottom", lift = 1, to = {} }
  local baja = { kind = "lift", side = "top", lift = 1, to = {} }
  local d = Arrow.DatosTarjeta(sube, "camino", nil, 40)
  REVISA(d ~= nil, "el elevador no tiene tarjeta de Alfa (sale el texto viejo de Polestar)")
  if d then
    REVISA(tostring(d.titulo):find("levador", 1, true) and tostring(d.titulo):find("arriba", 1, true), "la tarjeta no dice «Elevador hacia arriba»: " .. tostring(d.titulo))
    REVISA(tostring(d.sobre):find("levador", 1, true), "la tarjeta no dice «Ve al elevador»: " .. tostring(d.sobre))
  end
  local d2 = Arrow.DatosTarjeta(baja, "camino", nil, 40)
  REVISA(d2 and tostring(d2.titulo):find("abajo", 1, true), "bajando, la tarjeta no dice «hacia abajo»")
  local linea = Arrow.TextoViaje(sube)
  REVISA(type(linea) == "string" and linea:find("elevador", 1, true) and not linea:find("ascensor", 1, true), "la línea del elevador no es la de Alfa: " .. tostring(linea))
  REVISA(Arrow.TARJETA and Arrow.TARJETA.lift and Arrow.TARJETA.lift.icono == "viaje-elevador", "el elevador no tiene su dibujo propio")
end)

PASO("Los textos del motor para el elevador, con la voz de Alfa", function()
  local ruta = (os.getenv("ALFA_DIST") or "dist") .. "/Alfa_esMX/Interface.lua"
  local f = io.open(ruta, "rb")
  REVISA(f, "no encuentro " .. ruta)
  if not f then return end
  local t = f:read("*a") f:close()
  for _, clave in ipairs({ "Ride the elevator up", "Ride the elevator down", "Ride the elevator", "Walk to the lift", "Lift here, leaves in %s" }) do
    -- El último L[clave] es el que manda.
    local ultimo
    for v in t:gmatch('L%["' .. clave:gsub("%%", "%%%%") .. '"%] = "([^"]*)"') do ultimo = v end
    REVISA(ultimo and ultimo:find("elevador", 1, true), "«" .. clave .. "» sigue con el texto de Polestar: " .. tostring(ultimo))
  end
end)

PASO("Cada transporte de la tarjeta tiene su dibujo en el build", function()
  for kind, v in pairs(Arrow and Arrow.TARJETA or {}) do
    local ruta = (os.getenv("ALFA_DIST") or "dist") .. "/Alfa_Nucleo/Media/" .. v.icono .. ".tga"
    local f = io.open(ruta, "rb")
    REVISA(f, kind .. ": falta su dibujo " .. ruta)
    if f then f:close() end
  end
end)

PRUEBA_FIN()
