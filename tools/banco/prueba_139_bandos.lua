-- Prueba de la 1.3.9, área «bandos»:
--   * la tarjeta del viaje de la flecha (pedido urgente de Toxic): los cuatro
--     estados (camino, muelle, a bordo, llegando) y los cinco transportes,
--     sin el texto viejo del motor a la vez;
--   * 72 la flecha mínima;
--   * 103 la temática por bando (ventanas, anuncios, Hoy) para la Horda y la Alianza;
--   * 102 el marcador de La Jauría por bando;
--   * 105 los anuncios por tipo con su tema;
--   * 78/79 el mapa (leyenda, búsqueda, marcadores con nota y color);
--   * 80 los anuncios de zona de Forever; 92/93 la página y los mensajes de La Jauría.
-- Con BANCO_FOTOS=1 dibuja las capturas (tools/banco/shot-139-*.png).
SNAPSHOTS = {}
local FOTOS = os and os.getenv and os.getenv("BANCO_FOTOS")
local function SNAP(name, root, extra)
  if not FOTOS then return end
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
local function check(cond, msg) if not cond then NOTE("1.3.9 bandos", msg) end end

BANCO_LETRA = 0.64
Alfa.Hidden = function() return false end
FIRE_EVENT("PLAYER_LOGIN")
local N, B = AlfaNucleo, AlfaBienvenida
N.Datos("bienvenida").respondio = B and B.VERSION or 99
N.Datos("bienvenida").versionVista = B and B.VersionAlfa and B.VersionAlfa() or "9.9.9"
N.Datos("bienvenida").recorrido = true
FIRE_EVENT("PLAYER_ENTERING_WORLD", true, false)
RUN_TIMERS(10)
if AlfaBienvenida then AlfaBienvenida.Pendiente = function() return false end end

local A = Alfa
local K = N.Kit
local ns = NS_OF("Alfa")
local Nav = ns.Nav
if N.Entrando then N.Entrando = function() return false end end
if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end

local function fondoNoche(f, mx, my)
  local fondo = CreateFrame("Frame", nil, UIParent)
  fondo:SetFrameStrata("BACKGROUND")
  fondo:SetPoint("TOPLEFT", f, "TOPLEFT", -(mx or 40), my or 24)
  fondo:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", mx or 40, -(my or 24))
  local c = fondo:CreateTexture(nil, "BACKGROUND")
  c:SetAllPoints(fondo)
  c:SetTexture("white")
  c:SetGradient("VERTICAL", CreateColor(0.03, 0.05, 0.08, 1), CreateColor(0.1, 0.13, 0.19, 1))
  fondo:Show()
  return fondo
end

---------------------------------------------------------------------------
-- La tarjeta del viaje
---------------------------------------------------------------------------
local X = ns.Transit
local Ar = Nav.arrow
local T = Nav.travel
local horario = { medido = false, llega = nil, sale = nil, espera = 175, viaje = 300, siguiente = 840, abordo = nil }
local real = { NextArrival = X.NextArrival, NextDeparture = X.NextDeparture, Riding = X.Riding, Now = X.Now }
local function conHorario(kind)
  X.Now = function() return NOW end
  X.NextArrival = function()
    if not horario.medido then return nil end
    return horario.llega, horario.sale, true
  end
  X.NextDeparture = function(_, _, now)
    if not horario.medido then return horario.espera, horario.viaje, false end
    if now and now > NOW + 3 then return horario.siguiente, horario.viaje, true end
    return horario.sale or horario.espera, horario.viaje, true
  end
  X.Riding = function()
    if horario.abordo then return { kind = kind, route = "r1", dock = "Trinquete", arriveIn = horario.abordo } end
    return nil
  end
