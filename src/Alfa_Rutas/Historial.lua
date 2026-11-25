-- Alfa - Rutas: tus guías terminadas, con su fecha y su tiempo (toxic3000 /
-- La Jauría). GPL-3.0. 1.4.0 (32)
--
-- Cada guía que terminas queda en tu historial: cuándo la empezaste y la
-- terminaste, cuánto tiempo jugaste en ella (solo el rato que la seguías: no
-- cuenta el tiempo ausente ni el de otras guías), sus pasos y de qué nivel a
-- qué nivel te llevó. Se ve en «Guías terminadas» (el menú del rastreador, la
-- página Ruta y /alfa rutas historial), la más nueva arriba, con un clic para
-- volver a abrirla.
--
-- Lo que se guarda es de cada personaje (N.DatosPersonaje("rutas").historial):
--   { lista = { { id, nombre, inicio, fin, seg, pasos, nivel0, nivel1 }, ... },
--     curso = { [id] = { inicio, seg, nivel0, hecha } } }
-- Tope: 40 terminadas (se va la más vieja). Los planes de un clic («Cerrar mis
-- misiones», «Desbloquear») no son guías y no cuentan.
-- El tiempo se suma cada 30 s mientras sigues la guía y no estás ausente; un
-- hueco de más de 2 min entre dos sumas no cuenta (te fuiste a otra cosa).
--
--   Historial.Lista() -> la lista (la más nueva al final)
--   Historial.Anotar(g) -> la entrada | nil   (lo llama el fin de la guía)
--   Historial.Abrir()

local ADDON, M = ...
local A, L, N, K = M.A, M.L, M.N, M.K
local Hi = {}
M.Historial = Hi

local type, ipairs, pairs, tonumber, tostring, pcall = type, ipairs, pairs, tonumber, tostring, pcall
local format, floor, min, max = string.format, math.floor, math.min, math.max

local MAX = 40
local CADA = 30
local HUECO = 120

local function E() return A.Engine end
local function ahora() return time and time() or 0 end

local function datos()
	local d = M.Personaje()
	if type(d.historial) ~= "table" then d.historial = {} end
	local h = d.historial
	if type(h.lista) ~= "table" then h.lista = {} end
	if type(h.curso) ~= "table" then h.curso = {} end
	return h
end

function Hi.Lista() return datos().lista end

local function nivel()
	local n = UnitLevel and UnitLevel("player")
	n = N.Leer(n) -- 1.4.0: («Leer and Leer(x) or x» devolvía el secreto)
	return type(n) == "number" and n or nil
end

local function especial(id)
	return M.Guias and M.Guias.Especial and M.Guias.Especial(id) ~= nil
end

local function nombreDe(g)
	local u = A.UI
	local ok, s = pcall(function() return u and u.GuideLabel and u.GuideLabel(g) end)
	if ok and type(s) == "string" and s ~= "" then return s end
	return g.title or g.id
end

local function curso(g, crear)
	local h = datos()
	local c = h.curso[g.id]
	if not c and crear then
		c = { inicio = ahora(), seg = 0, nivel0 = nivel() }
		h.curso[g.id] = c
	end
	return c
end

local function guiaDeAhora()
	local e = E()
	local g = e and e.GetGuide and e.GetGuide()
	if type(g) ~= "table" or type(g.id) ~= "string" or especial(g.id) then return nil end
	return g, e.GetLiveStep and e.GetLiveStep() or nil
end

