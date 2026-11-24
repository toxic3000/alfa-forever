-- Alfa - Bolsas: «Lo que me sobra» (toxic3000 / La Jauría). GPL-3.0. 1.3.9.
--
-- Un botón en la cabecera de tus bolsas (las monedas) junta lo que te sobra
-- y te deja soltarlo en un clic:
--   * «Vender lo que sobra»: lo de la sugerencia de las bolsas (lo gris, tu
--     chatarra y lo que solo sirve para el comerciante, Sugerencias.lua). Con
--     un comerciante abierto se vende por lotes (Lotes.lua, la misma tanda
--     «vender»); sin él, la flecha te lleva al más cercano.
--   * «Mandar a <personaje>»: lo que sirve más a otro de tus personajes (sus
--     recetas o sus misiones, Guardar.lua) y lo de tus listas de envío de
--     Comercio (/alfa comercio alt, AlfaComercio.Envios). Con la pestaña
--     «Enviar» del buzón abierta, Alfa pone el nombre y adjunta (hasta llenar
--     la carta); el clic en «Enviar» siempre es tuyo (SendMail es restringida).
-- Nunca toca lo que tiene candado (Candado.lua), nunca en combate y nunca solo.
-- Ajuste bolsas.sobra (de fábrica, encendido).
--   Sb.Lista() -> { vender = { grupos }, valor, alts = { { nombre, piezas = { { bolsa, casilla, id } }, lista } } }
--   Sb.Menu(ancla) ; Sb.Vender() ; Sb.Mandar(nombre) ; Sb.Texto() -> «6 para vender · 2 para Garra»

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local D = M.Datos

local type, ipairs, pairs, tonumber, format, sort = type, ipairs, pairs, tonumber, string.format, table.sort

local Sb = {}
M.Sobra = Sb

local ORIGEN = { 0, 1, 2, 3, 4, 5 }
local CARTA = 12 -- adjuntos por carta (ATTACHMENTS_MAX_SEND en el juego)

function Sb.Encendido() return M.Get("sobra") ~= false end

local function S() return M.Sugerencias end
local function Cd() return M.Candado end

local function conCandado(bolsa, casilla)
	local c = Cd()
	return c and c.TieneCasilla(bolsa, casilla) and true or false
end

local function envios()
	local C = rawget(_G, "AlfaComercio")
	local En = type(C) == "table" and C.Envios
	return type(En) == "table" and type(En.Listas) == "function" and En or nil
end

local function yo()
	local n = UnitName and UnitName("player")
	return type(n) == "string" and n or nil
end

---------------------------------------------------------------------------
-- Qué te sobra
---------------------------------------------------------------------------