end
local function sinHorario() for k, v in pairs(real) do X[k] = v end end
local DESTINO = { boat = "Trinquete", zeppelin = "Orgrimmar", tram = "Forjaz", portal = "Ventormenta", fly = "Bahía del Botín" }
local MUELLE = { boat = "Bahía del Botín", zeppelin = "Entrañas", tram = "Ventormenta", portal = "Dalaran", fly = "Villa Oscura" }
local function tramo(kind)
  return { kind = kind, label = "x", to = { name = DESTINO[kind], c = 0, wx = 1, wy = 1 },
    from = { name = MUELLE[kind], c = 0, wx = 0, wy = 0 },
    transport = kind ~= "fly" and kind ~= "portal" and { id = "r1" } or nil, side = "a", seconds = 240 }
end
local guardaT, guardaNav = {}, {}
for _, k in ipairs({ "Active", "CurrentLeg", "NextLeg", "CurrentLabel", "Remaining" }) do guardaT[k] = T[k] end
for _, k in ipairs({ "Sample", "GetTarget", "HiddenWithGuide", "TomTomArrowGuides", "HandedOff", "IsHiddenState" }) do guardaNav[k] = Nav[k] end
local escena = { estado = "muelle", kind = "boat" }
local function montar()
  -- 1.4.0 (69): la compacta es la de fábrica; aquí se prueba la grande (prueba_140_mundo prueba la compacta).
  A.Set("nav.viajeCompacto", false)
  T.Active = function() return true end
  T.CurrentLeg = function()
    if escena.estado == "camino" then return { kind = "walk", to = { c = 0, wx = 0, wy = 0 } } end
    return tramo(escena.kind)
  end
  T.NextLeg = function() if escena.estado == "camino" then return tramo(escena.kind) end return nil end
  T.CurrentLabel = function() return "Toma el barco a Trinquete\nBarco: espera promedio 2:55" end
  T.Remaining = function() return 1500 end
  Nav.Sample = function()
    if escena.estado == "camino" then return "travel", 120, 0.4 end
    return "instruction", 0
  end
  Nav.GetTarget = function() return { label = "Ve a 23.8, 77.3", map = 1445, x = 0.238, y = 0.773 } end
  Nav.HiddenWithGuide = function() return false end
  Nav.TomTomArrowGuides = function() return false end
  Nav.HandedOff = function() return false end
  Nav.IsHiddenState = function() return false end
  A.Set("nav.arrow", true)
end
local function desmontar()
  A.Set("nav.viajeCompacto", nil)
  for k, fn in pairs(guardaT) do T[k] = fn end
  for k, fn in pairs(guardaNav) do Nav[k] = fn end
  sinHorario()
end
local function correr(veces)
  local f = Ar.frame
  for _ = 1, veces or 8 do NOW = NOW + 0.3 FIRE(f, "OnUpdate", 0.3) end
end

local CASOS = {
  { kind = "boat", estado = "camino", medido = false },
  { kind = "boat", estado = "muelle", medido = true, llega = 95, sale = 168 },
  { kind = "boat", estado = "muelle", medido = false, foto = "sin-horario" },
  { kind = "boat", estado = "abordo", abordo = 140 },
  { kind = "boat", estado = "llegando", abordo = 12 },
  { kind = "zeppelin", estado = "muelle", medido = true, llega = 0, sale = 35 },
  { kind = "zeppelin", estado = "abordo", abordo = 90 },
  { kind = "tram", estado = "muelle", medido = false },
  { kind = "tram", estado = "camino", medido = true, llega = 60, sale = 80 },
  { kind = "portal", estado = "camino" },
  { kind = "portal", estado = "muelle" },
  { kind = "fly", estado = "camino" },
  { kind = "fly", estado = "muelle" },
}

