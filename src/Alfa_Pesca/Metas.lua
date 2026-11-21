-- Alfa - Pesca: las metas de pesca (toxic3000 / La Jauría). GPL-3.0.
--
-- Una ventanita del Kit, aparte de la barra, con tus metas y su avance:
--   * de un pez ("Pargo crudo 6/15"), de capturas, de lanzamientos, de tiempo
--     pescando o de valor;
--   * se agregan con el botón + (o desde el diario: "Ponerme una meta");
--   * cuentan aunque la ventana esté cerrada; al cumplir una sale un aviso;
--   * clic derecho en una: reiniciarla, quitarla o, si es de un pez, llevarla
--     a Mis planes (Alfa_Rutas, AlfaPlanes.AgregarObjeto).
-- Se abre sola con el modo pesca si tienes metas (ajuste metasVentana).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID
local E = M.E

local floor, max, min, format, type, pairs, ipairs, tonumber, tostring = math.floor, math.max, math.min, string.format, type, pairs, ipairs, tonumber, tostring
local ESP = K.ESP

local Me = {}
M.Metas = Me

local ANCHO, FILA = 264, 40

local function opt(k) return N.Get(ID, k) end

-- 1.3.7: «2 h» y «15 min», no «120:00» ni «2 h 00 min». sinSeg: lo que
-- llevas, sin los segundos (cabe en la cifra de la fila).
local function corto(seg, sinSeg)
	seg = floor(max(0, tonumber(seg) or 0))
	if sinSeg and seg >= 60 then seg = seg - seg % 60 end
	local t = N.Duracion(seg)
	t = t:gsub(" 00 min$", ""):gsub(" 00 s$", "")
	return t
end
M.DuracionCorta = corto

function M.TextoMeta(m)
	local o, h = tonumber(m.objetivo) or 0, tonumber(m.hecho) or 0
	if m.tipo == "pez" then return format(L["%s: %d de %d"], m.nombre or (M.V and M.V.NombreObjeto(m.item)) or "?", min(h, o), o) end
	if m.tipo == "capturas" then return format(L["Capturas: %d de %d"], min(h, o), o) end
	if m.tipo == "lanzamientos" then return format(L["Lanzamientos: %d de %d"], min(h, o), o) end
	if m.tipo == "tiempo" then return format(L["Pescar %s: llevas %s"], corto(o), corto(min(h, o), true)) end
	if m.tipo == "valor" then return format(L["Valor de %s: llevas %s"], N.DineroTexto(o, true), N.DineroTexto(min(h, o), true)) end
	return "?"
end

local function titulo(m)
	if m.tipo == "pez" then return m.nombre or (M.V and M.V.NombreObjeto(m.item)) or "?" end
	if m.tipo == "capturas" then return L["Capturas"] end
	if m.tipo == "lanzamientos" then return L["Lanzamientos"] end
	if m.tipo == "tiempo" then return L["Tiempo pescando"] end
	if m.tipo == "valor" then return L["Valor de lo pescado"] end
	return "?"
end

local function cifra(m)
	local o, h = tonumber(m.objetivo) or 0, tonumber(m.hecho) or 0
	if m.tipo == "tiempo" then return format("%s/%s", corto(min(h, o), true), corto(o)) end
	if m.tipo == "valor" then return format("%s/%s", N.DineroTexto(min(h, o), true), N.DineroTexto(o, true)) end
	return format("%d/%d", min(h, o), o)
end

---------------------------------------------------------------------------
-- Agregar una meta: el tipo y luego cuánto
---------------------------------------------------------------------------
local CUANTO = {
	capturas = { 10, 25, 50, 100, 200 },
	lanzamientos = { 25, 50, 100, 250 },
	tiempo = { 900, 1800, 3600, 7200 },
	valor = { 10000, 50000, 100000, 500000 },
	pez = { 5, 10, 15, 20, 50, 100 },
}

local function textoCuanto(tipo, n)
	if tipo == "tiempo" then return corto(n) end
	if tipo == "valor" then return N.DineroTexto(n, true) end
	return tostring(n)
end

