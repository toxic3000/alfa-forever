-- Prueba de la 1.3.8, área «enciclopedia»: cómo se consigue cada objeto y
-- de qué facción es (src/Alfa_Enciclopedia/Origen.lua), con el Codex de verdad.
--   1. nada se calcula al entrar al juego (ni una etiqueta, ni la tarea);
--   2. las etiquetas de objetos conocidos: «De jefe · 20 %», «Serie de
--      misiones», «Vendedor», «Fabricado», «Recolección», la facción
--      («Alianza», «Neutral», «Ambas facciones»), nunca más de 3, y nada
--      para lo que no tiene fuente;
--   3. la ficha: «Cómo se consigue» primero, con todas las insignias, el
--      porcentaje de cada enemigo, «100 %» en una misión, «También en…»;
--   4. los filtros «Cómo se consigue» y «Facción» (O.Pasa y Cat.Buscar,
--      después de prepararse por lotes) y «Más probable primero»;
--   5. el porcentaje según el idioma (12 %, 12,5 %);
--   6. la ventana: las filas con sus etiquetas a la derecha y el nombre antes
--      de ellas (con BANCO_FOTOS, capturas de la lista y de la ficha en los 3 estilos).
SNAPSHOTS = {}
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["138-enc-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.8 enciclopedia", msg) end end
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS") and true or false
if FOTOS then BANCO_LETRA = 0.64 end

local N = AlfaNucleo
local A = N.A
local K = N.Kit
local E = NS_OF("Alfa_Enciclopedia")
local O = E.Origen
local Cat = E.Cat

-- Contar si alguien pide etiquetas antes de abrir la Enciclopedia.
local pedidas = 0
local resumenReal = O.Resumen
O.Resumen = function(...) pedidas = pedidas + 1 return resumenReal(...) end

FIRE_EVENT("PLAYER_LOGIN")
local Bv = rawget(_G, "AlfaBienvenida")
N.Datos("bienvenida").respondio = Bv and Bv.VERSION or 99
N.Datos("bienvenida").versionVista = Bv and Bv.VersionAlfa and Bv.VersionAlfa() or "9.9.9"
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)

---------------------------------------------------------------------------
-- 1. Nada al entrar
---------------------------------------------------------------------------
step("nada se calcula al entrar al juego", function()
  check(pedidas == 0, "se pidieron " .. pedidas .. " etiquetas al entrar")
  check(not E.Corriendo("origenes"), "la tarea de los orígenes corre sin abrir la Enciclopedia")
  check(not O.Listo(), "los orígenes ya estaban listos al entrar")
end)
O.Resumen = resumenReal

local C = E.Codex()
check(C ~= nil, "el banco no cargó el Codex")
if not C then return end

