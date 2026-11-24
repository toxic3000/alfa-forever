-- Prueba de la 1.3.7, el oro de las bolsas (tools/prueba.py la corre con las demás prueba_*.lua):
--   * el pie de tus bolsas enseña tu oro una sola vez (sin «Cuenta: …») y su
--     cuadro ya solo habla del espacio;
--   * el botón de monedas abre «Tu oro» y otro clic lo cierra;
--   * el desglose: 3 personajes de 2 reinos, tú primero, luego de más a menos
--     oro, «hace 3 días» en los demás, subtotal por reino y facción y «Toda la
--     cuenta»; clic en otro personaje abre sus bolsas y su oro dice de cuándo es;
--   * con 9.999.999 de oro y nombres largos nada se sale de su caja;
--   * la sesión de oro sobrevive a un /reload (y una entrada nueva empieza otra);
--   * el botín de tu farmeo y tu mejor zona;
--   * el nivel de objeto y la durabilidad sobre las ranuras de tu personaje;
--   * los botones de tus conjuntos: el macro de las armas se prepara fuera de
--     combate y en combate nada se toca.
SNAPSHOTS = {}
local pasos = 0
local function step(nombre, fn, ...)
  pasos = pasos + 1
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.7 oro", msg) end end

local impresos = {}
AlfaNucleo.Imprimir = function(...)
  local t = {}
  for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
  impresos[#impresos + 1] = table.concat(t, " ")
end
local function dijo(texto)
  for _, t in ipairs(impresos) do if t:find(texto, 1, true) then return true end end
  return false
end

local dinero = 123456
GetMoney = function() return dinero end
local function cambiarDinero(d)
  dinero = dinero + d
  FIRE_EVENT("PLAYER_MONEY")
end

if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(6)

local N, K = AlfaNucleo, AlfaNucleo.Kit
local B = NS_OF("Alfa_Bolsas")
local D, V, Or, Se = B.Datos, B.Ventana, B.Oro, B.Sesion
local ESP = K.ESP

-- Tres personajes de dos reinos: tú (Lobato-Forever, Horda), uno de tu reino
-- y facción, y uno de otro reino de la Alianza.
local yo = D.Clave()
local hace3 = time() - 3 * 86400 - 60
local pers = D.Raiz().personajes
pers["Garra-Forever"] = { nombre = "Garra", reino = "Forever", faccion = "Horde", clase = "HUNTER", nivel = 40, dinero = 50000, visto = hace3, bolsas = {}, banco = {}, equipo = {} }
pers["Luna-Otro Reino"] = { nombre = "Luna", reino = "Otro Reino", faccion = "Alliance", clase = "PRIEST", nivel = 25, dinero = 900000, visto = hace3, bolsas = {}, banco = {}, equipo = {} }
D.GuardarCabecera()

local function textosDe(marco)
  local out = {}
  for _, f in ipairs(ALL_FRAMES()) do
    if f.GetText and f:IsVisible() then
      local p, dentro = f, false
      while p do
        if p == marco then dentro = true break end
        p = p.GetParent and p:GetParent() or nil
      end
      if dentro then
        local t = f:GetText()
        if type(t) == "string" and t ~= "" then out[#out + 1] = t end
      end
    end
  end
  return table.concat(out, "\n")
end

V.MostrarBolsas(true)
RUN_TIMERS(4)
local win = V.Ventana("bolsas")

---------------------------------------------------------------------------
-- 1. El pie
---------------------------------------------------------------------------

step("El pie: tu oro una sola vez, sin «Cuenta:»", function()
  check(win:IsShown(), "la ventana de bolsas no se abrió")
  check(win.Cuenta == nil, "el pie aún tiene el texto de la cuenta")
  local pie = textosDe(win.Pie)
  check(not pie:find("Cuenta:", 1, true), "el pie todavía dice «Cuenta:»: " .. pie)
  check(win.Dinero:GetText() == N.Dinero(dinero, true), "el pie no enseña tu oro: " .. tostring(win.Dinero:GetText()))
  local veces = select(2, pie:gsub("moneda%-oro", ""))
  check(veces <= 1, "el oro sale " .. veces .. " veces en el pie")
  check(win.Monedas and win.Monedas:IsShown(), "falta el botón de monedas")
  -- El cuadro del pie: solo el espacio.
  local i = win.Pie.alfaInfo
  local titulo, lineas = i[1], i[2]
  if type(titulo) == "function" then titulo, lineas = titulo(win.Pie) end
  local todo = tostring(titulo) .. "\n" .. table.concat(type(lineas) == "table" and lineas or { tostring(lineas) }, "\n")
  check(not todo:find("Toda la cuenta", 1, true) and not todo:find("Esta sesión", 1, true), "el cuadro del pie aún habla del oro: " .. todo)
  check(todo:find("libres", 1, true), "el cuadro del pie no dice el espacio")
end)

---------------------------------------------------------------------------
-- 2. El botón y el desglose
---------------------------------------------------------------------------

step("Las monedas abren y cierran «Tu oro»", function()
  win.Monedas:Click()
  check(Or.Visible(), "un clic en las monedas no abrió «Tu oro»")
  win.Monedas:Click()
  check(not Or.Visible(), "otro clic no lo cerró")
  win.Monedas:Click()
  check(Or.Visible(), "no se volvió a abrir")
end)

step("El desglose: tú primero, de más a menos, por reino y facción", function()
  local grupos, total = Or.Grupos()
  check(#grupos == 2, "debían salir 2 grupos (reino y facción), salieron " .. #grupos)
  check(grupos[1].filas[1].clave == yo, "tú no vas primero")
  check(grupos[1].reino == "Forever" and grupos[1].faccion == "Horde", "tu grupo no es el de tu reino y facción")
  check(#grupos[1].filas == 2 and grupos[1].filas[2].clave == "Garra-Forever", "Garra no está en tu grupo")
  check(grupos[2].filas[1].clave == "Luna-Otro Reino", "Luna no está en el otro reino")
  check(total == dinero + 50000 + 900000, "Toda la cuenta no suma bien: " .. total)
  check(Or.TituloGrupo(grupos[2]):find("Alianza", 1, true), "el subtotal no dice la facción: " .. Or.TituloGrupo(grupos[2]))
  local p = Or.Panel()
  local texto = textosDe(p)
  check(texto:find("Tu oro", 1, true), "el panel no dice «Tu oro»")
  check(texto:find("Toda la cuenta", 1, true), "falta «Toda la cuenta»")
  check(texto:find("Esta sesión", 1, true), "falta «Esta sesión»")
  check(texto:find("hace 3 días", 1, true), "los demás no dicen «hace 3 días»: " .. texto)
  check(texto:find("Forever", 1, true) and texto:find("Otro Reino", 1, true), "faltan los subtotales por reino")
  check(p.filas[1].clave == yo and p.filas[1].Marca:IsShown(), "tu fila no va primero o no está marcada")
  -- Dentro de un grupo: de más a menos.
  pers["Garra-Forever"].dinero = dinero * 10
  Or.Pintar()
  local g = Or.Grupos()
  check(g[1].filas[1].clave == yo and g[1].filas[2].clave == "Garra-Forever", "aun con menos oro, tú sigues primero")
  pers["Garra-Forever"].dinero = 50000
end)

step("Clic en otro personaje: sus bolsas, y su oro dice de cuándo es", function()
  Or.Pintar()
  local p = Or.Panel()
  local fila
  for _, b in ipairs(p.filas) do if b:IsShown() and b.clave == "Luna-Otro Reino" then fila = b end end
  check(fila, "no hay fila de Luna")
  if not fila then return end
  fila:Click()
  RUN_TIMERS(3)
  check(win.clave == "Luna-Otro Reino", "el clic no abrió las bolsas de Luna")
  check(win.Dinero:GetText() == N.Dinero(900000, true), "el pie no enseña el oro de Luna")
  check(win.Cuando:IsShown() and (win.Cuando:GetText() or ""):find("hace 3 días", 1, true), "el oro de Luna no dice de cuándo es")
  check(fila.Marca:IsShown(), "la fila de Luna no se marca mientras la miras")
  -- Y de vuelta.
  p.filas[1]:Click()
  RUN_TIMERS(3)
  check(win.clave == nil, "el clic en tu fila no volvió a tus bolsas")
  check(not win.Cuando:IsShown(), "tu oro dice de cuándo es (es de ahora)")
end)

step("Mucho oro y nombres largos: nada se sale de su caja", function()
  dinero = 9999999 * 10000 + 9999
  pers["Garra-Forever"].dinero = 9999999 * 10000
  pers["Garra-Forever"].nombre = "Garraaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  pers["Luna-Otro Reino"].reino = "Un Reino Con Un Nombre Larguísimo De Verdad"
  FIRE_EVENT("PLAYER_MONEY")
  Or.Pintar()
  RUN_TIMERS(2)
  local p = Or.Panel()
  check(p:GetWidth() <= Or.ANCHO_MAX + 0.5, "el panel pasó de su ancho máximo: " .. p:GetWidth())
  local function cabe(nombre, izq, der, caja)
    local w = izq:GetWidth() + der:GetWidth() + 8 + 6 + ESP.s
    check(w <= caja:GetWidth() + 1, nombre .. ": se sale (" .. math.floor(w) .. " de " .. math.floor(caja:GetWidth()) .. ")")
    check(der:GetUnboundedStringWidth() <= der:GetWidth() + 1, nombre .. ": el oro se corta")
  end
  for i, b in ipairs(p.filas) do
    if b:IsShown() then
      cabe("fila " .. i, b.Nombre, b.Dinero, b)
      check(b.Detalle:GetWidth() <= b:GetWidth() - b.Dinero:GetWidth() - 14, "fila " .. i .. ": el detalle se sale")
    end
  end
  for i, h in ipairs(p.grupos) do if h:IsShown() then cabe("grupo " .. i, h.Texto, h.Total, h) end end
  cabe("toda la cuenta", p.Total.Texto, p.Total.Dinero, p.Total)
  for i, t in ipairs(p.lineas) do
    if t:IsShown() then check(t:GetWidth() <= p.util - 15, "la línea " .. i .. " de la sesión se sale") end
  end
  check(p.util + 2 * ESP.xs + 12 <= p:GetWidth() + 0.5, "el contenido es más ancho que el panel")
  -- El pie de la ventana, con tanto oro.
  V.Pie(win)
  local ocupado = (16 + 2) + win.Dinero:GetWidth() + ESP.xs + win.Monedas:GetWidth() + ESP.m + win.Libre:GetWidth() + (16 + 2)
  check(ocupado <= win:GetWidth() + 1, "el pie se sale con mucho oro: " .. math.floor(ocupado) .. " de " .. math.floor(win:GetWidth()))
  check(win.Dinero:GetUnboundedStringWidth() <= win.Dinero:GetWidth() + 1, "el oro del pie se corta")
  dinero = 123456
  pers["Garra-Forever"].dinero = 50000
  pers["Garra-Forever"].nombre = "Garra"
  pers["Luna-Otro Reino"].reino = "Otro Reino"
  FIRE_EVENT("PLAYER_MONEY")
end)

---------------------------------------------------------------------------
-- 3. La sesión sobrevive a un /reload
---------------------------------------------------------------------------

step("La sesión sigue después de un /reload", function()
  NOW = NOW + 1800
  cambiarDinero(40000)
  cambiarDinero(-10000)
  local s1 = Se.Datos()
  check(s1.ganado >= 40000 and s1.gastado >= 10000, "no contó lo ganado y lo gastado")
  check(s1.porHora > 0, "no hay por hora tras media hora")
  -- /reload: se olvida lo de esta carga; lo guardado sigue.
  Se.OlvidarCarga()
  NOW = NOW + 3
  FIRE_EVENT("PLAYER_ENTERING_WORLD", false, true)
  local s2 = Se.Datos()
  check(s2.ganado == s1.ganado and s2.gastado == s1.gastado, "el /reload borró la sesión (" .. s2.ganado .. " de " .. s1.ganado .. ")")
  check(s2.segundos >= s1.segundos, "el tiempo volvió a cero tras el /reload (" .. s2.segundos .. ")")
  check(s2.porHora > 0 and s2.porHora <= s1.porHora, "el por hora salió mal tras el /reload: " .. s2.porHora .. " (antes " .. s1.porHora .. ")")
  cambiarDinero(5000)
  check(Se.Datos().ganado == s1.ganado + 5000, "después del /reload no sigue sumando")
  -- Una entrada nueva al juego: otra sesión.
  Se.OlvidarCarga()
  FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
  check(Se.Datos().ganado == 0, "una entrada nueva siguió con la sesión vieja")
end)

---------------------------------------------------------------------------
-- 4. Tu farmeo
---------------------------------------------------------------------------

step("El botín y tu mejor zona", function()
  rawset(_G, "LOOT_ITEM_SELF", rawget(_G, "LOOT_ITEM_SELF") or "Recibes botín: %s.")
  rawset(_G, "LOOT_ITEM_SELF_MULTIPLE", rawget(_G, "LOOT_ITEM_SELF_MULTIPLE") or "Recibes botín: %sx%d.")
  local precioReal = C_Item.GetItemInfo
  C_Item.GetItemInfo = function() return "Piel", "x", 1, 10, 1, "Tipo", "Sub", 20, "", 134400, 250 end
  local link = "|cff9d9d9d|Hitem:4865::::::::|h[Garra rota]|h|r"
  local fmt = LOOT_ITEM_SELF_MULTIPLE
  FIRE_EVENT("CHAT_MSG_LOOT", fmt:format(link, 3), "", "", "", "", "", "", 0, "", "", 0, UnitGUID("player"))
  FIRE_EVENT("CHAT_MSG_LOOT", LOOT_ITEM_SELF:format(link), "", "", "", "", "", "", 0, "", "", 0, UnitGUID("player"))
  -- Lo de otro no cuenta.
  FIRE_EVENT("CHAT_MSG_LOOT", "Garra recibe botín: " .. link .. ".", "", "", "", "", "", "", 0, "", "", 0, "Player-1-0099")
  C_Item.GetItemInfo = precioReal
  local s = Se.Datos()
  check(s.botin == 4, "el botín no cuenta 4 objetos: " .. s.botin)
  check(s.valor == 1000, "el valor del botín no es 4 x 250: " .. s.valor)
  cambiarDinero(30000)
  NOW = NOW + 600
  local l = table.concat(Se.LineasFarmeo(), "\n")
  check(l:find("4 objetos", 1, true), "las líneas no dicen el botín: " .. l)
  check(l:find("Tu mejor zona: Durotar", 1, true), "no dice tu mejor zona: " .. l)
  Or.Pintar()
  check(textosDe(Or.Panel()):find("Tu mejor zona", 1, true), "«Tu oro» no enseña tu mejor zona")
end)

---------------------------------------------------------------------------
-- 5. Nivel y durabilidad en tu personaje
---------------------------------------------------------------------------

local Ra = B.Ranuras
step("Nivel de objeto y durabilidad sobre las ranuras", function()
  local cabeza = CreateFrame("Button", "CharacterHeadSlot", UIParent)
  local pecho = CreateFrame("Button", "CharacterChestSlot", UIParent)
  local link = "|cff0070dd|Hitem:9103::::::::|h[Yelmo del alfa]|h|r"
  local orig = { GetInventoryItemLink, GetInventoryItemDurability, GetInventoryItemQuality, C_Item.GetDetailedItemLevelInfo }
  GetInventoryItemLink = function(u, r) if r == 1 or r == 5 then return link end end
  GetInventoryItemDurability = function(r) if r == 1 then return 30, 100 end if r == 5 then return 100, 100 end end
  GetInventoryItemQuality = function() return 3 end
  C_Item.GetDetailedItemLevelInfo = function() return 45 end
  local n = Ra.Pintar("player")
  local nivel, dura = Ra.Texto(cabeza)
  check(n >= 2 and nivel == "45", "la cabeza no dice su nivel: " .. tostring(nivel))
  check(dura == "30%", "la cabeza no dice su durabilidad: " .. tostring(dura))
  local _, dura2 = Ra.Texto(pecho)
  check(dura2 == nil, "el pecho entero dice su durabilidad")
  -- Sin el nivel del cliente, nada.
  C_Item.GetDetailedItemLevelInfo = nil
  check(not Ra.Disponible() and Ra.Pintar("player") == 0 and Ra.Texto(cabeza) == nil, "sin el nivel del cliente pintó algo")
  C_Item.GetDetailedItemLevelInfo = function() return 45 end
  -- Apagado: se quita.
  N.Set("bolsas", "nivelPersonaje", false)
  Ra.Pintar("player")
  check(Ra.Texto(cabeza) == nil, "apagado, la cabeza sigue con su nivel")
  N.Set("bolsas", "nivelPersonaje", nil)
  GetInventoryItemLink, GetInventoryItemDurability, GetInventoryItemQuality, C_Item.GetDetailedItemLevelInfo = orig[1], orig[2], orig[3], orig[4]
end)

---------------------------------------------------------------------------
-- 6. Los botones de tus conjuntos
---------------------------------------------------------------------------

local Cb, Cj = B.Cambio, B.Conjuntos
step("Botones de conjuntos: el macro de las armas, preparado fuera de combate", function()
  local cf = CreateFrame("Frame", "CharacterFrame", UIParent)
  cf:SetSize(384, 512)
  cf:Show()
  local orig = { GetInventoryItemID, GetInventoryItemLink }
  local puestoEn = { [16] = 9201, [1] = 9103 }
  GetInventoryItemID = function(u, r) return puestoEn[r] end
  GetInventoryItemLink = function(u, r) return puestoEn[r] and ("|cff1eff00|Hitem:" .. puestoEn[r] .. "::::::::|h[x]|h|r") or nil end
  Cj.Guardar("Tanque")
  -- (1.3.9: la barra no sale si tu único conjunto es el que ya llevas puesto.)
  puestoEn[1] = nil
  Cb.Armar()
  local b = Cb.Botones()[1]
  check(Cb.Barra() and Cb.Barra():IsShown(), "la barra de conjuntos no salió junto a tu personaje")
  check(b and b.nombre == "Tanque", "no hay botón para «Tanque»")
  if not b then return end
  check((b:GetAttribute("macrotext1") or ""):find("/equipslot 16 item:9201", 1, true), "el macro no cambia el arma: " .. tostring(b:GetAttribute("macrotext1")))
  check(b:GetAttribute("type1") == "macro", "el botón no es de macro")
  -- En combate: no se toca ningún atributo, y el clic deja lo demás para después.
  local cambios = 0
  local setReal = b.SetAttribute
  b.SetAttribute = function(self, ...) cambios = cambios + 1 return setReal(self, ...) end
  InCombatLockdown = function() return true end
  Cb.Armar()
  B.Avisar("CONJUNTOS")
  check(cambios == 0, "en combate se tocaron " .. cambios .. " atributos")
  puestoEn[1] = nil
  b:Click("LeftButton")
  check(dijo("Te cambié las armas de «Tanque»"), "en combate no dijo que cambió las armas")
  check(Cj.esperando == "Tanque", "lo demás no espera al fin del combate")
  InCombatLockdown = function() return false end
  b.SetAttribute = setReal
  -- Clic derecho: ponérmelo al salir de cada combate.
  Cb.PonerAlSalir("Tanque")
  check(Cb.AlSalir() == "Tanque", "no recuerda ponértelo al salir de combate")
  Cb.PonerAlSalir("Tanque")
  check(Cb.AlSalir() == nil, "otro clic no lo quita")
  cf:Hide()
  Cb.Armar()
  check(not Cb.Barra():IsShown(), "con tu personaje cerrado la barra sigue")
  Cj.Olvidar("Tanque")
  GetInventoryItemID, GetInventoryItemLink = orig[1], orig[2]
end)

Or.Cerrar()
V.MostrarBolsas(false)
print(("PRUEBA: 1.3.7 oro, %d pasos, %d errores"):format(pasos, #ERRORS))
