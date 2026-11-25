-- Alfa - Bolsas: «Ordenar» con vista previa (toxic3000 / La Jauría). GPL-3.0. 1.4.0.
--
-- 1.4.0 (19): al pasar el ratón por «Ordenar» (tus bolsas, en vivo), al lado
-- de la ventana sale cómo quedarán tus bolsas antes de mover nada: los
-- objetos en su orden nuevo, con los montones ya juntos. Con tu orden
-- (bolsas.ordenarModo) es exacto, porque ordena Alfa (Ordenar.lua); con el
-- del juego es «más o menos así»: el juego decide el orden final. Lo que
-- tiene candado y se queda en su lugar (bolsas.ordenarCandado) se dice abajo.
-- Es solo para ver: no atrapa clics y en combate no sale.
--   Pv.Resultado() -> { { id, link, n, q, icono } }, exacto (bool)
--   Pv.Mostrar(f, ancla) ; Pv.Ocultar() ; Pv.Enganchar(f, boton)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L
local K = N.Kit
local ESP = K.ESP

local type, ipairs, tonumber, format, min, max, floor, ceil = type, ipairs, tonumber, string.format, math.min, math.max, math.floor, math.ceil

local Pv = {}
M.Previa = Pv

local COLS, ICONO, GAP, TOPE = 10, 20, 2, 80
Pv.COLS, Pv.ICONO, Pv.TOPE = COLS, ICONO, TOPE

local function icono(o)
	local e = o.e
	local i = type(e) == "table" and e.icono
	if not i and C_Item and C_Item.GetItemIconByID then i = M.Leer(M.Llamar(C_Item.GetItemIconByID, o.id)) end
	return i or 134400
end

