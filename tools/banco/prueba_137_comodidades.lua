-- Prueba de la 1.3.7, Comodidades (tools/prueba.py la corre con las demás prueba_*.lua):
--   1. la bitácora llena: no acepta, avisa una sola vez, el motor también la deja,
--      y con espacio otra vez vuelve a aceptar (155);
--   2. la barra de información: datos, colores, clic a su página, sin ratón en
--      combate, se arrastra y guarda su lugar, y sale en «Acomodar» (167);
--   3. los números de las recargas: los del juego con la letra de Alfa, el color
--      según lo que falta, el destello al quedar lista, nada con la global ni con
--      valores secretos, y el texto propio sin números del juego; al apagar, todo
--      como estaba (168);
--   4. el chat: la hora (sin la opción del juego), las direcciones que se copian,
--      copiar las líneas, los susurros por persona con su sonido, y el filtro de
--      spam (oro, repetidos, nunca a los amigos, «ver lo filtrado») (173–176);
--   5. el ID en el cuadro (190).
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
local function check(cond, msg) if not cond then NOTE("1.3.7 comodidades", msg) end end

FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(3)

local N = AlfaNucleo
local A = N.A
local M = NS_OF("Alfa_Comodidades")

-- Lo que Alfa escribe en el chat y lo que abre.
local impreso = {}
local imprimirAntes = N.Imprimir
N.Imprimir = function(...) impreso[#impreso + 1] = table.concat({ ... }, " ") end
local abiertas = {}
local abrirAntes = N.Abrir
N.Abrir = function(id) abiertas[#abiertas + 1] = id end
local copias = {}
A.UI = A.UI or {}
local copiaAntes = A.UI.ShowCopy
A.UI.ShowCopy = function(titulo, texto) copias[#copias + 1] = { titulo = titulo, texto = texto } end

local function poner(k, v) N.Set("comodidades", k, v) end

---------------------------------------------------------------------------
-- 1. La bitácora llena
---------------------------------------------------------------------------
step("bitácora llena: no acepta y avisa una vez", function()
  local Cp = A.Compat
  local enLog = 40
  local antesQ, antesT = Cp.GetLogQuests, Cp.GetLogCap
  Cp.GetLogQuests = function() local t = {} for i = 1, enLog do t[i] = 1000 + i end return t end
  Cp.GetLogCap = function() return 40 end
  local aceptadas = 0
  rawset(_G, "GetQuestID", function() return 777 end)
  rawset(_G, "QuestGetAutoAccept", function() return false end)
  rawset(_G, "AcceptQuest", function() aceptadas = aceptadas + 1 end)
  rawset(_G, "QuestFlagsPVP", function() return false end)
  rawset(_G, "QuestIsDaily", function() return false end)
  rawset(_G, "QuestIsWeekly", function() return false end)
  poner("misiones", true)
  local soloRuta = A.Get("ruta.soloRuta")
  A.Set("ruta.soloRuta", false) -- una misión que no es de la ruta
  local antes = #impreso
  M.Misiones.Detalle()
  M.Misiones.Detalle()
  check(aceptadas == 0, "con la bitácora llena intentó aceptar (" .. aceptadas .. ")")
  check(#impreso - antes == 1, "el aviso de la bitácora llena salió " .. (#impreso - antes) .. " veces, no una")
  check(tostring(impreso[#impreso]):find("llena", 1, true), "el aviso no dice que la bitácora está llena")
  check(A.LogFullHold and A.LogFullHold() == true, "el motor (ns.LogFullHold) no la deja con la bitácora llena")
  -- Una que el juego ya aceptó solo sigue igual.
  rawset(_G, "QuestGetAutoAccept", function() return true end)
  check(A.LogFullHold() == false, "una misión que el juego acepta solo quedó detenida")
  rawset(_G, "QuestGetAutoAccept", function() return false end)
  -- Apagado el ajuste, como antes.
  poner("bitacoraLlena", false)
  check(A.LogFullHold() == false, "con el ajuste apagado igual la detuvo")
  poner("bitacoraLlena", true)
  -- Con espacio otra vez, acepta (y el aviso puede volver otro día).
  enLog = 39
  FIRE_EVENT("QUEST_LOG_UPDATE")
  M.Misiones.Detalle()
  check(aceptadas == 1, "con espacio en la bitácora no aceptó")
  enLog = 40
  M.Misiones.Detalle()
  check(#impreso - antes == 2, "tras hacer espacio y volver a llenarla, el aviso no volvió a salir")
  Cp.GetLogQuests, Cp.GetLogCap = antesQ, antesT
  poner("misiones", false)
  A.Set("ruta.soloRuta", soloRuta)
end)

---------------------------------------------------------------------------
-- 2. La barra de información
---------------------------------------------------------------------------
step("barra de información: apagada de fábrica, datos y clics", function()
  local I = M.Info
  check(N.Get("comodidades", "info") == false, "la barra de información no viene apagada de fábrica")
  rawset(_G, "GetNetStats", function() return 0, 0, 45, 480 end)
  rawset(_G, "GetInventoryItemDurability", function(s) if s == 5 then return 20, 100 end if s == 1 then return 90, 100 end return nil end)
  rawset(_G, "C_Container", { GetContainerNumFreeSlots = function(b) if b == 0 then return 3, 0 end if b == 1 then return 8, 1 end return 1, 0 end })
  poner("info", true)
  local b = rawget(_G, "AlfaComodidadesInfo")
  check(b and b:IsShown(), "al encenderla no salió la barra")
  if not b then return end
  check(I.Fps() == 60, "los cuadros por segundo no se leen")
  check(I.Latencia() == 480, "la latencia no es la del mundo")
  check(I.Durabilidad() == 20, "la durabilidad no es la de la pieza más gastada (" .. tostring(I.Durabilidad()) .. ")")
  check(I.Libres() == 6, "las bolsas especiales cuentan como espacio libre (" .. tostring(I.Libres()) .. ")")
  local d = I.Datos
  local function txt(id) return d[id].b.fs:GetText() or "" end
  check(txt("rendimiento"):find("60", 1, true) and txt("rendimiento"):find("480", 1, true), "el rendimiento no dice fps y ms: " .. txt("rendimiento"))
  check(txt("durabilidad"):find("20 %", 1, true), "la durabilidad no sale en la barra: " .. txt("durabilidad"))
  check(d.bolsas.b:IsShown() and txt("bolsas"):find("6", 1, true), "las bolsas no salen en la barra")
  check(d.hora.b:IsShown(), "la hora no sale")
  -- Los datos no se salen de la barra ni se enciman.
  local fin = 0
  for _, x in ipairs(I.DATOS) do
    local e = d[x.id]
    if e.b:IsShown() then
      local l = e.b:GetLeft() or 0
      check(l >= fin - 0.5, "el dato " .. x.id .. " se encima con el anterior")
      fin = l + e.b:GetWidth()
    end
  end
  check(fin <= (b:GetLeft() or 0) + b:GetWidth() + 0.5, "los datos se salen de la barra")
  -- El clic abre su página.
  abiertas = {}
  FIRE(d.bolsas.b, "OnClick", "LeftButton")
  check(abiertas[1] == "bolsas", "el clic en las bolsas no abrió Bolsas (" .. tostring(abiertas[1]) .. ")")
  FIRE(d.rendimiento.b, "OnClick", "LeftButton")
  check(abiertas[2] == "vista", "el clic en el rendimiento no abrió Paisaje")
  -- La experiencia por hora, tras unos minutos.
  NOW = NOW + 600
  local ses = I.Sesion
  ses.ganada = 5000
  check(I.XPHora() and I.XPHora() > 0, "la experiencia por hora no se calcula")
  check(I.Miles(12345) == "12,345", "los miles no llevan su coma: " .. tostring(I.Miles(12345)))
end)

step("barra de información: combate, arrastre y Acomodar", function()
  local I = M.Info
  local b = rawget(_G, "AlfaComodidadesInfo")
  if not b then return end
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not b:IsMouseEnabled() and not I.Datos.oro.b:IsMouseEnabled(), "en combate la barra atrapa clics")
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  check(b:IsMouseEnabled(), "al salir de combate la barra no volvió a recibir el ratón")
  FIRE(b, "OnDragStart")
  b:ClearAllPoints()
  b:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 40, 30)
  FIRE(b, "OnDragStop")
  local pos = N.Datos("comodidades").infoPos
  check(type(pos) == "table" and pos[1] == "BOTTOMLEFT" and pos[3] == 40, "al soltarla no guardó su lugar")
  -- En «Acomodar la pantalla».
  local Ac = rawget(_G, "AlfaAcomodar")
  if type(Ac) == "table" and Ac.Abrir then
    Ac.Abrir()
    local B = NS_OF("Alfa_Bienvenida")
    local marcas = B.Acomodar and B.Acomodar.Marcas() or {}
    check(marcas.comodidadesInfo and marcas.comodidadesInfo:IsShown(), "la barra de información no sale en «Acomodar la pantalla»")
    Ac.Cerrar()
  end
  I.Restablecer()
  check(N.Datos("comodidades").infoPos == nil, "«su lugar de siempre» no la regresó")
  poner("info", false)
  check(not b:IsShown(), "al apagarla la barra siguió a la vista")
  check(not N.HayTarea("comodidades.info"), "apagada, su reloj siguió corriendo")
end)

---------------------------------------------------------------------------
-- 3. Los números de las recargas
---------------------------------------------------------------------------
local function botonDePrueba(nombre, delJuego)
  local b = CreateFrame("Button", nombre, UIParent)
  b:SetSize(40, 40)
  local cd = CreateFrame("Frame", nombre .. "Cooldown", b)
  cd:SetAllPoints(b)
  rawset(b, "cooldown", cd)
  cd.puestos = 0
  rawset(cd, "SetCooldown", function(self, i, d) self.puestos = self.puestos + 1 end)
  rawset(cd, "Clear", function() end)
  if delJuego then
    local fs = cd:CreateFontString(nil, "OVERLAY")
    fs:SetFont("Fonts\\FRIZQT__.TTF", 10, "")
    cd.oculto = true
    rawset(cd, "GetCountdownFontString", function() return fs end)
    rawset(cd, "SetHideCountdownNumbers", function(self, v) self.oculto = v end)
    rawset(cd, "GetHideCountdownNumbers", function(self) return self.oculto end)
    cd.fs = fs
  end
  return b, cd
end

step("recargas: los números del juego, color y destello", function()
  local Rc = M.Recargas
  local b1, cd1 = botonDePrueba("AlfaPruebaAccion1", true)
  local b2, cd2 = botonDePrueba("AlfaPruebaAccion2", false)
  local antesLista = M.BotonesDeAccion
  M.BotonesDeAccion = function() return { b1, b2 } end
  check(N.Get("comodidades", "recargas") == false, "los números de las recargas no vienen apagados de fábrica")
  poner("recargas", true)
  check(cd1.oculto == false, "no se encendieron los números del juego")
  local f, t = cd1.fs:GetFont()
  check(f ~= "Fonts\\FRIZQT__.TTF" and t >= 12, "los números del juego no tomaron la letra de Alfa en grande (" .. tostring(f) .. " " .. tostring(t) .. ")")
  local r1, r2 = Rc.Registros[cd1], Rc.Registros[cd2]
  check(r1 and r2, "los botones no se prepararon")
  check(r2 and r2.fs, "sin números del juego no hay texto propio")
  -- Una recarga de 30 s.
  cd1:SetCooldown(NOW, 30)
  cd2:SetCooldown(NOW, 30)
  check(cd1.puestos == 1, "el gancho cambió lo que hace SetCooldown")
  check(Rc.Activos[cd1], "la recarga no quedó contando")
  check(N.HayTarea("comodidades.recargas"), "el reloj de las recargas no despertó")
  check(r2.fs:GetText() == "30", "el texto propio no dice cuánto falta: " .. tostring(r2.fs:GetText()))
  local function color(fs) local c = fs._tc or {} return c[1], c[2], c[3] end
  NOW = NOW + 22
  Rc.Tic()
  check(r1.tono == "aviso", "a 8 s no está en amarillo (" .. tostring(r1.tono) .. ")")
  NOW = NOW + 6
  Rc.Tic()
  check(r1.tono == "peligro", "a 2 s no está en rojo")
  check(r2.fs:GetText() == "2.0", "el texto propio con decimales al final: " .. tostring(r2.fs:GetText()))
  NOW = NOW + 3
  FIRE(cd1, "OnCooldownDone")
  check((r1.destellos or 0) == 1, "al quedar lista no destelló")
  check(not Rc.Activos[cd1], "lista, siguió contando")
  check(r1.tono == nil, "lista, se quedó con el color")
  Rc.Tic()
  check(not N.HayTarea("comodidades.recargas"), "sin recargas el reloj siguió")
  -- La global: ni número ni destello.
  cd1:SetCooldown(NOW, 1.5)
  check(not Rc.Activos[cd1], "la recarga global quedó contando")
  NOW = NOW + 1.5
  FIRE(cd1, "OnCooldownDone")
  check((r1.destellos or 0) == 1, "destelló con la recarga global")
  -- En secreto: el número lo pone el juego, sin color propio.
  local SECRETO = {}
  local antesSec = issecretvalue
  issecretvalue = function(v) return v == SECRETO end
  cd1:SetCooldown(SECRETO, SECRETO)
  check(not Rc.Activos[cd1], "con valores secretos quiso contarlos")
  issecretvalue = antesSec
  NOW = NOW + 10
  FIRE(cd1, "OnCooldownDone")
  check((r1.destellos or 0) == 2, "una recarga larga en secreto no destelló al quedar lista")
  -- El juego la limpia justo al terminar, antes de avisar que acabó: un solo destello.
  cd1:SetCooldown(NOW, 30)
  NOW = NOW + 30
  cd1:Clear()
  FIRE(cd1, "OnCooldownDone")
  check((r1.destellos or 0) == 3, "limpiada al terminar, no destelló una vez (" .. tostring(r1.destellos) .. ")")
  -- Apagar: todo como estaba.
  poner("recargas", false)
  check(cd1.oculto == true, "al apagar, los números del juego no volvieron a como estaban")
  local f2 = cd1.fs:GetFont()
  check(f2 == "Fonts\\FRIZQT__.TTF", "al apagar, la letra no volvió")
  cd2:SetCooldown(NOW, 30)
  check(not Rc.Activos[cd2], "apagado, siguió contando")
  M.BotonesDeAccion = antesLista
end)

---------------------------------------------------------------------------
-- 4. El chat
---------------------------------------------------------------------------
local Ch = M.Charla

step("chat: la hora sin la opción del juego", function()
  local antesGet = C_CVar.GetCVar
  C_CVar.GetCVar = function(n) if n == "showTimestamps" then return nil end return "0" end
  poner("chatHora", true)
  check(Ch.HoraPropia(), "sin la opción del juego, el filtro no pone la hora")
  local _, nuevo = Ch.Filtro(nil, "CHAT_MSG_SAY", "hola", "Otro")
  check(type(nuevo) == "string" and nuevo:find("hola", 1, true) and nuevo:find("%d%d:%d%d"), "la línea no lleva la hora: " .. tostring(nuevo))
  poner("chatHora", false)
  local _, sin = Ch.Filtro(nil, "CHAT_MSG_SAY", "hola", "Otro")
  check(sin == nil, "apagada, la hora siguió saliendo")
  C_CVar.GetCVar = antesGet
end)

step("chat: copiar direcciones y líneas", function()
  check(N.Get("comodidades", "chatCopiar") == true, "copiar del chat no viene encendido")
  local s = Ch.ConEnlaces("Ven a https://discord.gg/hUNjA6BJwh. ¡Te esperamos!")
  check(s:find("|Haddon:alfacopiar:https://discord.gg/hUNjA6BJwh|h", 1, true), "la dirección no se volvió enlace: " .. s)
  check(s:find("|h|r. ", 1, true), "el punto final quedó dentro del enlace")
  local w = Ch.ConEnlaces("mira www.wowhead.com/item=1 y discord.gg/abc")
  local n = select(2, w:gsub("|Haddon:alfacopiar:", ""))
  check(n == 2, "no salieron las dos direcciones (" .. n .. "): " .. w)
  check(Ch.ConEnlaces("sin nada") == "sin nada", "un mensaje sin direcciones cambió")
  local _, conLink = Ch.Filtro(nil, "CHAT_MSG_GUILD", "lee https://x.org/a", "Amigo")
  check(conLink and conLink:find("alfacopiar", 1, true), "el filtro no puso el enlace en el chat de hermandad")
  copias = {}
  check(Ch.AlEnlace("addon:alfacopiar:https://x.org/a"), "el clic en el enlace no se atendió")
  check(copias[1] and copias[1].texto == "https://x.org/a", "el cuadro para copiar no trae la dirección")
  check(not Ch.AlEnlace("item:1234"), "se metió con un enlace del juego")
  -- Copiar las líneas de una ventana.
  local SECRETO = {}
  local antesSec = issecretvalue
  issecretvalue = function(v) return v == SECRETO end
  local cf = CreateFrame("Frame", nil, UIParent)
  local lineas = { "|cffff0000[Toxic]|r: hola", SECRETO, "un |Hitem:6948|h[Piedra de hogar]|h" }
  rawset(cf, "GetNumMessages", function() return #lineas end)
  rawset(cf, "GetMessageInfo", function(_, i) return lineas[i] end)
  local t = Ch.TextoDe(cf)
  issecretvalue = antesSec
  check(t == "[Toxic]: hola\n…\nun [Piedra de hogar]", "las líneas a copiar no salen limpias: " .. t)
  copias = {}
  Ch.CopiarVentana(cf)
  check(copias[1] and copias[1].texto:find("Piedra de hogar", 1, true), "«Copiar del chat» no abrió el cuadro")
  -- El botón de copiar no se ve (ni atrapa clics) sin el ratón encima.
  for cf2, bt in pairs(Ch.Botones) do check(not bt:IsShown(), "el botón de copiar está a la vista sin el ratón encima") break end
end)

step("chat: susurros por persona y su sonido", function()
  check(N.Get("comodidades", "susurros") == false, "los susurros a la vista no vienen apagados de fábrica")
  poner("susurros", true)
  local sonidos = Ch.sonidos or 0
  FIRE_EVENT("CHAT_MSG_WHISPER", "¿vamos a la mazmorra?", "Yuki-Forever")
  FIRE_EVENT("CHAT_MSG_WHISPER", "¿sí o no?", "Yuki-Forever")
  FIRE_EVENT("CHAT_MSG_WHISPER_INFORM", "¡vamos!", "Yuki-Forever")
  check((Ch.sonidos or 0) - sonidos == 1, "el sonido de susurro no salió una sola vez en pocos segundos (" .. ((Ch.sonidos or 0) - sonidos) .. ")")
  local gente = Ch.Personas()
  check(gente[1] and gente[1].nombre == "Yuki-Forever" and gente[1].n == 3, "el historial no guardó la conversación con Yuki")
  local t = Ch.Conversacion("Yuki-Forever")
  check(t:find("Lobato: ¡vamos!", 1, true), "lo que tú dijiste no sale con tu nombre: " .. t)
  copias = {}
  Ch.VerSusurros(nil, "Yuki-Forever")
  check(copias[1] and copias[1].titulo:find("Yuki", 1, true), "ver los susurros no abrió la conversación")
  -- 31 personas: la más vieja se va.
  for i = 1, 31 do FIRE_EVENT("CHAT_MSG_WHISPER", "hola", "Lobo" .. i) NOW = NOW + 1 end
  check(#Ch.Personas() <= 30, "el historial guarda más de 30 personas")
  poner("susurros", false)
  local n = #Ch.Personas()
  FIRE_EVENT("CHAT_MSG_WHISPER", "hola", "Otro")
  check(#Ch.Personas() == n, "apagado, siguió guardando susurros")
end)

step("chat: filtro de spam", function()
  check(N.Get("comodidades", "spam") == false, "el filtro de spam no viene apagado de fábrica")
  check(Ch.EsVentaDeOro("WTS cheap gold www.g0ld4u.com fast delivery"), "no reconoció la venta de oro con dirección")
  check(Ch.EsVentaDeOro("1000g = 5 USD, paypal ok"), "no reconoció la venta de oro con dinero real")
  check(not Ch.EsVentaDeOro("Vendo Lingote de cobre, precio 5 de oro"), "el comercio de siempre pasó por venta de oro")
  check(not Ch.EsVentaDeOro("¿alguien para Mazmorra? necesito tanque"), "un mensaje normal pasó por venta de oro")
  poner("spam", true)
  local antes = #Ch.Filtrados
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "WTS cheap gold www.g0ld4u.com", "Vendedor", "", "", "", "", 2, "", "", 0, 501, "Player-1-9") == true,
    "la venta de oro salió en el canal")
  -- La segunda ventana de chat dice lo mismo del mismo mensaje.
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "WTS cheap gold www.g0ld4u.com", "Vendedor", "", "", "", "", 2, "", "", 0, 501, "Player-1-9") == true,
    "la segunda ventana mostró la venta de oro")
  check(#Ch.Filtrados == antes + 1, "lo filtrado se guardó dos veces o ninguna")
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "busco grupo", "Lobo", "", "", "", "", 2, "", "", 0, 502) == false, "un mensaje normal no salió")
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "busco grupo", "Lobo", "", "", "", "", 2, "", "", 0, 503) == true, "el mensaje repetido salió otra vez")
  NOW = NOW + 61
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "busco grupo", "Lobo", "", "", "", "", 2, "", "", 0, 504) == false, "pasado un minuto, el mismo mensaje no salió")
  -- Un amigo nunca.
  rawset(_G, "C_FriendList", { IsFriend = function(g) return g == "Player-1-7" end })
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "WTS cheap gold www.g0ld4u.com", "Amiga", "", "", "", "", 2, "", "", 0, 505, "Player-1-7") == false,
    "se le filtró a un amigo")
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "WTS cheap gold www.g0ld4u.com", "Lobato", "", "", "", "", 2, "", "", 0, 506) == false,
    "se te filtró a ti mismo")
  -- Un susurro de spam no se guarda ni suena.
  poner("susurros", true)
  local n = #Ch.Personas()
  FIRE_EVENT("CHAT_MSG_WHISPER", "cheap gold www.g0ld4u.com 5 USD", "Spammer", "", "", "", "", 0, 0, "", 0, 507, "Player-1-8")
  check(#Ch.Personas() == n, "el susurro de spam quedó en tu historial")
  poner("susurros", false)
  -- Un mensaje secreto pasa tal cual.
  local SECRETO = {}
  local antesSec = issecretvalue
  issecretvalue = function(v) return v == SECRETO end
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", SECRETO, "Alguien") == false, "un mensaje secreto no pasó tal cual")
  issecretvalue = antesSec
  check(#impreso > 0 and impreso[#impreso]:find("filtrado", 1, true), "no avisó (una vez) que escondió spam")
  copias = {}
  Ch.VerFiltrado()
  check(copias[1] and copias[1].texto:find("Vendedor", 1, true) and copias[1].texto:find("venta de oro", 1, true), "«Ver lo filtrado» no muestra lo escondido")
  poner("spam", false)
  check(Ch.Filtro(nil, "CHAT_MSG_CHANNEL", "WTS cheap gold www.g0ld4u.com", "Otro", "", "", "", "", 2, "", "", 0, 508) == false, "apagado, siguió filtrando")
end)

---------------------------------------------------------------------------
-- 5. El ID en el cuadro
---------------------------------------------------------------------------
step("el ID en el cuadro", function()
  local Id = M.Ids
  check(Id.DePNJ("Creature-0-4372-0-17-2843-0000123456") == 2843, "no sacó el ID del PNJ de su GUID")
  check(Id.DePNJ("Player-1-0001") == nil, "un jugador dio ID de PNJ")
  local tip = CreateFrame("Frame", nil, UIParent)
  local lineas = {}
  rawset(tip, "AddDoubleLine", function(_, a, b) lineas[#lineas + 1] = { a, b } end)
  rawset(tip, "AddLine", function(_, a) lineas[#lineas + 1] = { a } end)
  rawset(tip, "NumLines", function() return #lineas end)
  check(N.Get("comodidades", "cuadroID") == true and N.Get("comodidades", "cuadroIDSiempre") == false, "los ajustes del ID no vienen como deben")
  check(Id.Linea(tip, "ID de objeto", 6948) == false, "sin Mayús salió el ID")
  local antesShift = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  check(Id.Linea(tip, "ID de objeto", 6948) == true, "con Mayús no salió el ID")
  IsShiftKeyDown = antesShift
  poner("cuadroIDSiempre", true)
  check(Id.Linea(tip, "ID de objeto", 6948) == true, "con «Verlo siempre» no salió el ID")
  check(Id.Linea(tip, "ID de objeto", 0) == false, "salió un ID vacío")
  poner("cuadroIDSiempre", false)
end)

N.Imprimir, N.Abrir, A.UI.ShowCopy = imprimirAntes, abrirAntes, copiaAntes
print(("PRUEBA: comodidades 1.3.7, %d pasos, errores: %d"):format(pasos, #ERRORS))
