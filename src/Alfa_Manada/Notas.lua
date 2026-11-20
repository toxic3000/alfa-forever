-- Alfa - La Jauría: las notas del lobo (1.2.8). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Una nota tuya en el mapa, donde estás parado: «Nota aquí» en la página de
-- La Jauría o /alfa nota <texto>. Sale como marca en el mapa del mundo (y el
-- minimapa) con su texto en el cuadro; un clic y la flecha te lleva. Se ven,
-- se llevan y se borran desde la página. (Nada de clic derecho en el mapa:
-- tocar el mapa del juego lo puede dejar bloqueado.)
--
-- Con «Compartir con la manada» (manada.notasCompartir, apagado de fábrica)
-- tus notas nuevas van a los lobos de tu hermandad que comparten, y ves las
-- suyas. Mensaje (Red.lua, prefijo AlfaManada, por la hermandad):
--   1N|<mapa>|<x>|<y>|<texto>   (x, y en 0-100, como la flecha)
-- Se guardan en N.Datos("manada").notas: hasta MIAS tuyas y SUYAS de otros
-- (las de otros se van a los DURAN días). Ajuste manada.notas.
--
--   No.Agregar(texto, tipo) -> nota | nil, por qué    en tu lugar de ahora
--   No.Lista(tipo) -> { nota }  ; No.Borrar(id) ; No.Ir(id) ; No.Pintar(forzar)
--
-- 1.3.0: los spots de farmeo. Una nota con tipo = "spot" («Spot aquí» en la
-- página o /alfa spot <texto>) sale en su propia capa del mapa (manada.spots,
-- con su ajuste manada.spots). Con «Compartir mis spots»
-- (manada.spotsCompartir, apagado de fábrica) tus spots nuevos van a tu
-- hermandad, sin pedir que compartas tu ubicación, y ves los suyos:
--   1N|<mapa>|<x>|<y>|<texto>|s   (un Alfa viejo que comparte notas lo ve
--                                  como una nota más)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID

local No = {}
M.Notas = No

local type, tonumber, tostring, pairs, ipairs, pcall, format = type, tonumber, tostring, pairs, ipairs, pcall, string.format
local sort = table.sort

local V = "1"
local CAPA = "manada.notas"
local CAPA_SPOTS = "manada.spots"
local MIAS, SUYAS = 60, 30
local DURAN = 14 * 86400
local CADA = 20 -- segundos entre dos notas de la misma persona

local function on(clave) return N.Get(ID, clave) and true or false end
local function activo() return N.Get(ID, "notas") ~= false end
local function compartir() return on("notasCompartir") and on("compartir") end
-- 1.3.0: los spots tienen su capa y su permiso (solo la hermandad).
local function spotsOn() return activo() and N.Get(ID, "spots") ~= false end
local function spotsCompartir() return spotsOn() and on("spotsCompartir") end
local function esSpot(x) return x.tipo == "spot" end
No.EsSpot = esSpot

No.version = 0
local function cambio()
	No.version = No.version + 1
	if No.Pintar then No.Pintar(true) end
	if M.Avisar then M.Avisar() end
end

local function datos()
	local d = N.Datos(ID)
	if type(d.notas) ~= "table" then d.notas = {} end
	return d
end