-- Lo que habrá en tus bolsas, en orden, con los montones juntos.
function Pv.Resultado()
	local Ord = M.Ordenar
	if not (Ord and Ord.Plan) then return {}, false end
	local ok, destino = pcall(Ord.Plan)
	if not ok or type(destino) ~= "table" then return {}, false end
	local por, orden = {}, {}
	for _, o in ipairs(destino) do
		local k = o.id .. "|" .. (o.link or "")
		local t = por[k]
		if not t then
			t = { o = o, n = 0 }
			por[k] = t
			orden[#orden + 1] = k
		end
		t.n = t.n + (tonumber(o.n) or 1)
	end
	local lista = {}
	for _, k in ipairs(orden) do
		local t = por[k]
		local tope = max(1, tonumber(t.o.max) or 1)
		local n = t.n
		while n > 0 do
			local c = min(n, tope)
			lista[#lista + 1] = { id = t.o.id, link = t.o.link, n = c, q = t.o.q, icono = icono(t.o) }
			n = n - c
		end
	end
	return lista, Ord.Usar and Ord.Usar() or false
end

---------------------------------------------------------------------------
-- El panel
---------------------------------------------------------------------------
local panel

local function armar()
	if panel then return panel end
	local p = CreateFrame("Frame", "AlfaBolsasPrevia", UIParent)
	p:SetFrameStrata("DIALOG")
	p:EnableMouse(false)
	p.caja = K.Caja(p, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	p.Titulo = K.Texto(p, "encabezado", "texto")
	p.Titulo:SetPoint("TOPLEFT", p, "TOPLEFT", ESP.m, -ESP.m)
	p.Modo = K.Texto(p, "nota", "textoSuave")
	p.Nota = K.Texto(p, "nota", "textoTenue")
	p.casillas = {}
	p:Hide()
	panel = p
	return p
end

local function casilla(p, i)
	local c = p.casillas[i]
	if c then return c end
	c = CreateFrame("Frame", nil, p)
	c:SetSize(ICONO, ICONO)
	c.Icono = c:CreateTexture(nil, "ARTWORK")
	c.Icono:SetAllPoints(c)
	c.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	c.Borde = c:CreateTexture(nil, "BORDER")
	c.Borde:SetPoint("TOPLEFT", c, "TOPLEFT", -1, 1)
	c.Borde:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, -1)
	c.Borde:SetTexture("Interface\\Buttons\\WHITE8x8")
	c.Cuenta = c:CreateFontString(nil, "OVERLAY")
	c.Cuenta:SetFont(K.Cara("semibold"), 8, "OUTLINE")
	c.Cuenta:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 1, 0)
	c.Cuenta:SetJustifyH("RIGHT")
	p.casillas[i] = c
	return c
end

local NOMBRE_MODO = { tipo = L["Por tipo"], calidad = L["Por calidad"], nombre = L["Por nombre"] }

function Pv.Ocultar()
	if panel then panel:Hide() end
end

-- f: la ventana de bolsas; ancla: el botón «Ordenar».
function Pv.Mostrar(f, ancla)
	if M.EnCombate() or not (f and f.esVivo and f.tipo == "bolsas") then return Pv.Ocultar() end
	local Ord = M.Ordenar
	if not Ord or Ord.Activo() then return Pv.Ocultar() end
	local lista, exacto = Pv.Resultado()
	local p = armar()
	local ancho = COLS * ICONO + (COLS - 1) * GAP + 2 * ESP.m
	local tw = ancho - 2 * ESP.m
	K.Escribir(p.Titulo, exacto and L["Así quedarán tus bolsas"] or L["Más o menos así quedarán"])
	K.Ajustar(p.Titulo, tw)
	local modo = Ord.Modo and Ord.Modo() or "juego"
	local texto
	if exacto then
		texto = NOMBRE_MODO[modo] or NOMBRE_MODO.tipo
		if M.Get("ordenarInverso") then texto = texto .. " \194\183 " .. L["desde el final"] end
	else
		texto = L["El juego decide el orden final."]
	end
	K.Escribir(p.Modo, texto)
	p.Modo:ClearAllPoints()
	p.Modo:SetPoint("TOPLEFT", p.Titulo, "BOTTOMLEFT", 0, -2)
	local y = ESP.m + K.AltoTexto(p.Titulo) + 2 + K.Parrafo(p.Modo, tw) + ESP.s
	local n = min(#lista, TOPE)
	for i = 1, n do
		local x = lista[i]
		local c = casilla(p, i)
		local col, fila = (i - 1) % COLS, floor((i - 1) / COLS)
		c:ClearAllPoints()
		c:SetPoint("TOPLEFT", p, "TOPLEFT", ESP.m + col * (ICONO + GAP), -(y + fila * (ICONO + GAP)))
		c.Icono:SetTexture(x.icono)
		local r, g, b = 0.3, 0.3, 0.32
		if type(x.q) == "number" and x.q >= 2 and M.Botones and M.Botones.CalidadColor then r, g, b = M.Botones.CalidadColor(x.q) end
		c.Borde:SetVertexColor(r, g, b, 0.9)
		c.Cuenta:SetText((x.n or 1) > 1 and tostring(x.n) or "")
		c:Show()
	end
	for i = n + 1, #p.casillas do p.casillas[i]:Hide() end
	y = y + ceil(n / COLS) * (ICONO + GAP)
	local notas = {}
	if #lista > TOPE then notas[#notas + 1] = format(L["y %d más"], #lista - TOPE) end
	if #lista == 0 then notas[#notas + 1] = L["No hay nada que ordenar."] end
	if exacto and M.Get("ordenarCandado") == true then notas[#notas + 1] = L["Lo que tiene candado se queda en su lugar."] end
	notas[#notas + 1] = L["Nada se mueve hasta que das clic."]
	K.Escribir(p.Nota, table.concat(notas, " "))
	p.Nota:ClearAllPoints()
	p.Nota:SetPoint("TOPLEFT", p, "TOPLEFT", ESP.m, -(y + ESP.xs))
	y = y + ESP.xs + K.Parrafo(p.Nota, tw) + ESP.m
	p:SetSize(ancho, y)
	-- Al lado de la ventana: a la izquierda si cabe, si no a la derecha.
	p:SetScale(f:GetEffectiveScale() / max(0.01, UIParent:GetEffectiveScale()))
	p:ClearAllPoints()
	local izq = tonumber(f:GetLeft())
	if izq and izq > ancho + 12 then
		p:SetPoint("TOPRIGHT", f, "TOPLEFT", -8, 0)
	else
		p:SetPoint("TOPLEFT", f, "TOPRIGHT", 8, 0)
	end
	p:Show()
	return p
end

function Pv.Enganchar(f, boton)
	if not (boton and boton.HookScript) then return end
	boton:HookScript("OnEnter", function() Pv.Mostrar(f, boton) end)
	boton:HookScript("OnLeave", Pv.Ocultar)
	boton:HookScript("OnHide", Pv.Ocultar)
	if f.HookScript then f:HookScript("OnHide", Pv.Ocultar) end
end

-- Empezó a ordenar o entraste en combate: fuera.
M.Escuchar("ORDENAR", Pv.Ocultar)
A.RegisterEvent("PLAYER_REGEN_DISABLED", Pv.Ocultar)
