-- Prueba de la 1.3.8, Horda y Alianza (tools/prueba.py la corre con las demás):
--   1. el Núcleo: tu facción, la marca «|~H» y el filtro de lo que llega;
--   2. todo lo que manda la Red de La Jauría lleva tu facción;
--   3. cada tipo de mensaje de la manada con la facción contraria no llega a
--      nadie (por la hermandad, el canal, el susurro o el grupo); con la tuya,
--      todo sigue igual; uno viejo sin marca solo por la hermandad o el grupo;
--   4. lo que va solo al grupo (ruta del grupo, marcadores, Lya): de alguien
--      del grupo de la otra facción, nada;
--   5. el canal oculto es uno por facción;
--   6. datos entre tus personajes: los de la otra facción, aparte.
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
local function check(cond, msg) if not cond then NOTE("1.3.8 facciones", msg) end end

local A = AlfaNucleo.A
local K = AlfaNucleo.Kit
local N = AlfaNucleo
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local MN = NS_OF("Alfa_Manada")
local R = MN and MN.Red

local function con(t, campos, fn)
  local antes = {}
  for k, v in pairs(campos) do antes[k] = { v = rawget(t, k) } rawset(t, k, v) end
  local ok, e = pcall(fn)
  for k, a in pairs(antes) do rawset(t, k, a.v) end
  if not ok then error(e) end
end

-- El grupo de la prueba: nombre -> facción del juego. «player» es Horda.
local grupo = {}
local function conGrupo(lista, fn)
  grupo = lista
  local function nombre(u) return (tostring(u):gsub("%-.*$", "")) end
  con(_G, {
    UnitFactionGroup = function(u)
      if u == "player" then return N.__miFaccion or "Horde", "Horda" end
      return grupo[nombre(u)]
    end,
    UnitInParty = function(u) return grupo[nombre(u)] ~= nil end,
    UnitInRaid = function() return nil end,
    Ambiguate = function(s) return s end,
  }, fn)
  grupo = {}
end

---------------------------------------------------------------------------
-- 1. El Núcleo
---------------------------------------------------------------------------