local function casoTarjeta(c, tema)
  K.bandoPrueba = tema
  A.Set("nucleo.bando", tema ~= nil)
  escena.estado, escena.kind = c.estado == "llegando" and "muelle" or (c.estado == "abordo" and "muelle" or c.estado), c.kind
  horario.medido, horario.llega, horario.sale = c.medido and true or false, c.llega, c.sale
  horario.abordo = c.abordo
  conHorario(c.kind)
  local f = Ar.frame
  f:ClearAllPoints()
  f:SetPoint("CENTER", UIParent, "CENTER", 0, 60)
  f:Hide()
  f:Show()
  correr(8)
  local tj = Ar.Tarjeta and Ar.Tarjeta()
  local nombre = c.kind .. "-" .. (c.foto or c.estado)
  check(tj ~= nil, nombre .. ": no salió la tarjeta del viaje")
  if not tj then return end
  print("TARJETA", nombre, "|", tj.estado, "|", tj.sobre, "|", tj.titulo, "|", tj.cuenta, "|", tj.nota, "|", tj.ruta)
  check(tj.estado == c.estado, nombre .. ": estado " .. tostring(tj.estado) .. " en vez de " .. c.estado)
  check(not tj.viejo, nombre .. ": el texto viejo del motor se ve a la vez")
  check(tj.titulo and tj.titulo:find(DESTINO[c.kind], 1, true), nombre .. ": el título no dice el destino")
  check(not (tj.ruta or ""):find("23.8", 1, true), nombre .. ": coordenadas sueltas")
  check(tj.abajo == (c.estado == "camino" or nil), nombre .. ": la tarjeta va en otro lugar")
  for _, t in ipairs({ tj.sobre or "", tj.titulo or "", tj.nota or "", tj.ruta or "" }) do
    check(not t:find("promedio") and not t:find("average"), nombre .. ": aún dice «espera promedio»")
  end
  if c.estado == "llegando" then check(tj.sobre and tj.sobre:find("TIERRA", 1, true), "llegando no dice «¡Tierra a la vista!»") end
  if c.estado == "abordo" then check(tj.sobre == "A BORDO", "a bordo no lo dice: " .. tostring(tj.sobre)) end
  if c.kind == "boat" and c.estado == "muelle" and not c.medido then
    check(tj.espera and tj.nota and tj.nota:find("Sale cada", 1, true) and tj.nota:find("Mide el horario", 1, true),
      "sin horario no dice «Sale cada» ni «Mide el horario»")
  end
  if c.medido and c.estado == "muelle" and c.llega and c.llega > 0 then
    check(tj.cuenta == "2:48", "con horario no cuenta grande «2:48»: " .. tostring(tj.cuenta))
  end
  if c.estado == "camino" then check(tj.sobre and tj.sobre:find("120", 1, true), "caminando no dice la distancia") end
  if FOTOS then
    local tf = Ar.tarjeta
    local fondo = fondoNoche(tf, 50, 30)
    SNAP("viaje-" .. nombre .. (tema and ("-" .. tema) or ""), fondo, { f })
    fondo:Hide()
  end
end

step("La tarjeta del viaje: 4 estados y 5 transportes", function()
  check(Ar.Tarjeta, "falta Arrow.Tarjeta")
  montar()
  for _, c in ipairs(CASOS) do casoTarjeta(c, nil) end
  -- Con la temática de cada bando.
  casoTarjeta({ kind = "boat", estado = "muelle", medido = true, llega = 95, sale = 168 }, "H")
  casoTarjeta({ kind = "zeppelin", estado = "abordo", abordo = 90 }, "H")
  casoTarjeta({ kind = "boat", estado = "muelle", medido = true, llega = 95, sale = 168 }, "A")
  casoTarjeta({ kind = "tram", estado = "camino", medido = true, llega = 60, sale = 80 }, "A")
  K.bandoPrueba = nil
  A.Set("nucleo.bando", false)
  -- Al dejar el viaje la tarjeta se va y la flecha vuelve a lo de siempre.
  T.Active = function() return false end
  Nav.Sample = function() return "travel", 300, 0.2 end
  correr(3)
  check(not (Ar.Tarjeta and Ar.Tarjeta()), "la tarjeta se quedó al dejar el viaje")
  check(Ar.distText:IsShown(), "la distancia no volvió")
  Ar.frame:Hide()
  desmontar()
end)

