-- Prueba de la 1.4.0, área «social»:
--   16. La Red: la versión en los mensajes («|^2» antes de la facción), un
--       Alfa 1.3.x y uno 1.4 se entienden, y nada truena con un mensaje raro.
--   56. Silenciar a un lobo (sus avisos no salen; las respuestas a lo tuyo, sí).
--   54. La ficha dice la guía que sigue el lobo y «Seguir la misma».
--   53. La próxima cita en Hoy con «Me apunto».
--   52. La bienvenida a la manada (tú llegas / alguien llega).
--   55. Los logros de la semana (peces, ayuda, metas y lo destacado).
--   64. Lya: «Solo lo importante» de un clic (y vuelve como estaba).
--   11. Tu temporada con la manada (datos, ventana, texto para Discord).
--   12. Lya 2.0: recuerdos, días especiales y el lore de tus misiones.
-- Con BANCO_FOTOS=1 dibuja las capturas (shot-140-*.png; BANCO_CAPTURAS elige la carpeta).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["140-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
end
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
local function check(cond, msg) if not cond then NOTE("1.4.0 social", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local A = Alfa
local K = N.Kit
if N.Entrando then N.Entrando = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
local MN = NS_OF("Alfa_Manada")
local LY = NS_OF("Alfa_Lya")
local R = MN.Red

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e) end
end
local function llega(texto, canal, quien)
  FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal, quien, "", "", 0, "")
end
-- Un fondo nocturno para las capturas (nada de verde liso).
local function fondo(de)
  local f = CreateFrame("Frame", nil, UIParent)
  f:SetFrameStrata("BACKGROUND")
  f:SetPoint("TOPLEFT", de, "TOPLEFT", -24, 24)
  f:SetPoint("BOTTOMRIGHT", de, "BOTTOMRIGHT", 24, -24)
  local c = f:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(f)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.04, 0.06, 1), CreateColor(0.09, 0.11, 0.16, 1))
  f:Show()
  return f