---------------------------------------------------------------------------
-- 2. Las etiquetas de objetos conocidos
---------------------------------------------------------------------------
local function textos(id)
  local t = {}
  for _, x in ipairs(O.Etiquetas(id, 3)) do t[#t + 1] = x[1] end
  return t, table.concat(t, " / ")
end
local function tieneTexto(lista, s)
  for _, x in ipairs(lista) do if x == s then return true end end
  return false
end

step("las etiquetas de la fila", function()
  local t, s = textos(5191) -- Púa cruel: la suelta Edwin VanCleef (Las Minas de la Muerte)
  check(tieneTexto(t, "De jefe · 20 %"), "la Púa cruel no dice «De jefe · 20 %»: " .. s)
  check(tieneTexto(t, "Neutral"), "lo de una mazmorra no es Neutral: " .. s)
  t, s = textos(1276) -- recompensa de una misión que pide otra antes
  check(tieneTexto(t, "Serie de misiones") and tieneTexto(t, "Alianza"), "1276 no es «Serie de misiones» de la Alianza: " .. s)
  t, s = textos(6256) -- la caña de pescar: la venden en las dos facciones
  check(tieneTexto(t, "Vendedor") and tieneTexto(t, "Ambas facciones"), "la caña no es «Vendedor» de «Ambas facciones»: " .. s)
  t, s = textos(1251) -- Venda de lino: misión y fabricado
  check(tieneTexto(t, "Misión") and tieneTexto(t, "Fabricado"), "la venda de lino no es misión y fabricado: " .. s)
  t, s = textos(2770) -- Mena de cobre
  check(tieneTexto(t, "Recolección"), "la mena de cobre no es de recolección: " .. s)
  t, s = textos(6150) -- lo sueltan, sin probabilidad en los datos: sin número
  check(tieneTexto(t, "Lo sueltan"), "sin probabilidad no dice «Lo sueltan» sin número: " .. s)
  t = textos(6948) -- la piedra de hogar: sin fuente, sin etiquetas
  check(#t == 0, "la piedra de hogar tiene etiquetas: " .. table.concat(t, " / "))
  -- Nunca más de 3, y cada una con su tono y su ícono.
  local n = 0
  C.Each("item", function(id)
    n = n + 1
    local et = O.Etiquetas(id, 3)
    if #et > 3 then NOTE("1.3.8 enciclopedia", "más de 3 etiquetas en " .. id) return false end
    for _, x in ipairs(et) do
      if not (type(x[1]) == "string" and x[1] ~= "" and K.TONOS[x[2]] and type(x[3]) == "string") then
        NOTE("1.3.8 enciclopedia", "una etiqueta sin texto, tono o ícono en " .. id) return false
      end
    end
    if n >= 3000 then return false end
  end)
  -- Se calcula una vez: la segunda vez sale de la memoria.
  local veces = 0
  local npcReal = C.Npc
  C.Npc = function(...) veces = veces + 1 return npcReal(...) end
  O.Etiquetas(5191, 3)
  C.Npc = npcReal
  check(veces == 0, "las etiquetas de un objeto ya visto se calcularon otra vez")
end)

---------------------------------------------------------------------------
-- 3. La ficha
---------------------------------------------------------------------------
local function seccion(f, clave)
  for i, s in ipairs(f.secciones or {}) do if s.clave == clave then return s, i end end
end
step("la ficha: cómo se consigue, con el detalle", function()
  local f = E.F.Construir("item", 5191)
  check(f, "no se armó la ficha de la Púa cruel") if not f then return end
  local s, pos = seccion(f, "origen")
  check(s and pos == 1, "«Cómo se consigue» no es la primera sección")
  local ins = {}
  for _, x in ipairs(f.insignias) do ins[#ins + 1] = x[1] end
  check(tieneTexto(ins, "De jefe · 20 %") and tieneTexto(ins, "Neutral"), "faltan insignias en la ficha: " .. table.concat(ins, " / "))
  local jefe = s and s.filas[1]
  check(jefe and jefe.titulo == "Lo suelta un jefe" and jefe.valor == "20 %", "la fila del jefe no tiene su porcentaje: "
    .. tostring(jefe and jefe.titulo) .. " " .. tostring(jefe and jefe.valor))
  check(jefe and jefe.ir and jefe.ir.kind == "npc", "la fila del jefe no lleva a su ficha")
  -- Lo sueltan muchos: el detalle de cada uno, de más a menos.
  f = E.F.Construir("item", 4306) -- Paño de seda
  local d = f and seccion(f, "drop")
  check(d and #d.filas > 3, "el paño de seda no tiene quién lo suelta")
  if d then
    local antes
    for _, fl in ipairs(d.filas) do
      if not fl.tenue then
        local v = -(fl.orden or 0)
        check(not antes or v <= antes, "los que lo sueltan no van de más a menos") antes = v
      end
    end
  end
  local o = f and seccion(f, "origen")
  local fd = o and o.filas[1]
  check(fd and fd.valor and fd.valor:find("%", 1, true), "la mejor fila de «Lo sueltan» no tiene porcentaje")
  -- La recompensa de una misión: 100 %.
  local qid
  C.Each("item", function(id)
    local rec = C.Item(id)
    local srcs = rec and rec.sources or {}
    if #srcs == 1 and srcs[1].type == "quest" and not srcs[1].choice then qid = id return false end
  end)
  f = qid and E.F.Construir("item", qid)
  local q = f and seccion(f, "quest")
  check(q and q.filas[1] and q.filas[1].valor == "100 %", "la recompensa de misión no dice 100 %: " .. tostring(q and q.filas[1] and q.filas[1].valor))
  -- En varias facciones: «También en…».
  f = E.F.Construir("item", 6256)
  ins = {}
  for _, x in ipairs(f and f.insignias or {}) do ins[#ins + 1] = x[1] end
  local tambien = false
  for _, x in ipairs(ins) do if x:find("También en", 1, true) then tambien = true end end
  check(tambien, "la caña no dice «También en…»: " .. table.concat(ins, " / "))
end)

---------------------------------------------------------------------------
-- 4. Los filtros
---------------------------------------------------------------------------
step("O.Pasa: cómo se consigue y facción", function()
  local B = O.BIT
  check(O.Pasa(B.suelta, 1, "suelta", nil), "lo que sueltan no pasa «Lo sueltan»")
  check(not O.Pasa(B.vendedor, 1, "suelta", nil), "lo de vendedor pasa «Lo sueltan»")
  check(O.Pasa(B.mision + B.serie, 1, "serie", nil) and not O.Pasa(B.mision, 1, "serie", nil), "«Serie de misiones» no distingue")
  check(O.Pasa(B.pesca, 4, "recoger", nil), "la pesca no pasa «Pesca y recolección»")
  check(O.Pasa(0, 1, nil, "A") and not O.Pasa(0, 2, nil, "A"), "el filtro Alianza no distingue")
  check(O.Pasa(0, 4, nil, "mio") and O.Pasa(0, 2, nil, "mio") and not O.Pasa(0, 1, nil, "mio"), "«Tu facción» (Horda) no distingue")
  check(O.Pasa(B.fabricado, 0, nil, "mio"), "lo fabricado (sin facción) no pasa «Tu facción»")
  check(not O.Pasa(B.fabricado, 0, nil, "N"), "lo fabricado pasa «Neutral»")
end)

local function esperar(fn, max)
  for _ = 1, max or 4000 do
    if fn() then return true end
    RUN_TIMERS(1)
  end
  return fn()
end

step("Cat.Buscar con los filtros nuevos", function()
  check(esperar(function() Cat.Pedir("objeto") return Cat.Listo("objeto") end), "el catálogo de objetos no se armó")
  local res, pend = Cat.Buscar("objeto", "", { origen = "serie" }, {})
  check(pend == "origenes", "sin preparar, el filtro no espera: " .. tostring(pend))
  O.Preparar()
  check(esperar(function() return O.Listo() end, 20000), "los orígenes no terminaron de prepararse")
  res, pend = Cat.Buscar("objeto", "", { origen = "serie" }, {})
  check(not pend and #res > 50, "«Serie de misiones» no encontró casi nada: " .. #res)
  for k = 1, #res, 17 do
    local m = O.Fila(res[k])
    check(O.Tiene(m, O.BIT.serie), "un resultado de «Serie de misiones» no es de una serie")
  end
  res = Cat.Buscar("objeto", "", { bando = "A" }, {})
  check(#res > 50, "el filtro Alianza no encontró nada")
  for k = 1, #res, 23 do
    local _, b = O.Fila(res[k])
    check(O.Tiene(b, O.BANDO.A), "un resultado de Alianza no es de la Alianza")
  end
  -- Más probable primero.
  res = Cat.Buscar("objeto", "", { origen = "suelta", probable = true }, {})
  check(#res > 100, "«Lo sueltan» no encontró nada")
  local antes = 1000
  for k = 1, math.min(#res, 3000) do
    local _, _, p = O.Fila(res[k])
    p = p or -1
    if p > antes then NOTE("1.3.8 enciclopedia", "«Más probable primero» no va de más a menos en " .. k .. ": " .. p .. " después de " .. antes) break end
    antes = p
  end
  -- Con texto también, y combinado con la facción.
  res = Cat.Buscar("objeto", "paño", { origen = "suelta", bando = "mio" }, {})
  check(#res > 0, "«paño» que sueltan en tu facción no encontró nada")
end)

---------------------------------------------------------------------------
-- 5. El porcentaje
---------------------------------------------------------------------------
step("el porcentaje según el idioma", function()
  check(E.Porcentaje(12) == "12 %", "12 no es «12 %»: " .. tostring(E.Porcentaje(12)))
  check(E.Porcentaje(1.5) == "1,5 %", "1,5 no es «1,5 %»: " .. tostring(E.Porcentaje(1.5)))
  check(E.Porcentaje(nil) == nil, "sin dato salió un número")
end)

---------------------------------------------------------------------------
-- 6. La ventana
---------------------------------------------------------------------------
step("la lista con etiquetas y la ficha", function()
  E.V.Abrir({ texto = "paño", tipo = "objeto" })
  RUN_TIMERS(30)
  local v = rawget(_G, "AlfaEnciclopediaVentana")
  check(v and v:IsShown(), "la Enciclopedia no abrió") if not v then return end
  v:SetTamano(1040, 660)
  if v.alAcomodar then v.alAcomodar() end
  RUN_TIMERS(5)
  -- Las filas de la lista: con sus etiquetas, el nombre termina antes de ellas.
  local vistas, conEtiqueta = 0, 0
  local function recorrer(f)
    if f.pildoras and f:IsShown() and f.Nombre then
      vistas = vistas + 1
      local n = 0
      for _, p in ipairs(f.pildoras) do
        if p:IsShown() then
          n = n + 1
          check(p:GetHeight() == K.ALTO.insignia, "una etiqueta de la fila no tiene el alto de una insignia")
        end
      end
      if n > 0 then conEtiqueta = conEtiqueta + 1 end
      check(n <= 3, "una fila con más de 3 etiquetas")
    end
    for _, h in ipairs({ f:GetChildren() }) do recorrer(h) end
  end
  recorrer(v)
  check(vistas > 3, "no se ven filas en la lista: " .. vistas)
  check(conEtiqueta > 3, "las filas no tienen etiquetas: " .. conEtiqueta .. " de " .. vistas)
  if FOTOS then
    for _, estilo in ipairs({ "alfa", "cristal", "clasico" }) do
      K.SetEstilo(estilo)
      RUN_TIMERS(3)
      SNAP("lista-" .. estilo, v)
    end
    K.SetEstilo("alfa")
    RUN_TIMERS(3)
  end
  E.V.Abrir({ kind = "item", id = 5191 })
  RUN_TIMERS(20)
  if FOTOS then
    SNAP("ficha-jefe", v)
    E.V.Abrir({ kind = "item", id = 6256 })
    RUN_TIMERS(20)
    SNAP("ficha-cana", v)
    E.V.Abrir({ kind = "item", id = 4306 })
    RUN_TIMERS(20)
    SNAP("ficha-seda", v)
    -- Bajar la ficha hasta «Cómo se consigue».
    local function bajar(f)
      if f.Contenido and f.Barra and f.IrArriba then FIRE(f, "OnMouseWheel", -6) end
      for _, h in ipairs({ f:GetChildren() }) do bajar(h) end
    end
    bajar(v)
    RUN_TIMERS(2)
    SNAP("ficha-seda-abajo", v)
    E.V.Abrir({ kind = "item", id = 5191 })
    RUN_TIMERS(20)
    bajar(v)
    RUN_TIMERS(2)
    SNAP("ficha-jefe-abajo", v)
  end
  v:Hide()
end)

print(("1.3.8 enciclopedia: %d pasos"):format(pasos))