---------------------------------------------------------------------------
-- 72. La flecha mínima
---------------------------------------------------------------------------
step("72: la flecha mínima", function()
  montar()
  T.Active = function() return false end
  Nav.Sample = function() return "travel", 300, 0.2 end
  A.Set("nav.arrowEta", true)
  A.Set("nav.arrowMinimo", false)
  local f = Ar.frame
  f:Show()
  correr(4)
  check(Ar.labelText:IsShown(), "sin mínima, la meta debería verse")
  A.Set("nav.arrowMinimo", true)
  correr(4)
  check(Ar.Minimo and Ar.Minimo(), "no se prendió la flecha mínima")
  check(not Ar.labelText:IsShown() and not Ar.etaText:IsShown(), "la flecha mínima sigue con la meta o el tiempo")
  check(Ar.distText:IsShown(), "la flecha mínima perdió la distancia")
  if FOTOS then
    local fondo = fondoNoche(f, 40, 20)
    SNAP("flecha-minima", fondo, { f })
    fondo:Hide()
  end
  A.Set("nav.arrowMinimo", false)
  correr(2)
  check(Ar.labelText:IsShown(), "al apagar la mínima no vuelve la meta")
  f:Hide()
  desmontar()
end)

---------------------------------------------------------------------------
-- 103. La temática por bando: ventanas, anuncios y el sello de Hoy
---------------------------------------------------------------------------
local function ventanaDePrueba(nombre)
  local v = K.Ventana({ nombre = nombre, titulo = "La Jauría", subtitulo = "Tu manada", icono = "ic-manada", ancho = 420, alto = 220 })
  v:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
  local t = K.Texto(v.Cuerpo, "cuerpo", "texto")
  t:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", 16, -16)
  K.Escribir(t, "Así se ve una ventana de Alfa con tu bando.")
  return v
end

step("103: la temática por bando", function()
  check(K.Bando and K.BandoMio and K.AdornarBando and K.SelloBando, "falta la API de la temática (Kit/Bando.lua)")
  check(A.Get("nucleo.bando") == false, "la temática debe venir apagada de fábrica")
  K.bandoPrueba = "H"
  check(K.Bando() == nil, "apagada, K.Bando() debe dar nil")
  check(K.BandoMio() and K.BandoMio().clave == "horda", "K.BandoMio no sabe tu bando")
  local v = ventanaDePrueba("AlfaPruebaBando")
  v:Show()
  check(not (v.alfaBando and v.alfaBando.tira:IsShown()), "apagada, la ventana no debe llevar adornos")
  for _, l in ipairs({ "H", "A" }) do
    K.bandoPrueba = l
    A.Set("nucleo.bando", true)
    local t = K.Bando()
    check(t and t.letra == l, l .. ": K.Bando() no da el tema")
    check(v.alfaTemaBando == t.clave, l .. ": la ventana no se vistió al prender (" .. tostring(v.alfaTemaBando) .. ")")
    -- 1.4.0 (67): la tira cede su lugar a la cabecera con textura (salvo en Clásico WoW).
    check(v.alfaBando and v.alfaBando.emblema:IsShown() and (v.alfaBando.tira:IsShown() or v.alfaBando.cab:IsShown()), l .. ": falta el emblema o la tira")
    check(not v.Cabecera.Linea:IsShown(), l .. ": la línea de la cabecera debe ceder su lugar a la tira")
    if FOTOS then
      local fondo = fondoNoche(v, 30, 30)
      SNAP("ventana-" .. t.clave, fondo, { v })
      fondo:Hide()
    end
    -- Un anuncio con el tema del bando (105).
    K.QuitarAnuncio()
    K.Anuncio({ estilo = "llegada", titulo = "Orgrimmar", sobre = "Llegaste", texto = "La manada te esperaba", ya = true })
    local f = rawget(_G, "AlfaAnuncio")
    if f then for _ = 1, 12 do FIRE(f, "OnUpdate", 0.1) end end
    local a = K.AnuncioActual()
    check(a and a.bando == t.clave and a.emblema and a.tira, l .. ": el anuncio no lleva el tema del bando")
    check(a and type(a.color) == "table", l .. ": el anuncio no toma el color del bando")
    if FOTOS and f then
      local fondo = fondoNoche(f, 0, 0)
      SNAP("anuncio-" .. t.clave, fondo, { f })
      fondo:Hide()
    end
    K.QuitarAnuncio()
  end
  A.Set("nucleo.bando", false)
  check(not v.alfaBando.tira:IsShown() and not v.alfaBando.cab:IsShown() and v.Cabecera.Linea:IsShown(), "al apagar, la ventana no vuelve a lo de siempre")
  v:Hide()
  -- La pregunta de una vez.
  local d = N.Datos("kit")
  d.bandoPreguntado, d.bandoElegido = nil, nil
  local avisos = 0
  local off = A.On("ALFA_AVISO", function(o) if type(o) == "table" and tostring(o.titulo):find("bando", 1, true) then avisos = avisos + 1 end end)
  K.PreguntarBando()
  K.PreguntarBando()
  check(d.bandoPreguntado == true, "no anotó que ya preguntó")
  check(avisos <= 1, "preguntó más de una vez")
  K.bandoPrueba = nil
end)