end
-- Cuenta los avisos del Kit mientras corre fn.
local function contarAvisos(fn)
  local n, titulos = 0, {}
  con(K, { Aviso = function(o) n = n + 1 titulos[#titulos + 1] = o and o.titulo return {} end }, fn)
  return n, titulos
end

---------------------------------------------------------------------------
-- 16. La Red
---------------------------------------------------------------------------
step("16: lo que sale lleva la versión de la Red antes de la facción", function()
  local salidos = {}
  con(R, { Via = function() return "hermandad" end }, function()
    con(_G, { IsInGuild = function() return true end }, function()
      con(C_ChatInfo, { SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = t end }, function()
        R.EnviarHermandad("prueba140:a", "1E|n|60")
        R.EnviarHermandad("prueba140:b", "1Z|" .. ("x"):rep(247)) -- demasiado largo: sin la versión
        for _ = 1, 40 do FIRE(R.motor, "OnUpdate", 0.2) end
      end)
    end)
  end)
  check(salidos[1] == "1E|n|60|^2|~H", "el mensaje no lleva «|^2|~H»: " .. tostring(salidos[1]))
  check(salidos[2] and not salidos[2]:find("|^", 1, true) and #salidos[2] <= 255, "un mensaje largo se pasó de 255 o llevó la versión")
end)

step("16: la 1.4 lee a la 1.3.x y a la 1.4; lo raro no truena", function()
  local oidos = {}
  R.Escuchar()
  R.OlvidarVersiones()
  local malos0, nuevos0 = R.diag.malos or 0, R.diag.nuevos or 0
  con(R.Oyentes, {
    Z = function(clave, _, _, campos) oidos[#oidos + 1] = { clave = clave, campos = { unpack(campos) } } end,
    W = function() error("un campo de una versión más nueva") end,
  }, function()
    con(R.Libres, { Z = true, W = true }, function()
      llega("1Z|a|b|^2|~H", "GUILD", "Ana Smith")   -- 1.4
      llega("1Z|c|d|~H", "GUILD", "Beto Ruiz")      -- 1.3.8 / 1.3.9
      llega("1Z|e|^3|~H", "GUILD", "Caro Paz")      -- una Red más nueva
      llega("1W|x|^2|~H", "GUILD", "Ana Smith")     -- su lectura falla
      llega("1q|lo|que|sea|^2|~H", "GUILD", "Ana Smith") -- un tipo que no se conoce
      llega("basura sin forma", "GUILD", "Ana Smith")
    end)
  end)
  check(#oidos == 3, "no llegaron los 3 mensajes: " .. #oidos)
  check(oidos[1] and oidos[1].campos[1] == "a" and oidos[1].campos[2] == "b" and oidos[1].campos[3] == nil, "la versión quedó en los campos del 1.4")
  check(oidos[2] and oidos[2].campos[1] == "c" and oidos[2].campos[2] == "d", "el de la 1.3.x no se leyó igual")
  check(oidos[3] and oidos[3].campos[1] == "e" and oidos[3].campos[2] == nil, "el de la Red más nueva no se leyó")
  local va, vb = R.VersionDe("ana smith"), R.VersionDe("beto ruiz")
  check(va and va.proto == 2 and vb and vb.proto == 1, "no se anotó la versión de cada lobo")
  check(R.EsNuevo("ana smith") == true and R.EsNuevo("beto ruiz") == false and R.EsNuevo("nadie") == nil, "R.EsNuevo no distingue")
  check((R.diag.malos or 0) == malos0 + 1, "el mensaje que falla no se contó como malo")
  check((R.diag.nuevos or 0) == nuevos0 + 1, "el de la Red más nueva no se contó")
  -- El saludo deja la versión de su Alfa.
  A.Set("manada.compartir", true)
  con(MN.Gente, { Oido = function() end }, function() llega("1H|1.4.0|1|^2|~H", "GUILD", "Ana Smith") end)
  A.Set("manada.compartir", false)
  check(R.VersionDe("ana smith").version == "1.4.0", "el saludo no dejó la versión: " .. tostring(R.VersionDe("ana smith").version))
end)

---------------------------------------------------------------------------
-- 56. Silenciar a un lobo
---------------------------------------------------------------------------
step("56: silenciar a un lobo calla sus avisos y no los de los demás", function()
  local Ca = MN.Callados
  check(Ca and Ca.Poner and Ca.Esta, "falta Callados.lua")
  if not Ca then return end
  Ca.QuitarTodos()
  check(Ca.Poner("Ana Smith", true) and Ca.Esta("ana smith") and Ca.Esta("Ana-Smith"), "no quedó silenciada")
  check(not Ca.Poner(UnitName("player"), true), "te pudiste silenciar a ti")
  local ocultos0 = Ca.Ocultos()
  local n, titulos = contarAvisos(function()
    con(R.Oyentes, {
      Z = function(clave, remitente) MN.U.Aviso({ titulo = "Aviso de " .. remitente, texto = tostring(NOW) }) end,
      R = function(clave, remitente) MN.U.Aviso({ titulo = "Te abre la puerta " .. remitente }) end,
    }, function()
      con(R.Libres, { Z = true }, function()
        llega("1Z|1|^2|~H", "GUILD", "Ana Smith")
        llega("1Z|2|^2|~H", "GUILD", "Beto Ruiz")
      end)
      llega("1R|1|^2|~H", "WHISPER", "Ana Smith") -- la respuesta a algo que pediste sale
    end)
    MN.U.Aviso({ de = "ana smith", titulo = "Cazar juntos con Ana" })
  end)
  check(n == 2, "salieron " .. n .. " avisos (esperaba el de Beto y la puerta): " .. table.concat(titulos, " / "))
  check(Ca.Ocultos() >= ocultos0 + 2, "no se contaron los avisos callados")
  check(Ca.Alternar("Ana Smith") == false and not Ca.Esta("Ana Smith"), "Alternar no le quitó el silencio")
  -- Su Lya tampoco platica con la tuya.
  Ca.Poner("Ana Smith", true)
  check(AlfaManada.Callado("Ana Smith") == true, "AlfaManada.Callado no la ve")
  local Gr = LY.EnGrupo or LY.Grupo
  Ca.QuitarTodos()
end)

---------------------------------------------------------------------------
-- 54. La guía del lobo y «Seguir la misma»
---------------------------------------------------------------------------
step("54: la ficha cuenta la guía que sigue y cabe en un mensaje", function()
  local Fi = MN.Ficha
  local m = { nivel = 30, clase = "WARRIOR", oficios = { { linea = 186, r = 120, m = 150 }, { linea = 164, r = 110, m = 150 } }, objetos = {},
    guia = "Alfa_Guides_Horde/Los Baldíos 20-30 con un nombre bastante largo para probar el tope", paso = 12 }
  for i = 1, 12 do m.objetos[i] = { id = 1000000 + i } end
  local t = Fi.Armar(m)
  check(#t <= 230, "la ficha mide " .. #t)
  check(t:find(m.guia, 1, true) and t:find("|12$"), "la ficha no lleva la guía y su paso: " .. t)
  m.guia = ("g"):rep(120)
  check(#Fi.Armar(m) <= 230, "con una guía muy larga se pasa del tope")
  -- Recibir: de un Alfa 1.4 con su guía, y de uno 1.3.x sin ella.
  local f = { clave = "ana smith", nombre = "Ana Smith", envio = "Ana Smith", conectado = true }
  local g = { clave = "beto ruiz", nombre = "Beto Ruiz", envio = "Beto Ruiz", conectado = true }
  Fi.Olvidar()
  R.OlvidarVersiones()
  local seguida
  con(_G, { AlfaRuta = { NombreGuia = function(id) return id == "guia-x" and "Los Baldíos (20-30)" or nil end,
      SeguirGuia = function(id) seguida = id return true end, GuiaActual = function() return nil end } }, function()
    con(R, { EnviarLibre = function() return true end }, function()
      Fi.Pedir(f) Fi.Pedir(g)
      llega("1h|f|30|WARRIOR|186:120:150|2589|guia-x|7|^2|~H", "WHISPER", "Ana Smith")
      llega("1h|f|25|MAGE|197:80:150|2589|~H", "WHISPER", "Beto Ruiz")
      local ta, id = Fi.TextoGuia(f)
      check(ta and ta:find("Los Baldíos (20-30)", 1, true) and ta:find("7") and id == "guia-x", "no dice la guía de Ana: " .. tostring(ta))
      local tb, idb = Fi.TextoGuia(g)
      check(tb and tb:find("1.4", 1, true) and idb == nil, "no dice que el Alfa de Beto es de antes de la 1.4: " .. tostring(tb))
      check(Fi.SeguirSuGuia(f) and seguida == "guia-x", "«Seguir la misma» no tomó su guía")
      Fi.Abrir(f)
      local v = Fi.Ventana()
      check(v and v:IsShown() and v.Misma:IsShown(), "la ficha no enseña «Seguir la misma»")
      check(v.Callar:IsShown(), "la ficha no enseña «Silenciar sus avisos»")
      SNAP("ficha-guia", fondo(v), { v })
      v:Cerrar()
    end)
  end)
end)

---------------------------------------------------------------------------
-- 53. La próxima cita en Hoy
---------------------------------------------------------------------------
step("53: la próxima cita sale en Hoy con «Me apunto»", function()
  N.Datos("manada").citas = {}
  local cuando = GetServerTime() + 3 * 3600
  llega(("1C|42|%d|Minas de la Muerte|^2|~H"):format(cuando), "GUILD", "Ana Smith")
  local c = AlfaManada.ProximaCita()
  check(c and c.apuntar and c.valor and c.texto:find("Minas", 1, true), "no hay próxima cita con «Me apunto»")
  local respondido
  con(R, { EnviarLibre = function(_, texto) respondido = texto return true end }, function()
    check(AlfaManada.MeApunto(c.llave), "«Me apunto» no respondió")
  end)
  check(respondido and respondido:find("^1D|42|s"), "no le dijo «voy»: " .. tostring(respondido))
  local c2 = AlfaManada.ProximaCita()
  check(c2 and c2.voy and not c2.apuntar, "después de apuntarte sigue pidiendo «Me apunto»")
  -- La tarjeta de Hoy (Alfa_Inicio).
  local lista = AlfaInicio and AlfaInicio.Numeros and AlfaInicio.Numeros() or {}
  local hay = false
  for _, t in ipairs(lista) do if t.titulo == c2.titulo then hay = true end end
  check(hay, "Hoy no enseña la cita de la manada")
  N.Datos("manada").citas = {}
end)

---------------------------------------------------------------------------
-- 52. La bienvenida
---------------------------------------------------------------------------
step("52: bienvenida al entrar a una hermandad y al llegar un lobo con Alfa", function()
  local Bi = MN.Bienvenida
  check(Bi, "falta Bienvenida.lua")
  if not Bi then return end
  local d = N.DatosPersonaje("manada")
  d.hermandadVista = nil
  local enGuild, nombre = false, nil
  con(_G, { IsInGuild = function() return enGuild end, GetGuildInfo = function() return nombre end }, function()
    local n = contarAvisos(function()
      check(Bi.Revisar() == nil, "sin hermandad hubo tarjeta")
      enGuild, nombre = true, "La Jauría"
      check(Bi.Revisar() == "nueva", "al entrar a La Jauría no hubo tarjeta")
      check(Bi.Revisar() == nil, "la tarjeta salió dos veces")
    end)
    check(n == 1, "salieron " .. n .. " tarjetas")
    -- La primera vez que Alfa ve al personaje ya en una hermandad: sin tarjeta.
    d.hermandadVista = nil
    check(Bi.Revisar() == nil and d.hermandadVista == "La Jauría", "un personaje de siempre recibió la bienvenida")
  end)
  -- Alguien llega a tu hermandad.
  ERR_GUILD_JOIN_S = "%s se ha unido a la hermandad."
  check(Bi.QuienLlego("Ana Smith se ha unido a la hermandad.") == "Ana Smith", "no se leyó quién llegó")
  Bi.Olvidar()
  R.OlvidarVersiones()
  local n, titulos = contarAvisos(function()
    FIRE_EVENT("CHAT_MSG_SYSTEM", "Ana Smith se ha unido a la hermandad.")
    FIRE_EVENT("CHAT_MSG_SYSTEM", "Beto Ruiz se ha unido a la hermandad.")
    -- El Alfa de Ana se deja oír; el de Beto, no (no usa Alfa).
    con(R.Oyentes, { Z = function() end }, function()
      con(R.Libres, { Z = true }, function() llega("1Z|^2|~H", "GUILD", "Ana Smith") end)
    end)
    NOW = NOW + 60
    RUN_TIMERS(60)
  end)
  check(n == 1 and tostring(titulos[1]):find("Ana Smith", 1, true), "no hubo un solo aviso para Ana: " .. table.concat(titulos, " / "))
end)

---------------------------------------------------------------------------
-- 55. Los logros de la semana
---------------------------------------------------------------------------
step("55: peces, ayuda, metas y lo destacado de la semana", function()
  local Lo = MN.Logros
  local dp = N.DatosPersonaje("manada")
  dp.semana = nil
  local pesca = N.DatosPersonaje("pesca")
  pesca.vida = { capturas = 100 }
  local w = Lo.Semana()
  check(w.peces == 0 and w.ayuda == 0, "la semana nueva no empieza en cero peces y cero ayuda")
  pesca.vida.capturas = 160
  check(Lo.Semana().peces == 60, "no contó los peces de la semana: " .. tostring(Lo.Semana().peces))
  check(Lo.Ayudar("llamado:ana") and not Lo.Ayudar("llamado:ana") and Lo.Ayudar("guarida:beto"), "Lo.Ayudar no frena lo repetido")
  check(Lo.Semana().ayuda == 2, "la ayuda no suma")
  local dichos = 0
  con(AlfaLya, { Decir = function() dichos = dichos + 1 return true end }, function()
    check(Lo.RevisarMetas() >= 1, "50 peces no festejó «Pescador de la semana»")
    check(Lo.RevisarMetas() == 0, "la meta se festejó dos veces")
  end)
  check(dichos >= 1, "Lya no lo dijo")
  -- La semana de otros: de la 1.4 (con peces y ayuda) y de la 1.3.x (sin ellos).
  N.Datos("manada").semanaManada = {}
  local s = Lo.NumeroSemana()
  llega(("1S|%d|10|0|1|2|80|5|^2|~H"):format(s), "GUILD", "Ana Smith")
  llega(("1S|%d|40|1|0|1|~H"):format(s), "GUILD", "Beto Ruiz")
  local _, tot = Lo.Manada("nombre")
  check(tot.lobos == 3 and tot.peces == 140 and tot.ayuda == 7, "no sumó la semana de todos: " .. tostring(tot.peces) .. "/" .. tostring(tot.ayuda))
  local dest = Lo.TextoDestacados()
  check(dest and dest:find("Ana Smith (80)", 1, true) and dest:find("Beto Ruiz (40)", 1, true), "lo destacado no sale bien: " .. tostring(dest))
  -- Lo que sale ahora lleva peces y ayuda al final.
  local salido
  A.Set("manada.semanaCompartir", true)
  con(R, { EnviarHermandad = function(_, t) salido = t return true end }, function() Lo.CompartirSemana(true) end)
  A.Set("manada.semanaCompartir", false)
  check(salido and salido:find("|60|2$"), "tu semana no manda peces y ayuda: " .. tostring(salido))
  N.Datos("manada").semanaManada = {}
  dp.semana = nil
end)

---------------------------------------------------------------------------
-- 64. Solo lo importante
---------------------------------------------------------------------------
step("64: «Solo lo importante» de un clic, y vuelve a como estaba", function()
  local Ce = LY.Cerebro
  A.Set("lya.frecuencia", "pocos")
  check(Ce.AlternarImportante() == true and Ce.Frecuencia() == "importantes", "no pasó a solo lo importante")
  check(Ce.AlternarImportante() == false and Ce.Frecuencia() == "pocos", "no volvió a «pocos»: " .. tostring(Ce.Frecuencia()))
  A.Set("lya.frecuencia", "muchos")
  Ce.AlternarImportante(true)
  Ce.AlternarImportante(true) -- dos veces: lo de antes no se pierde
  Ce.AlternarImportante(false)
  check(Ce.Frecuencia() == "muchos", "dos clics seguidos perdieron cómo estaba")
end)

---------------------------------------------------------------------------
-- 11. Tu temporada con la manada
---------------------------------------------------------------------------
local hoy = date("%Y-%m-%d")
local function haceDias(n) return date("%Y-%m-%d", os.time() - n * 86400) end

step("11: tu temporada junta lo de Alfa y lo cuenta de por vida", function()
  local Te = LY.Temporada
  local d = N.DatosPersonaje("lya")
  d.temporada = nil
  d.dia = { fecha = hoy, misiones = 4, niveles = 1, oro = 25000, raros = 1, muertes = 0, minutos = 50 }
  d.dias = { { fecha = haceDias(1), misiones = 10, niveles = 2, oro = 90000, raros = 0, muertes = 2, minutos = 120 },
    { fecha = haceDias(3), misiones = 0, minutos = 0 } }
  d.historia = { empezado = haceDias(40), lista = {}, hechos = {} }
  d.record = { misiones = 18, fecha = haceDias(1) }
  d.salchichas = 7
  local t = Te.Libro()
  check(t.misiones == 14 and t.niveles == 3 and t.dias == 2 and t.desde == haceDias(40), "no empezó con lo que ya había")
  -- Lo de hoy suma (Dia.lua) sin contar dos veces.
  LY.Dia.Sumar("misiones")
  check(Te.Libro().misiones == 15 and d.dia.misiones == 5, "Dia.Sumar no sumó en la temporada")
  Te.Sumar("mazmorras") Te.Sumar("guias")
  local x = Te.Datos()
  check(x.conAlfa == 40 and x.mazmorras == 1 and x.guias == 1 and x.mejorDia == 18 and x.salchichas == 7, "Te.Datos no junta todo")
  N.DatosPersonaje("pesca").vida = { capturas = 321, mejorRacha = 9, segundos = 7200 }
  x = Te.Datos()
  check(x.pesca and x.pesca.capturas == 321 and x.pesca.racha == 9, "no leyó la pesca")
  local s = Te.TextoCompartir(x)
  check(not s:find(UnitName("player"), 1, true) and not s:find(GetRealmName(), 1, true), "el texto lleva tu nombre o tu reino: " .. s)
  check(s:find("321") and s:find("15") and s:find("Discord", 1, true) == nil, "el texto no cuenta lo tuyo")
  check(not s:find("|", 1, true), "el texto lleva códigos del juego")
end)

step("11: la ventana de tu temporada (y copiar para Discord)", function()
  local Di = LY.Diario
  local h = N.DatosPersonaje("lya").historia
  h.lista = {
    { clave = "nivel20", fecha = haceDias(5), icono = "ic-nivel", t = "Nivel %d", a = { 20 }, l = "Veinte. Ya te respetan en los caminos." },
    { clave = "montura", fecha = haceDias(12), icono = "ic-aventura", t = "Tu primera montura", l = "¡Ahora sí te sigo corriendo con la lengua de fuera!" },
    { clave = "raro", fecha = haceDias(20), icono = "ic-raros", t = "Tu primer raro: %s", a = { "Rasguño" }, l = "Lo olimos, lo seguimos y cayó. ¡Así caza la manada!" },
  }
  check(SlashCmdList and true, "")
  local V = LY.VentanaTemporada
  check(LY.Temporada.Abrir() and V.Ventana():IsShown(), "/alfa temporada no abrió la ventana")
  local v = V.Ventana()
  check(#v.secciones == 4, "faltan secciones")
  -- El ícono de la cabecera es una textura que existe (no un cuadro vacío).
  local tex = v.Cabecera and v.Cabecera.Icono and v.Cabecera.Icono:GetTexture()
  local dist = (os.getenv("ALFA_DIST") or "dist"):gsub("\\", "/")
  local ruta = type(tex) == "string" and tex:gsub("\\", "/"):gsub("^[Ii]nterface/[Aa]dd[Oo]ns/", "") or nil
  local f = ruta and (io.open(dist .. "/" .. ruta .. ".tga", "rb") or io.open(dist .. "/" .. ruta, "rb"))
  check(f ~= nil, "el ícono de la cabecera no existe: " .. tostring(tex))
  if f then f:close() end
  -- El número grande son los días juntos; los días de caza van en palabras.
  local h = v.Portada
  check(tostring(h.Titulo:GetText()):find("40", 1, true) and tostring(h.Texto:GetText()):find("Salimos a cazar", 1, true), "la portada no dice los días juntos y los de caza: " .. tostring(h.Titulo:GetText()) .. " / " .. tostring(h.Texto:GetText()))
  for _, s in ipairs(v.secciones) do check(#s.Rejilla.elementos > 0, "una sección quedó vacía") end
  check(#v.secciones[4].Rejilla.elementos == 3, "los momentos con Lya no son las 3 páginas")
  SNAP("temporada", fondo(v), { v })
  local texto = V.Copiar()
  check(v.Copia:IsShown() and type(texto) == "string" and texto:find("321"), "«Copiar para Discord» no enseñó el texto")
  SNAP("temporada-copiar", fondo(v), { v })
  v:Cerrar()
  -- En inglés-like letra grande también cabe (sin errores al repintar).
  A.Set("nucleo.letraGrande", true)
  LY.Temporada.Abrir()
  V.Pintar()
  v:Cerrar()
  A.Set("nucleo.letraGrande", false)
end)

---------------------------------------------------------------------------
-- 12. Lya 2.0
---------------------------------------------------------------------------
step("12: recuerdos («¿Te acuerdas…?») y días especiales", function()
  local Re = LY.Recuerdos
  local e, dias, llave = Re.Elegir()
  check(e and dias >= 5, "no eligió una página para recordar")
  local t = Re.Texto(e, 12, 1)
  check(t:find("12") and t:find("«"), "el recuerdo no se armó: " .. t)
  for n = 1, 4 do check(not Re.Texto(e, 3, n):find("%%"), "una frase quedó sin llenar") end
  N.DatosPersonaje("lya").recuerdos = nil
  local Ce = LY.Cerebro
  local dichos = {}
  con(Ce, { Decir = function(c) dichos[#dichos + 1] = c.texto if c.alDecir then c.alDecir() end return true end }, function()
    check(Re.Algo({}) == true, "Lya no recordó nada")
    -- Un mes desde que empezaron: su día especial, una vez.
    LY.Temporada.Libro().desde = haceDias(30)
    check(Re.Especial() == "a30", "no festejó el mes juntos")
    check(Re.Especial() ~= "a30", "el mes se festejó dos veces")
  end)
  check(#dichos >= 2, "no habló")
end)

step("12: el lore del tema de tus misiones", function()
  local Lm = LY.LoreMisiones
  local H = LY.Historias
  local q = H.Todas()
  q[990001] = { t = "La Hermandad Defias", d = "Los Defias atacan a los granjeros.", a = GetServerTime() - 100 }
  local temas = Lm.Temas()
  local hay = false
  for _, x in ipairs(temas) do if x == "la Hermandad Defias" then hay = true end end
  check(hay, "no vio el tema de la misión")
  local e, i, id = Lm.Elegir({ "la Hermandad Defias" })
  check(e and e.id == "defias" and id:match("^mdefias%.%d$"), "no eligió una nota de los Defias")
  local dicho
  con(LY.Cerebro, { Decir = function(c) dicho = c.texto if c.alDecir then c.alDecir() end return true end }, function()
    check(Lm.Algo({}) == true and dicho, "Lya no lo contó")
  end)
  -- Cada nota sale una vez.
  for _ = 1, 4 do con(LY.Cerebro, { Decir = function(c) if c.alDecir then c.alDecir() end return true end }, function() Lm.Algo({}) end) end
  check(Lm.Elegir({ "la Hermandad Defias" }) == nil, "una nota se repitió")
  for _, x in ipairs(LY.LORE_TEMA) do
    for _, nota in ipairs(x.notas) do check(#nota <= 200, "una nota es muy larga: " .. nota:sub(1, 40)) end
  end
  q[990001] = nil
end)

step("La página de Lya: «Solo lo importante» y «Tu temporada»", function()
  N.Abrir("lya")
  RUN_TIMERS(2)
  local view = LY.vista
  check(view ~= nil, "no se abrió la página de Lya")
  if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
end)

print(("prueba_140_social: %d pasos"):format(pasos))