local function elegirCuanto(dueno, tipo, item, nombre)
	local op = {}
	for _, n in ipairs(CUANTO[tipo]) do op[#op + 1] = { valor = n, texto = textoCuanto(tipo, n) } end
	A.After(0, function()
		K.Menu(dueno, op, nil, function(n)
			M.AgregarMeta({ tipo = tipo, item = item, nombre = nombre, objetivo = n })
			Me.Alternar(true)
		end, 200)
	end)
end

-- Los peces para elegir: los que más pescas y el catálogo de peces.
local function opcionesPez()
	local op, visto = {}, {}
	local t = {}
	for id, e in pairs(M.Diario()) do
		if type(e) == "table" and (tonumber(e.n) or 0) > 0 then t[#t + 1] = { id, e.n, e.nombre } end
	end
	table.sort(t, function(a, b) return a[2] > b[2] end)
	for i = 1, min(12, #t) do
		local id = t[i][1]
		visto[id] = true
		op[#op + 1] = { valor = id, texto = (type(id) == "number" and M.V and M.V.NombreObjeto(id)) or t[i][3] or tostring(id) }
	end
	if #op == 0 then
		for _, c in ipairs(M.CATALOGO) do
			if c.clase == "pez" and #op < 12 and not visto[c.id] then
				op[#op + 1] = { valor = c.id, texto = M.V and M.V.NombreObjeto(c.id) or tostring(c.id) }
			end
		end
	end
	return op
end

function Me.MenuAgregar(dueno)
	local op = {
		{ valor = "pez", texto = L["Pescar un pez en particular…"] },
		{ valor = "capturas", texto = L["Capturas"] },
		{ valor = "lanzamientos", texto = L["Lanzamientos"] },
		{ valor = "tiempo", texto = L["Tiempo pescando"] },
		{ valor = "valor", texto = L["Valor de lo pescado"] },
	}
	K.Menu(dueno, op, nil, function(tipo)
		if tipo == "pez" then
			A.After(0, function()
				K.Menu(dueno, opcionesPez(), nil, function(id, o)
					elegirCuanto(dueno, "pez", id, o and o.texto)
				end, 240)
			end)
		else
			elegirCuanto(dueno, tipo)
		end
	end, 220)
end

local function menuMeta(dueno, m)
	local op = {
		{ valor = "reiniciar", texto = L["Empezar de cero"] },
		{ valor = "quitar", texto = L["Quitar la meta"] },
	}
	local P = rawget(_G, "AlfaPlanes")
	if m.tipo == "pez" and type(m.item) == "number" and type(P) == "table" and type(P.AgregarObjeto) == "function" then
		op[#op + 1] = { separador = true }
		op[#op + 1] = { valor = "plan", texto = L["Llevarla a Mis planes"] }
	end
	K.Menu(dueno, op, nil, function(v)
		if v == "reiniciar" then M.ReiniciarMeta(m.uid)
		elseif v == "quitar" then M.QuitarMeta(m.uid)
		elseif v == "plan" and P then pcall(P.AgregarObjeto, m.item, m.objetivo) end
	end, 200)
end

---------------------------------------------------------------------------
-- La ventanita
---------------------------------------------------------------------------
local f

local function fila(i)
	local r = f.filas[i]
	if r then return r end
	r = CreateFrame("Button", nil, f)
	r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	r:SetHeight(FILA)
	r.Nombre = K.Texto(r, "etiqueta", "texto")
	r.Nombre:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -4)
	r.Cifra = K.Texto(r, "numero", "textoSuave")
	r.Cifra:SetJustifyH("RIGHT")
	r.Cifra:SetPoint("TOPRIGHT", r, "TOPRIGHT", 0, -4)
	r.Nombre:SetPoint("RIGHT", r.Cifra, "LEFT", -6, 0)
	r.Barra = K.Progreso(r, { alto = 4 })
	r.Barra:SetPoint("TOPLEFT", r, "TOPLEFT", 0, -24)
	r:SetScript("OnClick", function(self, boton)
		if self.alfaMeta and boton == "RightButton" then menuMeta(self, self.alfaMeta) end
	end)
	K.ConInfo(r, function(self) return self.alfaMeta and M.TextoMeta(self.alfaMeta) or nil, L["Clic derecho: reiniciar, quitar o llevar a Mis planes."] end)
	f.filas[i] = r
	return r
end

local function crear()
	f = CreateFrame("Frame", "AlfaPescaMetas", K.Raiz())
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetMovable(true)
	f:EnableMouse(true)
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", function(self) if not (A.DragLocked and A.DragLocked()) then self:StartMoving() end end)
	f:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, rp, x, y = self:GetPoint(1)
		if p then N.Datos(ID).metasLugar = { p, rp, floor(x + 0.5), floor(y + 0.5) } end
	end)
	f.caja = K.Caja(f, { fondo = "fondo", borde = "linea", corte = K.CORTE.panel, rol = "panel" })
	f.Marca = K.Marca(f, K.CORTE.panel)
	f.Icono = K.Icono(f, M.ICONO.meta, 14, "acento")
	f.Icono:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -ESP.m)
	f.Titulo = K.Texto(f, "encabezado", "texto")
	f.Titulo:SetPoint("LEFT", f.Icono, "RIGHT", ESP.s, 0)
	K.Escribir(f.Titulo, L["Metas de pesca"])
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() Me.Alternar(false) end, { tam = 22, icono = 10, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -6, -6)
	f.Mas = K.BotonIcono(f, "ic-mas", function(self) Me.MenuAgregar(self) end, { tam = 22, icono = 12, ayuda = L["Agregar una meta"] })
	f.Mas:SetPoint("RIGHT", f.Cerrar, "LEFT", -2, 0)
	f.Vacio = K.Texto(f, "nota", "textoTenue")
	f.filas = {}
	f:Hide()
	M.VISIBLES[#M.VISIBLES + 1] = f
	return f
end

function Me.Refrescar()
	if not (f and f:IsShown()) then return end
	local metas = M.MetasGuardadas()
	local y = ESP.m + 18 + ESP.s
	local ancho = ANCHO - 2 * ESP.m
	for i, m in ipairs(metas) do
		local r = fila(i)
		r.alfaMeta = m
		K.Escribir(r.Nombre, titulo(m))
		K.ColorTexto(r.Nombre, m.cumplida and "exito" or "texto")
		r.Cifra:SetText(cifra(m))
		K.ColorTexto(r.Cifra, m.cumplida and "exito" or "textoSuave")
		r.Barra:Set(tonumber(m.hecho) or 0, max(1, tonumber(m.objetivo) or 1))
		r.Barra:SetTono(m.cumplida and "exito" or "acento")
		r:ClearAllPoints()
		r:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -y)
		r:SetWidth(ancho)
		r.Barra:Acomodar(ancho)
		r:Show()
		y = y + FILA
	end
	for i = #metas + 1, #f.filas do f.filas[i]:Hide() end
	if #metas == 0 then
		K.Escribir(f.Vacio, L["Sin metas todavía. Pulsa + para ponerte una: un pez, capturas, tiempo o valor."])
		f.Vacio:ClearAllPoints()
		f.Vacio:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.m, -y)
		y = y + K.Parrafo(f.Vacio, ancho, 3) + ESP.s
		f.Vacio:Show()
	else
		f.Vacio:Hide()
	end
	f:SetSize(ANCHO, y + ESP.s)
end

function Me.Alternar(mostrar)
	if mostrar == nil then mostrar = not (f and f:IsShown()) end
	N.DatosPersonaje(ID).metasCerrada = (not mostrar) or nil
	if mostrar then
		f = f or crear()
		if not f:IsShown() then
			f:ClearAllPoints()
			local l = N.Datos(ID).metasLugar
			if type(l) == "table" and type(l[3]) == "number" then
				f:SetPoint(l[1], UIParent, l[2], l[3], l[4])
			else
				f:SetPoint("RIGHT", UIParent, "RIGHT", -60, 80)
			end
		end
		f:Show()
		Me.Refrescar()
	elseif f then
		f:Hide()
	end
end

function Me.Visible() return f ~= nil and f:IsShown() end
function Me.Marco() return f end

-- Con el modo pesca abierto y alguna meta, la ventanita se ve (si no la cerraste).
M.Escuchar(function(m)
	if m.modo or m.todo then
		local hay = #M.MetasGuardadas() > 0
		if E.modo and hay and opt("metasVentana") and not N.DatosPersonaje(ID).metasCerrada then
			Me.Alternar(true)
		elseif not E.modo and f and f:IsShown() and opt("metasVentana") then
			f:Hide()
		end
	end
	-- Solo con el modo pesca abierto (pescar con la tecla fija no la abre).
	if m.metas and E.modo and #M.MetasGuardadas() > 0 and not Me.Visible() and opt("metasVentana") and not N.DatosPersonaje(ID).metasCerrada then
		Me.Alternar(true)
	end
	Me.Refrescar()
end)