step("El Núcleo sabe tu facción y marca los mensajes", function()
  check(type(N.Faccion) == "function" and type(N.FiltroFaccion) == "function", "faltan N.Faccion / N.FiltroFaccion")
  if not N.FiltroFaccion then return end
  N.FaccionOlvidar()
  check(N.Faccion() == "Horde" and N.FaccionLetra() == "H", "tu facción no es la Horda: " .. tostring(N.Faccion()))
  check(N.ConFaccion("1P|1|2|3") == "1P|1|2|3|~H", "la marca no quedó al final: " .. tostring(N.ConFaccion("1P|1|2|3")))
  local l, f = N.SinFaccion("1P|1|2|3|~A")
  check(l == "1P|1|2|3" and f == "A", "la marca no se quitó bien")
  l, f = N.SinFaccion("1X")
  check(l == "1X" and f == nil, "un mensaje sin marca cambió")
  -- La matriz del filtro (sin grupo).
  conGrupo({}, function()
    local casos = {
      { "1P|1|~H", "GUILD", true }, { "1P|1|~H", "CHANNEL", true }, { "1P|1|~H", "WHISPER", true },
      { "1P|1|~A", "GUILD", false }, { "1P|1|~A", "CHANNEL", false }, { "1P|1|~A", "WHISPER", false },
      { "1P|1|~A", "PARTY", false }, { "1P|1|~A", "RAID", false },
      { "1P|1", "GUILD", true }, { "1P|1", "PARTY", true }, { "1P|1", "RAID", true },
      -- 1.3.8 revisión: un susurro sin marca (de un Alfa 1.3.7) pasa si no se sabe ajeno.
      { "1P|1", "CHANNEL", false }, { "1P|1", "WHISPER", true }, { "1P|1", "INSTANCE_CHAT", false },
    }
    for _, c in ipairs(casos) do
      local sigue, limpio = N.FiltroFaccion(c[1], c[2], "Ana Smith")
      check((sigue and true or false) == c[3], ("%s por %s: %s (quería %s)"):format(c[1], c[2], tostring(sigue), tostring(c[3])))
      if sigue then check(limpio == "1P|1", "llegó con la marca: " .. tostring(limpio)) end
    end
    check(N.FiltroFaccion(SECRETO("1P|1|~H"), "GUILD", "Ana") == false, "un texto secreto pasó")
    check(N.FiltroFaccion("1P|1|~H", SECRETO("GUILD"), "Ana") == false, "un canal secreto pasó")
    check(N.FiltroFaccion("1P|1|~H", "GUILD", SECRETO("Ana")) == false, "un remitente secreto pasó")
  end)
  -- Del grupo: el juego dice su facción.
  conGrupo({ Ana = "Horde", Alia = "Alliance" }, function()
    check(N.FaccionDe("Ana") == "H" and N.FaccionDe("Alia") == "A" and N.FaccionDe("Nadie") == nil, "la facción de los del grupo no se leyó")
    check(N.FiltroFaccion("1Y|H", "WHISPER", "Ana") == true, "un susurro viejo de alguien de tu grupo y tu facción no pasó")
    check(N.FiltroFaccion("1Y|H", "PARTY", "Alia") == false, "lo del grupo de la otra facción pasó (sin marca)")
    check(N.FiltroFaccion("1Y|H|~H", "PARTY", "Alia") == false, "lo del grupo de la otra facción pasó (con una marca falsa)")
    check(N.FaccionAjena("Alia") == true and N.FaccionAjena("Ana") == false and N.FaccionAjena("Nadie") == false, "N.FaccionAjena no distingue")
  end)
  -- Sin saber la tuya: solo lo que ya es de tu facción.
  con(_G, { UnitFactionGroup = function() return nil end }, function()
    N.FaccionOlvidar()
    check(N.ConFaccion("1H") == "1H", "sin facción se marcó")
    check(N.FiltroFaccion("1P|1|~H", "CHANNEL", "Ana") == false, "sin saber la tuya pasó algo por el canal")
    check(N.FiltroFaccion("1P|1|~H", "GUILD", "Ana") == true, "sin saber la tuya no pasó lo de la hermandad")
  end)
  N.FaccionOlvidar()
end)

---------------------------------------------------------------------------
-- 2 y 3. La Red de La Jauría
---------------------------------------------------------------------------

local TIPOS = { "G", "Q", "R", "V", "A", "B", "C", "D", "T", "N", "L", "O", "W", "U", "E", "S", "F", "M", "Y", "b", "a", "i", "p" }