---------------------------------------------------------------------------
-- 105. Los anuncios por tipo: la onda de entrada y la tira
---------------------------------------------------------------------------
step("105: los anuncios, más cine por tipo", function()
  check(K.ONDA_ANUNCIO and K.ONDA_ANUNCIO.desliza and K.ONDA_ANUNCIO.flota, "falta la onda por animación")
  for estilo, e in pairs(K.ESTILOS_ANUNCIO) do
    check(K.ONDA_ANUNCIO[e.anim or ""], estilo .. ": su animación no tiene onda")
  end
  K.bandoPrueba = "A"
  A.Set("nucleo.bando", true)
  for _, estilo in ipairs({ "barco", "zona", "descubrir", "manada" }) do
    K.QuitarAnuncio()
    K.Anuncio({ estilo = estilo, titulo = "Ventormenta", sobre = "Llegas a", texto = "Niveles 1–10", ya = true, espaciar = 0 })
    local f = rawget(_G, "AlfaAnuncio")
    check(f and f.Onda, estilo .. ": falta la onda")
    if f then
      FIRE(f, "OnUpdate", 0.2)
      check(f.Onda:IsShown(), estilo .. ": la onda no sale al entrar")
      for _ = 1, 30 do FIRE(f, "OnUpdate", 0.1) end
      check(not f.Onda:IsShown(), estilo .. ": la onda no se va")
      if FOTOS and (estilo == "barco" or estilo == "descubrir") then
        local fondo = fondoNoche(f, 0, 0)
        SNAP("anuncio-alianza-" .. estilo, fondo, { f })
        fondo:Hide()
      end
    end
  end
  K.QuitarAnuncio()
  A.Set("nucleo.bando", false)
  K.bandoPrueba = nil
end)

