-- Alfa - Pesca: la tabla de pescadores de La Jauría (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8: los mejores pescadores de tu hermandad (solo los de tu facción) por
-- la temporada, el nivel de pescador y los récords. Es opcional y viene
-- apagado (ajuste pesca.jauria): la pestaña lo pregunta con un clic.
--
-- Cómo se comparte: con la red de La Jauría (Alfa_Manada, AlfaManada.Red),
-- tipo "p", solo por la hermandad (EnviarHermandad); nunca a canales
-- públicos ni por susurro. Quien no lo prende no envía ni guarda nada.
--   1p|D|<versión>|<facción A/H>|<nivel>|<xp>|<récords>|<especies>|<id del mejor>|<gramos>|<temporada>|<xp temporada>|<récords temporada>
--   1p|Q                tabla nueva: los demás responden con su D (una vez cada 2 min, tras una espera al azar)
-- Tu D sale al entrar, al subir de nivel o con un récord nuevo (una vez por
-- tanda, N.Una) y al prenderlo. Lo de otra facción se ignora.
-- Lo que llega se guarda en la cuenta (AlfaNucleoDB.pesca.jauria), los 45
-- días últimos y como mucho 300 lobos.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local V = M.V
local Eq = M.Eq

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP
local DOT = " \194\183 "

local J = {}
M.Jauria = J

J.TIPO = "p"
local VERSION = "1"
local VIDA = 45 * 86400
local TOPE = 300
local RESP_HUECO = 120
local ultimaRespuesta = -math.huge

local function num(v) return tonumber(v) or 0 end
local function ahoraJuego() return GetTime and GetTime() or 0 end

local function red()
	local Ma = rawget(_G, "AlfaManada")
	local R = type(Ma) == "table" and rawget(Ma, "Red")
	if type(R) == "table" and type(R.EnviarHermandad) == "function" and type(R.Escuchar) == "function" then return R end
	return nil
end
J.Red = red

function J.Activo() return M.Opt("jauria") and true or false end

function J.EnHermandad()
	if not IsInGuild then return false end
	local ok, si = pcall(IsInGuild)
	return ok and N.Si(si) or false
end

local function tabla()
	local d = N.Datos(ID)
	if type(d.jauria) ~= "table" then d.jauria = {} end
	return d.jauria
end
J.Tabla = tabla

---------------------------------------------------------------------------
-- Lo tuyo
---------------------------------------------------------------------------
function J.Mio()
	local Pz = M.Pez
	local p = Pz.Datos()
	local nivel = Pz.Nivel(p.xp)
	local clave, mejor = Pz.MejorDeTodos()
	local t = p.temporada or {}
	return {
		f = Pz.Faccion() or "A", nivel = nivel, xp = floor(num(p.xp)), rec = Pz.CuantosRecords(), esp = M.Especies(),
		mejorId = type(clave) == "number" and clave or 0, mejorG = mejor and floor(num(mejor.g)) or 0,
		tid = tostring(t.id or Pz.Temporada()), txp = floor(num(t.xp)), trec = floor(num(t.records)),
	}
end

local function texto(m)
	return table.concat({ "D", VERSION, m.f, m.nivel, m.xp, m.rec, m.esp, m.mejorId, m.mejorG, m.tid, m.txp, m.trec }, "|")
end
J.Texto = texto

function J.Enviar()
	if not J.Activo() then return false end
	local R = red()
	if not R then return false end
	local ok, r = pcall(R.EnviarHermandad, "pesca.tabla", J.TIPO, texto(J.Mio()))
	return ok and r and true or false
end

function J.Preguntar()
	if not J.Activo() then return false end
	local R = red()
	if not R then return false end
	local ok, r = pcall(R.EnviarHermandad, "pesca.pregunta", J.TIPO, "Q")
	return ok and r and true or false
end

-- Algo tuyo cambió (nivel, récord): sale una vez por tanda.
function J.Cambio()
	if not J.Activo() then return end
	N.Una("pesca.jauria.envio", 20, J.Enviar)
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------
local function entero(s, a, b)
	if type(s) ~= "string" or not s:match("^%d+$") or #s > 10 then return nil end
	local n = tonumber(s)
	if not n or n < a or n > b then return nil end
	return n
end

-- campos = { "D", versión, facción, nivel, xp, récords, especies, mejorId, gramos, temporada, xpT, récordsT }
function J.Leer(campos)
	if type(campos) ~= "table" or campos[1] ~= "D" then return nil end
	local f = campos[3]
	if f ~= "A" and f ~= "H" then return nil end
	local m = {
		f = f, nivel = entero(campos[4], 1, M.Pez.MAX), xp = entero(campos[5], 0, 100000000),
		rec = entero(campos[6], 0, 5000), esp = entero(campos[7], 0, 5000), mejorId = entero(campos[8], 0, 10000000),
		mejorG = entero(campos[9], 0, 1000000), tid = type(campos[10]) == "string" and campos[10]:match("^%d%d%d%d%d%d$") or nil,
		txp = entero(campos[11], 0, 100000000), trec = entero(campos[12], 0, 5000),
	}
	if not (m.nivel and m.xp and m.rec and m.esp and m.mejorId and m.mejorG and m.tid and m.txp and m.trec) then return nil end
	return m
end

local function nombreCorto(remitente)
	local n = type(remitente) == "string" and remitente:match("^([^%-]+)") or remitente
	return n
end

function J.Podar(ahora)
	ahora = ahora or time()
	local t = tabla()
	local lista = {}
	for k, x in pairs(t) do
		if type(x) ~= "table" or ahora - num(x.t) > VIDA then t[k] = nil else lista[#lista + 1] = { k, num(x.t) } end
	end
	if #lista > TOPE then
		table.sort(lista, function(a, b) return a[2] > b[2] end)
		for i = TOPE + 1, #lista do t[lista[i][1]] = nil end
	end
end

function J.AlMensaje(clave, remitente, campos, canal)
	if not J.Activo() or canal ~= "GUILD" then return end
	if type(campos) ~= "table" then return end
	if campos[1] == "Q" then
		-- Responder a quien abre su tabla: tras un rato al azar y no seguido.
		local ahora = ahoraJuego()
		if ahora - ultimaRespuesta < RESP_HUECO then return end
		ultimaRespuesta = ahora
		N.Una("pesca.jauria.respuesta", 3 + math.random() * 9, J.Enviar)
		return
	end
	local m = J.Leer(campos)
	if not m then return end
	local mia = M.Pez.Faccion()
	if mia and m.f ~= mia then return end -- lo de la otra facción no cuenta
	m.nombre = nombreCorto(remitente)
	m.t = time()
	if type(clave) ~= "string" or clave == "" then return end
	tabla()[clave] = m
	J.Podar(m.t)
	M.Avisar("jauria")
end

local escuchando = false
function J.Escuchar()
	if escuchando then return true end
	local R = red()
	if not R then return false end
	local ok, si = pcall(R.Escuchar, J.TIPO, J.AlMensaje, true)
	escuchando = ok and si and true or false
	return escuchando
end

A.RegisterEvent("PLAYER_ENTERING_WORLD", function(_, inicial)
	J.Escuchar()
	if not (inicial and J.Activo()) then return end
	N.Una("pesca.jauria.envio", 30, J.Enviar)
	N.Una("pesca.jauria.pregunta", 40, J.Preguntar)
end)

A.On("SETTING_CHANGED", function(path)
	if path ~= ID .. ".jauria" then return end
	if J.Activo() then
		J.Escuchar()
		J.Enviar()
		J.Preguntar()
	end
	M.Avisar("jauria")
end)

---------------------------------------------------------------------------
-- La tabla: tú y los demás, ordenados por temporada, nivel o récords
---------------------------------------------------------------------------
-- orden: "temporada" | "nivel" | "records" -> { { nombre, yo, nivel, xp, rec, esp, mejorId, mejorG, txp, trec, t } }
function J.Lista(orden)
	local tid = M.Pez.Temporada()
	local mia = M.Pez.Faccion()
	local out = {}
	local yo = J.Mio()
	yo.nombre = (UnitName and N.Leer((UnitName("player")))) or L["Tú"]
	yo.yo = true
	yo.t = time()
	out[1] = yo
	for _, x in pairs(tabla()) do
		if type(x) == "table" and (not mia or x.f == mia) then out[#out + 1] = x end
	end
	local function temporada(x) return x.tid == tid and num(x.txp) or 0 end
	local function trec(x) return x.tid == tid and num(x.trec) or 0 end
	table.sort(out, function(a, b)
		if orden == "nivel" then
			if num(a.xp) ~= num(b.xp) then return num(a.xp) > num(b.xp) end
		elseif orden == "records" then
			if num(a.rec) ~= num(b.rec) then return num(a.rec) > num(b.rec) end
			if num(a.mejorG) ~= num(b.mejorG) then return num(a.mejorG) > num(b.mejorG) end
		else
			if temporada(a) ~= temporada(b) then return temporada(a) > temporada(b) end
			if trec(a) ~= trec(b) then return trec(a) > trec(b) end
		end
		return tostring(a.nombre or "") < tostring(b.nombre or "")
	end)
	for i, x in ipairs(out) do x.puesto = i end
	return out, tid
end

local function tarjeta(x, orden, tid)
	local Pz = M.Pez
	local partes = { format(L["Nivel %d · %s"], num(x.nivel), Pz.Titulo(num(x.nivel))) }
	partes[#partes + 1] = N.Plural(num(x.rec), L["%d récord"], L["%d récords"])
	if num(x.mejorG) > 0 then
		local nombre = num(x.mejorId) > 0 and V.NombreObjeto(x.mejorId) or nil
		partes[#partes + 1] = nombre and format(L["mejor: %s, %s"], nombre, Pz.Peso(x.mejorG)) or format(L["mejor: %s"], Pz.Peso(x.mejorG))
	end
	local valor
	if orden == "nivel" then valor = format(L["%d exp."], num(x.xp))
	elseif orden == "records" then valor = N.Plural(num(x.rec), L["%d récord"], L["%d récords"])
	else valor = format(L["%d exp."], x.tid == tid and num(x.txp) or 0) end
	local medalla = ({ "oro", "acento", "aviso" })[x.puesto]
	return { variante = "compacta", icono = x.yo and "ic-lobo" or "ic-manada", tono = x.yo and "acento" or (medalla or "neutro"),
		elegida = x.yo or nil, titulo = format(L["%d. %s"], x.puesto, tostring(x.nombre or "?")) .. (x.yo and (" (" .. L["tú"] .. ")") or ""),
		texto = table.concat(partes, DOT), valor = valor }
end

local function construir(padre)
	local p = V.Pagina(padre)
	local pila = p.pila
	local estado = { orden = "temporada" }
	local ui = {}
	ui.pedir = pila:Agregar(K.Tarjeta(pila, { variante = "estado" }))
	ui.sec = pila:Agregar(K.Seccion(pila, L["Pescadores de La Jauría"]))
	ui.seg = pila:Agregar(K.Segmentos(pila, { estilo = "pildoras", valor = "temporada", opciones = {
		{ valor = "temporada", texto = M.Pez.NombreTemporada() }, { valor = "nivel", texto = L["Nivel"] }, { valor = "records", texto = L["Récords"] },
	}, alCambiar = function(v2) estado.orden = v2 V.Acomodar() end }))
	ui.lista = pila:Agregar(K.Rejilla(pila, { min = 560, gap = ESP.xs, variante = "compacta" }), { espacio = ESP.s })
	ui.nota = pila:Agregar(V.Parrafo(pila, "nota", "textoTenue"), { espacio = ESP.m })
	p.antes = function()
		local activo = J.Activo()
		K.Mostrar(ui.pedir, not activo)
		K.Mostrar(ui.sec, activo)
		K.Mostrar(ui.seg, activo)
		K.Mostrar(ui.lista, activo)
		if not activo then
			ui.pedir:Set({ lobo = "atento", tono = "acento", sobre = L["Opcional"], titulo = L["La tabla de pescadores de La Jauría"],
				texto = L["Compara tu nivel de pescador y tus récords con los lobos de tu hermandad que usan Alfa (solo los de tu facción). Se comparte solo con tu hermandad: nada va a canales públicos."],
				accion = { texto = L["Sí, compartir"], alClic = function() N.Set(ID, "jauria", true) end } })
			ui.nota:Set(J.EnHermandad() and L["Puedes apagarlo cuando quieras aquí o en Ajustes > Pesca."]
				or L["Para verla necesitas estar en una hermandad."])
			return
		end
		local lista, tid = J.Lista(estado.orden)
		local datos = {}
		for i = 1, min(#lista, 50) do datos[i] = tarjeta(lista[i], estado.orden, tid) end
		ui.lista:Llenar(datos)
		ui.sec:Set(L["Pescadores de La Jauría"], { cuenta = #lista,
			enlace = { texto = L["Dejar de compartir"], alClic = function() N.Set(ID, "jauria", false) end } })
		-- La temporada cambia de nombre con el mes.
		ui.seg:SetOpciones({ { valor = "temporada", texto = M.Pez.NombreTemporada(tid) }, { valor = "nivel", texto = L["Nivel"] },
			{ valor = "records", texto = L["Récords"] } })
		ui.seg:SetValor(estado.orden)
		if not J.EnHermandad() then
			ui.nota:Set(L["No estás en una hermandad: por ahora la tabla solo te muestra a ti."])
		elseif #lista <= 1 then
			ui.nota:Set(L["Todavía no llega nadie más. Cuando otros lobos de tu hermandad con Alfa la prendan, aparecen aquí."])
		else
			ui.nota:Set(L["Se comparte solo con tu hermandad. La temporada cambia cada mes."])
		end
		-- Al mirarla, pedir lo nuevo (no más de una vez cada 2 minutos).
		if not J.ultimaPregunta or ahoraJuego() - J.ultimaPregunta > RESP_HUECO then
			J.ultimaPregunta = ahoraJuego()
			N.Una("pesca.jauria.pregunta", 1, J.Preguntar)
		end
	end
	return p
end

V.Registrar("jauria", { nombre = L["La Jauría"], icono = "ic-manada", orden = 6,
	cambia = { jauria = true, pescador = true, ajustes = true }, construir = construir })
