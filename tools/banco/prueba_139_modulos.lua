-- Prueba de la 1.3.9, módulos (tools/prueba.py la corre con las demás):
--   43. Pesca: el aviso del pez de la semana en su zona (una vez por zona y
--       semana; nunca en combate, sin pescar o apagado).
--   44. Pesca: la fecha de los récords («12 de noviembre»), cada zona con la suya.
--   87. Pesca: cuatro pestañas y «Más» (con la abierta), todas con el ajuste.
--   88. Comercio: el consejo del cuadro en una línea (y dos con el detalle).
--   46. Oficios: lo más barato para subir (color de la receta, lo que tienes, el costo por punto).
--   89. Oficios: lo que ya puedes fabricar, con cuánto ganas, en la ventana.
--   47. Curación: mapas de clics guardados, usar uno, el de la rama al cambiar talentos.
--   85. Curación: el dibujo del ratón (con el botón que probaste marcado).
--   48. Combate: las últimas 5 peleas con su diferencia.
--   84. Combate: la página simple de fábrica y «Más ajustes».
--   86. Mazmorras: la lista de cotejo de «Prepárame» y «¡Todo listo!».
--   Mapa de la mazmorra por dentro (pedido de Toxic): plano, pisos, zoom,
--       centrar, la flecha solo si el juego da tu posición; sin posición, el
--       avance por jefes; sin plano, lo dice. El botón del mapa del juego.
--   90. Enciclopedia: secciones plegables y «Guíame» fijo al bajar.
--   91. Enciclopedia: búsqueda con errores de dedo.
--   49/50. La Jauría: los lobos con Alfa (versión, nivel, zona), solo por la
--       hermandad, lo mal formado no, la otra facción no; la ventana.
--   94/95. Escritorio: los paneles nuevos y las plantillas vertical y ultraancha.
--   Y capturas de cada cosa visual.
SNAPSHOTS = {}
BANCO_LETRA = 0.64
local function SNAP(name, root, extra)
  local entries, l, b, w, h = DUMP(root, extra)
  SNAPSHOTS["139-" .. name] = { entries = entries, l = l, b = b, w = w, h = h }
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
local function check(cond, msg) if not cond then NOTE("1.3.9 modulos", msg) end end
local function T(n) RUN_TIMERS(n or 2) end

local N = AlfaNucleo
local A = Alfa
local K = N.Kit
Alfa.Hidden = Alfa.Hidden or function() return false end
FIRE_EVENT("PLAYER_LOGIN")
do
  local B = rawget(_G, "AlfaBienvenida")
  N.Datos("bienvenida").respondio = B and B.VERSION or 99
  N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
  N.Datos("bienvenida").recorrido = true
