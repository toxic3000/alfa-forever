-- Prueba de la 1.3.9, calidad interna (tools/prueba.py la corre con las
-- demás). Los números son los del plan (docs/PLAN-1.3.9.md):
--   20. la Enciclopedia arma los filtros de los objetos antes que los demás catálogos;
--   19. Hoy, el rastreador y el Escritorio comparten una lectura de la guía por segundo;
--   21. volver a abrir las páginas no deja memoria;
--   97. todos los comandos /alfa: ninguno da error y todos responden algo
--       (una línea en el chat, un aviso, una ventana, un ajuste o un evento);
--   98. cada aviso de Alfa (K.Aviso) en los 10 idiomas: el título y el texto
--       caben en su tarjeta (los renglones de verdad, con las letras chinas,
--       japonesas y coreanas más anchas que las latinas);
--   24. /alfa reportar: los datos que adjunta (versión, módulos, modo,
--       memoria y los últimos errores) sin el nombre ni el reino;
--   23. una sesión larga: 3 horas simuladas al paso real del reloj, con
--       eventos de juego, combates y avisos, sin que crezcan la memoria, las
--       tareas del reloj, los marcos ni los datos guardados (22).
-- Lo que falla por algo de otra área sale con su nombre en FALLA EN.
local function step(nombre, fn, ...)
  local antes = #ERRORS
  local ok, e = xpcall(fn, debug.traceback, ...)
  if not ok then NOTE("paso " .. nombre, e) end
  if #ERRORS > antes then
    print("FALLA EN: " .. nombre)
    for i = antes + 1, #ERRORS do print("   " .. tostring(ERRORS[i]):sub(1, 700)) end
  end
end
local function check(cond, msg) if not cond then NOTE("1.3.9 calidad", msg) end end

if WorldMapFrame and WorldMapFrame.Hide then WorldMapFrame:Hide() end
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
do -- la bienvenida ya se vio (la del primer día tiene su propia prueba)
  local B = AlfaBienvenida
  AlfaNucleo.Datos("bienvenida").respondio = B and B.VERSION or 99
  AlfaNucleo.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
NOW = NOW + 120

local N = AlfaNucleo
local A = N.A
local K = N.Kit
if N.Entrando then N.Entrando = function() return false end end
if A.UI.Options.frame then A.UI.Options.frame:Hide() end

-- Lo que un comando puede hacer para que se note.
local respuestas = 0
local function envolver(t, nombre)
  local f = t and rawget(t, nombre)
  if type(f) ~= "function" then return end
  rawset(t, nombre, function(...) respuestas = respuestas + 1 return f(...) end)
end
envolver(K, "Aviso")
envolver(K, "Anuncio")
envolver(N, "Imprimir")
envolver(A, "Fire")
envolver(A, "Set")
envolver(A, "Print")
if AlfaLya then envolver(AlfaLya, "Decir") envolver(AlfaLya, "Hablar") end
local base = {}
local function visibles()
  local n = 0
  for _, f in ipairs(ALL_FRAMES()) do if f.IsVisible and f:IsVisible() then n = n + 1 end end
  return n
end