step("Todo lo que manda la Red lleva tu facción", function()
  check(R ~= nil, "no hay Red de La Jauría")
  if not R then return end
  local salidos = {}
  A.Set("manada.compartir", true)
  R.Escuchar()
  con(R, { Via = function() return "hermandad" end }, function()
    con(_G, { IsInGuild = function() return true end }, function()
      con(C_ChatInfo, { SendAddonMessage = function(_, t, c, d) salidos[#salidos + 1] = { t, c, d } end }, function()
        R.Saludar()
        R.EnviarHermandad("prueba:h", "1E|n|60")
        R.EnviarLibre("prueba:l", "1a|p|60", "Ana Smith")
        R.Enviar("prueba:x", "1X")
        for _ = 1, 80 do FIRE(R.motor, "OnUpdate", 0.2) end
      end)
    end)
  end)
  A.Set("manada.compartir", false)
  check(#salidos >= 4, "no salieron los 4 mensajes: " .. #salidos)
  for _, s in ipairs(salidos) do
    check(type(s[1]) == "string" and s[1]:match("|~H$") ~= nil, "salió sin tu facción: " .. tostring(s[1]))
    check(s[2] ~= "CHANNEL" or true, "")
  end
end)

step("Lo de la otra facción no llega a nadie; lo tuyo, igual que antes", function()
  if not R then return end
  local oidos = {}
  local espias = {}
  for _, t in ipairs(TIPOS) do
    espias[t] = function(clave, remitente, via, campos, canal)
      oidos[#oidos + 1] = { t = t, quien = remitente, canal = canal, campos = campos }
    end
  end
  local G = MN.Gente
  local gente = {}
  A.Set("manada.compartir", true)
  R.Escuchar()
  local Cn = MN.Canal
  check(Cn.Nombres and Cn.Nombres() and Cn.NOMBRE == "AlfaJauriaH", "el canal no es el de la Horda: " .. tostring(Cn.NOMBRE))
  local function llega(texto, canal, quien)
    FIRE_EVENT("CHAT_MSG_ADDON", "AlfaManada", texto, canal, quien, "", "", canal == "CHANNEL" and 7 or 0, canal == "CHANNEL" and Cn.NOMBRE or "")
  end
  con(R.Oyentes, espias, function()
    con(G, {
      Oido = function(clave, remitente, via, d) gente[#gente + 1] = { quien = remitente, via = via, d = d } end,
      Olvidar = function(clave) gente[#gente + 1] = { olvido = clave } end,
    }, function()
      con(MN.U, { EnElClan = function() return true end }, function()
        local respuestas = 0
        con(R, { Enviar = function(clave) if tostring(clave):match("^K:") then respuestas = respuestas + 1 end return true end }, function()
          conGrupo({}, function()
            -- La otra facción, por cada camino.
            local n = 0
            for _, canal in ipairs({ "GUILD", "CHANNEL", "WHISPER", "PARTY", "RAID" }) do
              for _, t in ipairs(TIPOS) do
                n = n + 1
                llega("1" .. t .. "|1|2|3|4|5|~A", canal, "Alia" .. n)
              end
              llega("1H|1.3.8|1|~A", canal, "AliaH" .. canal)
              llega("1P|1453|40.00|50.00|30|MAGE|~A", canal, "AliaP" .. canal)
              llega("1X|~A", canal, "AliaX" .. canal)
              llega("1J|1.3.8|~A", canal, "AliaJ" .. canal)
            end
            check(#oidos == 0, "llegó algo de la otra facción: " .. (oidos[1] and (oidos[1].t .. " por " .. tostring(oidos[1].canal)) or ""))
            check(#gente == 0, "la otra facción quedó en la manada: " .. (gente[1] and tostring(gente[1].quien) or ""))
            check(respuestas == 0, "se le contestó «Quiero unirme» a la otra facción")

            -- Tu facción: todo llega como antes (y sin la marca).
            for _, t in ipairs(TIPOS) do llega("1" .. t .. "|1|2|3|4|5|~H", "GUILD", "Ana" .. t) end
            check(#oidos == #TIPOS, ("de tu facción no llegó todo: %d de %d"):format(#oidos, #TIPOS))
            local ultimo = oidos[#oidos]
            check(ultimo and ultimo.campos and #ultimo.campos == 5 and ultimo.campos[5] == "5", "los campos llegaron con la marca: " .. tostring(ultimo and ultimo.campos and ultimo.campos[#ultimo.campos]))
            llega("1P|1453|40.00|50.00|30|MAGE|~H", "CHANNEL", "Beto")
            check(#gente == 1 and gente[1].d and gente[1].d.map == 1453 and gente[1].d.clase == "MAGE", "tu posición no llegó por el canal")
            llega("1J|1.3.8|~H", "WHISPER", "Caro")
            check(respuestas == 1, "a tu facción no se le contestó «Quiero unirme»")

            -- Un Alfa viejo (sin marca): por la hermandad y por susurro sí (el susurro
            -- no cruza facciones; 1.3.8 revisión); por el canal, no.
            oidos, gente = {}, {}
            llega("1G|1453|8001|1", "GUILD", "Viejo1")
            llega("1G|1453|8001|1", "CHANNEL", "Viejo2")
            llega("1U|5|3575|2|Lingote", "WHISPER", "Viejo3")
            llega("1P|1453|40.00|50.00|30|MAGE", "CHANNEL", "Viejo4")
            check(#oidos == 2 and oidos[1].quien == "Viejo1" and oidos[2].quien == "Viejo3", "lo viejo sin marca no se trató bien: " .. #oidos)
            check(#gente == 0, "una posición vieja sin marca llegó por el canal")
          end)
          -- Un susurro viejo de alguien de tu grupo y tu facción: sí (las Lyas del grupo).
          oidos = {}
          conGrupo({ Ana = "Horde", Alia = "Alliance" }, function()
            llega("1Y|H", "WHISPER", "Ana")
            llega("1Y|H", "WHISPER", "Alia")
            llega("1Y|H|~H", "WHISPER", "Alia")
          end)
          check(#oidos == 1 and oidos[1].quien == "Ana", "los susurros del grupo no se trataron bien: " .. #oidos)
        end)
      end)
    end)
  end)
  A.Set("manada.compartir", false)
end)

---------------------------------------------------------------------------
-- 4. Lo que va solo al grupo
---------------------------------------------------------------------------

step("Ruta del grupo, marcadores y Lya: nada de alguien del grupo de la otra facción", function()
  local Rt = NS_OF("Alfa_Rutas")
  local RG = Rt and Rt.RutaGrupo
  local Ly = NS_OF("Alfa_Lya")
  local Gr = Ly and Ly.EnGrupo
  local oidos = {}
  local function espia(nombre) return function(...) oidos[#oidos + 1] = { nombre, ... } return true end end
  local function probar(fn)
    if RG then con(RG, { AlMensaje = espia("ruta") }, function() fn() end) else fn() end
  end
  probar(function()
    local function conLya(f) if Gr then con(Gr, { Mensaje = espia("lya") }, f) else f() end end
    conLya(function()
      conGrupo({ Ana = "Horde", Alia = "Alliance" }, function()
        FIRE_EVENT("CHAT_MSG_ADDON", "Alfa", "3W|1453|40|50||Aquí", "PARTY", "Alia")
        if Gr then FIRE_EVENT("CHAT_MSG_ADDON", Gr.PREFIJO, "1H", "PARTY", "Alia") end
        check(#oidos == 0, "llegó algo del grupo de la otra facción: " .. tostring(oidos[1] and oidos[1][1]))
        FIRE_EVENT("CHAT_MSG_ADDON", "Alfa", "3W|1453|40|50||Aquí", "PARTY", "Ana")
        if Gr then FIRE_EVENT("CHAT_MSG_ADDON", Gr.PREFIJO, "1H", "PARTY", "Ana") end
        check(#oidos == (RG and 1 or 0) + (Gr and 1 or 0), "lo del grupo de tu facción no llegó: " .. #oidos)
        check(not RG or (oidos[1] and oidos[1][2] == "3W|1453|40|50||Aquí"), "la ruta del grupo llegó cambiada")
      end)
    end)
  end)
  -- Marcadores (AlfaMarca): uno de la otra facción no crea nada.
  local Mu = NS_OF("Alfa_Mundo")
  local Mk = Mu and Mu.Marcadores
  if Mk and Mk.Crear then
    local creados = 0
    con(Mk, { Crear = function() creados = creados + 1 return nil end }, function()
      conGrupo({ Alia = "Alliance" }, function()
        con(_G, { IsInGroup = function() return true end }, function()
          FIRE_EVENT("CHAT_MSG_ADDON", "AlfaMarca", "1|1453|4000|5000|huella|acento|Cueva", "PARTY", "Alia")
        end)
      end)
    end)
    check(creados == 0, "un marcador de la otra facción llegó")
  end
  -- El motor: el avance del grupo y los barcos revisan lo mismo (parche de Party.lua y Transit.lua).
  check(type(N.FaccionAjena) == "function", "el motor no tiene N.FaccionAjena")
end)

---------------------------------------------------------------------------
-- 5. El canal oculto, uno por facción
---------------------------------------------------------------------------

step("El canal oculto es uno por facción", function()
  local Cn = MN and MN.Canal
  if not Cn then return end
  check(Cn.NOMBRE == "AlfaJauriaH" and Cn.NOMBRES[2] == "AlfaJauriaH2", "la Horda no tiene su canal: " .. tostring(Cn.NOMBRE))
  check(Cn.EsNuestro("5. AlfaJauriaH") and not Cn.EsNuestro("AlfaJauriaA") and not Cn.EsNuestro("AlfaJauria"), "EsNuestro acepta el de otra facción o el viejo")
  -- Una Alianza arma el suyo.
  local antes, nombres, nombre = Cn.faccion, Cn.NOMBRES, Cn.NOMBRE
  Cn.faccion = nil
  N.__miFaccion = "Alliance"
  conGrupo({}, function()
    N.FaccionOlvidar()
    Cn.Nombres()
    check(Cn.NOMBRE == "AlfaJauriaA", "la Alianza no tiene su canal: " .. tostring(Cn.NOMBRE))
    -- Y lo de la Horda ya no le llega.
    check(N.FiltroFaccion("1P|1|~H", "CHANNEL", "Toro") == false, "a la Alianza le llegó lo de la Horda")
    check(N.FiltroFaccion("1P|1|~A", "CHANNEL", "Elfa") == true, "a la Alianza no le llegó lo suyo")
  end)
  N.__miFaccion = nil
  N.FaccionOlvidar()
  Cn.faccion, Cn.NOMBRES, Cn.NOMBRE = antes, nombres, nombre
end)

---------------------------------------------------------------------------
-- 6. Datos entre tus personajes
---------------------------------------------------------------------------

step("Tus personajes de la otra facción, aparte y marcados; nada se pierde", function()
  local B = NS_OF("Alfa_Bolsas")
  local D = B and B.Datos
  check(D and D.OtraFaccion and D.Lista, "Bolsas no tiene D.OtraFaccion")
  if not (D and D.OtraFaccion) then return end
  local lista = D.Raiz().personajes
  local yo = D.Clave()
  local copia = {}
  for k, v in pairs(lista) do copia[k] = v end
  local function bolsa(id, n) return { [0] = { n = 4, { i = id, c = n } } } end
  lista["Zed-Reino"] = { nombre = "Zed", reino = "Reino", faccion = "Alliance", clase = "MAGE", dinero = 5000, bolsas = bolsa(2589, 7), v = 1 }
  lista["Ana-Reino"] = { nombre = "Ana", reino = "Reino", faccion = "Horde", clase = "WARRIOR", dinero = 3000, bolsas = bolsa(2589, 4), v = 1 }
  lista["Viejo-Reino"] = { nombre = "Viejo", reino = "Reino", clase = "ROGUE", dinero = 1000, bolsas = bolsa(2589, 2), v = 1 } -- (sin facción: versión vieja)
  local l = D.Lista()
  local orden = {}
  for i, p in ipairs(l) do orden[i] = p.r.nombre or p.clave end
  check(l[1] and l[1].clave == yo, "tú no vas primero")
  check(l[#l] and l[#l].r.nombre == "Zed" and l[#l].otraFaccion == true, "la Alianza no va al final y marcada: " .. table.concat(orden, ","))
  for _, p in ipairs(l) do
    if p.r.nombre == "Ana" or p.r.nombre == "Viejo" then check(not p.otraFaccion, p.r.nombre .. " quedó como de la otra facción") end
  end
  -- El oro de toda la cuenta suma a todos.
  local total = D.DineroCuenta()
  check(total >= 9000, "el oro de toda la cuenta no suma a la otra facción: " .. tostring(total))
  -- Lo que puedes mandarte por correo no cuenta a la otra facción.
  local _, otros = D.Sumas(2589)
  check(otros == 6, "las sumas cuentan a la otra facción: " .. tostring(otros))
  local linea = D.LineaCuadro(2589) or ""
  check(linea:find("Zed", 1, true) and linea:find("(Alianza)", 1, true), "el cuadro del objeto no marca a la otra facción: " .. linea)
  -- Nada se borró.
  check(lista["Zed-Reino"] and lista["Viejo-Reino"] and lista["Ana-Reino"], "se perdió un personaje")
  for k in pairs(lista) do if not copia[k] and k ~= "Zed-Reino" and k ~= "Ana-Reino" and k ~= "Viejo-Reino" then check(false, "apareció " .. k) end end
  lista["Zed-Reino"], lista["Ana-Reino"], lista["Viejo-Reino"] = nil, nil, nil
end)

---------------------------------------------------------------------------
-- 7. Las guías: solo las de tu facción, y las lejanas sin armar
---------------------------------------------------------------------------

step("Solo las guías de tu facción; las de clase lejanas no se arman al entrar", function()
  local G = Alfa and Alfa.Guides
  check(G and G.List, "no hay guías")
  if not (G and G.List) then return end
  local otras, armadasLejos, n = 0, {}, 0
  local nivel = UnitLevel("player")
  for _, h in ipairs(G.List()) do
    n = n + 1
    local g = G.Get(h.id)
    local fa = g and rawget(g, "faction")
    if type(fa) == "string" and fa:lower() == "alliance" then otras = otras + 1 end
    if g and rawget(g, "category") == "Class" and rawget(g, "steps") ~= nil and rawget(g, "stepsSrc") ~= nil
      and (tonumber(rawget(g, "minLevel")) or 0) > nivel + 10 then
      armadasLejos[#armadasLejos + 1] = h.id
    end
  end
  check(n > 100, "muy pocas guías: " .. n)
  check(otras == 0, "se leyeron guías de la Alianza: " .. otras)
  check(#armadasLejos == 0, "se armaron guías de clase lejanas: " .. table.concat(armadasLejos, ", "))
  local CQ = Alfa.QoL and Alfa.QoL.ClassQuests
  check(CQ and CQ.Lejana, "falta ClassQuests.Lejana (parche 1.3.8)")
  if CQ and CQ.Lejana then
    check(CQ.Lejana({ minLevel = 60, maxLevel = 60 }, 23) == true, "una de nivel 60 no es lejana a nivel 23")
    check(CQ.Lejana({ minLevel = 10, maxLevel = 11 }, 23) == true, "una superada (10-11) no es lejana a nivel 23")
    check(CQ.Lejana({ minLevel = 30, maxLevel = 40 }, 23) == false, "una de 30-40 es lejana a nivel 23")
    check(CQ.Lejana({ minLevel = 20, maxLevel = 32 }, 23) == false, "una de 20-32 es lejana a nivel 23")
  end
  -- Pedida, se arma igual.
  local g = G.Get("forever/class/warrior/quelserrar")
  if g then
    local pasos = g.steps
    check(type(pasos) == "table" and #pasos > 0, "una guía lejana no se abre al pedirla")
    if G.Release then G.Release(g.id) end
  end
end)

---------------------------------------------------------------------------
-- 8. Lo de tu facción primero (Enciclopedia)
---------------------------------------------------------------------------

step("Enciclopedia: los PNJ de tu facción primero; con el filtro, solo los tuyos", function()
  local E = NS_OF("Alfa_Enciclopedia")
  local Cat = E and E.Cat
  check(Cat and Cat.PorBando and Cat.BANDOS_PNJ, "la Enciclopedia no ordena por facción")
  if not (Cat and Cat.PorBando) then return end
  local bandos = { [1] = "A", [2] = "H", [3] = false, [4] = "A", [5] = "H" }
  local c = { id = { 1, 2, 3, 4, 5 } }
  con(Cat, { BandoPnj = function(id) return bandos[id] end }, function()
    local s = { 1, 2, 3, 4, 5 }
    local n = Cat.PorBando(c, s, 5, {})
    check(n == 5 and table.concat(s, ",") == "2,3,5,1,4", "no van primero los de la Horda (y los de los dos): " .. table.concat(s, ","))
    s = { 1, 2, 3, 4, 5 }
    n = Cat.PorBando(c, s, 5, { bando = "mio" })
    check(n == 3 and #s == 3 and table.concat(s, ",") == "2,3,5", "«Solo tu facción» dejó a la Alianza: " .. table.concat(s, ","))
  end)
end)

print(("1.3.8 facciones: %d pasos"):format(pasos))
