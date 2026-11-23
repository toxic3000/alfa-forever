-- Alfa - Combate: el detalle de un compañero en el medidor (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.7 (tercera vuelta). Un clic izquierdo sobre la barra de alguien en la
-- gráfica del medidor abre a su lado una tarjeta pequeña con su pelea: su
-- daño (o curación) y por segundo, su parte del grupo y sus hechizos que más
-- pegaron (o curaron), cada uno con su ícono, su barra y su porcentaje.
--   * Se lee del medidor oficial del juego con
--     C_DamageMeter.GetCombatSessionSourceFromType / FromID (su GUID), igual
--     que el resumen de tu pelea (Resumen.lua). Solo fuera de combate: en
--     combate la gráfica no recibe clics y los números llegan secretos; si
--     empieza una pelea con la tarjeta abierta, se cierra.
--   * Lo secreto (nombres dentro de mazmorras) no se lee: la tarjeta lo dice.
--   * Otro clic en la misma barra, su X o esconder el medidor la cierran.
--   * Solo lee: no anuncia nada ni toca nada del juego.

local ADDON, M = ...
local N, A, K, L = M.N, M.A, M.K, M.L
local D = M.Medidor
local Dt = {}
M.Detalle = Dt

local type, ipairs, pcall, floor, max, min, format, tostring = type, ipairs, pcall, math.floor, math.max, math.min, string.format, tostring
local ESP = K.ESP

Dt.ANCHO = 236
Dt.TOPE = 6 -- hechizos a la vista
local ANCHO, FILA, ICONO = Dt.ANCHO, 18, 14

local function numero(v)
	if M.Secreto(v) or type(v) ~= "number" then return nil end
	return v
end

local function enumTipo(nombre, num)
	local E = Enum and Enum.DamageMeterType
	return E and type(E[nombre]) == "number" and E[nombre] or num
end

local function enumSesion(clave)
	local E = Enum and Enum.DamageMeterSessionType
	if clave == "todo" then return E and E.Overall or 0 end
	return E and E.Current or 1
end

---------------------------------------------------------------------------
-- Leer su detalle
---------------------------------------------------------------------------
-- x: una fila de D.Leer (con guid/criatura); r: su lectura.
-- -> { ok, motivo, nombre, clase, valor, porSeg, parte, hechizos = { { id, nombre, icono, valor, frac } }, total }
function Dt.Leer(x, r)
	local out = { hechizos = {} }
	if type(x) ~= "table" or type(r) ~= "table" then out.motivo = L["No hay nada que mostrar."] return out end
	if M.EnCombate() then out.motivo = L["El detalle se ve al salir de combate."] return out end
	if M.Secreto(x.nombre) or M.Secreto(x.valor) or M.Secreto(x.porSeg) or r.secreto then
		out.motivo = L["El juego todavía oculta los números de esta pelea. Inténtalo en un momento."]
		return out
	end
	out.nombre = type(x.nombre) == "string" and (x.nombre:gsub("%-.*$", "")) or "?"
	out.clase, out.valor, out.porSeg, out.yo = x.clase, numero(x.valor), numero(x.porSeg), x.yo
	local total = numero(r.total)
	if total and total > 0 and out.valor and (r.cuantos or 0) > 1 then out.parte = out.valor / total end
	local t = r.tipo or D.Tipo("dps")
	out.curacion = t.curacion and true or false
	local guid = x.guid
	if M.Secreto(guid) then guid = nil end
	local criatura = numero(x.criatura)
	if not (D.Existe() and (type(guid) == "string" or criatura)) then
		out.motivo = L["El juego no da el detalle de este compañero."]
		return out
	end
	local tipo = t.curacion and enumTipo("HealingDone", 2) or enumTipo("DamageDone", 0)
	local s
	if r.sesion == "anterior" then
		local ant = D.Anterior()
		local fn = C_DamageMeter.GetCombatSessionSourceFromID
		if ant and type(fn) == "function" then s = M.Llamar(fn, ant.id, tipo, guid, criatura) end
	else
		local fn = C_DamageMeter.GetCombatSessionSourceFromType
		if type(fn) == "function" then s = M.Llamar(fn, enumSesion(r.sesion), tipo, guid, criatura) end
	end
	local lista = type(s) == "table" and not M.Secreto(s) and s.combatSpells
	if type(lista) ~= "table" or M.Secreto(lista) then
		out.ok = true
		return out
	end
	local suma, tope = 0, 0
	local todos = {}
	for _, h in ipairs(lista) do
		local v = type(h) == "table" and numero(h.totalAmount)
		if v and v > 0 then
			local id = numero(h.spellID)
			todos[#todos + 1] = { id = id, valor = v,
				nombre = id and id > 0 and M.NombreHechizo(id) or (t.curacion and L["Otras curas"] or L["Golpes cuerpo a cuerpo"]),
				icono = id and id > 0 and M.IconoHechizo(id) or nil }
			suma = suma + v
			if v > tope then tope = v end
		end
	end
	table.sort(todos, function(a, b) return a.valor > b.valor end)
	for i = 1, min(Dt.TOPE, #todos) do
		local h = todos[i]
		h.frac = suma > 0 and h.valor / suma or 0
		h.barra = tope > 0 and h.valor / tope or 0
		out.hechizos[#out.hechizos + 1] = h
	end
	out.otros = max(0, #todos - Dt.TOPE)
	out.total = suma
	out.ok = true
	return out
end

---------------------------------------------------------------------------
-- La tarjeta
---------------------------------------------------------------------------
local f
local abiertoDe -- la fila de la gráfica cuyo detalle se ve

local function crear()
	if f then return f end
	f = CreateFrame("Frame", "AlfaCombateDetalle", K.Raiz())
	f:SetFrameStrata("MEDIUM")
	f:SetClampedToScreen(true)
	f:SetSize(ANCHO, 80)
	f:EnableMouse(true)
	f.caja = K.Caja(f, { fondo = "fondo", alfaFondo = 0.92, borde = "linea", corte = K.CORTE.chico })
	f.Franja = f:CreateTexture(nil, "ARTWORK")
	f.Franja:SetTexture("Interface\\Buttons\\WHITE8X8")
	f.Franja:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
	f.Franja:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 1, 1)
	f.Franja:SetWidth(2)
	f.Nombre = K.Texto(f, "etiqueta", "texto")
	f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", ESP.s + 4, -ESP.s)
	f.Nombre:SetPoint("RIGHT", f, "RIGHT", -24, 0)
	f.Nombre:SetJustifyH("LEFT")
	f.Cerrar = K.BotonIcono(f, "ic-cerrar", function() Dt.Cerrar() end, { tam = 16, icono = 9, ayuda = L["Cerrar"] })
	f.Cerrar:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
	f.Linea = K.Texto(f, "pequeno", "textoSuave")
	f.Linea:SetJustifyH("LEFT")
	f.ParteTexto = K.Texto(f, "pequeno", "textoTenue")
	f.ParteTexto:SetJustifyH("LEFT")
	f.Parte = K.Progreso(f, { alto = 3 })
	f.Nota = K.Texto(f, "pequeno", "textoTenue")
	f.Nota:SetJustifyH("LEFT")
	f.filas = {}
	f:SetScript("OnHide", function() abiertoDe = nil end)
	f:Hide()
	return f
end

local function fila(i)
	local x = f.filas[i]
	if x then return x end
	x = CreateFrame("Frame", nil, f)
	x:SetHeight(FILA)
	x.Icono = x:CreateTexture(nil, "ARTWORK")
	x.Icono:SetSize(ICONO, ICONO)
	x.Icono:SetPoint("LEFT", x, "LEFT", 0, 0)
	x.Icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	x.Barra = K.Progreso(x, { alto = 2, tono = "acento" })
	x.Barra:SetPoint("BOTTOMLEFT", x, "BOTTOMLEFT", ICONO + 4, 0)
	x.Pct = K.Texto(x, "pequeno", "textoSuave")
	x.Pct:SetJustifyH("RIGHT")
	x.Pct:SetPoint("RIGHT", x, "RIGHT", 0, 1)
	x.Pct:SetWidth(32)
	x.Valor = K.Texto(x, "pequeno", "texto")
	x.Valor:SetJustifyH("RIGHT")
	x.Valor:SetPoint("RIGHT", x.Pct, "LEFT", -2, 0)
	x.Nombre = K.Texto(x, "pequeno", "texto")
	x.Nombre:SetJustifyH("LEFT")
	x.Nombre:SetWordWrap(false)
	x.Nombre:SetPoint("LEFT", x.Icono, "RIGHT", 4, 1)
	x.Nombre:SetPoint("RIGHT", x.Valor, "LEFT", -4, 0)
	f.filas[i] = x
	return x
end

local function pct(fr) return format("%d %%", floor((fr or 0) * 100 + 0.5)) end

-- Junto a la gráfica: a su izquierda; si no cabe, a su derecha.
local function colocar(med)
	f:ClearAllPoints()
	if not med then f:SetPoint("CENTER", UIParent, "CENTER", 0, 0) return end
	local izq = med.GetLeft and med:GetLeft()
	if type(izq) == "number" and not M.Secreto(izq) and izq < ANCHO + 12 then
		f:SetPoint("BOTTOMLEFT", med, "BOTTOMRIGHT", 6, 0)
	else
		f:SetPoint("BOTTOMRIGHT", med, "BOTTOMLEFT", -6, 0)
	end
end

function Dt.Pintar(d, med)
	crear()
	local w = ANCHO - 2 * ESP.s - 4
	local x0 = ESP.s + 4
	-- El nombre con el color de su clase y la franja del mismo color.
	local cr, cg, cb = D.Color(d.clase)
	f.Franja:SetVertexColor(cr, cg, cb, 0.9)
	K.Escribir(f.Nombre, d.nombre or L["Compañero"])
	f.Nombre:SetTextColor(cr, cg, cb, 1)
	local y = ESP.s + K.Tamano("etiqueta") + 6
	-- «Daño 15.2 k · 184 por s · 32 % del grupo»
	local partes = {}
	if d.valor then partes[#partes + 1] = format("%s %s", d.curacion and L["Curación"] or L["Daño"], D.Numero(d.valor)) end
	if d.porSeg then partes[#partes + 1] = format(L["%s por s"], D.Numero(d.porSeg)) end
	if #partes > 0 then
		K.Escribir(f.Linea, table.concat(partes, "  \194\183  "))
		f.Linea:ClearAllPoints()
		f.Linea:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y)
		y = y + K.Parrafo(f.Linea, w, 2) + 3
		f.Linea:Show()
	else
		f.Linea:Hide()
	end
	if d.parte then
		K.Escribir(f.ParteTexto, format(d.curacion and L["%s de la curación del grupo"] or L["%s del daño del grupo"], pct(d.parte)))
		f.ParteTexto:ClearAllPoints()
		f.ParteTexto:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y)
		y = y + K.Parrafo(f.ParteTexto, w, 2) + 2
		f.ParteTexto:Show()
		f.Parte:ClearAllPoints()
		f.Parte:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y)
		f.Parte:Acomodar(w)
		f.Parte:Set(d.parte)
		f.Parte:SetTono(d.yo and "acento" or "neutro")
		f.Parte:Show()
		y = y + 3 + ESP.s
	else
		f.Parte:Hide()
		f.ParteTexto:Hide()
		y = y + 2
	end
	local n = #d.hechizos
	for i = 1, n do
		local h, x = d.hechizos[i], fila(i)
		x:ClearAllPoints()
		x:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -y)
		x:SetWidth(w)
		if h.icono then x.Icono:SetTexture(h.icono) else x.Icono:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark") end
		K.Escribir(x.Nombre, h.nombre or "?")
		x.Valor:SetText(D.Numero(h.valor))
		x.Pct:SetText(pct(h.frac))
		x.Barra:Acomodar(w - ICONO - 4)
		x.Barra:Set(h.barra or 0)
		x:Show()
		y = y + FILA + 2
	end
	for i = n + 1, #f.filas do f.filas[i]:Hide() end
	local nota = d.motivo
	if not nota and n == 0 then nota = L["El juego no guardó el detalle de sus hechizos en esta pelea."] end
	if not nota and (d.otros or 0) > 0 then nota = N.Plural(d.otros, L["y %d hechizo más"], L["y %d hechizos más"]) end
	if nota then
		K.Escribir(f.Nota, nota)
		f.Nota:ClearAllPoints()
		f.Nota:SetPoint("TOPLEFT", f, "TOPLEFT", x0, -(y + 1))
		y = y + 1 + K.Parrafo(f.Nota, w, 3) + 2
		f.Nota:Show()
	else
		f.Nota:Hide()
	end
	f:SetHeight(floor(y + ESP.s + 0.5))
	colocar(med)
	f:Show()
	return f
end

-- Desde una fila de la gráfica (Ventana.lua): abre su detalle, o lo cierra si ya era el suyo.
function Dt.Alternar(filaMarco, med)
	if not filaMarco then return end
	if f and f:IsShown() and abiertoDe == filaMarco and f.alfaPos == (filaMarco.alfaDato and filaMarco.alfaDato.pos) then
		Dt.Cerrar()
		return
	end
	local d = Dt.Leer(filaMarco.alfaDato, filaMarco.alfaLectura)
	Dt.Pintar(d, med)
	abiertoDe = filaMarco
	f.alfaPos = filaMarco.alfaDato and filaMarco.alfaDato.pos
	return d
end

function Dt.Cerrar()
	if f then f:Hide() end
	abiertoDe = nil
end

function Dt.Abierto() return f ~= nil and f:IsShown() end
function Dt.Marco() return f end