---------------------------------------------------------------------------
-- 102. El marcador de La Jauría por bando
---------------------------------------------------------------------------
local Mn = NS_OF("Alfa_Manada")
step("102: el marcador por bando", function()
  local Mc = Mn.Marcador
  check(Mc and Mc.Nuevo and Mc.Contar, "falta Marcador.lua")
  if not Mc then return end
  for _, l in ipairs({ "H", "A" }) do
    K.bandoPrueba = l
    local otra = l == "H" and "A" or "H"
    local db = Mc.Datos()
    db[otra] = nil
    local c = Mc.Contar()
    check(c.mia == l, "no sabe tu bando")
    check(c[l].vivo and c[l].n >= 1, "tu bando no se cuenta en vivo (al menos tú)")
    check(c[otra].n == nil, "sin datos, el otro bando no debe inventar un número")
    check(db[l] and db[l].n == c[l].n and db[l].fecha, "no guarda tu número en AlfaNucleoDB.jauria.bandos")
    local padre = CreateFrame("Frame", nil, UIParent)
    padre:SetSize(520, 300)
    padre:SetPoint("CENTER")
    local b = Mc.Nuevo(padre)
    b:SetPoint("TOPLEFT", padre, "TOPLEFT", 16, -16)
    b:Llenar()
    local h = b:Acomodar(488)
    check(h > 150, "el marcador quedó muy chico: " .. h)
    check(b[otra].Nota:GetText() == "Se ve desde su lado", "el otro bando no dice «Se ve desde su lado»: " .. tostring(b[otra].Nota:GetText()))
    check(b[l].Tuyo:IsShown(), "tu columna no dice «Tu bando»")
    -- Con un número que llegó de fuera (el instalador).
    db[otra] = { n = 7, fecha = (time and time() or 0) - 3 * 86400, fuente = "instalador" }
    b:Llenar()
    b:Acomodar(488)
    check(b[otra].Cifra:GetText() == "7", "no enseña el último número conocido del otro bando")
    check((b[otra].Nota:GetText() or ""):find("Último conocido", 1, true), "no dice que es el último conocido")
    padre:SetSize(520, h + 32)
    if FOTOS then
      local fondo = fondoNoche(padre, 0, 0)
      SNAP("marcador-" .. K.TemaBando(l).clave, fondo, { padre })
      fondo:Hide()
    end
    padre:Hide()
    db[otra] = nil
  end
  K.bandoPrueba = nil
  -- En la página de La Jauría.
  N.Abrir("manada")
  RUN_TIMERS(2)
  local ui = Mn.Pagina and Mn.Pagina.ui
  check(ui and ui.marcador and ui.marcador:IsShown(), "el marcador no está en la página de La Jauría")
  if A.UI and A.UI.Options and A.UI.Options.frame then A.UI.Options.frame:Hide() end
  -- El panel del Escritorio.
  local E = rawget(_G, "AlfaEscritorio")
  if E and E.RegistrarPanel then
    Mc.RegistrarPanel()
    local Bv = NS_OF("Alfa_Bienvenida")
    check(Bv.Escritorio and Bv.Escritorio.TIPOS.jauria, "el marcador no se registró como panel del Escritorio")
  end
end)

---------------------------------------------------------------------------
-- 92 y 93. La página en tres partes y los avisos de la manada
---------------------------------------------------------------------------
step("92: la manada a la vista en tres partes", function()
  local P = Mn.Pagina
  local gente = {
    { tipo = "manada", clave = "c", nombre = "Cerca1", via = "canal" },
    { tipo = "manada", clave = "h", nombre = "Herm1", via = "hermandad" },
    { tipo = "grupo", clave = "g", nombre = "Grupo1" },
    { tipo = "manada", clave = "c2", nombre = "Cerca2", via = "canal" },
  }
  P.Ordenar(gente)
  check(gente[1].seccion == "grupo" and gente[2].seccion == "hermandad" and gente[3].seccion == "cerca" and gente[4].clave == "c2",
    "no ordena en tu grupo, tu hermandad y cerca: " .. gente[1].clave .. gente[2].clave .. gente[3].clave .. gente[4].clave)
  local texto = P.Cuentas(gente)
  check(texto:find("Tu grupo 1", 1, true) and texto:find("Tu hermandad 1", 1, true) and texto:find("Cerca 2", 1, true), "las cuentas no salen: " .. texto)
end)

step("93: los avisos de la manada, un estilo y sin duplicados", function()
  local U = Mn.U
  check(U.Aviso, "falta U.Aviso")
  local n = 0
  local off = A.On("ALFA_AVISO", function(o) if type(o) == "table" and o.titulo == "Prueba de la manada" then n = n + 1 end end)
  local o1 = { titulo = "Prueba de la manada", texto = "Un lobo anda cerca" }
  U.Aviso(o1)
  U.Aviso({ titulo = "Prueba de la manada", texto = "Un lobo anda cerca" })
  check(o1.modulo == "manada" and o1.icono == "ic-manada", "el aviso no lleva la firma de la manada")
  check(n <= 1, "el mismo aviso salió dos veces")
  check(U.AvisosDados()["Prueba de la manada|Un lobo anda cerca"], "no anotó el aviso")
  -- Ningún archivo de La Jauría llama a K.Aviso por su cuenta.
end)