local function limpiar(s)
	if type(s) ~= "string" or U.Secreto(s) then return nil end
	s = s:gsub("[|\n\r]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	s = U.Cortar(s, 60) -- hasta 60 letras (1.3.1: U.Cortar)
	return s ~= "" and s or nil
end

-- `tipo`: "spot" solo los spots, "nota" solo las notas, nil todo.
function No.Lista(tipo)
	local out, t = {}, U.Reloj()
	local d = datos()
	for i = #d.notas, 1, -1 do
		local x = d.notas[i]
		if type(x) ~= "table" or not (x.map and x.x and x.y) or (x.de and t - (x.at or 0) > DURAN) then table.remove(d.notas, i) end
	end
	for _, x in ipairs(d.notas) do
		local spot = esSpot(x)
		local vale = (tipo == nil or (tipo == "spot") == spot)
			and (not x.de or (spot and spotsCompartir()) or (not spot and compartir()))
		if vale then out[#out + 1] = x end
	end
	sort(out, function(a, b)
		if (a.de == nil) ~= (b.de == nil) then return a.de == nil end
		return (a.at or 0) > (b.at or 0)
	end)
	return out
end

local function buscar(id)
	for i, x in ipairs(datos().notas) do if x.id == id then return x, i end end
	return nil
end

local function contar(deOtro)
	local n = 0
	for _, x in ipairs(datos().notas) do if (x.de ~= nil) == deOtro then n = n + 1 end end
	return n
end

-- Una nota nueva en tu lugar de ahora: la nota, o nil y por qué
-- ("apagado", "texto", "lugar", "muchas"). `tipo`: "spot" (1.3.0) o nil.
function No.Agregar(texto, tipo)
	if not activo() then return nil, "apagado" end
	local spot = tipo == "spot"
	if spot and not spotsOn() then return nil, "spots" end
	texto = limpiar(texto)
	if not texto then return nil, "texto" end
	local map, x, y = U.MiPosicion()
	if not map then return nil, "lugar" end
	if contar(false) >= MIAS then return nil, "muchas" end
	local d = datos()
	d.notaN = (tonumber(d.notaN) or 0) + 1
	local nota = { id = "n" .. d.notaN, map = map, x = x, y = y, texto = texto, at = U.Reloj(), tipo = spot and "spot" or nil }
	d.notas[#d.notas + 1] = nota
	if spot then
		if spotsCompartir() and M.Red.EnviarHermandad("N:" .. nota.id, format("%sN|%d|%.2f|%.2f|%s|s", V, map, x, y, texto)) then nota.compartida = true end
	elseif compartir() and U.EnHermandad() then
		if M.Red.Enviar("N:" .. nota.id, format("%sN|%d|%.2f|%.2f|%s", V, map, x, y, texto), "GUILD") then nota.compartida = true end
	end
	cambio()
	return nota
end

local MOTIVOS = {
	apagado = "Las notas del lobo están apagadas (Ajustes de La Jauría).",
	texto = "Escribe qué dice la nota: /alfa nota Aquí sale el mineral",
	lugar = "Alfa no sabe dónde estás (en una instancia no hay notas).",
	muchas = "Ya tienes 60 notas. Borra alguna en La Jauría para dejar otra.",
	spots = "Los spots de farmeo están apagados (Ajustes de La Jauría).",
	textoSpot = "Escribe qué se farmea ahí: /alfa spot Lobos para pieles",
}
No.MOTIVOS = MOTIVOS

function No.AgregarYDecir(texto, tipo)
	local nota, por = No.Agregar(texto, tipo)
	if nota then
		U.Decir(format(esSpot(nota) and L["Marcaste un spot de farmeo: «%s»."] or L["Dejaste una nota en tu mapa: «%s»."], nota.texto)
			.. (nota.compartida and (" " .. L["La manada también la ve."]) or ""))
	elseif MOTIVOS[por] then
		U.Decir(L[MOTIVOS[(por == "texto" and tipo == "spot") and "textoSpot" or por]])
	end
	return nota, por
end

function No.Borrar(id)
	local _, i = buscar(id)
	if not i then return false end
	table.remove(datos().notas, i)
	cambio()
	return true
end

function No.Ir(id)
	local x = type(id) == "table" and id or buscar(id)
	local Nav = A.Nav
	if not (x and Nav and Nav.SetTarget) then return false end
	Nav.SetTarget(x.map, x.x, x.y, x.texto)
	N.EmpezarRuta()
	return true
end

---------------------------------------------------------------------------
-- Lo que llega
---------------------------------------------------------------------------

local function numero(s, max)
	if type(s) ~= "string" or not s:match("^%d+%.?%d*$") or #s > 10 then return nil end
	local n = tonumber(s)
	if not n or n > max then return nil end
	return n
end

local oidas = {} -- clave -> cuándo
M.Red.Oyentes.N = function(clave, remitente, _, f, canal)
	local spot = f[5] == "s"
	if canal ~= "GUILD" or not activo() then return end
	if spot and not spotsCompartir() then return end
	if not spot and not compartir() then return end
	local map, x, y = numero(f[1], 100000), numero(f[2], 100), numero(f[3], 100)
	local texto = limpiar(f[4])
	if not (map and x and y and texto) then return end
	local t = U.Ahora()
	if oidas[clave] and t - oidas[clave] < CADA then return end
	oidas[clave] = t
	local d = datos()
	-- La misma nota otra vez: nada.
	for _, n in ipairs(d.notas) do
		if n.de and n.texto == texto and esSpot(n) == spot and n.map == map and math.abs(n.x - x) < 0.5 and math.abs(n.y - y) < 0.5 then return end
	end
	-- Demasiadas de otros: se va la más vieja.
	if contar(true) >= SUYAS * (spot and 2 or 1) then
		local vieja, cuando
		for i, n in ipairs(d.notas) do if n.de and (not cuando or (n.at or 0) < cuando) then vieja, cuando = i, n.at or 0 end end
		if vieja then table.remove(d.notas, vieja) end
	end
	d.notaN = (tonumber(d.notaN) or 0) + 1
	d.notas[#d.notas + 1] = { id = "n" .. d.notaN, map = math.floor(map), x = x, y = y, texto = texto, at = U.Reloj(), de = U.Mostrar(remitente), tipo = spot and "spot" or nil }
	cambio()
end
-- (1.3.0) Los spots llegan aunque no compartas tu ubicación (su propio permiso).
M.Red.Libres.N = true

---------------------------------------------------------------------------
-- En el mapa
---------------------------------------------------------------------------

local function media(nombre)
	local ok, p = pcall(A.Theme.Media, nombre)
	if ok and type(p) == "string" then return p end
	return "Interface\\AddOns\\Alfa\\Media\\UI\\" .. nombre
end

local function acento()
	local ok, r, g, b = pcall(A.Theme.Accent)
	if ok and type(r) == "number" then return r, g, b end
	return 0.545, 0.878, 0.306
end

local function cuadro(x)
	return function(tip)
		local r, g, b = acento()
		tip:SetText(x.texto or "?", 1, 1, 1)
		if esSpot(x) then
			tip:AddLine(x.de and format(L["Spot de farmeo de %s"], x.de) or L["Tu spot de farmeo"], 1, 0.82, 0.3)
		else
			tip:AddLine(x.de and format(L["Nota de %s"], x.de) or L["Tu nota"], r, g, b)
		end
		local hace = U.Hace(U.Reloj() - (x.at or U.Reloj()))
		if hace then tip:AddLine(hace, 0.6, 0.6, 0.6) end
		tip:AddLine(L["Clic: la flecha te lleva aquí."], 0.4, 0.9, 0.4)
	end
end

local firmas = {}
local function capa(nombre, lista, color, icono, visible, forzar)
	local P = A.Pins
	local pins, partes = {}, {}
	local mini = on("minimapa")
	if visible then
		for _, x in ipairs(lista) do
			pins[#pins + 1] = {
				map = x.map, x = x.x, y = x.y,
				icon = media(icono), color = x.de and { 0.75, 0.75, 0.75, 1 } or color, backdrop = true,
				size = 14, minimapSize = 11, priority = 3,
				tooltip = cuadro(x),
				onClick = function(button)
					if button == "LeftButton" or button == nil then No.Ir(x) end
				end,
			}
			partes[#partes + 1] = format("%s%d:%.1f:%.1f", x.id, x.map, x.x, x.y)
		end
	end
	local f = (mini and "m" or "-") .. table.concat(partes, "|")
	if forzar or f ~= firmas[nombre] then
		firmas[nombre] = f
		pcall(P.SetLayer, nombre, pins, { world = true, minimap = mini, edge = false })
	end
	pcall(P.SetLayerVisible, nombre, visible)
end

function No.Pintar(forzar)
	local P = A.Pins
	if not (P and P.SetLayer) then return end
	local r, g, b = acento()
	capa(CAPA, activo() and No.Lista("nota") or {}, { r, g, b, 1 }, "icon-note", activo(), forzar)
	-- 1.3.0: los spots de farmeo, en su propia capa (dorados).
	capa(CAPA_SPOTS, spotsOn() and No.Lista("spot") or {}, { 1, 0.78, 0.25, 1 }, "ic-recoleccion", spotsOn(), forzar)
end

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and (path == "" or path == ID or path:sub(1, #ID + 1) == ID .. ".") then No.Pintar(true) end
end)

A.RegisterCommand("nota", function(rest)
	rest = tostring(rest or "")
	if rest:match("^%s*$") then
		U.Decir(L[MOTIVOS.texto])
		return
	end
	No.AgregarYDecir(rest)
end, L["Deja una nota en tu mapa donde estás (/alfa nota <texto>)"])

-- 1.3.0: /alfa spot <texto>, un spot de farmeo donde estás.
A.RegisterCommand("spot", function(rest)
	rest = tostring(rest or "")
	if rest:match("^%s*$") then
		U.Decir(L[MOTIVOS.textoSpot])
		return
	end
	No.AgregarYDecir(rest, "spot")
end, L["Marca un spot de farmeo donde estás (/alfa spot <texto>)"])

A.OnLogin(function() A.After(2, function() No.Pintar(true) end) end)