-- La guía de ahora terminada: a la lista (una vez por vuelta).
function Hi.Anotar(g)
	g = g or guiaDeAhora()
	if type(g) ~= "table" or type(g.id) ~= "string" or especial(g.id) then return nil end
	local c = curso(g, true)
	if c.hecha then return nil end
	c.hecha = true
	local e = E()
	local _, total = 0, 0
	if e and e.GetProgress then
		local ok, _h, t = pcall(e.GetProgress)
		if ok then total = tonumber(t) or 0 end
	end
	local h = datos()
	local x = { id = g.id, nombre = nombreDe(g), inicio = c.inicio, fin = ahora(), seg = floor(c.seg or 0),
		pasos = total > 0 and total or nil, nivel0 = c.nivel0, nivel1 = nivel() }
	h.lista[#h.lista + 1] = x
	while #h.lista > MAX do table.remove(h.lista, 1) end
	M.Avisar("HISTORIAL")
	return x
end

-- Revisa si la de ahora ya terminó (todos sus pasos hechos de verdad), o si
-- volvió a empezar (una terminada con un paso vivo otra vez: otra vuelta).
function Hi.Revisar()
	local g, vivo = guiaDeAhora()
	if not g then return end
	local c = curso(g, true)
	if c.hecha and vivo then
		-- Otra vuelta (la restableciste o la abriste de nuevo).
		datos().curso[g.id] = { inicio = ahora(), seg = 0, nivel0 = nivel() }
		return
	end
	if not c.hecha and not vivo and M.GuiaTerminada and M.GuiaTerminada() then Hi.Anotar(g) end
end

-- El tiempo que llevas en la guía de ahora.
local ultima
local function sumar()
	local g, vivo = guiaDeAhora()
	local t = GetTime and GetTime() or 0
	local antes = ultima
	ultima = t
	if not (g and vivo and antes) then return end
	local dt = t - antes
	if dt <= 0 or dt > HUECO then return end
	if UnitIsAFK and N.Si(UnitIsAFK("player")) then return end
	local c = curso(g, true)
	if c.hecha then return end
	c.seg = (c.seg or 0) + dt
end
Hi.Sumar = sumar

-- Lo que llevas en una guía sin terminar (para el banco y la ventana).
function Hi.Curso(id)
	local c = type(id) == "string" and datos().curso[id] or nil
	return c
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local ventana

local function fecha(t)
	t = tonumber(t)
	if not (t and date) then return "?" end
	local d = date("*t", t)
	return (L["{dia}/{mes}/{año}"]:gsub("{dia}", tostring(d.day)):gsub("{mes}", tostring(d.month)):gsub("{año}", tostring(d.year)))
end
Hi.Fecha = fecha

function Hi.TextoDe(x)
	local partes = { fecha(x.fin) }
	if (x.seg or 0) >= 60 then partes[#partes + 1] = format(L["en %s"], M.Minutos(x.seg)) end
	if x.nivel0 and x.nivel1 and x.nivel1 > x.nivel0 then
		partes[#partes + 1] = format(L["del nivel %d al %d"], x.nivel0, x.nivel1)
	elseif x.nivel1 then
		partes[#partes + 1] = format(L["nivel %d"], x.nivel1)
	end
	if x.pasos then partes[#partes + 1] = M.Plural(x.pasos, L["%d paso"], L["%d pasos"]) end
	return table.concat(partes, "  \194\183  ")
end

local function armar()
	ventana = M.VentanaSimple({
		nombre = "AlfaRutasHistorial", titulo = L["Guías terminadas"], icono = "ic-guia", ancho = 460, alto = 480, altoFila = 46,
		vacio = { lobo = "atento", titulo = L["Aún no terminas ninguna guía"], texto = L["Cuando termines una, aquí verás cuándo y cuánto tardaste."] },
		crear = function(fila)
			fila.Icono = K.Icono(fila, "ic-exito", 14, "exito")
			fila.Icono:SetPoint("TOPLEFT", fila, "TOPLEFT", 10, -9)
			fila.Titulo = K.Texto(fila, "cuerpo", "texto")
			fila.Titulo:SetPoint("TOPLEFT", fila, "TOPLEFT", 32, -7)
			fila.Titulo:SetPoint("RIGHT", fila, "RIGHT", -10, 0)
			fila.Titulo:SetJustifyH("LEFT")
			fila.Sub = K.Texto(fila, "pequeno", "textoTenue")
			fila.Sub:SetPoint("TOPLEFT", fila.Titulo, "BOTTOMLEFT", 0, -3)
			fila.Sub:SetPoint("RIGHT", fila, "RIGHT", -10, 0)
			fila.Sub:SetJustifyH("LEFT")
		end,
		pintar = function(fila, x)
			K.Escribir(fila.Titulo, x.nombre or x.id or "?")
			K.Escribir(fila.Sub, Hi.TextoDe(x))
		end,
		alClic = function(x)
			if type(x) == "table" and type(x.id) == "string" and M.Biblioteca and M.Biblioteca.Seguir and M.NombreGuia and M.NombreGuia(x.id) then
				ventana:Cerrar()
				M.Biblioteca.Seguir(x.id)
			end
		end,
	})
end

function Hi.Abrir()
	if not ventana then armar() end
	local l = Hi.Lista()
	local orden = {}
	for i = #l, 1, -1 do orden[#orden + 1] = l[i] end
	local seg = 0
	for _, x in ipairs(l) do seg = seg + (x.seg or 0) end
	local linea = #l > 0 and format(L["%s en total. Un clic en una la vuelve a abrir."], M.Minutos(seg)) or ""
	ventana:Llenar(orden, L["Guías terminadas"], #l > 0 and M.Plural(#l, L["%d guía terminada"], L["%d guías terminadas"]) or nil, linea)
	return ventana
end
function Hi.Ventana() return ventana end

N.Cada("rutas.historial", CADA, sumar)
for _, msg in ipairs({ "GUIDE_COMPLETED", "STEP_CHANGED", "GUIDE_CHANGED" }) do
	A.On(msg, function() N.Una("rutas.historialVer", 1, Hi.Revisar) end)
end
A.RegisterEvent("QUEST_TURNED_IN", function() N.Una("rutas.historialVer", 2, Hi.Revisar) end)