-- Las casillas de un objeto en tus bolsas, sin las que tienen candado.
local function casillasDe(ids)
	local out = {}
	local C = M.CC
	for _, bolsa in ipairs(ORIGEN) do
		for s = 1, M.Num(M.Llamar(C.GetContainerNumSlots, bolsa)) or 0 do
			local info = M.Llamar(C.GetContainerItemInfo, bolsa, s)
			local id = type(info) == "table" and M.Num(info.itemID)
			if id and ids[id] and not conCandado(bolsa, s) then out[#out + 1] = { bolsa, s, id } end
		end
	end
	return out
end

function Sb.Lista()
	local r = { vender = {}, valor = 0, alts = {} }
	if not Sb.Encendido() then return r end
	-- Para vender: la sugerencia, sin lo que tiene candado.
	local Sg = S()
	if Sg then
		local est = Sg.Estado()
		local c = Cd()
		for _, g in ipairs(est.vender or {}) do
			if not (c and c.Tiene(g.id, g.link, { q = g.q })) then
				r.vender[#r.vender + 1] = g
				r.valor = r.valor + (g.valor or 0)
			end
		end
	end
	-- Para tus otros personajes: lo que sirve a sus recetas o misiones.
	local porNombre = {}
	local mio = yo()
	local Gu = M.Guardar
	if Gu and M.Get("queGuardar") ~= false then
		for _, x in ipairs(Gu.Sugerencias()) do
			local nombre = x.nombre
			if type(nombre) == "string" and nombre ~= "" and nombre ~= mio and not conCandado(x.bolsa, x.casilla) then
				local a = porNombre[nombre]
				if not a then
					a = { nombre = nombre, piezas = {} }
					porNombre[nombre] = a
					r.alts[#r.alts + 1] = a
				end
				a.piezas[#a.piezas + 1] = { x.bolsa, x.casilla, x.id }
			end
		end
	end
	-- Tus listas de envío (Comercio): «las hierbas a mi alquimista».
	local En = envios()
	if En then
		local ok, listas = pcall(En.Listas)
		if ok and type(listas) == "table" then
			for nombre, l in pairs(listas) do
				if type(nombre) == "string" and nombre ~= mio then
					local ok2, cands = pcall(En.Candidatos, l)
					local n = ok2 and type(cands) == "table" and #cands or 0
					if n > 0 then
						local a = porNombre[nombre]
						if not a then
							a = { nombre = nombre, piezas = {} }
							porNombre[nombre] = a
							r.alts[#r.alts + 1] = a
						end
						a.lista = n
					end
				end
			end
		end
	end
	sort(r.alts, function(a, b) return a.nombre < b.nombre end)
	return r
end

local function cuantas(a) return math.max(#a.piezas, a.lista or 0) end

-- «6 para vender · 2 para Garra»
function Sb.Texto(r)
	r = r or Sb.Lista()
	local partes = {}
	if #r.vender > 0 then partes[#partes + 1] = format(L["%d para vender"], #r.vender) end
	for _, a in ipairs(r.alts) do partes[#partes + 1] = format(L["%d para %s"], cuantas(a), a.nombre) end
	if #partes == 0 then return L["No te sobra nada ahora."] end
	return table.concat(partes, " \194\183 ")
end

---------------------------------------------------------------------------
-- Vender (con un comerciante)
---------------------------------------------------------------------------

function Sb.Vender()
	if M.EnCombate() then N.Imprimir(L["No se puede en combate."]) return false end
	local Sg = S()
	if not Sg then return false end
	if M.Lotes.Activo("vender") then
		M.Lotes.Cancelar("vender")
		return false
	end
	local r = Sb.Lista()
	if #r.vender == 0 then
		N.Imprimir(L["No te sobra nada para vender."])
		return false
	end
	if not Sg.ComercianteAbierto() then
		N.Imprimir(L["Habla con un comerciante y vuelve a darle a «Vender lo que sobra»."])
		Sg.LlevarComerciante()
		return false
	end
	local ids = {}
	for _, g in ipairs(r.vender) do ids[g.id] = true end
	local lista = casillasDe(ids)
	local C = M.CC
	local vendidos = 0
	return M.Lotes.Iniciar({
		nombre = "vender", lista = lista,
		puede = function()
			if not Sg.ComercianteAbierto() then return false, "cerrado" end
			return true
		end,
		mover = function(bolsa, casilla)
			-- El candado otra vez, justo antes (pudiste ponérselo mientras tanto).
			if conCandado(bolsa, casilla) then return end
			M.Llamar(C.UseContainerItem, bolsa, casilla)
			vendidos = vendidos + 1
		end,
		alTerminar = function(hechos, total, corte)
			if corte and corte ~= "cancelado" then
				N.Imprimir(format(L["La venta se detuvo: vendiste %d de %d."], vendidos, total))
			elseif vendidos > 0 then
				N.Imprimir(format(L["Vendiste lo que te sobraba: %s, por unos %s."], N.Plural(vendidos, L["%d objeto"], L["%d objetos"]), N.Dinero(r.valor, true)))
			end
			Sg.Invalidar()
			M.Avisar("SUGERENCIAS")
		end,
	}) and true or false
end

---------------------------------------------------------------------------
-- Mandar a otro personaje (con el buzón, pestaña «Enviar»)
---------------------------------------------------------------------------

local function enviarVisible()
	local f = rawget(_G, "SendMailFrame")
	return type(f) == "table" and f.IsVisible and f:IsVisible() and true or false
end
Sb.EnviarVisible = enviarVisible

local function adjuntosLibres()
	local hay = rawget(_G, "HasSendMailItem")
	local tope = tonumber(rawget(_G, "ATTACHMENTS_MAX_SEND")) or CARTA
	local libres = {}
	for i = 1, tope do
		if not (type(hay) == "function" and M.Leer(M.Llamar(hay, i))) then libres[#libres + 1] = i end
	end
	return libres
end

function Sb.Mandar(nombre)
	if M.EnCombate() then N.Imprimir(L["No se puede en combate."]) return false end
	local r = Sb.Lista()
	local a
	for _, x in ipairs(r.alts) do if x.nombre == nombre then a = x end end
	if not a then return false end
	if not enviarVisible() then
		N.Imprimir(format(L["Abre el buzón en la pestaña «Enviar» y vuelve a darle a «Mandar a %s»."], nombre))
		return false
	end
	-- Lo de tu lista de Comercio lo prepara Comercio (su placa del buzón).
	if #a.piezas == 0 and a.lista then
		local En = envios()
		if En and En.Preparar then return M.Llamar(En.Preparar, nombre) and true or false end
		return false
	end
	local caja = rawget(_G, "SendMailNameEditBox")
	if type(caja) == "table" and caja.SetText then pcall(caja.SetText, caja, nombre) end
	local libres = adjuntosLibres()
	local lista = {}
	for i = 1, math.min(#libres, #a.piezas) do lista[i] = a.piezas[i] end
	if #lista == 0 then
		N.Imprimir(L["La carta ya está llena: mándala y vuelve a darle."])
		return false
	end
	local C = M.CC
	local clic = rawget(_G, "ClickSendMailItemButton")
	local puestos = 0
	return M.Lotes.Iniciar({
		nombre = "sobra.carta", lista = lista,
		puede = function()
			if not enviarVisible() then return false, "cerrado" end
			return true
		end,
		mover = function(bolsa, casilla)
			if conCandado(bolsa, casilla) then return end
			local libre = adjuntosLibres()[1]
			if not (libre and type(clic) == "function") then return end
			M.Llamar(C.PickupContainerItem, bolsa, casilla)
			M.Llamar(clic, libre)
			puestos = puestos + 1
		end,
		alTerminar = function(hechos, total, corte)
			if puestos > 0 then
				local resto = #a.piezas - puestos
				local texto = format(L["Listo: %s en la carta para %s. Revísala y dale «Enviar»."], N.Plural(puestos, L["%d objeto"], L["%d objetos"]), nombre)
				if resto > 0 then texto = texto .. " " .. format(L["Quedan %d para otra carta."], resto) end
				N.Imprimir(texto)
			end
		end,
	}) and true or false
end

---------------------------------------------------------------------------
-- El menú del botón
---------------------------------------------------------------------------

function Sb.Menu(ancla)
	local K = N.Kit
	if not (K and K.Menu) then return end
	if M.EnCombate() then N.Imprimir(L["No se puede en combate."]) return end
	local r = Sb.Lista()
	local ops = {}
	if #r.vender > 0 then
		ops[#ops + 1] = { valor = "vender", icono = "ic-oro",
			texto = format(L["Vender lo que sobra · %d (%s)"], #r.vender, N.Dinero(r.valor, true)) }
	end
	for _, a in ipairs(r.alts) do
		ops[#ops + 1] = { valor = "alt:" .. a.nombre, icono = "ic-personajes",
			texto = format(L["Mandar a %s · %s"], a.nombre, N.Plural(cuantas(a), L["%d objeto"], L["%d objetos"])) }
	end
	if #ops == 0 then ops[1] = { valor = "", texto = L["No te sobra nada ahora."] } end
	K.Menu(ancla, ops, nil, function(v)
		if v == "vender" then Sb.Vender()
		elseif type(v) == "string" and v:sub(1, 4) == "alt:" then Sb.Mandar(v:sub(5)) end
	end, 280)
end
