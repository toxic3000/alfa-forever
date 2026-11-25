-- Alfa - Bienvenida: "Reportar un error, una mejora o un comentario"
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.9 (101 y 106, pedido de Toxic: «un reporte de bugs sencillo, sin tanto
-- tema, para que la comunidad nos ayude a encontrar bugs»):
--   * Cuando Alfa atrapa un error de Lua suyo (Alfa_Nucleo/Errores.lua), sale
--     un aviso discreto «Alfa encontró un error · Reportar», con el ícono del
--     Lobo Malo (el que caza bichos). Nunca en combate, una vez por error
--     distinto y tres por sesión como mucho. Se apaga en Ajustes > Estilo y
--     sonido > Centro de avisos («Errores de Alfa», nucleo.avisos.errores).
--   * Una sola ventana sencilla: pestañas chicas (Error · Mejora · Comentario),
--     un cuadro «¿Qué hacías cuando pasó? (opcional)» y un botón grande
--     «Enviar». Lo técnico se agrega solo y se manda sin enseñarlo (1.4.0,
--     plan 71: el jugador ya no ve ese bloque; nunca lleva datos privados).
--     Una línea recuerda que las capturas se suben en el formulario.
--   * «Enviar» guarda el reporte en el buzón (lo de abajo) y el instalador de
--     Alfa (Instalar-Alfa.exe, fuera del juego: un addon no puede mandar nada
--     a internet) lo manda solo al formulario del desarrollador (un
--     formulario de Google que le llega a su correo).
--   * «Enviar ya por el navegador»: el enlace del formulario con todo ya
--     escrito, en un cuadro para copiar (el juego no abre el navegador).
--     «Copiar» (el reporte para Discord, #buzon-alfa) queda como extra.
--   * 106: el reporte de un error recuerda tomar una captura (la tecla del
--     juego, de fábrica Impr Pant).
--
-- El reporte nunca lleva datos personales: ni el nombre de tu personaje ni tu
-- reino. Lleva el tipo, tu texto, la versión de Alfa y del cliente, el idioma,
-- tu clase y nivel, la zona, la guía que seguías y, si es un error, los
-- últimos errores de Lua de Alfa (con su versión y cuántas veces salieron) y
-- lo que el juego le bloqueó (Alfa.Blocked). Cabe en un mensaje de Discord.
--
-- El buzón (contrato con el instalador): la variable guardada AlfaNucleoDB
-- (WTF/Account/<CUENTA>/SavedVariables/Alfa_Nucleo.lua), en
--   AlfaNucleoDB.buzon.pendientes = { { id, fecha, version, tipo, texto, enviado = false }, ... }
--   id       texto único ("1732400000-0042")
--   fecha    "2026-11-24 18:30" (la hora de tu computadora)
--   version  la de Alfa ("1.3.9")
--   tipo     "error" | "mejora" | "comentario"
--   texto    el reporte ya armado (Markdown de Discord, 1950 bytes como mucho)
--   escrito  lo que escribió el jugador (o «(sin comentario)»)
--   tecnico  los datos técnicos (versiones, clase, zona, errores)
--   enviado  false (booleano); el instalador lo pone en true (o quita la entrada) al mandarlo
-- Tope: 20 (se va el más viejo). Al entrar al juego se quitan los enviados.
--
-- Contrato (global AlfaReporte):
--   AlfaReporte.Abrir(tipo)        "error" | "mejora" | "comentario" (de fábrica, error)
--   AlfaReporte.Pendientes() -> n  reportes que esperan al instalador
--   AlfaReporte.Buzon() -> lista   (la de AlfaNucleoDB.buzon.pendientes)
-- Comando: /alfa reportar [error | mejora | comentario]

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ESP = K.ESP

local format, max, min = string.format, math.max, math.min
local type, tostring, tonumber, ipairs, pcall, rawget = type, tostring, tonumber, ipairs, pcall, rawget

local idiomaJuego = GetLocale -- sin llamar: el build cambia las llamadas por el idioma de Alfa
local ANCHO, ALTO = 660, 580
local MAX_TEXTO = 1000   -- letras de tu texto
local MAX_REPORTE = 1950 -- un mensaje de Discord admite 2000
local MAX_ERRORES = 5
local MAX_LINEA = 180
local MAX_BUZON = 20
local MAX_AVISOS_SESION = 3
-- El canal se llama "📮-buzon-alfa" en Discord, pero las letras del juego no
-- tienen emojis (saldría un cuadro): en el juego se escribe sin él.
local CANAL = "#buzon-alfa"
local INVITACION = "https://discord.gg/hUNjA6BJwh"
-- El Lobo Malo, el que caza bichos (tools/lobo_malo.py).
local LOBO_MALO = "Interface\\AddOns\\Alfa_Nucleo\\Media\\lobo-malo"
M.LOBO_MALO = LOBO_MALO

local TIPOS = {
	{ valor = "error", texto = "Error", pregunta = "¿Qué hacías cuando pasó? (opcional)",
		ayuda = "Por ejemplo: «abrí las bolsas en el banco y salió el error»." },
	{ valor = "mejora", texto = "Mejora [reporte]", pregunta = "¿Qué te gustaría que Alfa hiciera?",
		ayuda = "Qué te gustaría que Alfa hiciera, o hiciera mejor, y para qué te serviría." },
	{ valor = "comentario", texto = "Comentario", pregunta = "¿Qué nos quieres contar?",
		ayuda = "Lo que quieras contarle al desarrollador de Alfa." },
}

local v
local ui = { tipo = "error" }

local function legible(x)
	if issecretvalue and issecretvalue(x) then return nil end
	return x
end

local function tipoDe(valor)
	for _, t in ipairs(TIPOS) do if t.valor == valor then return t end end
	return TIPOS[1]
end

-- Un texto cortado a n bytes, nunca a media letra.
local function cortar(s, n)
	s = tostring(s or "")
	if #s <= n then return s end
	return (s:sub(1, n - 3):gsub("[\192-\255][\128-\191]*$", "")) .. "..."
end

-- Sin códigos de color ni de textura del juego.
local function plano(s)
	s = tostring(s or ""):gsub("||", "\1")
	s = s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", "")
	return (s:gsub("\1", "|"))
end

---------------------------------------------------------------------------
-- Los datos del reporte
---------------------------------------------------------------------------
local function version()
	local ver = tostring(A.version or N.version or "dev")
	if A.stage then ver = ver .. " " .. tostring(A.stage) end
	return ver
end

local function cliente()
	if not GetBuildInfo then return "?", "?" end
	local ok, ver, build = pcall(GetBuildInfo)
	if not ok then return "?", "?" end
	return tostring(ver or "?"), tostring(build or "?")
end

local function personaje()
	local _, clase = M.Clase()
	local nivel = UnitLevel and legible(UnitLevel("player")) or nil
	return clase or "?", type(nivel) == "number" and nivel or 0
end

local function lugar()
	local zona, x, y
	local CM = C_Map
	if CM and CM.GetBestMapForUnit then
		local ok, mapa = pcall(CM.GetBestMapForUnit, "player")
		mapa = ok and legible(mapa) or nil
		if type(mapa) == "number" then
			local ok2, info = pcall(CM.GetMapInfo, mapa)
			if ok2 and type(info) == "table" and type(legible(info.name)) == "string" then zona = info.name end
			local ok3, pos = pcall(CM.GetPlayerMapPosition, mapa, "player")
			if ok3 and pos and pos.GetXY then
				local px, py = pos:GetXY()
				px, py = legible(px), legible(py)
				if type(px) == "number" and type(py) == "number" and (px > 0 or py > 0) then x, y = px * 100, py * 100 end
			end
			zona = (zona or "?") .. format(" [%d]", mapa)
		end
	end
	if not zona and GetZoneText then zona = legible(GetZoneText()) end
	local sub = GetSubZoneText and legible(GetSubZoneText()) or nil
	if type(sub) == "string" and sub ~= "" then zona = (zona or "?") .. " - " .. sub end
	if x then return format("%s (%.1f, %.1f)", zona or "?", x, y) end
	return zona or "?"
end

-- Qué hacías según Alfa: la guía que seguías (sin nombres de nadie).
local function haciendo()
	local I = rawget(_G, "AlfaInicio")
	if type(I) ~= "table" or type(I.Paso) ~= "function" then return nil end
	local ok, p = pcall(I.Paso)
	if not ok or type(p) ~= "table" then return nil end
	local guia = type(p.guia) == "string" and p.guia ~= "" and plano(p.guia) or nil
	if not guia then return nil end
	if tonumber(p.num) then return format("Guía: %s (paso %d)", cortar(guia, 80), p.num) end
	return format("Guía: %s", cortar(guia, 80))
end

-- 1.4.0 (71): el código de cada reporte, corto y fácil de copiar (sin letras
-- que se confundan: ni I, L, O, 0 ni 1). Va al inicio del texto, en el buzón
-- (su id) y en el enlace del formulario de capturas.
local LETRAS_CODIGO = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
function M.NuevoCodigo()
	local out = {}
	for i = 1, 6 do
		local k = (math.random and math.random(1, #LETRAS_CODIGO)) or ((i * 7) % #LETRAS_CODIGO + 1)
		out[i] = LETRAS_CODIGO:sub(k, k)
	end
	return table.concat(out)
end
local function codigo()
	if not ui.codigo then ui.codigo = M.NuevoCodigo() end
	return ui.codigo
end
M.CodigoReporte = codigo

local function textoEscrito()
	return ((ui.texto or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

-- 1.3.9: el reporte se ve de Alfa Forever y se lee fácil en el formulario y
-- en su hoja de cálculo: renglones claros con su etiqueta (en español, para
-- que todas las filas digan lo mismo), sin bloques de código ni Markdown.
local LOBO = "\240\159\144\186" -- 🐺 (las letras del juego no lo tienen: en la ventana no se dibuja)
M.LOBO_EMOJI = LOBO
local NOMBRE_TIPO = { error = "Error", mejora = "Mejora", comentario = "Comentario" }

-- La traza corta de cada error (lo que pasó por los archivos de Alfa), de esta sesión.
local trazas = {}
local function trazaDe(pila)
	if type(pila) ~= "string" or (issecretvalue and issecretvalue(pila)) then return nil end
	local out = {}
	for linea in pila:gmatch("[^\n]+") do
		if linea:find("AddOns[/\\]Alfa") then
			linea = linea:gsub('%[string "@?([^"]*)"%]', "%1"):gsub("Interface[/\\]AddOns[/\\]", ""):gsub("^%s+", "")
			out[#out + 1] = cortar(linea, 120)
			if #out >= 4 then break end
		end
	end
	return #out > 0 and out or nil
end
M.TrazaDe = trazaDe

local function faccion()
	if not UnitFactionGroup then return nil end
	local ok, ingles, local_ = pcall(UnitFactionGroup, "player")
	if not ok then return nil end
	local f = legible(local_) or legible(ingles)
	return type(f) == "string" and f ~= "" and f or nil
end

-- Los renglones técnicos: { texto, quitar = prioridad (mayor se quita antes) }.
local function renglones(t)
	local out = {}
	local function pon(s, quitar) out[#out + 1] = { texto = s, quitar = quitar } end
	local cv, build = cliente()
	local idioma = tostring(idiomaJuego and idiomaJuego() or "?")
	local cabeza = format("%s Alfa Forever %s · cliente %s (%s) · idioma %s", LOBO, version(), cv, build, idioma)
	local alfaEn = M.IdiomaActual()
	if alfaEn and alfaEn ~= idioma then cabeza = cabeza .. " · Alfa en " .. tostring(alfaEn) end
	pon(cabeza)
	local clase, nivel = personaje()
	local f = faccion()
	pon(format("Personaje: %s nivel %d%s", clase, nivel, f and (" (" .. f .. ")") or ""))
	pon("Lugar: " .. lugar())
	local h = haciendo()
	if h then pon(h, 2) end
	if t.valor == "error" then
		local l = N.Errores and N.Errores() or {}
		local e = l[#l]
		if type(e) == "table" then
			pon("Módulo: " .. tostring(e.addon or "?"))
			-- (con la versión de Alfa en que salió y cuántas veces)
			pon(format("Error: [%s] %s%s", tostring(e.v or "?"), tostring(e.msg or "?"), (tonumber(e.n) or 1) > 1 and format(" (%d veces)", e.n) or ""))
			for _, x in ipairs(trazas[e.msg] or {}) do pon("  " .. x, 3) end
			if #l > 1 then
				pon("Otros errores:", 4)
				for i = #l - 1, math.max(1, #l - MAX_ERRORES + 1), -1 do
					local x = l[i]
					if type(x) == "table" then
						pon(cortar(format("  %dx [%s] %s", tonumber(x.n) or 1, tostring(x.v or "?"), tostring(x.msg or "")), MAX_LINEA), 4)
					end
				end
			end
		else
			pon("Módulo: ?")
			pon("Error: ninguno atrapado en esta sesión")
		end
		-- Lo que el juego le bloqueó a Alfa.
		local ok2, b = pcall(function() return A.Blocked and A.Blocked() end)
		b = ok2 and type(b) == "table" and b or {}
		if #b == 0 then
			pon("Acciones bloqueadas: ninguna")
		else
			pon(format("Acciones bloqueadas: %d", #b))
			for i = #b, math.max(1, #b - 2), -1 do
				local x = b[i]
				pon(cortar(format("  %dx %s en %s (%s)", x.count or 1, plano(x.fn), tostring(x.addon or "?"), tostring(x.where or x.at or "?")), MAX_LINEA), 4)
			end
		end
	end
	-- Los módulos, el modo, la memoria y los otros addons (Alfa_Nucleo/Informe.lua).
	local otros = false
	if N.InformeTecnico then
		local ok, l = pcall(N.InformeTecnico)
		if ok and type(l) == "table" then
			for i, x in ipairs(l) do
				if i == 3 then otros = true end
				pon(x, i < #l and 1 or nil)
			end
		end
	end
	if not otros then pon("Otros addons: 0") end
	-- 1.4.0 (7): lo que confirmaste en el juego (/alfa confirmar, Alfa_Rutas/Confirmar.lua).
	local Cf = rawget(_G, "AlfaConfirmar")
	if type(Cf) == "table" and type(Cf.Resumen) == "function" then
		local okC, sC = pcall(Cf.Resumen)
		if okC and type(sC) == "string" and sC ~= "" then pon(sC, 2) end
	end
	-- 1.3.9 (24): sin tu nombre, tu reino ni los de otros jugadores.
	-- («Alfa Forever» se aparta antes: un reino que se llame Forever no lo borra.)
	if N.SinPrivado then
		for _, r in ipairs(out) do
			r.texto = (N.SinPrivado((r.texto:gsub("Alfa Forever", "\1"))):gsub("\1", "Alfa Forever"))
		end
	end
	return out
end

-- El reporte. -> texto (para «Copiar»), escrito (tal cual), tecnico (renglones)
local function componerTodo()
	local t = tipoDe(ui.tipo)
	local escrito = textoEscrito()
	-- 1.3.9 (24): tampoco lo que escribiste lleva tu nombre ni tu reino.
	if N.SinPrivado and escrito ~= "" then escrito = N.SinPrivado(escrito) end
	local lineas = renglones(t)
	local function unir()
		local d = {}
		for _, r in ipairs(lineas) do d[#d + 1] = r.texto end
		return table.concat(d, "\n")
	end
	local function armar(tec, esc)
		local cuerpo = esc ~= "" and esc or (t.valor == "error" and L["(sin comentario)"] or L["(todavía sin texto: escríbelo arriba)"])
		return format("%s Reporte de Alfa Forever · %s\nCódigo: %s\n\n%s\n\n%s", LOBO, NOMBRE_TIPO[t.valor] or "Error", codigo(), cuerpo, tec)
	end
	local tecnico = unir()
	local s = armar(tecnico, escrito)
	-- Si no cabe en un mensaje, se quitan los renglones de detalle (los que
	-- más se pueden quitar primero, de abajo hacia arriba).
	while #s > MAX_REPORTE do
		local peor, idx = 0, nil
		for i = #lineas, 1, -1 do
			local q = lineas[i].quitar or 0
			if q > peor then peor, idx = q, i end
		end
		if not idx then break end
		table.remove(lineas, idx)
		tecnico = unir()
		s = armar(tecnico, escrito)
	end
	-- Si aún no cabe (un texto largo en ruso, coreano o chino ocupa más bytes
	-- que letras), se recorta lo que escribiste en el texto de «Copiar».
	local esc = escrito
	if #s > MAX_REPORTE then
		esc = cortar(escrito, math.max(20, #escrito - (#s - MAX_REPORTE)))
		s = armar(tecnico, esc)
	end
	return cortar(s, MAX_REPORTE), escrito, cortar(tecnico, MAX_REPORTE)
end

local function componer() return (componerTodo()) end
M.ComponerReporte = componer
M.ComponerPartes = componerTodo

---------------------------------------------------------------------------
-- 1.3.9: «Enviar ya por el navegador»: el formulario del desarrollador con
-- todo ya escrito (el juego no abre el navegador: el enlace va en un cuadro
-- para copiar). Cada valor codificado para URL (UTF-8 en %XX; espacio %20).
---------------------------------------------------------------------------
local FORMULARIO = "https://docs.google.com/forms/d/e/1FAIpQLSfCKW97uxmZL5ZGl5Ym4hLjUMTWt6O0N7TJgw6buSDMoRIXUA/viewform?usp=pp_url"
-- 1.4.0 (71): el formulario ya no tiene «Datos técnicos»: lo técnico va al
-- final del texto, tras la línea «— Datos de Alfa —».
local CAMPO = { tipo = "entry.832145550", escrito = "entry.1889667288", version = "entry.1259972415" }
local SEPARADOR = "\n\n— Datos de Alfa —\n"
M.SEPARADOR_DATOS = SEPARADOR
-- Las capturas, en un formulario aparte (pide cuenta de Google): con el código.
local FORMULARIO_CAPTURAS = "https://docs.google.com/forms/d/e/1FAIpQLSd8g5jhxh6AM5p9oAKSqz4LocnRLNhtIxpeYqP3Rx2o8KFV4Q/viewform?usp=pp_url"
local CAMPO_CODIGO = "entry.1102491070"
-- El tipo, tal cual lo espera el formulario (sin traducir).
local TIPO_FORMULARIO = { error = "Error", mejora = "Mejora", comentario = "Comentario" }
local MAX_ENLACE = 1800

local function codificar(s)
	return (tostring(s or ""):gsub("[^A-Za-z0-9%-%._~]", function(c) return format("%%%02X", c:byte()) end))
end
M.CodificarURL = codificar

-- s recortado (sin partir una letra) hasta que, codificado, quepa en n.
local function caber(s, n)
	if #codificar(s) <= n then return s end
	if n <= 0 then return "" end
	local lo, hi = 0, #s
	while lo < hi do
		local mid = math.floor((lo + hi + 1) / 2)
		local pedazo = s:sub(1, mid):gsub("[\192-\255][\128-\191]*$", "")
		if #codificar(pedazo .. "...") <= n then lo = mid else hi = mid - 1 end
	end
	local pedazo = s:sub(1, lo):gsub("[\192-\255][\128-\191]*$", "")
	return pedazo ~= "" and (pedazo .. "...") or ""
end

-- -> el enlace (MAX_ENLACE letras como mucho). Un solo texto: «Código: X»,
-- lo que escribiste y, tras «— Datos de Alfa —», lo técnico (ya sin datos
-- privados). Lo técnico se recorta primero; lo escrito, solo si aún no cabe.
function M.EnlaceFormulario(tipo, escrito, tecnico, ver, cod)
	tipo = TIPO_FORMULARIO[tipoDe(tipo).valor] or "Error"
	ver = tostring(ver or A.version or N.version or "dev")
	local cabeza = (type(cod) == "string" and cod ~= "") and ("Código: " .. cod .. "\n\n") or ""
	tecnico = tostring(tecnico or "")
	if N.SinPrivado and tecnico ~= "" then
		tecnico = (N.SinPrivado((tecnico:gsub("Alfa Forever", "\1"))):gsub("\1", "Alfa Forever"))
	end
	local base = FORMULARIO .. "&" .. CAMPO.tipo .. "=" .. codificar(tipo) .. "&" .. CAMPO.version .. "=" .. codificar(ver)
		.. "&" .. CAMPO.escrito .. "=" .. codificar(cabeza)
	local libre = MAX_ENLACE - #base
	local sep = tecnico ~= "" and SEPARADOR or ""
	escrito = caber(tostring(escrito or ""), math.max(0, libre - (sep ~= "" and 200 or 0)))
	local resto = libre - #codificar(escrito)
	if sep ~= "" then
		resto = resto - #codificar(sep)
		tecnico = resto > 20 and caber(tecnico, resto) or ""
		if tecnico == "" then sep = "" end
	end
	return FORMULARIO .. "&" .. CAMPO.tipo .. "=" .. codificar(tipo)
		.. "&" .. CAMPO.escrito .. "=" .. codificar(cabeza .. escrito .. sep .. tecnico)
		.. "&" .. CAMPO.version .. "=" .. codificar(ver)
end

-- 1.4.0 (71): el enlace del formulario de capturas, con el código ya puesto.
function M.EnlaceCapturas(cod)
	return FORMULARIO_CAPTURAS .. "&" .. CAMPO_CODIGO .. "=" .. codificar(cod or codigo())
end

---------------------------------------------------------------------------
-- El buzón: los reportes que esperan al instalador (AlfaNucleoDB.buzon)
---------------------------------------------------------------------------
local Bz = {}
M.Buzon = Bz

function Bz.Lista()
	local d = N.Datos("buzon")
	d.pendientes = type(d.pendientes) == "table" and d.pendientes or {}
	return d.pendientes
end

-- Los que el instalador todavía no mandó.
function Bz.Pendientes()
	local n = 0
	for _, e in ipairs(Bz.Lista()) do
		if type(e) == "table" and e.enviado ~= true then n = n + 1 end
	end
	return n
end

-- Quita lo que el instalador ya mandó (y lo que no es un reporte).
function Bz.Limpiar()
	local l = Bz.Lista()
	for i = #l, 1, -1 do
		local e = l[i]
		if type(e) ~= "table" or e.enviado == true or type(e.texto) ~= "string" then table.remove(l, i) end
	end
	while #l > MAX_BUZON do table.remove(l, 1) end
end

local siguiente = 0
-- -> la entrada y true si ya estaba (el mismo texto sin mandar no se guarda dos veces).
function Bz.Guardar(texto, tipo, escrito, tecnico, cod)
	local l = Bz.Lista()
	for _, e in ipairs(l) do
		if type(e) == "table" and e.enviado ~= true and e.texto == texto then return e, true end
	end
	siguiente = siguiente + 1
	local t = time and time() or 0
	local e = {
		-- 1.4.0 (71): el id es el código que ve el jugador («Código: X»).
		id = (type(cod) == "string" and cod ~= "") and cod or format("%d-%04d", t, (siguiente + (math.random and math.random(0, 9999) or 0)) % 10000),
		codigo = (type(cod) == "string" and cod ~= "") and cod or nil,
		fecha = date and date("%Y-%m-%d %H:%M") or "",
		version = tostring(A.version or N.version or "dev"),
		tipo = tipoDe(tipo).valor,
		texto = cortar(texto, MAX_REPORTE),
		-- (1.3.9) por separado, para el formulario del desarrollador
		escrito = cortar(escrito or "", MAX_TEXTO * 4),
		tecnico = cortar(tecnico or "", MAX_REPORTE),
		enviado = false,
	}
	l[#l + 1] = e
	while #l > MAX_BUZON do table.remove(l, 1) end
	return e, false
end

---------------------------------------------------------------------------
-- Piezas: un cuadro de texto (para escribir o para copiar)
---------------------------------------------------------------------------

-- o = { alto, lineas = true (varias líneas), soloCopiar = true, alCambiar = fn(texto), max }
local function cuadro(padre, o)
	local c = CreateFrame("Frame", nil, padre)
	c:SetHeight(o.alto or K.ALTO.control)
	c:EnableMouse(true)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, c)
	c.Campo = e
	e:SetAutoFocus(false)
	if o.max then e:SetMaxLetters(o.max) end
	K.Pintar(e, function(x)
		K.FuenteSegura(x, K.Cara("medium"), K.Tamano("cuerpo"), "")
		x:SetTextColor(K.Color("texto"))
	end)
	if o.lineas then
		e:SetMultiLine(true)
		local sf = CreateFrame("ScrollFrame", nil, c)
		c.Desliza = sf
		sf:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m, -ESP.s)
		sf:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -ESP.m, ESP.s)
		sf:SetScrollChild(e)
		sf:EnableMouseWheel(true)
		sf:SetScript("OnMouseWheel", function(self, delta)
			local rango = self.GetVerticalScrollRange and self:GetVerticalScrollRange() or 0
			self:SetVerticalScroll(max(0, min(rango, self:GetVerticalScroll() - delta * 20)))
		end)
		-- El cursor siempre a la vista al escribir.
		e:SetScript("OnCursorChanged", function(_, _, y, _, h)
			local arriba, alto = sf:GetVerticalScroll(), K.num(sf:GetHeight(), 0)
			y = -(y or 0)
			if y < arriba then
				sf:SetVerticalScroll(y)
			elseif y + (h or 0) > arriba + alto then
				sf:SetVerticalScroll(y + (h or 0) - alto)
			end
		end)
	else
		e:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
		e:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
		e:SetHeight(K.ALTO.control - 4)
	end
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	e:SetScript("OnEditFocusGained", function(self)
		if o.soloCopiar then self:HighlightText() end
		c.caja:Estilo({ borde = "acento", alfaBorde = 0.8 })
	end)
	e:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		c.caja:Estilo({ borde = "lineaFuerte", alfaBorde = 1 })
	end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	if not o.lineas then e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
	e:SetScript("OnTextChanged", function(self, usuario)
		if o.soloCopiar then
			if usuario and self:GetText() ~= (c.texto or "") then
				self:SetText(c.texto or "")
				self:HighlightText()
			end
			return
		end
		if c.Ayuda then c.Ayuda:SetShown((self:GetText() or "") == "") end
		if usuario and o.alCambiar then K.Llamar(o.alCambiar, self:GetText() or "") end
	end)
	if o.soloCopiar then e:SetScript("OnMouseUp", function(self) self:HighlightText() end) end
	-- La ayuda del cuadro vacío, para escribir.
	if not o.soloCopiar then
		c.Ayuda = K.Texto(c, "texto", "textoTenue")
		c.Ayuda:SetPoint("TOPLEFT", c, "TOPLEFT", ESP.m + 2, o.lineas and -ESP.s - 2 or -9)
		c.Ayuda:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
		c.Ayuda:SetJustifyH("LEFT")
		c.Ayuda:SetWordWrap(true)
	end
	function c:SetAyuda(t) if self.Ayuda then K.Escribir(self.Ayuda, t or "") end end
	function c:Set(t)
		self.texto = t or ""
		e:SetText(self.texto)
		e:SetCursorPosition(0)
		if self.Desliza then self.Desliza:SetVerticalScroll(0) end
		if self.Ayuda then self.Ayuda:SetShown(self.texto == "") end
	end
	function c:Copiar()
		e:SetFocus()
		e:HighlightText()
	end
	function c:Acomodar(ancho)
		self:SetWidth(ancho)
		if o.lineas then e:SetWidth(max(60, ancho - 2 * ESP.m)) end
		return K.num(self:GetHeight(), K.ALTO.control)
	end
	return c
end

-- Un cuadro para copiar con su botón a la derecha.
local function filaCopiar(padre, o)
	local f = CreateFrame("Frame", nil, padre)
	f.Cuadro = cuadro(f, { alto = o.alto, lineas = o.lineas, soloCopiar = true })
	f.Boton = K.Boton(f, L[o.boton or "Elegir para copiar"], function() f.Cuadro:Copiar() end, { tipo = "secundario" })
	function f:Set(t) self.Cuadro:Set(t) end
	function f:Acomodar(ancho)
		local bw = self.Boton:AnchoNatural()
		self.Cuadro:ClearAllPoints()
		self.Cuadro:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Boton:ClearAllPoints()
		local h = self.Cuadro:Acomodar(max(120, ancho - bw - ESP.s))
		self.Boton:SetPoint("TOPRIGHT", self, "TOPRIGHT", 0, 0)
		self:SetSize(ancho, h)
		return h
	end
	return f
end

-- Un bloque que no se estira: los segmentos y los botones miden su propio ancho.
local function suelto(padre, crear)
	local b = CreateFrame("Frame", nil, padre)
	local hijo = crear(b)
	b.Hijo = hijo
	hijo:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Acomodar(ancho)
		local h = hijo.Acomodar and hijo:Acomodar(ancho) or K.num(hijo:GetHeight(), K.ALTO.boton)
		self:SetSize(ancho, h)
		return h
	end
	return b
end

-- Una línea de texto como bloque de una pila.
local function parrafo(pila, rol, color, opts)
	local b = CreateFrame("Frame", nil, pila)
	b.Texto = K.Texto(b, rol or "nota", color or "textoSuave")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	function b:Set(t) K.Escribir(self.Texto, t or "") end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, ancho)
		self:SetHeight(h)
		return h
	end
	return pila:Agregar(b, opts)
end

-- El Lobo Malo con su línea al lado (arriba de la ventana y al dar las gracias).
local function conLobo(pila, rol, color, opts)
	local TAM = 44
	local b = CreateFrame("Frame", nil, pila)
	b.Lobo = b:CreateTexture(nil, "ARTWORK")
	b.Lobo:SetTexture(LOBO_MALO)
	b.Lobo:SetSize(TAM, TAM)
	b.Lobo:SetPoint("TOPLEFT", b, "TOPLEFT", 0, 0)
	b.Texto = K.Texto(b, rol or "texto", color or "texto")
	b.Texto:SetPoint("TOPLEFT", b, "TOPLEFT", TAM + ESP.m, 0)
	function b:Set(t) K.Escribir(self.Texto, t or "") end
	function b:Acomodar(ancho)
		local h = K.Parrafo(self.Texto, max(60, ancho - TAM - ESP.m))
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self, "TOPLEFT", TAM + ESP.m, -max(0, (TAM - h) / 2))
		h = max(h, TAM)
		self:SetHeight(h)
		return h
	end
	return pila:Agregar(b, opts)
end

---------------------------------------------------------------------------
-- La ventana
---------------------------------------------------------------------------
local function letras(t)
	return strlenutf8 and strlenutf8(t) or #(t:gsub("[\128-\191]", ""))
end

-- La tecla del juego para las capturas (106).
local function teclaCaptura()
	local k = K.TeclaJuego and K.TeclaJuego("SCREENSHOT") or nil
	return (type(k) == "string" and k ~= "") and k or L["Impr Pant"]
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo()
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -ESP.base)
	local h = ui.pila:Acomodar(ancho)
	v:SetAltoContenido(h + 2 * ESP.base)
end

local function pintarEstado()
	if not ui.pila then return end
	local t = tipoDe(ui.tipo)
	local enviado = ui.enviado ~= nil
	ui.pregunta:Set(L[t.pregunta])
	if ui.entrada then ui.entrada:SetAyuda(L[t.ayuda]) end
	K.Mostrar(ui.captura, t.valor == "error")
	-- 1.4.0 (71): las capturas se suben en su formulario (abajo), ya no en Discord.
	ui.captura:Set(format(L["Una captura ayuda mucho: presiona %s y el juego la guarda en la carpeta Screenshots de tu WoW."], teclaCaptura()))
	-- 1.4.0 (71): lo técnico no se enseña; solo sale el cuadro al pedir «Copiar».
	K.Mostrar(ui.reporte, ui.verDatos == true)
	-- Las gracias y dónde mandarlo ya, después de «Enviar» o «Copiar».
	K.Mostrar(ui.gracias, enviado)
	if enviado then
		ui.gracias:Set(ui.enviado == "ya" and L["Ese reporte ya estaba guardado: se enviará solo con el instalador de Alfa."]
			or L["¡Gracias! Se enviará solo la próxima vez que abras el instalador de Alfa. Si lo quieres mandar ya: «Enviar ya por el navegador»."])
	end
	-- El enlace del formulario, después de «Enviar ya por el navegador».
	K.Mostrar(ui.navegadorNota, ui.mostrarEnlace == true)
	if ui.codigoTexto then ui.codigoTexto:Set(format(L["Código: %s"], codigo())) end
	K.Mostrar(ui.capturasNota, ui.mostrarCapturas == true)
	K.Mostrar(ui.capturasEnlace, ui.mostrarCapturas == true)
	K.Mostrar(ui.enlace, ui.mostrarEnlace == true)
	K.Mostrar(ui.donde, ui.mostrarDonde == true)
	K.Mostrar(ui.invitacion, ui.mostrarDonde == true)
	local n = Bz.Pendientes()
	K.Mostrar(ui.pendientes, n > 0)
	if n > 0 then
		ui.pendientes:Set(N.Plural and N.Plural(n, L["%d reporte espera al instalador de Alfa."], L["%d reportes esperan al instalador de Alfa."])
			or format(L["%d reportes esperan al instalador de Alfa."], n))
	end
	if ui.enviar then
		ui.enviar:SetTexto(enviado and L["Enviado"] or L["Enviar"])
		ui.enviar:SetIcono(enviado and "ic-exito" or "ic-flecha")
	end
end

local function rehacer()
	if not ui.reporte then return end
	-- (en la ventana sin el 🐺: las letras del juego no lo tienen)
	ui.reporte:Set((componer():gsub(LOBO .. " ?", "")))
	local t = ui.texto or ""
	ui.cuenta:Set(format(L["%d de %d letras"], letras(t), MAX_TEXTO))
	pintarEstado()
	acomodar()
end

-- Lo que acaba de aparecer al final (las gracias, el enlace), a la vista.
local function abajo()
	if v and v.Desplazable and v.Desplazable.IrAbajo then v.Desplazable:IrAbajo() end
end

local function elegirTipo(valor)
	local nuevo = tipoDe(valor).valor
	if nuevo ~= ui.tipo then ui.enviado, ui.mostrarEnlace = nil, nil end
	ui.tipo = nuevo
	if ui.segmentos then ui.segmentos:SetValor(ui.tipo) end
	rehacer()
end

-- «Enviar»: al buzón, para el instalador. -> la entrada guardada | nil
function M.EnviarReporte()
	local t = tipoDe(ui.tipo)
	if t.valor ~= "error" and textoEscrito() == "" then
		if ui.estado then ui.estado:Set(L["Escribe primero lo que nos quieres contar."]) K.Mostrar(ui.estado, true) end
		if ui.entrada then ui.entrada.Campo:SetFocus() end
		acomodar()
		return nil
	end
	if ui.estado then K.Mostrar(ui.estado, false) end
	local texto, escrito, tecnico = componerTodo()
	local e, ya = Bz.Guardar(texto, t.valor, escrito, tecnico, codigo())
	ui.enviado = ya and "ya" or "nuevo"
	if ui.entrada then ui.entrada.Campo:ClearFocus() end
	rehacer()
	abajo()
	if N.Sonar then N.Sonar("exito", 2) end
	return e
end

-- «Enviar ya por el navegador»: el enlace del formulario con todo ya escrito,
-- elegido para Ctrl+C. -> el enlace
function M.EnlaceReporte()
	local _, escrito, tecnico = componerTodo()
	local url = M.EnlaceFormulario(ui.tipo, escrito, tecnico, nil, codigo())
	ui.mostrarEnlace = true
	if ui.enlace then ui.enlace:Set(url) end
	rehacer()
	abajo()
	if ui.enlace then ui.enlace.Cuadro:Copiar() end
	return url
end

-- 1.4.0 (71): «Subir capturas»: el enlace del formulario de capturas con tu
-- código, elegido para Ctrl+C.
function M.EnlaceCapturasReporte()
	local url = M.EnlaceCapturas(codigo())
	ui.mostrarCapturas = true
	if ui.capturasEnlace then ui.capturasEnlace:Set(url) end
	rehacer()
	if ui.capturasEnlace then ui.capturasEnlace.Cuadro:Copiar() end
	return url
end

-- «Copiar» (lo de siempre, como extra): el reporte a la vista, elegido para
-- Ctrl+C, y el Discord donde pegarlo.
function M.CopiarReporte()
	ui.verDatos = true
	ui.mostrarDonde = true
	rehacer()
	abajo()
	if ui.reporte then ui.reporte.Cuadro:Copiar() end
end

local function armar()
	v = K.Ventana({
		nombre = "AlfaReporteVentana", titulo = L["Reportar a Alfa"],
		subtitulo = L["Ayúdanos a cazar errores: le llega directo al desarrollador"], icono = "ic-info",
		ancho = ANCHO, alto = ALTO, desplazar = true,
		fija = true, -- un reporte a medio escribir no se cierra al empezar algo
	})
	v.alAcomodar = acomodar
	local p = K.Pila(v.Cuerpo, { espacio = ESP.m })
	ui.pila = p

	conLobo(p, "texto", "texto"):Set(L["Cuéntanos qué pasó. Alfa agrega solo lo que ayuda a arreglarlo; nunca tu nombre ni tu reino."])
	local opciones = {}
	for i, t in ipairs(TIPOS) do opciones[i] = { valor = t.valor, texto = L[t.texto] } end
	-- 1.4.0 (71): el código del reporte, a la vista.
	ui.codigoTexto = parrafo(p, "subtitulo", "acento", { espacio = ESP.s })
	ui.segmentos = p:Agregar(suelto(p, function(b)
		return K.Segmentos(b, { estilo = "segmentos", opciones = opciones, valor = ui.tipo, alCambiar = function(x) elegirTipo(x) end })
	end)).Hijo
	ui.pregunta = parrafo(p, "subtitulo", "texto")
	ui.entrada = p:Agregar(cuadro(p, { alto = 100, lineas = true, max = MAX_TEXTO,
		alCambiar = function(t) ui.texto = t ui.enviado = nil ui.mostrarEnlace = nil rehacer() end }), { espacio = ESP.s })
	ui.cuenta = parrafo(p, "pequeno", "textoTenue", { espacio = ESP.s })
	ui.estado = parrafo(p, "nota", "aviso", { espacio = ESP.s })
	K.Mostrar(ui.estado, false)
	ui.captura = parrafo(p, "nota", "textoSuave")
	-- 1.4.0 (71): el formulario tiene un campo opcional para subir capturas.
	ui.capturasForm = parrafo(p, "texto", "acento", { espacio = ESP.s })
	ui.capturasForm:Set(L["¿Tienes capturas? Súbelas en el formulario de capturas, con el código de tu reporte."])
	ui.subirCapturas = p:Agregar(suelto(p, function(b)
		return K.Boton(b, L["Subir capturas"], function() M.EnlaceCapturasReporte() end, { tipo = "secundario", icono = "ic-flecha" })
	end), { espacio = ESP.s })
	ui.capturasNota = parrafo(p, "nota", "textoSuave", { espacio = ESP.s })
	ui.capturasNota:Set(L["Pega este enlace en tu navegador, entra con tu cuenta de Google y sube hasta 5 capturas."])
	ui.capturasEnlace = p:Agregar(filaCopiar(p, { alto = 54, lineas = true, boton = "Elegir todo" }), { espacio = ESP.s })

	-- Lo técnico se agrega solo y se manda sin enseñarlo (71); el cuadro solo
	-- sale con «Copiar» (lo que se pega en Discord).
	ui.reporte = p:Agregar(filaCopiar(p, { alto = 140, lineas = true, boton = "Elegir todo" }), { espacio = ESP.s })

	ui.gracias = conLobo(p, "texto", "exito", { espacio = ESP.l })
	ui.navegadorNota = parrafo(p, "texto", "texto")
	ui.navegadorNota:Set(L["Pega este enlace en tu navegador y dale Enviar."])
	ui.enlace = p:Agregar(filaCopiar(p, { alto = 70, lineas = true, boton = "Elegir todo" }), { espacio = ESP.s })
	ui.donde = parrafo(p, "nota", "textoSuave", { espacio = ESP.l })
	ui.donde:Set(format(L["Si prefieres, pégalo en %s del Discord de La Jauría. Si aún no estás, entra con esta invitación:"], CANAL))
	ui.invitacion = p:Agregar(filaCopiar(p, {}), { espacio = ESP.s })
	ui.pendientes = parrafo(p, "pequeno", "textoTenue", { espacio = ESP.l })

	ui.enviar = K.Boton(v, L["Enviar"], function() M.EnviarReporte() end, { tipo = "primario", icono = "ic-flecha" })
	ui.navegador = K.Boton(v, L["Enviar ya por el navegador"], function() M.EnlaceReporte() end, { tipo = "secundario" })
	ui.copiar = K.Boton(v, L["Copiar"], function() M.CopiarReporte() end, { tipo = "fantasma" })
	v:SetPie({ ui.navegador, ui.enviar }, { K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "secundario" }), ui.copiar })
end

function M.AbrirReporte(tipo)
	if not v then armar() end
	local url = type(A.DiscordURL) == "string" and A.DiscordURL ~= "" and A.DiscordURL or INVITACION
	ui.invitacion:Set(url)
	if ui.entrada and ui.entrada.Campo:GetText() ~= (ui.texto or "") then ui.entrada:Set(ui.texto or "") end
	ui.mostrarDonde, ui.mostrarEnlace, ui.mostrarCapturas = nil, nil, nil
	-- Un reporte ya enviado deja su código; el siguiente lleva uno nuevo.
	if ui.enviado then ui.codigo, ui.enviado = nil, nil end
	v:Abrir()
	elegirTipo(tipo or ui.tipo)
	if v.Desplazable then v.Desplazable:IrArriba() end
	acomodar()
	ui.entrada.Campo:SetFocus()
end

-- Para el banco: la ventana y sus piezas.
function M.ReporteUI() return v, ui end

---------------------------------------------------------------------------
-- El aviso del bicho: Alfa atrapó un error suyo (101)
---------------------------------------------------------------------------
local avisadosSesion, nAvisos = {}, 0

local function avisarBicho()
	if not (K and K.Aviso) then return end
	K.Aviso({
		id = "alfa.bicho", firma = "errores", textura = LOBO_MALO, lya = false,
		titulo = L["Alfa encontró un error"],
		texto = L["Ya lo guardé. Si lo reportas, nos ayudas a arreglarlo más rápido."],
		prioridad = "util", caduca = 600, sonido = false,
		acciones = { { texto = L["Reportar"], alClic = function() M.AbrirReporte("error") end } },
	})
end

-- -> true si avisará (para el banco).
function M.NuevoBicho(e)
	if type(e) ~= "table" then return false end
	if A.Get and A.Get("nucleo.avisos.errores") == false then return false end
	local clave = tostring(e.msg or "")
	if avisadosSesion[clave] or e.avisado or nAvisos >= MAX_AVISOS_SESION then return false end
	-- En el banco, solo en las escenas que lo piden (las viejas anotan errores a propósito).
	if rawget(_G, "FIRE_EVENT") ~= nil and rawget(_G, "BANCO_BICHO") ~= true then return false end
	avisadosSesion[clave] = true
	e.avisado = true
	nAvisos = nAvisos + 1
	-- Nunca dentro del manejador de errores ni en combate.
	local function luego() N.FueraDeCombate("bienvenida.bicho", avisarBicho) end
	if N.Una then N.Una("bienvenida.bicho", 2, luego) else luego() end
	return true
end
function M.OlvidarBichos() avisadosSesion, nAvisos = {}, 0 end -- (para el banco)

-- Se escucha al anotador del Núcleo (lo llama el manejador cada vez, por su
-- nombre): un error nuevo (n = 1) es un bicho que avisar.
if type(N.AnotarError) == "function" and not N.alfaBichoPuesto then
	N.alfaBichoPuesto = true
	local anotar = N.AnotarError
	N.AnotarError = function(msg, pila)
		local r = anotar(msg, pila)
		if r == true and N.Errores then
			local l = N.Errores()
			local e = l[#l]
			-- La traza corta, para el reporte (solo de esta sesión).
			if type(e) == "table" and e.msg and not trazas[e.msg] then trazas[e.msg] = trazaDe(pila) end
			if type(e) == "table" and tonumber(e.n) == 1 then pcall(M.NuevoBicho, e) end
		end
		return r
	end
end

-- Al entrar: fuera lo que el instalador ya mandó.
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_LOGIN")
ev:SetScript("OnEvent", function(self)
	self:UnregisterEvent("PLAYER_LOGIN")
	pcall(Bz.Limpiar)
end)

-- /alfa reportar [error | mejora | comentario]
local PALABRAS = { error = "error", bug = "error", fallo = "error", mejora = "mejora", idea = "mejora",
	sugerencia = "mejora", comentario = "comentario", comment = "comentario" }

A.RegisterCommand("reportar", function(resto)
	local palabra = type(resto) == "string" and resto:lower():match("^%s*(%S*)") or ""
	M.AbrirReporte(PALABRAS[palabra])
end, L["reporta un error, una mejora o un comentario al desarrollador de Alfa (también: mejora, comentario)"])

AlfaReporte = type(AlfaReporte) == "table" and AlfaReporte or {}
function AlfaReporte.Abrir(tipo) return M.AbrirReporte(tipo) end
function AlfaReporte.Pendientes() return Bz.Pendientes() end
function AlfaReporte.Buzon() return Bz.Lista() end
