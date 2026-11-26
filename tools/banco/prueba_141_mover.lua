-- Prueba de la 1.4.1: todo se mueve y nada se empalma.
--
-- Toxic: «este mensaje (Tienes algo por abrir) se empalma con el de muerte y
-- quería moverlo, no me deja; ya te había pedido que cualquier cosa se pueda
-- mover para que cada quien la ajuste a placer».
--   1. Con un cuadro del juego arriba (StaticPopup1: «Liberar espíritu»), la
--      pila de avisos empieza debajo de él; al irse, vuelve a su lugar.
--   2. Arrastrar una tarjeta de aviso (sin Mayús) mueve la pila y lo guarda;
--      en combate no se mueve.
--   3. Arrastrar un anuncio grande (sin Mayús) lo mueve y lo guarda, y el
--      clic que suelta el arrastre no lo cierra.
PRUEBA_AREA("1.4.1 mover")

-- El cuadro del juego de «Liberar espíritu» (arriba al centro, como el juego).
local popup = CreateFrame("Frame", "StaticPopup1", UIParent)
popup:SetSize(320, 110)
popup:SetPoint("TOP", UIParent, "TOP", 0, -135)
popup:SetFrameStrata("DIALOG")
popup:Hide()

PRUEBA_ENTRAR()
local A, N = Alfa, AlfaNucleo
local K = N.Kit

local function solapa(a, b)
  local al, ab, aw, ah = a:GetRect()
  local bl, bb, bw, bh = b:GetRect()
  return al < bl + bw and bl < al + aw and ab < bb + bh and bb < ab + ah
end

PASO("Un aviso no se empalma con «Liberar espíritu»", function()
  K.Aviso({ titulo = "Tienes algo por abrir", texto = "[Almeja gruesa]. Ábrelo de un clic y libera espacio.", duracion = 30, lya = false, importante = "siempre" })
  TIEMPO_CORTO(0.5)
  local a = K.Avisos()[1]
  REVISA(a and a:IsShown(), "no salió el aviso")
  if not a then return end
  popup:Show()
  TIEMPO_CORTO(0.3)
  REVISA(not solapa(a, popup), "el aviso se empalma con el cuadro de «Liberar espíritu»")
  popup:Hide()
  TIEMPO_CORTO(0.3)
  local ancla = rawget(_G, "AlfaAvisosAncla")
  local _, _, _, at = a:GetRect()
  REVISA(math.abs(a:GetTop() - ancla:GetTop()) < 1, "al irse el cuadro del juego, el aviso no volvió a su lugar")
end)

PASO("Arrastrar un aviso lo mueve y lo guarda", function()
  local a = K.Avisos()[1]
  if not a then return end
  local ancla = rawget(_G, "AlfaAvisosAncla")
  REVISA(a:GetScript("OnDragStart") ~= nil, "la tarjeta del aviso no se puede arrastrar (el bug de Toxic)")
  FIRE(a, "OnDragStart", "LeftButton")
  ancla:ClearAllPoints()
  ancla:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 200, 300)
  FIRE(a, "OnDragStop")
  local g = K.MovibleGuardado("avisos")
  REVISA(g ~= nil, "arrastrar el aviso no guardó su lugar")
  local l, b = ancla:GetLeft(), ancla:GetBottom()
  REVISA(l and math.abs(l - 200) < 16 and math.abs(b - 300) < 16, "la pila no quedó donde se soltó: " .. tostring(l) .. ", " .. tostring(b))
  -- En combate, no.
  local real = InCombatLockdown
  InCombatLockdown = function() return true end
  FIRE(a, "OnDragStart", "LeftButton")
  REVISA(not a.alfaArrastrando, "en combate el aviso empezó a moverse")
  InCombatLockdown = real
  K.MovibleVolver("avisos")
end)

PASO("Arrastrar un anuncio lo mueve, lo guarda y no lo cierra", function()
  K.Anuncio({ titulo = "Bosque de Elwynn", texto = "Tierras de los humanos", clave = "probar", segundos = 60 })
  TIEMPO(1)
  local an = rawget(_G, "AlfaAnuncio")
  REVISA(an and an:IsShown(), "no salió el anuncio")
  if not (an and an:IsShown()) then return end
  local t = an.Toque
  REVISA(t:GetScript("OnDragStart") ~= nil, "el anuncio no se puede arrastrar sin Mayús")
  local ancla = rawget(_G, "AlfaAnuncioAncla")
  FIRE(t, "OnDragStart", "LeftButton")
  ancla:ClearAllPoints()
  ancla:SetPoint("CENTER", UIParent, "CENTER", 300, 200)
  FIRE(t, "OnDragStop")
  FIRE(t, "OnClick", "LeftButton")
  REVISA(an:IsShown(), "el clic que suelta el arrastre cerró el anuncio")
  local p = A.Get("anuncios.pos")
  REVISA(type(p) == "table" and math.abs((p.x or 0) - 300) < 16 and math.abs((p.y or 0) - 200) < 16, "arrastrar el anuncio no guardó su lugar")
  K.CerrarAnuncio()
  K.AnclaAnuncioVolver()
end)

PASO("El ratón sigue siendo del jugador", function() TIEMPO(20) RATON_LIMPIO("tras mover") end)

PRUEBA_FIN()
