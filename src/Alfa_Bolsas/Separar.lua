-- Alfa - Bolsas: «Separar»: lo que vale la pena subastar y lo que conviene
-- vender al comerciante, en un clic (toxic3000 / La Jauría). GPL-3.0. 1.3.8.
--
-- Un botón en la cabecera de tus bolsas (el ícono de Comercio) prende o
-- apaga la vista: cada casilla lleva una marca chica (el martillo de la
-- subasta en el color de acento, la moneda dorada para el comerciante) y lo
-- demás se atenúa. Arriba, en la búsqueda, cuántos de cada uno y cuánto
-- valen, y un botón para marcar como chatarra lo del comerciante (lo vende el
-- motor al abrir un comerciante, o «Acomodar»). Las cuentas son las de la
-- sugerencia de las bolsas (Sugerencias.lua: el consejo y los precios de
-- Comercio): nada se vende ni se subasta solo.
-- Funciona también en combate (solo pinta: los botones seguros no se tocan).
-- Ajuste bolsas.separar (el botón; de fábrica, sí). La vista no se guarda:
-- se apaga al cerrar las bolsas.
--
--   Sp.Activo() ; Sp.Alternar(f) ; Sp.Clase(id) -> "subasta" | "vendedor" | nil
--   Sp.Cuentas() -> { subasta = n, valorSubasta, vendedor = n, valorVendedor, sinMarcar }
--   Sp.Pintar(b, p, ent)   (Botones.lua, al pintar cada casilla)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit

local type, ipairs, pairs, format = type, ipairs, pairs, string.format

local Sp = {}
M.Separar = Sp

local activo = false
local porId, deEstado = {}, nil

function Sp.Activo() return activo and M.Get("separar") ~= false end

local function S() return M.Sugerencias end

-- El mapa id -> clase, rehecho solo cuando cambia el análisis de la sugerencia.
local function mapa()
	local Sg = S()
	if not Sg then return porId end
	local est = Sg.Estado()
	if est == deEstado then return porId end
	deEstado = est
	porId = {}
	for _, g in ipairs(est.vender or {}) do porId[g.id] = "vendedor" end
	for _, g in ipairs(est.conservar or {}) do
		if g.mejor == "subastar" then porId[g.id] = "subasta" end
	end
	return porId
end

function Sp.Clase(id) return id and mapa()[id] or nil end

function Sp.Cuentas()
	local Sg = S()
	local r = { subasta = 0, valorSubasta = 0, vendedor = 0, valorVendedor = 0, sinMarcar = 0 }
	if not Sg then return r end
	local est = Sg.Estado()
	for _, g in ipairs(est.vender or {}) do
		r.vendedor = r.vendedor + 1
		r.valorVendedor = r.valorVendedor + (g.valor or 0)
		if not g.chatarra then r.sinMarcar = r.sinMarcar + 1 end
	end
	for _, g in ipairs(est.conservar or {}) do
		if g.mejor == "subastar" then
			r.subasta = r.subasta + 1
			r.valorSubasta = r.valorSubasta + (g.valor or 0)
		end
	end
	return r
end

-- «4 a la subasta (~1 o) · 6 al vendedor (~35 p)»
function Sp.Texto()
	local c = Sp.Cuentas()
	if c.subasta + c.vendedor == 0 then return L["Nada que separar"] end
	local partes = {}
	if c.subasta > 0 then partes[#partes + 1] = format(L["%d a la subasta (%s)"], c.subasta, N.Dinero(c.valorSubasta, true)) end
	if c.vendedor > 0 then partes[#partes + 1] = format(L["%d al comerciante (%s)"], c.vendedor, N.Dinero(c.valorVendedor, true)) end
	return table.concat(partes, " \194\183 ")
end

-- En la caja de búsqueda: «4 subasta · 6 comerciante».
function Sp.TextoCorto()
	local c = Sp.Cuentas()
	if c.subasta + c.vendedor == 0 then return L["Nada que separar"] end
	return format(L["%d subasta · %d comerciante"], c.subasta, c.vendedor)
end

---------------------------------------------------------------------------
-- La marca de cada casilla
---------------------------------------------------------------------------

local MARTILLO = "ic-comercio"
local MONEDA = "ic-oro"

local function marca(b, p)
	if p.separa then return p.separa end
	local t = p.capa:CreateTexture(nil, "OVERLAY", nil, 6)
	t:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
	t:Hide()
	local fondo = p.capa:CreateTexture(nil, "OVERLAY", nil, 5)
	fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
	fondo:SetPoint("TOPLEFT", t, "TOPLEFT", -1, 1)
	fondo:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 1, -1)
	fondo:SetVertexColor(0, 0, 0, 0.6)
	fondo:Hide()
	t.fondo = fondo
	p.separa = t
	return t
end

function Sp.Pintar(b, p, ent)
	if not p then return end
	local rec = ent and ent.rec
	local on = Sp.Activo() and rec ~= nil
	local clase = on and Sp.Clase(tonumber(rec.i)) or nil
	if not on then
		if p.separa then p.separa:Hide() p.separa.fondo:Hide() end
		if p.separaAtenuado then
			p.icono:SetAlpha(1)
			p.separaAtenuado = nil
		end
		return
	end
	if clase then
		local t = marca(b, p)
		local lado = math.max(10, math.floor((p.tam or 36) * 0.36 + 0.5))
		t:SetSize(lado, lado)
		t:SetTexture(K.Ruta(clase == "subasta" and MARTILLO or MONEDA))
		if clase == "subasta" then t:SetVertexColor(M.Acento()) else t:SetVertexColor(1, 0.82, 0.25, 1) end
		t:Show()
		t.fondo:Show()
		p.icono:SetAlpha(1)
		p.separaAtenuado = nil
	else
		if p.separa then p.separa:Hide() p.separa.fondo:Hide() end
		p.icono:SetAlpha(0.3)
		p.separaAtenuado = true
	end
end

---------------------------------------------------------------------------
-- Prender y apagar
---------------------------------------------------------------------------

function Sp.Alternar(f, si)
	if si == nil then si = not activo end
	activo = si and true or false
	if M.Ventana and M.Ventana.RepintarTodo then M.Ventana.RepintarTodo() end
	if f and f.Separar and f.Separar.SetMarcado then f.Separar:SetMarcado(activo) end
	M.Avisar("SEPARAR", activo)
	return activo
end

-- Marca como chatarra lo del comerciante (lo de la sugerencia de las bolsas).
function Sp.MarcarVendedor()
	local Sg = S()
	if not Sg then return 0 end
	local n = Sg.MarcarChatarra()
	if M.Ventana and M.Ventana.RepintarTodo then M.Ventana.RepintarTodo() end
	return n
end

-- Lo nuevo de las bolsas: la marca se rehace con la sugerencia.
M.Escuchar("SUGERENCIAS", function()
	if activo and M.Ventana and M.Ventana.RepintarTodo then M.Ventana.RepintarTodo() end
end)