end
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
T(10)
if AlfaBienvenida and AlfaBienvenida.Pendiente then AlfaBienvenida.Pendiente = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local avisos = {}
local avisoReal = K.Aviso
K.Aviso = function(o) avisos[#avisos + 1] = o return avisoReal(o) end
local function ultimoAviso(id)
  for i = #avisos, 1, -1 do if avisos[i].id == id then return avisos[i] end end
  return nil
end
local combate = false
local enCombateReal = InCombatLockdown
InCombatLockdown = function() return combate end

local function texto(fs) return fs and fs.GetText and (fs:GetText() or "") or "" end
local function todoTexto(f, out)
  out = out or {}
  if not f then return out end
  for _, c in ipairs(rawget(f, "_children") or {}) do
    if c._kind == "FontString" then
      if c._shown then out[#out + 1] = c:GetText() or "" end
    elseif c._kind ~= "Texture" and c:IsShown() then
      todoTexto(c, out)
    end
  end
  return out
end
local function contiene(f, s) return table.concat(todoTexto(f), " | "):find(s, 1, true) ~= nil end

-- Un fondo para capturar piezas sueltas.
local function escenario(w, h)
  local esc = CreateFrame("Frame", nil, UIParent)
  esc:SetSize(w, h)
  esc:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local fondo = esc:CreateTexture(nil, "BACKGROUND")
  fondo:SetAllPoints(esc)
  fondo:SetTexture("white")
  fondo:SetVertexColor(0.06, 0.07, 0.09, 1)
  return esc
end

---------------------------------------------------------------------------
-- Pesca
---------------------------------------------------------------------------
local P = NS_OF("Alfa_Pesca")
local Pz = P.Pez

step("43. el pez de la semana en su zona", function()
  check(type(Pz.AvisoSemanaZona) == "function", "falta Pz.AvisoSemanaZona")
  local s = Pz.Semana()
  check(s and s.mapas and #s.mapas > 0, "el pez de la semana no tiene zonas")
  local zona = s.mapas[1]
  local hab = P.Habilidad
  P.Habilidad = function() return 120, 150, 0 end
  avisos = {}
  -- Apagado: nada.
  N.Set("pesca", "avisoSemana", false)
  check(not Pz.AvisoSemanaZona(zona), "apagado, avisó")
  N.Set("pesca", "avisoSemana", nil)
  -- En combate: nada.
  combate = true
  check(not Pz.AvisoSemanaZona(zona), "avisó en combate")
  combate = false
  -- Fuera de sus zonas: nada.
  check(not Pz.AvisoSemanaZona(99999), "avisó fuera de las zonas del pez")
  -- En su zona: una vez.
  check(Pz.AvisoSemanaZona(zona), "en su zona no avisó")
  T(2)
  local a = ultimoAviso("pesca.semanaZona")
  check(a and a.titulo and a.texto and a.texto:find(tostring(s.meta), 1, true), "el aviso no dice cuánto llevas: " .. tostring(a and a.texto))
  check(a and a.accion and a.accion.alClic, "el aviso no tiene «Ver el pez de la semana»")
  check(not Pz.AvisoSemanaZona(zona), "avisó dos veces en la misma zona y semana")
  -- Sin pescar: nada.
  P.Habilidad = function() return nil end
  check(not Pz.AvisoSemanaZona(s.mapas[2] or zona), "avisó a quien no pesca")
  P.Habilidad = hab
end)

step("44. la fecha de los récords", function()
  local t = time({ year = 2025, month = 11, day = 12, hour = 12 })
  local f = Pz.Fecha(t)
  check(f == "12 de noviembre de 2025", "la fecha de otro año sale mal: " .. tostring(f))
  local hoy = date("*t", time())
  local f2 = Pz.Fecha(time({ year = hoy.year, month = 3, day = 5, hour = 12 }))
  check(f2 == "5 de marzo", "la fecha de este año sale mal: " .. tostring(f2))
  local c = P.V.CuandoRecord(time() - 3 * 86400)
  check(c:find("hace 3 días", 1, true) and c:find("^el "), "«el … (hace …)» sale mal: " .. c)
  check(Pz.Fecha(nil) == nil, "una fecha vacía da texto")
end)

step("87. cuatro pestañas y «Más»", function()
  P.MapaJugador = function() return 1413 end
  P.V.Abrir("diario")
  T(3)
  local v = rawget(_G, "AlfaPescaVentana")
  check(v and v:IsShown(), "no se abrió la ventana de pesca")
  if not v then return end
  local ops = v.Seg.opciones
  check(#ops == 5 and ops[5].valor == P.V.MAS, "esperaba 4 pestañas y «Más»: " .. #ops)
  SNAP("pesca-pestanas", v)
  P.V.Mostrar("estadisticas")
  T(2)
  check(v.Seg:Valor() == P.V.MAS, "con Estadísticas abierta, «Más» no queda marcada")
  check(v.Seg.opciones[5].texto == P.V.PESTANAS.estadisticas.nombre, "«Más» no dice cuál está abierta")
  P.V.MenuMas()
  T(1)
  local menu = rawget(_G, "AlfaKitMenu")
  check(menu and menu:IsShown(), "«Más» no abrió su menú")
  K.CerrarMenu()
  P.V.Mostrar("pescador")
  T(2)
  SNAP("pesca-pescador", v)
  N.Set("pesca", "pestanasTodas", true)
  T(2)
  check(#v.Seg.opciones == 8, "con «Todas las pestañas», no salen las ocho: " .. #v.Seg.opciones)
  N.Set("pesca", "pestanasTodas", nil)
  T(2)
  check(#v.Seg.opciones == 5, "al apagarlo no volvió a cuatro y «Más»")
  v:Cerrar()
end)

step("44. el récord en la ficha del pez, con su fecha y su zona", function()
  local t = time() - 86400 * 40
  local rec = Pz.Records()
  rec[6289] = { mm = 380, g = 520, t = t, z = "Durotar" }
  local rz = Pz.RecordsZona()
  rz["Durotar"] = { [6289] = { mm = 380, g = 520, t = t } }
  rz["Los Baldíos"] = { [6289] = { mm = 330, g = 400, t = t - 86400 } }
  P.V.Abrir("diario")
  T(3)
  local v = rawget(_G, "AlfaPescaVentana")
  local vista = v.vistas.diario
  -- La ficha del pargo de barro.
  local lf
  local function buscar(f) if f.MostrarFicha and f.Lista then lf = f return end for _, h in ipairs({ f:GetChildren() }) do if not lf then buscar(h) end end end
  buscar(vista)
  if lf then
    local lista = lf.Lista.datos or lf.Lista.alfaDatos or {}
    for i, d in ipairs(lista) do if type(d) == "table" and d.id == 6289 then lf:Elegir(i) break end end
    T(2)
    check(contiene(v, "En cada zona:") and contiene(v, "Los Baldíos"), "la ficha no trae los récords por zona")
    SNAP("pesca-ficha-record", v)
  else
    NOTE("1.3.9 modulos", "no encontré la ficha del diario")
  end
  v:Cerrar()
end)

---------------------------------------------------------------------------
-- Comercio
---------------------------------------------------------------------------
local Co = NS_OF("Alfa_Comercio")

step("88. el consejo del cuadro en una línea", function()
  local c = { id = 1, info = { pila = 20, clase = 7 }, venta = 15, mejor = "subastar", valor = 120, ganancia = 7,
    subasta = { bruto = 130, neto = 120, fecha = time(), viejo = false } }
  local l = Co.LineaCuadro(c)
  check(type(l) == "string" and not l:find("\n"), "no es una sola línea")
  check(l:find("Súbelo a la subasta", 1, true) and l:find("+700%", 1, true) and l:find("×20", 1, true), "la línea no dice qué, cuánto y la pila: " .. tostring(l))
  c.mejor, c.valor, c.ganancia = "vender", 15, 0
  l = Co.LineaCuadro(c)
  check(l:find("Véndelo al comerciante", 1, true) and not l:find("+0%", 1, true), "vender sale mal: " .. l)
  c.mejor, c.motivo = "guardar", "Es de una misión."
  l = Co.LineaCuadro(c)
  check(l:find("Guárdalo", 1, true) and l:find("misión", 1, true), "guardar no dice por qué: " .. l)
  check(not Co.CuadroDetalle(), "el detalle sale sin Mayús ni el ajuste")
  N.Set("comercio", "tooltipDetalle", true)
  check(Co.CuadroDetalle(), "con el ajuste no salen las dos líneas")
  N.Set("comercio", "tooltipDetalle", nil)
  local shift = IsShiftKeyDown
  IsShiftKeyDown = function() return true end
  check(Co.CuadroDetalle(), "con Mayús no salen las dos líneas")
  IsShiftKeyDown = shift
end)

step("46/89. lo más barato para subir y lo que ya puedes fabricar", function()
  local Of = Co.Oficios
  check(type(Of.MasBarata) == "function" and type(Of.YaPuedes) == "function", "faltan Of.MasBarata / Of.YaPuedes")
  local habilidad = A.Compat.GetSkillRank
  A.Compat.GetSkillRank = function(l) if l == 171 then return 70, 150 end return nil end
  local todas, tienes, costo, fabricar = Co.TodasLasRecetas, Co.Tienes, Co.CostoCompra, Co.Fabricar
  -- Dos recetas tuyas: una amarilla que te cuesta, una verde que ya puedes hacer.
  Co.TodasLasRecetas = function() return {
    { propio = true, id = 1, rec = { n = "Poción menor", o = 858, q = 1, r = { 118, 1, 2450, 1 }, p = "Alquimia", d = 1, s = 70 } },
    { propio = true, id = 2, rec = { n = "Elixir", o = 2454, q = 1, r = { 2449, 1, 765, 1 }, p = "Alquimia", d = 2, s = 70 } },
    { propio = true, id = 3, rec = { n = "Gris", o = 2455, q = 1, r = { 785, 1 }, p = "Alquimia", d = 3, s = 70 } },
  } end
  Co.Tienes = function(id) if id == 2449 or id == 765 then return 10 end if id == 118 then return 0 end return 0 end
  Co.CostoCompra = function(id) return ({ [118] = 40, [2450] = 25, [2449] = 30, [765] = 5 })[id] end
  local lista = Of.MasBarata(171, 70)
  check(#lista >= 2, "esperaba al menos 2 recetas para subir: " .. #lista)
  for _, x in ipairs(lista) do check(x.o ~= 2455, "una receta gris salió para subir") end
  check(lista[1] and lista[1].o == 2454 and lista[1].veces == 10 and lista[1].porPunto == 0, "la más barata no es la que ya puedes hacer: " .. tostring(lista[1] and lista[1].o))
  local amarilla
  for _, x in ipairs(lista) do if x.o == 858 then amarilla = x end end
  check(amarilla and amarilla.porPunto == math.floor(65 / 0.8 + 0.5), "el costo por punto de la amarilla sale mal: " .. tostring(amarilla and amarilla.porPunto))
  -- Lo que ya puedes fabricar (Fabricar.lua): su sección en la ventana.
  Co.Fabricar = function() return { { e = { rec = { o = 2454, p = "Alquimia", r = {} } }, veces = 10, total = 3000, gana = 300, valor = 400, costo = 100 } } end
  local ya = Of.YaPuedes(171)
  check(#ya == 1 and ya[1].total == 3000, "Of.YaPuedes no trae lo que puedes hacer")
  Co.VentanaOficios.Abrir(171)
  T(2)
  local v = Co.VentanaOficios.Ventana()
  check(contiene(v, "sin gastar nada") and contiene(v, "Verde: a veces sube"), "la ventana no trae «Lo más barato para subir»: " .. table.concat(todoTexto(v), " | "):sub(1, 400))
  check(contiene(v, "Ya puedes fabricar y ganar"), "la ventana no trae «Ya puedes fabricar y ganar»")
  SNAP("oficios", v, {})
  v:Cerrar()
  Co.TodasLasRecetas, Co.Tienes, Co.CostoCompra, Co.Fabricar = todas, tienes, costo, fabricar
  A.Compat.GetSkillRank = habilidad
end)

---------------------------------------------------------------------------
-- Curación
---------------------------------------------------------------------------
local Cu = NS_OF("Alfa_Curacion")

step("47. mapas de clics guardados y por rama", function()
  local spec = "sagrado"
  local G = A.Gear or {}
  A.Gear = G
  local getSpec = G.GetSpec
  G.GetSpec = function() return spec, spec == "sagrado" and "Sagrado" or "Sombra", "talents" end
  local d = Cu.Datos()
  d.mapas, d.mapaActivo = nil, nil
  d.mapa = { ["1"] = { t = "spell", id = 2050 }, ["2"] = { t = "target" } }
  local id1 = Cu.GuardarMapa()
  check(id1 and Cu.MapaGuardado(id1).nombre == "Sagrado" and Cu.MapaGuardado(id1).rama == "sagrado", "no guardó el mapa con el nombre de tu rama")
  spec = "sombra"
  d.mapa = { ["1"] = { t = "spell", id = 589 }, ["2"] = { t = "menu" } }
  local id2 = Cu.GuardarMapa()
  check(id2 and id2 ~= id1 and #Cu.MapasGuardados() == 2, "no guardó el segundo mapa")
  -- Guardar otra vez con la misma rama actualiza, no duplica.
  Cu.GuardarMapa()
  check(#Cu.MapasGuardados() == 2, "guardar con la misma rama duplicó el mapa")
  check(Cu.UsarMapa(id1), "no usó el primer mapa")
  check(Cu.Mapa()["1"].id == 2050 and d.mapaActivo == id1, "usar el mapa no puso sus clics")
  -- Cambiar de talentos a «Sombra»: su mapa solo.
  Cu.OlvidarRama()
  spec = "sagrado"
  Cu.RevisarRama()
  spec = "sombra"
  avisos = {}
  check(Cu.RevisarRama(), "al cambiar de rama no puso su mapa")
  check(Cu.Mapa()["1"].id == 589, "el mapa de la rama no quedó")
  check(ultimoAviso("curacion.mapa"), "no dijo que cambió el mapa")
  N.Set("curacion", "mapaPorRama", false)
  spec = "sagrado"
  check(not Cu.RevisarRama(), "apagado, cambió el mapa")
  N.Set("curacion", "mapaPorRama", nil)
  -- El bloque de la página.
  local esc = escenario(560, 200)
  local b = Cu.BloqueMapas(esc)
  b:SetPoint("TOPLEFT", esc, "TOPLEFT", 12, -12)
  b:Llenar()
  local h = b:Acomodar(536)
  esc:SetHeight(h + 24)
  check(contiene(b, "Sagrado") and contiene(b, "Sombra"), "el bloque no muestra los mapas guardados")
  SNAP("curacion-mapas", esc)
  esc:Hide()
  check(Cu.BorrarMapa(id2) and #Cu.MapasGuardados() == 1, "no borró el mapa")
  G.GetSpec = getSpec
end)

step("85. el dibujo del ratón", function()
  local d = Cu.Datos()
  d.mapa = { ["1"] = { t = "spell", id = 2050 }, ["2"] = { t = "target" }, ["3"] = { t = "spell", id = 139 },
    ["shift-1"] = { t = "spell", id = 2061 }, ["shift-2"] = { t = "menu" } }
  local esc = escenario(560, 340)
  local r = Cu.DibujoRaton(esc)
  r:SetPoint("TOPLEFT", esc, "TOPLEFT", 12, -12)
  r:Set({ mod = "" })
  local h = r:Acomodar(536)
  esc:SetHeight(h + 24)
  check(contiene(r, "Seleccionar objetivo"), "el dibujo no dice qué hace el derecho")
  SNAP("curacion-raton", esc)
  r:Set({ marcar = "shift-1" })
  r:Acomodar(536)
  check(r.Mods:Valor() == "shift-", "probar Mayús+izquierdo no cambió la tecla del dibujo")
  check(r.Izq.alfaMarcada, "el botón probado no quedó marcado")
  SNAP("curacion-raton-mayus", esc)
  esc:Hide()
  -- En el asistente (paso 3).
  Cu.AbrirAsistente(3)
  T(2)
  local v = rawget(_G, "AlfaCuracionAsistente")
  if v and Cu.alProbarClic then Cu.alProbarClic("shift-1", d.mapa["shift-1"]) T(1) SNAP("curacion-asistente", v) v:Cerrar() end
end)

---------------------------------------------------------------------------
-- Combate
---------------------------------------------------------------------------
local Cb = NS_OF("Alfa_Combate")

step("48. las últimas 5 peleas", function()
  local Rs = Cb.Resumen
  local d = N.DatosPersonaje("combate")
  d.peleas = nil
  for i = 1, 7 do Rs.Anotar({ dur = 20 + i, dano = 1000 * i, dps = 100 + i * 10, cuando = time() - (8 - i) * 60 }, d) end
  check(#Rs.Peleas() == 5, "no se quedan solo las últimas 5: " .. #Rs.Peleas())
  check(Rs.Peleas()[1].dps == 170, "la primera no es la más nueva")
  local dif = Rs.Diferencia(1)
  check(dif and math.abs(dif - (170 - 160) / 160) < 0.001, "la diferencia contra la de antes sale mal: " .. tostring(dif))
  Rs.Anotar({ dur = 30, cura = 9000, cps = 300, curas = true, cuando = time() }, d)
  check(Rs.Diferencia(1) == nil, "una pelea de curación se comparó con una de daño")
end)

step("84. la página simple de Combate", function()
  A.Fire("SHOW_OPTIONS", "combate")
  T(3)
  local ui = Cb.ui
  check(ui and ui.ajustes and #ui.ajustes == 7, "la página no tiene sus 7 grupos")
  if not ui then return end
  local avanzados = { ui.ajustes[5], ui.ajustes[6], ui.ajustes[7] }
  for _, g in ipairs(avanzados) do check(g.alfaOculto, "un grupo avanzado se ve de fábrica") end
  local hijas = 0
  for _, f in ipairs(ui.ajustes[2].filas) do if f.alfaDatos.hija and f.alfaOculto then hijas = hijas + 1 end end
  check(hijas > 0, "las filas finas de «Cortar» se ven de fábrica")
  check(ui.peleas and ui.peleas:IsShown(), "no sale «Tus últimas peleas»")
  local o = A.UI.Options.frame
  SNAP("combate-pagina", o)
  N.Set("combate", "paginaCompleta", true)
  T(3)
  for _, g in ipairs(avanzados) do check(not g.alfaOculto, "con «Más ajustes» un grupo sigue oculto") end
  N.Set("combate", "paginaCompleta", nil)
  T(2)
  o:Hide()
end)

---------------------------------------------------------------------------
-- Mazmorras
---------------------------------------------------------------------------
local Mz = NS_OF("Alfa_Mazmorras")
local D = Mz.D
local KEY = (D.Lista()[1] or {}).key

step("86. la lista de cotejo de «Prepárame»", function()
  check(KEY ~= nil, "el banco no tiene mazmorras") if not KEY then return end
  local Ct = Mz.Cotejo
  local estado, entrada, preparar = Mz.P.Estado, Mz.P.Entrada, Mz.P.Preparar
  local I = rawget(_G, "AlfaInicio") or {}
  AlfaInicio = I
  local faltas = I.Faltas
  local recoger = { 1 }
  Mz.P.Estado = function() return { recoger = recoger, esperan = {}, listas = 0, llevas = 0, lista = {} } end
  I.Faltas = function() return { { clave = "reparar", ir = "repair", texto = "Tu equipo está al 30 %: repara antes de entrar" } } end
  local grupo = IsInGroup
  local g = false
  IsInGroup = function() return g end
  local lista = Ct.Lista(KEY)
  check(#lista == 4, "esperaba 4 cosas en la lista: " .. #lista)
  local h, t = Ct.Progreso(KEY)
  check(h == 0 and t == 4, "con todo pendiente no da 0 de 4: " .. h .. " de " .. t)
  check(lista[1].accion and lista[2].accion, "lo que falta no trae su botón")
  -- La sección en el resumen de la mazmorra.
  Mz.V.AbrirMazmorra(KEY, "resumen")
  T(3)
  local o = A.UI.Options.frame
  check(contiene(o, "Antes de entrar"), "el resumen no trae «Antes de entrar»")
  SNAP("mazmorras-cotejo", o)
  -- Todo listo tras «Prepárame»: el aviso, una vez.
  Ct.Empezar(KEY)
  recoger = {}
  I.Faltas = function() return {} end
  g = true
  local actual = D.MazmorraActual
  D.MazmorraActual = function() return KEY end
  avisos = {}
  check(Ct.Revisar(), "con todo marcado no dijo «¡Todo listo!»")
  T(2)
  check(ultimoAviso("mazmorras.cotejo"), "no salió el aviso de todo listo")
  check(not Ct.Revisar(), "«¡Todo listo!» salió dos veces")
  D.MazmorraActual = actual
  o:Hide()
  Mz.P.Estado, Mz.P.Entrada, Mz.P.Preparar = estado, entrada, preparar
  I.Faltas = faltas
  IsInGroup = grupo
end)

step("el mapa de la mazmorra por dentro", function()
  if not KEY then return end
  local Md = Mz.MapaDentro
  local CM = C_Map
  local real = {}
  for _, k in ipairs({ "GetBestMapForUnit", "GetMapInfo", "GetMapGroupID", "GetMapGroupMembersInfo", "GetMapArtLayers", "GetMapArtLayerTextures", "GetPlayerMapPosition" }) do real[k] = CM[k] end
  local piso, pos, conArte = 9001, nil, true
  CM.GetBestMapForUnit = function() return piso end
  CM.GetMapInfo = function(id)
    if id == 9001 or id == 9002 then return { mapID = id, name = id == 9001 and "Las cuevas" or "El templo", mapType = 4, parentMapID = 1413 } end
    return real.GetMapInfo(id)
  end
  CM.GetMapGroupID = function(id) if id == 9001 or id == 9002 then return 77 end return nil end
  CM.GetMapGroupMembersInfo = function(g) if g == 77 then return { { mapID = 9002, relativeHeightIndex = 2, name = "El templo" }, { mapID = 9001, relativeHeightIndex = 1, name = "Las cuevas" } } end return nil end
  CM.GetMapArtLayers = function(id) if conArte and (id == 9001 or id == 9002) then return { { layerWidth = 1002, layerHeight = 668, tileWidth = 256, tileHeight = 256 } } end return nil end
  CM.GetMapArtLayerTextures = function(id) if conArte then local t = {} for i = 1, 12 do t[i] = 136000 + i end return t end return nil end
  CM.GetPlayerMapPosition = function() if pos then return { x = pos[1], y = pos[2], GetXY = function() return pos[1], pos[2] end } end return nil end
  local inst = IsInInstance
  IsInInstance = function() return true, "party" end
  local actual = D.MazmorraActual
  D.MazmorraActual = function() return KEY end
  local s = Md.Leer()
  check(s.dentro and s.mapa == 9001, "no reconoció el mapa de la mazmorra")
  check(#s.pisos == 2 and s.pisos[1].mapa == 9001 and s.piso == 1, "los pisos no van en orden o no marca el tuyo")
  check(s.arte and #s.arte.texturas == 12, "no leyó el arte del plano")
  check(s.x == nil, "sin posición del juego, inventó una")
  Md.Abrir()
  T(2)
  local v = Md.Ventana()
  check(v and v:IsShown(), "no abrió el mapa por dentro")
  check(contiene(v, "Dentro de las mazmorras el juego no comparte tu posición."), "sin posición no lo dice")
  check(not Md.Plano().Flecha:IsShown(), "sin posición se ve la flecha")
  SNAP("mazmorra-mapa-sin-posicion", v)
  -- Zoom con la rueda y arrastrar: no se sale del plano.
  local p = Md.Plano()
  p:Zoom(2)
  check(p.zoom == 2, "el zoom no cambió")
  p.ox = 100000
  p:Colocar()
  local w, _, lw = p:Medidas()
  check(p.ox <= (lw - w) / 2 + 0.5, "arrastrar deja el plano fuera de la vista")
  FIRE(p, "OnMouseWheel", 1)
  check(p.zoom > 2, "la rueda no acerca")
  -- Con posición: la flecha y centrar.
  pos = { 0.4, 0.6 }
  p.zoom, p.ox, p.oy = 1, 0, 0
  Md.Pintar()
  T(1)
  check(p.Flecha:IsShown(), "con posición no se ve la flecha")
  SNAP("mazmorra-mapa-con-posicion", v)
  p:Centrar()
  local _, _, lw2, lh2 = p:Medidas()
  check(math.abs(p.ox - (0.5 - 0.4) * lw2) < 1, "centrar no pone tu posición en medio")
  -- Otro piso: sin flecha (no es el tuyo).
  FIRE(p, "OnMouseUp")
  Mz.MapaDentro.Pintar()
  -- En combate el plano no toma clics.
  combate = true
  FIRE_EVENT("PLAYER_REGEN_DISABLED")
  check(not p:IsMouseEnabled(), "en combate el plano toma clics")
  combate = false
  FIRE_EVENT("PLAYER_REGEN_ENABLED")
  -- Sin plano del juego: lo dice, y el camino de jefes sigue.
  conArte = false
  pos = nil
  p.mapaArte = nil
  Md.Pintar()
  T(1)
  check(contiene(v, "El juego no trae el plano de esta mazmorra"), "sin plano no lo dice")
  SNAP("mazmorra-mapa-sin-plano", v)
  v:Cerrar()
  -- El botón del mapa del juego.
  local W = rawget(_G, "WorldMapFrame")
  if W then
    Md.RevisarBotonMapa()
    local b = Md.BotonMapaJuego()
    check(b and b:IsShown(), "dentro de una mazmorra no sale el botón en el mapa del juego")
    IsInInstance = function() return false end
    Md.RevisarBotonMapa()
    check(b and not b:IsShown(), "fuera de una mazmorra sale el botón en el mapa del juego")
  end
  IsInInstance = inst
  D.MazmorraActual = actual
  for k, f in pairs(real) do CM[k] = f end
end)

---------------------------------------------------------------------------
-- Enciclopedia
---------------------------------------------------------------------------
local E = NS_OF("Alfa_Enciclopedia")
local Cat = E.Cat

step("91. errores de dedo", function()
  check(Cat.Parecido("espada", "espda", 1), "una letra de menos no se parece")
  check(Cat.Parecido("espada", "espdaa", 2), "dos al revés y una de más no se parecen")
  check(Cat.Parecido("sword", "swrod", 1), "dos letras al revés no se parecen")
  check(not Cat.Parecido("hacha", "lanza", 1), "«hacha» y «lanza» se parecen")
  check(Cat.FilaParecida(" sword of light\1 espada de luz", { "espadq", "luz" }), "una fila en tu idioma con un error de dedo no salió")
  check(not Cat.FilaParecida(" sword of light", { "escudo" }), "una fila sin nada que ver salió")
end)

step("90/91. la ficha plegable, «Guíame» fijo y la búsqueda con errores", function()
  E.V.Abrir({ texto = "silk clth", tipo = "objeto" })
  T(30)
  local v = rawget(_G, "AlfaEnciclopediaVentana")
  check(v and v:IsShown(), "la Enciclopedia no abrió") if not v then return end
  v:SetTamano(1040, 660)
  if v.alAcomodar then v.alAcomodar() end
  T(5)
  local cuenta = ""
  local function buscarCuenta(f) if f.Cuenta and f.Lista and f.MostrarFicha then cuenta = texto(f.Cuenta) end for _, h in ipairs({ f:GetChildren() }) do buscarCuenta(h) end end
  buscarCuenta(v)
  check(cuenta:find("parecidos", 1, true), "con un error de dedo no salen los parecidos: " .. cuenta)
  SNAP("enciclopedia-parecidos", v)
  E.V.Abrir({ kind = "item", id = 4306 })
  T(20)
  -- Plegar la primera sección con su título.
  local sec
  local function buscarSec(f) if f.Plegar and f.alfaS and f:IsShown() and not sec then sec = f end for _, h in ipairs({ f:GetChildren() }) do buscarSec(h) end end
  buscarSec(v)
  check(sec ~= nil, "la ficha no tiene secciones plegables")
  if sec then
    local clave = sec.alfaS.clave
    FIRE(sec.Plegar, "OnClick")
    T(2)
    check(E.V.Plegadas()[clave] == true and sec.alfaN == 0, "el clic no plegó la sección")
    SNAP("enciclopedia-plegada", v)
    FIRE(sec.Plegar, "OnClick")
    T(1)
    check(E.V.Plegadas()[clave] == nil, "el segundo clic no la abrió")
  end
  -- Bajar en la ficha: «Guíame» fijo.
  local function bajar(f)
    if f.Contenido and f.Barra and f.IrArriba then f:SetVerticalScroll(400) FIRE(f, "OnMouseWheel", -6) end
    for _, h in ipairs({ f:GetChildren() }) do bajar(h) end
  end
  bajar(v)
  T(2)
  E.V.RevisarGuiaFija()
  local fija
  local function buscarFija(f) for _, h in ipairs({ f:GetChildren() }) do if h.alfaTipo == "primario" and texto(h.Texto) == "Guíame" and h:IsShown() then fija = h end buscarFija(h) end end
  buscarFija(v)
  check(fija ~= nil, "al bajar en la ficha no sale «Guíame» fijo")
  SNAP("enciclopedia-guia-fija", v)
  v:Hide()
end)

---------------------------------------------------------------------------
-- La Jauría: los lobos con Alfa
---------------------------------------------------------------------------
local Mn = NS_OF("Alfa_Manada")
local Ce = Mn.Censo

step("49/50. los lobos con Alfa", function()
  local versionReal = A.version
  A.version = "1.3.9"
  -- (revisión 8: «dev» no se compara; un solo lobo no basta para avisar)
  check(Ce.Comparar("dev", "1.3.9") == 0, "«dev» cuenta como más nueva o más vieja")
  check(Ce.Comparar("1.3.10", "1.3.9") == 1 and Ce.Comparar("1.3.9", "1.3.9") == 0 and Ce.Comparar("1.2.9", "1.3.0") == -1, "comparar versiones sale mal")
  N.Datos("manada").censo = {}
  N.Datos("manada").censoAvisada = nil
  avisos = {}
  local mia = Ce.MiVersion()
  Ce.AlMensaje("Hocico-Reino", "Hocico-Reino", { "v", "99.0.0", "34", "1413" }, "GUILD")
  Ce.AlMensaje("Colmillo-Reino", "Colmillo-Reino", { "v", "1.0.0", "12", "0" }, "GUILD")
  Ce.AlMensaje("Susurro-Reino", "Susurro-Reino", { "v", "1.3.9", "20", "1413" }, "WHISPER")
  Ce.AlMensaje("Malo-Reino", "Malo-Reino", { "v", "1.3|9", "x", "1413" }, "GUILD")
  local lista = Ce.Lista()
  check(#lista == 2, "esperaba 2 lobos (ni el susurro ni lo mal formado): " .. #lista)
  local h
  for _, e in ipairs(lista) do if e.clave == "Hocico-Reino" then h = e end end
  check(h and h.nivel == 34 and h.mapa == 1413 and h.conectado and h.nueva, "el lobo no trae nivel, zona y que es más nuevo")
  check(Ce.Nueva() == nil, "un solo lobo con 99.0.0 ya cuenta como la versión nueva")
  T(2)
  check(not ultimoAviso("manada.censoNueva"), "avisó con un solo lobo")
  Ce.AlMensaje("Aullido-Reino", "Aullido-Reino", { "v", "99.0.0", "40", "0" }, "GUILD")
  check(Ce.Nueva() == "99.0.0", "con dos lobos no sabe cuál es la versión más nueva")
  T(2)
  check(ultimoAviso("manada.censoNueva"), "no avisó de la versión nueva")
  avisos = {}
  Ce.AlMensaje("Hocico-Reino", "Hocico-Reino", { "v", "99.0.0", "35", "1413" }, "GUILD")
  T(2)
  check(not ultimoAviso("manada.censoNueva"), "avisó dos veces de la misma versión")
  -- Lo mío: sin compartir tu ubicación, ni nivel ni zona.
  N.Set("manada", "compartir", false)
  check(Ce.Mensaje():match("^v|[^|]+|0|0$"), "sin compartir manda nivel o zona: " .. Ce.Mensaje())
  check(#Ce.Conectados() == 3, "los conectados no son 3")
  Ce.Abrir()
  T(2)
  local v = rawget(_G, "AlfaManadaLobos")
  check(v and v:IsShown() and contiene(v, "Debe actualizar"), "la ventana no dice quién debe actualizar")
  SNAP("manada-lobos", v)
  v:Cerrar()
  check(mia ~= "", "no sé mi versión")
  A.version = versionReal
end)

---------------------------------------------------------------------------
-- El Escritorio: paneles nuevos y plantillas
---------------------------------------------------------------------------
local Bv = NS_OF("Alfa_Bienvenida")
local Es = Bv.Escritorio

local function panel(id, w, h, tam)
  local def = Es.TIPOS[id]
  check(def ~= nil, "falta el panel " .. id) if not def then return end
  local esc = escenario(w + 24, h + 24)
  local c = CreateFrame("Frame", nil, esc)
  c:SetPoint("TOPLEFT", esc, "TOPLEFT", 12, -12)
  c:SetSize(w, h)
  local p = { def = def }
  def.crear(p, c)
  def.pintar(p, c, w, h, tam or "medio")
  SNAP("escritorio-" .. id, esc)
  return esc, c, p
end

step("94. los paneles nuevos del Escritorio", function()
  -- Tus misiones: el diario, las listas primero.
  local Q = C_QuestLog
  local n, info, objs = Q.GetNumQuestLogEntries, Q.GetInfo, Q.GetQuestObjectives
  local diario = {
    { title = "Lobos sarnosos", questID = 101, level = 8 },
    { title = "Carta para Grommash", questID = 102, level = 9, isComplete = true },
    { title = "Hierbas del valle", questID = 103, level = 7 },
  }
  Q.GetNumQuestLogEntries = function() return #diario end
  Q.GetInfo = function(i) return diario[i] end
  Q.GetQuestObjectives = function(id) if id == 101 then return { { text = "Lobo sarnoso: 4/10", finished = false } } end return {} end
  local lista = Es.Diario()
  check(#lista == 3 and lista[1].questID == nil and lista[1].lista, "la lista no va primero")
  local esc, c = panel("misiones", 380, 300)
  check(contiene(c, "Lobo sarnoso: 4/10") and contiene(c, "Lista para entregar"), "el panel de misiones no dice cuánto falta")
  esc:Hide()
  esc, c = panel("cerrar", 380, 220)
  check(contiene(c, "Listas para entregar"), "el panel «Cerrar mis misiones» no trae sus números")
  esc:Hide()
  Q.GetNumQuestLogEntries, Q.GetInfo, Q.GetQuestObjectives = n, info, objs
  -- Enciclopedia rápida: el buscador y lo último que viste.
  esc, c = panel("enciclopedia", 380, 300)
  esc:Hide()
  -- ¿Dónde está la manada?
  esc, c = panel("manada", 380, 300)
  check(contiene(c, "Hocico"), "el panel de la manada no muestra a quien está conectado")
  esc:Hide()
  -- Mapa de la mazmorra (fuera de una: lo dice).
  esc, c = panel("mapaMazmorra", 420, 320)
  check(contiene(c, "No estás en una mazmorra"), "fuera de una mazmorra el panel no lo dice")
  esc:Hide()
end)

step("95. plantillas vertical y ultraancha", function()
  local hay = {}
  for _, d in ipairs(Es.DISTRIBUCIONES) do hay[d.id] = d end
  for _, id in ipairs({ "vertical", "ultraancho" }) do
    local d = hay[id]
    check(d ~= nil, "falta la plantilla " .. id)
    if d then
      for _, lista in ipairs({ d.paneles, d.angosta }) do
        local ocupado = {}
        for _, x in ipairs(lista or {}) do
          check(Es.TIPOS[x.id] ~= nil, id .. ": el panel " .. x.id .. " no existe")
          check(x.x >= 0 and x.y >= 0 and x.x + x.w <= Es.COLUMNAS and x.y + x.h <= Es.FILAS, id .. ": " .. x.id .. " se sale de la rejilla")
          for cx = x.x, x.x + x.w - 1 do
            for cy = x.y, x.y + x.h - 1 do
              local k = cx .. ":" .. cy
              check(not ocupado[k], id .. ": " .. x.id .. " se encima con " .. tostring(ocupado[k]))
              ocupado[k] = x.id
            end
          end
        end
      end
    end
  end
  check(hay.vertical and hay.vertical.angosta, "la vertical no trae su acomodo angosto")
  for _, x in ipairs(hay.mazmorra and hay.mazmorra.paneles or {}) do check(x.id ~= "mapa", "la de mazmorra sigue con el mapa del mundo") end
end)

InCombatLockdown = enCombateReal
print(string.format("PRUEBA: 1.3.9 modulos, %d pasos, %d errores", pasos, #ERRORS))