---------------------------------------------------------------------------
-- 78, 79. El mapa: buscar un lugar, la leyenda y la nota de un marcador
---------------------------------------------------------------------------
local Mu = NS_OF("Alfa_Mundo")
step("78 y 79: buscar, leyenda y notas", function()
  local Bu = Mu.Buscar
  check(Bu and Bu.Buscar and Bu.Leyenda, "falta Buscar.lua")
  if not Bu then return end
  check(Bu.Simple("Ciudad de Ventormenta") == "ciudad de ventormenta", "Simple no deja minúsculas")
  check(Bu.Simple("Árbol Ñandú") == "arbol nandu", "Simple no quita tildes: " .. Bu.Simple("Árbol Ñandú"))
  local ley = Bu.Leyenda()
  check(#ley > 3, "la leyenda está vacía")
  local conEjemplo = 0
  for _, d in ipairs(ley) do if d.ejemplo and d.ejemplo ~= "" then conEjemplo = conEjemplo + 1 end end
  check(conEjemplo > 0, "la leyenda no trae ejemplos")
  -- Un marcador con nota.
  local Mk = Mu.Marcadores
  local m = Mk.Crear({ mapa = 1411, x = 50, y = 50, nombre = "Cueva de Lya", nota = "Aquí\nhay salchichas|r ricas", color = "oro" })
  check(m and m.nota == "Aquí hay salchichas r ricas", "la nota no se guarda limpia: " .. tostring(m and m.nota))
  Mk.Cambiar(m.id, { nota = "" })
  check(m.nota == nil, "una nota vacía debe borrarse")
  Mk.Cambiar(m.id, { nota = "Salchichas" })
  local r = Bu.Buscar("salchi")
  local hallado = false
  for _, x in ipairs(r) do if x.m and x.m.id == m.id then hallado = true end end
  check(hallado, "buscar no encuentra un marcador por su nota")
  local r2 = Bu.Buscar("cueva de LYA")
  check(r2[1] and r2[1].m, "buscar no encuentra un marcador por su nombre")
  -- El panel en el mapa.
  if Mu.Ventana then
    Mu.Ventana.Abrir()
    RUN_TIMERS(1)
    Bu.Abrir(nil)
    local F = Bu.Marco()
    check(F and F:IsShown(), "el panel de buscar no abre")
    if FOTOS and F then
      local fondo = fondoNoche(F, 10, 10)
      SNAP("mapa-leyenda", fondo, { F })
      fondo:Hide()
    end
    Bu.Abrir(nil, "lya")
    if FOTOS and F then
      local fondo = fondoNoche(F, 10, 10)
      SNAP("mapa-buscar", fondo, { F })
      fondo:Hide()
    end
    if F then F:Hide() end
    Mu.Ventana.Cerrar()
  end
  Mk.Borrar(m.id, true)
end)

---------------------------------------------------------------------------
-- 80. Los anuncios de zona de Forever
---------------------------------------------------------------------------
step("80: los rangos y colores de las zonas", function()
  local Z = N.Zonas
  local real = A.Maps and A.Maps.GetZoneLevels
  -- Lo medido de más por el motor se corrige.
  if A.Maps then A.Maps.GetZoneLevels = function(id) if id == 1412 then return 3, 27 end if id == 2548 then return 37, 57 end return nil end end
  local lo, hi = Z.Niveles(1412)
  check(lo == 1 and hi == 10, "Mulgore no se corrige a 1–10: " .. tostring(lo) .. "–" .. tostring(hi))
  lo, hi = Z.Niveles(2548)
  check(lo == 37 and hi == 57, "Riverglades (nueva de Forever) pierde su rango")
  check(Z.Niveles(1450) == nil, "el Claro de la Luna no debe decir niveles")
  check(Z.DUENO_ALFA[2482] and Z.NUEVAS_FOREVER[2521], "faltan las zonas nuevas de Forever")
  if A.Maps then A.Maps.GetZoneLevels = real end
end)

print("PRUEBA 1.3.9 bandos:", pasos, "pasos")
