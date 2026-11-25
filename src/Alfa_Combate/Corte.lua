-- Alfa - Combate: el aviso para cortar (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.0. Cuando tu objetivo (o tu foco, combate.corteFoco) empieza a lanzar
-- algo que se puede cortar, un aviso claro: tu habilidad para cortar, su
-- tecla de tu barra y si está lista o cuánto le falta.
--   * UnitCastingInfo / UnitChannelInfo (UnitDocumentation): notInterruptible
--     dice si se puede cortar; isTradeskill (nunca secreto), si es un oficio.
--   * En mazmorras esos datos llegan secretos: no se comparan. Si el nombre
--     es secreto, sí hay un lanzamiento (no se compara con nil); si lo secreto
--     es notInterruptible, el aviso se pinta con SetAlphaFromBoolean (el
--     juego decide si se ve) y, sin esa función, sale como «¡Está lanzando!».
--   * La recarga de tu corte, con Recargas.Falta (también con tiempos secretos).
-- Solo muestra: nada recibe el ratón, no elige objetivo ni lanza nada.
-- Se vigila por eventos (UNIT_SPELLCAST_* de target y focus); un reloj
-- ligero (0.2 s) solo mientras el aviso está a la vista.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local Co = {}
M.Corte = Co

local type, ipairs, pcall, floor, max, min, format, tonumber = type, ipairs, pcall, math.floor, math.max, math.min, string.format, tonumber
local ESP = K.ESP
local ANCHO, ALTO, ICONO = 280, 56, 40
local TOPE = 12 -- segundos como mucho a la vista, si el fin no se puede leer

-- Las habilidades para cortar de cada clase, en orden de preferencia (todos
-- sus rangos, de menor a mayor: vale el más alto que conozcas).
Co.HABILIDADES = {
	WARRIOR = { { 6552, 6554 }, { 72, 1671, 1672 } },                 -- Patada (rabioso), Golpe de escudo
	ROGUE = { { 1766, 1767, 1768, 1769 } },                            -- Patada
	MAGE = { { 2139 } },                                              -- Contrahechizo
	SHAMAN = { { 8042, 8044, 8045, 8046, 10412, 10413, 10414 } },     -- Choque de tierra
	PALADIN = { { 853, 5588, 5589, 10308 } },                         -- Martillo de justicia
	DRUID = { { 5211, 6798, 8983 }, { 16979 } },                      -- Azote, Cargar feral
	HUNTER = { { 19503 } },                                           -- Disparo de dispersión
	PRIEST = { { 15487 } },                                           -- Silencio
	WARLOCK = { { 6789, 17925, 17926 } },                             -- Espiral de la muerte
}

-- -> el id que conoces para cortar, o nil. Si conoces varios, el que el juego
--    te deja usar ahora (Patada solo en actitud rabiosa, Golpe de escudo con escudo).
--    1.3.1: si a una solo le falta recurso (ira, energía, maná), esa es la que
--    toca: en actitud defensiva con poca ira gana Golpe con escudo, no Patada.
function Co.Habilidad()
	local primero, sinRecurso
	for _, ids in ipairs(Co.HABILIDADES[M.Clase() or ""] or {}) do
		for i = #ids, 1, -1 do
			if M.Conoce(ids[i]) then
				local usable, falta = M.Llamar(C_Spell and C_Spell.IsSpellUsable, ids[i])
				if M.Legible(usable) == true then return ids[i] end
				if M.Legible(falta) == true then sinRecurso = sinRecurso or ids[i] end
				primero = primero or ids[i]
				break
			end
		end
	end
	return sinRecurso or primero
end

---------------------------------------------------------------------------
-- ¿Quién lanza qué?
---------------------------------------------------------------------------
local function enemigo(u)
	if M.Legible(M.Llamar(UnitExists, u)) ~= true then return false end
	if M.Legible(M.Llamar(UnitCanAttack, "player", u)) ~= true then return false end
	return M.Legible(M.Llamar(UnitIsDeadOrGhost or UnitIsDead, u)) ~= true
end

-- -> nil (nada que cortar) o { unidad, textura, fin (o nil), seguro (true |
--    false: no se sabe), inmune (el valor secreto, si lo es) }
function Co.Lanza(u)
	if not enemigo(u) then return nil end
	local nombre, _, tex, _, fin, oficio, _, inmune = M.Llamar(UnitCastingInfo, u)
	local canal = false
	if not M.Secreto(nombre) and nombre == nil then
		local n2, _, t2, _, f2, o2, inm2 = M.Llamar(UnitChannelInfo, u)
		nombre, tex, fin, oficio, inmune, canal = n2, t2, f2, o2, inm2, true
	end
	-- Lo secreto primero: un valor secreto no se compara (ni con nil).
	if not M.Secreto(nombre) and nombre == nil then return nil end
	if not M.Secreto(oficio) and oficio == true then return nil end
	local x = { unidad = u, textura = tex, canal = canal }
	if not M.Secreto(fin) and type(fin) == "number" then x.fin = fin / 1000 end
	if M.Secreto(inmune) then
		x.seguro, x.inmune = false, inmune
	elseif inmune == true then
		return nil
	else
		x.seguro = not M.Secreto(nombre)
	end
	return x
end

---------------------------------------------------------------------------
-- El aviso
---------------------------------------------------------------------------
local f, reloj, actual
local sonoPara -- el lanzamiento (unidad y cuándo empezó) que ya sonó

local function crear()
	if f then return f end
	f = M.Marco("Corte", L["Aviso para cortar"], ANCHO, ALTO, { "CENTER", "CENTER", 0, 200 })
	f.Cuerpo = CreateFrame("Frame", nil, f)
	f.Cuerpo:SetAllPoints(f)
	f.Cuerpo.caja = K.Caja(f.Cuerpo, { fondo = "fondo", alfaFondo = 0.92, borde = "peligro", alfaBorde = 0.8, corte = K.CORTE.control })
	f.Cuerpo.Franja = K.Plano(f.Cuerpo, "peligro", "ARTWORK", 1)
	f.Cuerpo.Franja:SetWidth(3)
	f.Cuerpo.Franja:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", 0, -K.CORTE.control - 2)
	f.Cuerpo.Franja:SetPoint("BOTTOMLEFT", f.Cuerpo, "BOTTOMLEFT", 0, K.CORTE.control + 2)
	-- Lo que lanza el enemigo (su ícono; la textura acepta un valor secreto).
	f.Lanza = f.Cuerpo:CreateTexture(nil, "ARTWORK")
	f.Lanza:SetSize(28, 28)
	f.Lanza:SetPoint("LEFT", f.Cuerpo, "LEFT", ESP.m, 0)
	f.Lanza:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	-- Tu corte: grande a la derecha, con su barrido y su tecla.
	f.Tuyo = CreateFrame("Frame", nil, f.Cuerpo)
	f.Tuyo:SetSize(ICONO, ICONO)
	f.Tuyo:SetPoint("RIGHT", f.Cuerpo, "RIGHT", -ESP.s - 2, 0)
	f.Tuyo.caja = K.Caja(f.Tuyo, { fondo = "hundido", borde = "acento", corte = K.CORTE.casilla })
	f.Tuyo.Icono = f.Tuyo:CreateTexture(nil, "ARTWORK")
	f.Tuyo.Icono:SetPoint("TOPLEFT", f.Tuyo, "TOPLEFT", 2, -2)
	f.Tuyo.Icono:SetPoint("BOTTOMRIGHT", f.Tuyo, "BOTTOMRIGHT", -2, 2)
	f.Tuyo.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	f.Tuyo.Recarga = M.CrearBarrido(f.Tuyo, f.Tuyo.Icono)
	f.Tecla = CreateFrame("Frame", nil, f.Tuyo)
	f.Tecla:SetFrameLevel(f.Tuyo:GetFrameLevel() + 6)
	f.Tecla.caja = K.Caja(f.Tecla, { fondo = "fondo", alfaFondo = 0.85, borde = false, corte = K.CORTE.casilla })
	f.Tecla.Texto = K.Texto(f.Tecla, "numero", "texto")
	f.Tecla.Texto:SetPoint("CENTER", f.Tecla, "CENTER", 0, 0)
	f.Tecla:SetPoint("BOTTOM", f.Tuyo, "BOTTOM", 0, 2)
	local x = ESP.m + 28 + ESP.m
	f.Titulo = K.Texto(f.Cuerpo, "subtitulo", "peligro")
	f.Titulo:SetPoint("TOPLEFT", f.Cuerpo, "TOPLEFT", x, -ESP.s - 2)
	f.Titulo:SetWidth(ANCHO - x - ICONO - ESP.m - ESP.s)
	f.Linea = K.Texto(f.Cuerpo, "nota", "textoSuave")
	f.Linea:SetPoint("TOPLEFT", f.Titulo, "BOTTOMLEFT", 0, -2)
	f.Linea:SetWidth(ANCHO - x - ICONO - ESP.m - ESP.s)
	f:Hide()
	return f
end

local function sinReloj()
	if reloj then reloj:Cancel() reloj = nil end
end

local function ocultar()
	actual = nil
	sinReloj()
	if f and not M.Desbloqueado() then f:Hide() end
end

-- 1.3.2: tu corte para este lanzamiento (habilidad, nombre, ícono y tecla) se
-- elige al empezar el lanzamiento, no en cada vuelta del reloj, y se olvida
-- cuando cambian tus barras o tus hechizos (Rotacion.OlvidarBarras -> Co.Olvidar).
local elegido
function Co.Olvidar() elegido = nil end

local function datosDe(id)
	return { id = id, nombre = M.NombreHechizo(id) or "?", icono = M.IconoHechizo(id) or K.Lobo("atento"),
		tecla = M.Rotacion and M.Rotacion.Tecla and M.Rotacion.Tecla(id) or nil }
end

-- -> el corte elegido, o nil si no conoces ninguno.
function Co.Elegido()
	if elegido then return elegido end
	local id = Co.Habilidad()
	if not id then return nil end
	elegido = datosDe(id)
	return elegido
end

-- La línea de abajo: lista (con tecla), cuánto le falta o que te acerques.
-- e: el corte elegido (nombre y tecla ya buscados); conFalta: `falta` ya se
-- pidió a Recargas en esta vuelta (puede ser nil: en recarga, sin saber cuánto).
function Co.Estado(id, unidad, e, falta, conFalta)
	local nombre = e and e.nombre or M.NombreHechizo(id) or "?"
	if not conFalta then falta = M.Recargas and M.Recargas.Falta(id) end
	local tecla
	if e then tecla = e.tecla else tecla = M.Rotacion and M.Rotacion.Tecla and M.Rotacion.Tecla(id) or nil end
	if falta == nil then return format(L["%s está en recarga"], nombre), "aviso", tecla end
	if falta > 0.3 then return format(L["%s vuelve en %d s"], nombre, floor(falta + 0.5)), "aviso", tecla end
	local alcance = unidad and C_Spell and C_Spell.IsSpellInRange and M.Legible(M.Llamar(C_Spell.IsSpellInRange, id, unidad))
	if alcance == false then return format(L["Acércate para usar %s"], nombre), "aviso", tecla end
	if tecla then return format(L["%s: pulsa %s"], nombre, tecla), "exito", tecla end
	return format(L["%s está lista"], nombre), "exito", tecla
end

local function pintar(x, e)
	crear()
	-- 1.3.1: un secreto va tal cual a SetTexture (sin `or`, que lo probaría).
	local tex = x.textura
	if not M.Secreto(tex) and tex == nil then tex = K.Lobo("atento") end
	pcall(f.Lanza.SetTexture, f.Lanza, tex)
	if f.alfaIcono ~= e.icono then
		f.alfaIcono = e.icono
		f.Tuyo.Icono:SetTexture(e.icono)
	end
	local titulo
	if not x.seguro then titulo = L["¡Está lanzando!"]
	elseif x.unidad == "focus" then titulo = L["¡Córtale a tu foco!"]
	else titulo = L["¡Córtalo!"] end
	K.Escribir(f.Titulo, titulo)
	-- 1.3.1: las dos respuestas de Falta; 1.3.2: una sola vez por vuelta.
	local falta, dur
	if M.Recargas then falta, dur = M.Recargas.Falta(e.id) end
	local linea, tono, tecla = Co.Estado(e.id, x.unidad, e, falta, true)
	K.Escribir(f.Linea, linea)
	K.ColorTexto(f.Linea, tono == "exito" and "exito" or "textoSuave")
	if tecla then
		if f.alfaTecla ~= tecla then
			f.alfaTecla = tecla
			K.Escribir(f.Tecla.Texto, tecla)
			f.Tecla:SetSize(K.Ajustar(f.Tecla.Texto, ICONO) + 6, K.Tamano("numero") + 4)
		end
		f.Tecla:Show()
	else
		f.Tecla:Hide()
	end
	if f.Tuyo.Recarga then
		if falta and falta > 0 and dur then pcall(f.Tuyo.Recarga.SetCooldown, f.Tuyo.Recarga, GetTime() + falta - dur, dur)
		else pcall(f.Tuyo.Recarga.Clear, f.Tuyo.Recarga) end
	end
	f.Tuyo.Icono:SetDesaturated(tono ~= "exito")
	-- Si el juego oculta si se puede cortar, que el juego decida si se ve.
	f.Cuerpo:SetAlpha(1)
	if M.Secreto(x.inmune) and f.Cuerpo.SetAlphaFromBoolean then
		pcall(f.Cuerpo.SetAlphaFromBoolean, f.Cuerpo, x.inmune, 0, 1)
	end
	f:Show()
end

-- Repasa tu objetivo y tu foco; lo pinta o lo esconde. empieza: un
-- lanzamiento nuevo (o cambiaste de objetivo): se vuelve a elegir tu corte.
function Co.Revisar(empieza)
	if not M.Opt("corte") then ocultar() return end
	if M.Desbloqueado() then Co.Ver() return end
	local x = Co.Lanza("target")
	if not x and M.Opt("corteFoco") and M.Legible(M.Llamar(UnitIsUnit, "focus", "target")) ~= true then
		x = Co.Lanza("focus")
	end
	if not x then ocultar() return end
	local nuevo = not actual or actual.unidad ~= x.unidad
	if nuevo or empieza == true then elegido = nil end
	local e = Co.Elegido()
	if not e then ocultar() return end
	x.desde = nuevo and GetTime() or actual.desde
	actual = x
	pintar(x, e)
	-- 1.3.2: yendo solo en el mundo no suena, salvo que lo pidas (corteSonidoSolo).
	if nuevo and M.Opt("corteSonido") and (M.Opt("corteSonidoSolo") or M.EnGrupo()) and x.seguro and sonoPara ~= x.desde then
		sonoPara = x.desde
		M.Sonar("RAID_WARNING", 8959)
	-- 1.3.3: en una instancia el juego oculta el hechizo (x.seguro = false): un
	-- sonido más suave aparte (corteSonidoOculto), que a veces también suena
	-- con lo que no se puede cortar (el juego no deja saberlo).
	elseif nuevo and not x.seguro and M.Opt("corteSonido") and M.Opt("corteSonidoOculto") and M.EnInstancia() and sonoPara ~= x.desde then
		sonoPara = x.desde
		M.Sonar("MAP_PING", 3175)
	end
	if not reloj then
		reloj = N.Ticker("combate.corte", 0.2, function()
			if not actual then sinReloj() return end
			-- Sin fin legible, se va a los TOPE segundos; con fin, al terminar.
			local ahora = GetTime()
			if (actual.fin and ahora > actual.fin + 0.2) or ahora - (actual.desde or ahora) > TOPE then ocultar() return end
			Co.Revisar()
		end)
	end
end

-- Para la página y "/alfa combate corte": así se ve (aunque esté apagado).
function Co.Probar()
	elegido = nil
	local e = Co.Elegido()
	local x = { unidad = "target", seguro = true, textura = 136197 }
	crear()
	if e then
		pintar(x, e)
	else
		pintar(x, datosDe(6552))
		K.Escribir(f.Linea, L["Cuando aprendas a cortar, aquí sale tu habilidad y su tecla."])
	end
	A.After(4, function() if not actual then ocultar() end end)
end

-- Mientras mueves los marcos, se queda a la vista.
function Co.Ver()
	if M.Desbloqueado() and M.Opt("corte") then
		elegido = nil
		pintar({ unidad = "target", seguro = true }, Co.Elegido() or datosDe(6552))
	elseif not actual and f then
		f:Hide()
	end
end

---------------------------------------------------------------------------
-- Eventos: solo de tu objetivo y tu foco
---------------------------------------------------------------------------
local EVENTOS = {
	"UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
	"UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}
local ev = CreateFrame("Frame")
for _, e in ipairs(EVENTOS) do
	if not pcall(ev.RegisterUnitEvent, ev, e, "target", "focus") then pcall(ev.RegisterEvent, ev, e) end
end
local EMPIEZA = { UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_CHANNEL_START = true }
ev:SetScript("OnEvent", function(_, evento, unidad)
	if unidad ~= "target" and unidad ~= "focus" then return end
	K.Llamar(Co.Revisar, EMPIEZA[evento] == true)
end)

A.OnLogin(function()
	M.Ensenar({ id = "combate.corte", icono = "ic-alerta",
		pregunta = L["¿Cómo sé cuándo cortar un hechizo?"],
		respuesta = L["Cuando tu objetivo o tu foco empieza a lanzar algo que se puede cortar, Alfa te avisa con tu habilidad para cortar, su tecla y si ya está lista. En mazmorras el juego a veces lo oculta: ahí avisa igual que está lanzando."] })
end)