---------------------------------------------------------------------------
-- 20. La Enciclopedia: los filtros de los objetos no esperan a los demás catálogos
---------------------------------------------------------------------------
step("20. Los filtros de los objetos van primero", function()
  local E = NS_OF("Alfa_Enciclopedia")
  if not (E and E.V and E.Tarea and E.Cat) then print("AVISO: no está la Enciclopedia") return end
  local orden = {}
  local Tarea = E.Tarea
  E.Tarea = function(nombre, paso, fin, primero)
    return Tarea(nombre, paso, function(...) orden[#orden + 1] = nombre if fin then return fin(...) end end, primero)
  end
  E.V.Abrir({ texto = "" })
  for _ = 1, 400 do
    RUN_TIMERS(1)
    if E.Cat.Facetas().nivel then break end
  end
  E.Tarea = Tarea
  if E.V.Cerrar then E.V.Cerrar() end
  local pos, ultimoCat = {}, 0
  for i, n in ipairs(orden) do pos[n] = pos[n] or i if n:find("^cat:") then ultimoCat = i end end
  check(E.Cat.Facetas().lista, "los filtros de tipo y ranura no quedaron listos")
  check(pos.facetas and pos["cat:objeto"] and pos.facetas < ultimoCat,
    "los filtros de los objetos esperaron a todos los catálogos: " .. table.concat(orden, ", "))
end)

---------------------------------------------------------------------------
-- 19. Hoy, el rastreador y el Escritorio comparten una lectura de la guía por segundo
---------------------------------------------------------------------------
step("19. Una sola lectura de la guía por segundo", function()
  check(type(N.VistaPaso) == "function" and type(N.Compartido) == "function", "falta N.VistaPaso o N.Compartido (Reloj.lua)")
  local E = A.Engine
  if not (N.VistaPaso and E and E.GetStepView and E.GetLiveStep) then return end
  local vivo = E.GetLiveStep()
  if type(vivo) ~= "number" then print("AVISO: sin paso vivo en el banco") return end
  local real, lecturas = E.GetStepView, 0
  E.GetStepView = function(i, ...)
    local v = real(i, ...)
    if i ~= vivo or type(v) ~= "table" then return v end
    lecturas = lecturas + 1
    local copia = {}
    for k, x in pairs(v) do copia[k] = x end
    copia._lectura = lecturas
    return copia
  end
  local ok, e = pcall(function()
    -- Hoy (AlfaInicio.Paso), el rastreador y el panel del Escritorio en el mismo segundo.
    N.Olvidar()
    local antes = lecturas
    for _ = 1, 3 do
      if AlfaInicio and AlfaInicio.Paso then AlfaInicio.Paso() end
      N.VistaPaso(vivo)
    end
    check(lecturas - antes == 1, "en un segundo la guía se leyó " .. (lecturas - antes) .. " veces (debía ser 1)")
    -- Un cambio de la guía la olvida enseguida; un segundo después, también.
    local v1 = N.VistaPaso(vivo)
    A.Fire("STEP_UPDATED")
    local v2 = N.VistaPaso(vivo)
    check(v1 and v2 and (v2._lectura or 0) > (v1._lectura or 0), "después de un cambio de la guía se leyó la vista vieja")
    NOW = NOW + 1.5
    local v3 = N.VistaPaso(vivo)
    check(v3 and (v3._lectura or 0) > (v2._lectura or 0), "un segundo después no se volvió a leer")
    -- Lo mismo que leer directo.
    local x, y = N.VistaPaso(vivo), real(vivo)
    check(type(x) == "table" and type(y) == "table" and x.title == y.title, "la vista compartida no es la del motor")
  end)
  E.GetStepView = real
  if not ok then error(e, 0) end
end)

---------------------------------------------------------------------------
-- 97. Todos los comandos /alfa
---------------------------------------------------------------------------
local function comandos()
  local lista, orden
  for i = 1, 20 do
    local nombre, v = debug.getupvalue(A.RegisterCommand, i)
    if not nombre then break end
    if nombre == "commands" then lista = v elseif nombre == "commandOrder" then orden = v end
  end
  return lista, orden
end
-- Los que no se pueden probar en el banco, con su porqué.
local NO_SE_PRUEBA = {}
-- Los que no dicen nada a propósito (su porqué).
local CALLADOS = {
  debug = "solo prende el registro interno del motor",
}

step("97. Todos los comandos /alfa responden sin error", function()
  local lista, orden = comandos()
  check(type(lista) == "table" and type(orden) == "table" and #orden > 40, "no encontré la lista de comandos del motor")
  if not orden then return end
  local SlashAlfa = SlashCmdList and SlashCmdList.ALFA
  check(type(SlashAlfa) == "function", "no está /alfa (SlashCmdList.ALFA)")
  local correr = SlashAlfa or A.RunCommand
  local probados, mudos = 0, {}
  base = {}
  for _, f in ipairs(ALL_FRAMES()) do if f.IsShown and f:IsShown() then base[f] = true end end
  local function una(texto)
    local antesE, antesP, antesR, antesV = #ERRORS, rawget(_G, "PRINTED") or 0, respuestas, visibles()
    local ok, e = pcall(correr, texto)
    if not ok then NOTE("/alfa " .. texto, e) end
    RUN_TIMERS(2)
    local dijo = (rawget(_G, "PRINTED") or 0) ~= antesP or respuestas ~= antesR or visibles() ~= antesV
    -- Lo que el comando dejó abierto (y el escritorio o el modo zen) no
    -- tapa al siguiente: se cierra todo lo nuevo de arriba.
    if UIParent and not UIParent:IsShown() then UIParent:Show() end
    for _, f in ipairs(ALL_FRAMES()) do
      if not base[f] and f.IsShown and f:IsShown() and f.Hide then
        local p = f.GetParent and f:GetParent()
        if p == nil or p == UIParent or base[p] then pcall(f.Hide, f) end
      end
    end
    return dijo, #ERRORS > antesE
  end
  for _, nombre in ipairs(orden) do
    if not NO_SE_PRUEBA[nombre] then
      probados = probados + 1
      local dijo, fallo = una(nombre)
      if fallo then print("   /alfa " .. nombre .. ": dio un error") end
      if not dijo and not CALLADOS[nombre] then mudos[#mudos + 1] = nombre end
      -- Con algo raro detrás, tampoco se rompe.
      local _, fallo2 = una(nombre .. " zzz 123")
      if fallo2 then print("   /alfa " .. nombre .. " zzz 123: dio un error") end
    end
  end
  -- /alfa solo, /alfa help y uno que no existe.
  for _, t in ipairs({ "", "help", "estenoexiste" }) do
    local dijo = una(t)
    check(dijo, "/alfa " .. t .. " no respondió")
  end
  print(("COMANDOS: %d probados (con y sin algo detrás), %d sin respuesta"):format(probados, #mudos))
  check(#mudos == 0, "comandos que no responden nada: /alfa " .. table.concat(mudos, ", /alfa "))
end)

---------------------------------------------------------------------------
-- 98. Cada aviso en los 10 idiomas
---------------------------------------------------------------------------
-- Los avisos se buscan en el código (cada K.Aviso con su título y su texto
-- en L["..."]), se traducen con los diccionarios de cada idioma y se arman de
-- verdad. Luego se cuentan sus renglones con un ancho de letra más real que
-- el del banco: las letras CJK miden casi un cuadro entero.
local DIST = (os.getenv and os.getenv("ALFA_DIST")) or "dist"
local function leer(ruta)
  local f = io and io.open(ruta, "rb")
  if not f then return nil end
  local s = f:read("*a")
  f:close()
  return s
end
local function leerJson(ruta)
  local s = leer(ruta)
  if not s then return {} end
  local out = {}
  local function cadena(i)
    local partes = {}
    i = i + 1
    while true do
      local c = s:sub(i, i)
      if c == "" then return table.concat(partes), i end
      if c == '"' then return table.concat(partes), i + 1 end
      if c == "\\" then
        local e = s:sub(i + 1, i + 1)
        if e == "n" then partes[#partes + 1] = "\n" elseif e == "t" then partes[#partes + 1] = "\t"
        elseif e == "u" then
          local cp = tonumber(s:sub(i + 2, i + 5), 16) or 63
          if cp < 0x80 then partes[#partes + 1] = string.char(cp)
          elseif cp < 0x800 then partes[#partes + 1] = string.char(0xC0 + math.floor(cp / 64), 0x80 + cp % 64)
          else partes[#partes + 1] = string.char(0xE0 + math.floor(cp / 4096), 0x80 + math.floor(cp / 64) % 64, 0x80 + cp % 64) end
          i = i + 4
        else partes[#partes + 1] = e end
        i = i + 2
      else
        partes[#partes + 1] = c
        i = i + 1
      end
    end
  end
  local i = 1
  while true do
    local a = s:find('"', i, true)
    if not a then break end
    local k, j = cadena(a)
    local dos = s:find(":", j, true)
    local b = dos and s:find('"', dos, true)
    if not b then break end
    local v, j2 = cadena(b)
    out[k] = v
    i = j2
  end
  return out
end
local function archivosDe(carpeta, patron)
  local out = {}
  local p = io and io.popen and io.popen('dir /b "' .. carpeta:gsub("/", "\\") .. '" 2>nul')
  if not p then return out end
  for l in p:lines() do if l:match(patron) then out[#out + 1] = l end end
  p:close()
  return out
end

-- Los avisos del código: { archivo, titulo = clave, texto = clave }.
local function avisosDelCodigo()
  local out, vistos = {}, {}
  local function clave(s)
    local f = loadstring('return "' .. s .. '"')
    local ok, v = pcall(f or error)
    return ok and v or s
  end
  for _, nombre in ipairs(ARCHIVOS_CARGADOS or {}) do
    local s = nombre:find("Textos.lua", 1, true) == nil and nombre:find("Idiomas", 1, true) == nil and leer(DIST .. "/" .. nombre:gsub("\\", "/"))
    local i = 1
    while s do
      local a, b = s:find("K%.Aviso%(", i)
      if not a then break end
      -- Hasta su paréntesis de cierre (saltando textos).
      local prof, j, n = 1, b + 1, #s
      while j <= n and prof > 0 do
        local c = s:sub(j, j)
        if c == '"' or c == "'" then
          local k = j + 1
          while k <= n and s:sub(k, k) ~= c do k = k + (s:sub(k, k) == "\\" and 2 or 1) end
          j = k
        elseif c == "(" then prof = prof + 1
        elseif c == ")" then prof = prof - 1 end
        j = j + 1
      end
      local cuerpo = s:sub(b + 1, j - 2)
      local t = cuerpo:match('titulo%s*=%s*L%["(.-)"%]')
      local x = cuerpo:match('texto%s*=%s*L%["(.-)"%]') or cuerpo:match('texto%s*=%s*format%(%s*L%["(.-)"%]')
        or cuerpo:match('texto%s*=%s*[%w_.]+%.format%(%s*L%["(.-)"%]')
      if t or x then
        local id = tostring(t) .. "|" .. tostring(x)
        if not vistos[id] then
          vistos[id] = true
          out[#out + 1] = { archivo = nombre, titulo = t and clave(t), texto = x and clave(x) }
        end
      end
      i = j
    end
  end
  return out
end

local IDIOMAS = { "esMX", "esES", "enUS", "deDE", "frFR", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }
local function diccionario(loc)
  if loc == "esMX" or loc == "esES" then return {} end
  local d = {}
  if loc == "enUS" then
    for _, nombre in ipairs(ARCHIVOS_CARGADOS or {}) do
      local mod = nombre:match("^(Alfa_[%w_]+)\\Textos%.lua$")
      if mod then
        local f = loadfile(DIST .. "/" .. nombre:gsub("\\", "/"))
        local M2 = {}
        if f and pcall(f, mod, M2) and type(M2.EN) == "table" then for k, v in pairs(M2.EN) do d[k] = v end end
      end
    end
    return d
  end
  local f = loadfile("src/Alfa_Nucleo/Idiomas/" .. loc .. ".lua")
  if f then
    local gl, prev = GetLocale, rawget(_G, "AlfaNucleoIdiomas")
    GetLocale = function() return loc end
    AlfaNucleoIdiomas = {}
    pcall(f)
    d = AlfaNucleoIdiomas[loc] or {}
    GetLocale, AlfaNucleoIdiomas = gl, prev
  end
  -- Lo de esta versión que aún no está en Idiomas/ (textos.py generar lo junta al final).
  for _, archivo in ipairs(archivosDe("textos/" .. loc, "^Alfa_1%.3%.9.*%.json$")) do
    for k, v in pairs(leerJson("textos/" .. loc .. "/" .. archivo)) do if d[k] == nil then d[k] = v end end
  end
  return d
end

-- Ancho de cada letra: CJK y hangul casi un cuadro; mayúsculas un poco más.
local function anchoLetra(cp, tam)
  if cp >= 0x1100 and (cp <= 0x11FF or cp >= 0x2E80) then return tam * 1.0 end
  if cp >= 0x41 and cp <= 0x5A then return tam * 0.66 end
  if cp == 0x20 then return tam * 0.28 end
  return tam * 0.56
end
local function letras(s)
  local out = {}
  for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
    local b1 = ch:byte(1)
    local cp = b1
    if #ch == 2 then cp = (b1 % 32) * 64 + ch:byte(2) % 64
    elseif #ch == 3 then cp = (b1 % 16) * 4096 + (ch:byte(2) % 64) * 64 + ch:byte(3) % 64
    elseif #ch >= 4 then cp = 0x10000 end
    out[#out + 1] = { ch, cp }
  end
  return out
end
local function plano(s) return (tostring(s or ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "WW")) end
-- Renglones al envolver en `ancho` (por palabras; CJK se parte en cualquier letra).
local function renglones(texto, tam, ancho)
  local total = 0
  for parrafo in (plano(texto) .. "\n"):gmatch("(.-)\n") do
    local n, x, wp = 1, 0, 0
    local function poner(w)
      if w <= 0 then return end
      if x > 0 and x + w > ancho then n = n + 1 x = 0 end
      while w > ancho do n = n + 1 w = w - ancho end
      x = x + w
    end
    for _, l in ipairs(letras(parrafo)) do
      local w = anchoLetra(l[2], tam)
      if l[2] == 0x20 then
        poner(wp) wp = 0
        x = x + w
      elseif l[2] >= 0x2E80 then
        poner(wp) wp = 0
        poner(w)
      else
        wp = wp + w
      end
    end
    poner(wp)
    total = total + n
  end
  return total
end
local function anchoDe(texto, tam)
  local m = 0
  for linea in (plano(texto) .. "\n"):gmatch("(.-)\n") do
    local w = 0
    for _, l in ipairs(letras(linea)) do w = w + anchoLetra(l[2], tam) end
    if w > m then m = w end
  end
  return m
end
-- Los huecos de format con un relleno largo pero creíble.
local function llenar(s)
  if type(s) ~= "string" then return s end
  s = s:gsub("%%%%", "\1")
  s = s:gsub("%%%d*%$?[%-%+ #0]*%d*%.?%d*([sdifgxq])", function(t)
    if t == "s" or t == "q" then return "Bosque de Argénteos" end
    if t == "d" or t == "i" or t == "x" then return "120" end
    return "99.5"
  end)
  return (s:gsub("\1", "%%"))
end

step("98. Cada aviso en los 10 idiomas cabe en su tarjeta", function()
  local avisos = avisosDelCodigo()
  check(#avisos >= 40, "encontré muy pocos avisos en el código: " .. #avisos)
  local revisados, faltan, malos, peor, cortados = 0, 0, {}, {}, {}
  for _, loc in ipairs(IDIOMAS) do
    local d = diccionario(loc)
    local function tr(k)
      if not k then return nil end
      local v = d[k]
      if v == nil and loc ~= "esMX" and loc ~= "esES" then faltan = faltan + 1 end
      return llenar(N.SinContexto and N.SinContexto(v or k) or (v or k))
    end
    for _, av in ipairs(avisos) do
      local o = { titulo = tr(av.titulo), texto = tr(av.texto), lya = false, pedido = true, icono = "ic-info", sonido = false }
      local ok, a = pcall(K.Aviso, o)
      check(ok, loc .. ": K.Aviso dio error con «" .. tostring(av.titulo or av.texto) .. "»: " .. tostring(a))
      if ok and type(a) == "table" and a.Titulo then
        revisados = revisados + 1
        local function medir(fs, que, texto)
          if not (fs and texto and texto ~= "") then return end
          local tam = (fs._font and fs._font[2]) or 12
          local w = fs._w or 0
          if w <= 0 then return end
          if fs._wrap then
            local nr = renglones(texto, tam, w)
            local maxl = fs._max or 0
            if maxl > 0 and nr > maxl then
              malos[#malos + 1] = ("%s, %s (%d de %d renglones): %s · %s"):format(loc, que, nr, maxl, plano(texto):sub(1, 80), av.archivo)
              cortados[#cortados + 1] = { loc = loc, o = o }
            end
            if not peor[loc] or nr > peor[loc].n then peor[loc] = { n = nr, o = o } end
          else
            local aw = anchoDe(texto, tam)
            if aw > w + 2 then
              malos[#malos + 1] = ("%s, %s (%d de %d px): %s · %s"):format(loc, que, aw, w, plano(texto):sub(1, 80), av.archivo)
              cortados[#cortados + 1] = { loc = loc, o = o }
            end
          end
        end
        medir(a.Titulo, "título", o.titulo)
        medir(a.Texto, "texto", o.texto)
        if a.Cerrar then pcall(a.Cerrar, a, a.turno) end
      end
    end
    RUN_TIMERS(1)
  end
  print(("AVISOS: %d avisos del código x %d idiomas = %d revisados; %d se cortan; %d textos sin traducir (salen en español)")
    :format(#avisos, #IDIOMAS, revisados, #malos, faltan))
  for i = 1, math.min(#malos, 30) do print("   se corta: " .. malos[i]) end
  check(#malos == 0, #malos .. " avisos se cortan en algún idioma (arriba la lista)")
  -- Con BANCO_CAPTURAS, el más largo de cada idioma, para mirarlo.
  if os.getenv and os.getenv("BANCO_CAPTURAS") then
    SNAPSHOTS = SNAPSHOTS or {}
    local lista = {}
    for loc, x in pairs(peor) do lista[#lista + 1] = { nombre = "aviso-" .. loc, o = x.o } end
    for i, x in ipairs(cortados) do lista[#lista + 1] = { nombre = ("aviso-corta-%02d-%s"):format(i, x.loc), o = x.o } end
    for _, x in ipairs(lista) do
      local a = K.Aviso(x.o)
      if type(a) == "table" then
        local entries, l, b, w, h = DUMP(a)
        SNAPSHOTS[x.nombre] = { entries = entries, l = l, b = b, w = w, h = h }
        if a.Cerrar then pcall(a.Cerrar, a, a.turno) end
      end
    end
  end
end)

---------------------------------------------------------------------------
-- 24. Los datos que adjunta /alfa reportar
---------------------------------------------------------------------------
step("24. /alfa reportar adjunta versión, módulos y errores sin datos privados", function()
  check(type(N.InformeTecnico) == "function" and type(N.SinPrivado) == "function", "falta N.InformeTecnico o N.SinPrivado (Informe.lua)")
  if not N.InformeTecnico then return end
  local lineas = N.InformeTecnico()
  local todo = table.concat(lineas, "\n")
  check(todo:find("Rutas", 1, true) and todo:find("Lya", 1, true), "el informe no dice los módulos: " .. todo)
  check(todo:find("MB", 1, true), "el informe no dice la memoria: " .. todo)
  -- Un error que nombra al personaje, al reino y a otro jugador.
  local s = N.SinPrivado("Alfa_Manada\\Red.lua:12: Lobato de Forever recibió algo de Ragnar-Kazzak")
  check(not s:find("Lobato", 1, true) and not s:find("Forever", 1, true) and not s:find("Ragnar", 1, true) and not s:find("Kazzak", 1, true),
    "N.SinPrivado dejó un nombre: " .. s)
  check(s:find("Red.lua:12", 1, true), "N.SinPrivado se comió el archivo: " .. s)
  -- El reporte entero (Reporte.lua) con un error atrapado que nombra al personaje.
  if N.AnotarError then N.AnotarError("Interface/AddOns/Alfa_Rutas/Plan.lua:5: Lobato no tiene ruta", "Interface/AddOns/Alfa_Rutas/Plan.lua") end
  local Bi = NS_OF("Alfa_Bienvenida")
  local componer = Bi.ComponerReporte
  check(type(componer) == "function", "no encontré cómo se compone el reporte")
  if not componer then return end
  local ok, rep = pcall(componer)
  check(ok and type(rep) == "string", "el reporte no se compuso: " .. tostring(rep))
  if not (ok and type(rep) == "string") then return end
  check(rep:find(tostring(A.version or N.version or "1.3"), 1, true), "el reporte no lleva la versión")
  check(rep:find("Rutas", 1, true), "el reporte no lleva los módulos")
  check(not rep:find("Lobato", 1, true), "el reporte lleva el nombre del personaje")
  -- (1.3.9: «Alfa Forever» es el nombre del addon en la cabecera, no el reino)
  local sinMarca = rep:gsub("Alfa Forever", "")
  check(not sinMarca:find("Forever-", 1, true) and not sinMarca:find(" Forever", 1, true), "el reporte lleva el reino")
  check(#rep <= 2000, "el reporte no cabe en un mensaje de Discord: " .. #rep)
end)

---------------------------------------------------------------------------
-- 21. Lo que se ve y se cierra no se queda: volver a abrir cada página no
-- deja memoria (cada página se arma una vez y se reusa; lo de adentro se suelta).
---------------------------------------------------------------------------
step("21. Abrir y cerrar las páginas otra vez no deja memoria", function()
  local function viva() collectgarbage("collect") collectgarbage("collect") return collectgarbage("count") end
  local function vuelta()
    for _, spec in ipairs(N.modulos or {}) do
      A.Fire("SHOW_OPTIONS", spec.id)
      RUN_TIMERS(2)
    end
    local f = A.UI.Options.frame or rawget(_G, "AlfaOptions")
    if f then f:Hide() end
    RUN_TIMERS(5)
  end
  vuelta()
  local m1 = viva()
  vuelta() vuelta()
  local m2 = viva()
  print(("MEMORIA: dos vueltas más por las %d páginas dejan %.0f KB"):format(#(N.modulos or {}), m2 - m1))
  check(m2 - m1 < 768, ("dos vueltas por las páginas dejaron %.0f KB"):format(m2 - m1))
end)

---------------------------------------------------------------------------
-- 23 y 22. Una sesión larga: 3 horas al paso real del reloj
---------------------------------------------------------------------------
-- Cuánto pesa lo guardado (aprox. en bytes), y por rama hasta 3 niveles.
local function guardadas()
  local nombres, visto = {}, {}
  for addon in pairs(LOADED) do
    local m = ADDON_META[addon]
    for _, campo in ipairs({ "SavedVariables", "SavedVariablesPerCharacter" }) do
      for n in tostring((m and m[campo]) or ""):gmatch("[^,%s]+") do
        if not visto[n] then visto[n] = true nombres[#nombres + 1] = n end
      end
    end
  end
  local ramas = {}
  local function peso(v, camino, nivel, vistos)
    local t = type(v)
    if t == "string" then return #v + 4 end
    if t ~= "table" then return 8 end
    if vistos[v] then return 0 end
    vistos[v] = true
    local total = 2
    for k, x in pairs(v) do
      local c = nivel <= 3 and (camino .. "." .. tostring(k)) or camino
      local p = (type(k) == "string" and #k + 4 or 8) + peso(x, c, nivel + 1, vistos)
      total = total + p
      if nivel <= 3 then ramas[c] = (ramas[c] or 0) + p end
    end
    return total
  end
  local total = 0
  for _, n in ipairs(nombres) do
    local v = rawget(_G, n)
    if v ~= nil then total = total + peso(v, n, 1, {}) end
  end
  return total, ramas, nombres
end
local function memoria()
  collectgarbage("collect") collectgarbage("collect")
  return collectgarbage("count")
end

step("23. Una sesión de 3 horas sin que crezca nada", function()
  local R = N.Reloj
  check(R and R.marco, "no está el reloj de Alfa")
  if not (R and R.marco) then return end
  collectgarbage("restart")
  local conUpdate = {}
  local function refrescar()
    conUpdate = {}
    for _, f in ipairs(ALL_FRAMES()) do
      if f._scripts and f._scripts.OnUpdate and f ~= R.marco then conUpdate[#conUpdate + 1] = f end
    end
  end
  local avisos, combate = 0, false
  local function segundo(s)
    FIRE(R.marco, "OnUpdate", 1)
    RUN_TIMERS(1) -- (adelanta NOW un segundo)
    for _, f in ipairs(conUpdate) do if f:IsVisible() then FIRE(f, "OnUpdate", 1) end end
    if s % 5 == 0 then
      FIRE_EVENT("UNIT_AURA", "player") FIRE_EVENT("UNIT_HEALTH", "target") FIRE_EVENT("UNIT_POWER_UPDATE", "player", "MANA")
    end
    if s % 15 == 0 then
      FIRE_EVENT("BAG_UPDATE", 0) FIRE_EVENT("BAG_UPDATE_DELAYED") FIRE_EVENT("QUEST_LOG_UPDATE")
      FIRE_EVENT("PLAYER_TARGET_CHANGED") FIRE_EVENT("UPDATE_MOUSEOVER_UNIT")
    end
    if s % 60 == 0 then
      local m = math.floor(s / 60)
      FIRE_EVENT("CHAT_MSG_ADDON", "ALFA", "x" .. m, "GUILD", "Otro" .. (m % 7) .. "-Forever")
      FIRE_EVENT("ZONE_CHANGED")
      FIRE_EVENT("CHAT_MSG_LOOT", "Recibes botín: |cffffffff|Hitem:" .. (2000 + m % 50) .. "::::::::|h[Cosa " .. m .. "]|h|r.", "", "", "", "Lobato")
      FIRE_EVENT("PLAYER_XP_UPDATE", "player")
      FIRE_EVENT("PLAYER_MONEY")
      -- Un aviso distinto cada minuto (su historial y la campanita tienen tope).
      avisos = avisos + 1
      pcall(K.Aviso, { titulo = "Aviso de prueba " .. avisos, texto = "Texto " .. avisos, pedido = true, lya = false })
      -- Un combate corto cada 5 minutos.
      if m % 5 == 0 then FIRE_EVENT("PLAYER_REGEN_DISABLED") combate = true end
    end
    if combate and s % 60 == 20 then FIRE_EVENT("PLAYER_REGEN_ENABLED") combate = false end
    if s % 600 == 0 then FIRE_EVENT("ZONE_CHANGED_NEW_AREA") refrescar() end
  end
  refrescar()
  local marcas = {}
  local function marcar(nombre)
    local sv, ramas = guardadas()
    marcas[#marcas + 1] = { nombre = nombre, kb = memoria(), tareas = #N.Tareas(), marcos = #ALL_FRAMES(), sv = sv, ramas = ramas }
  end
  local t0 = os.clock()
  for s = 1, 3 * 3600 do
    segundo(s)
    if s == 1800 then marcar("30 min") elseif s == 3600 then marcar("1 h") elseif s == 7200 then marcar("2 h") elseif s == 10800 then marcar("3 h") end
  end
  print(("SESIÓN LARGA: 3 h simuladas en %.1f s del banco, %d avisos, %d combates"):format(os.clock() - t0, avisos, math.floor(avisos / 5)))
  for _, m in ipairs(marcas) do
    print(("   %-6s memoria %7.1f MB · %3d tareas del reloj · %5d marcos · lo guardado %6.1f KB"):format(m.nombre, m.kb / 1024, m.tareas, m.marcos, m.sv / 1024))
  end
  local a, z = marcas[2], marcas[4]
  if not (a and z) then return end
  -- Lo que crece entre la primera y la tercera hora.
  local crecen = {}
  for k, v in pairs(z.ramas) do
    local d = v - (a.ramas[k] or 0)
    if d > 2048 then crecen[#crecen + 1] = { k, d } end
  end
  table.sort(crecen, function(x, y) return x[2] > y[2] end)
  for i = 1, math.min(#crecen, 10) do print(("   crece %6.1f KB: %s"):format(crecen[i][2] / 1024, crecen[i][1])) end
  check(z.kb - a.kb < 2048, ("la memoria creció %.1f MB entre la hora 1 y la 3"):format((z.kb - a.kb) / 1024))
  check(z.tareas - a.tareas <= 2, ("las tareas del reloj crecieron de %d a %d"):format(a.tareas, z.tareas))
  check(z.marcos - a.marcos <= 30, ("los marcos crecieron de %d a %d"):format(a.marcos, z.marcos))
  check(z.sv - a.sv < 64 * 1024, ("lo guardado creció %.1f KB entre la hora 1 y la 3"):format((z.sv - a.sv) / 1024))
end)
