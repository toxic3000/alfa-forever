-- Alfa - Inicio: los avisos del motor, con el Kit (Toxic / La Jauría). GPL-3.0.
--
-- Cuatro avisos del motor se muestran con piezas de Alfa (AlfaNucleo.Reemplazar,
-- tabla en docs/KIT.md). El motor sigue decidiendo cuándo; aquí solo se
-- dibujan, cortos, sin estorbar y con su acción. Las frases son de Alfa: del
-- motor solo se toman los datos.
--   WHILE_HERE   "Mientras estás aquí": un K.Aviso con "Llévame". Si el
--                rastreador de la ruta (AlfaRuta.RastreadorVisible) ya lo
--                muestra, no sale.
--   CLASS_TOAST  tu misión de clase: la tarjeta de aviso (M.Aviso) con "Abrir
--                su guía" o "Llévame", y "Ahora no".
--   UPDATE_CARD  hay una versión nueva: la tarjeta de aviso con "Entendido".
--   LEVEL_TIP    lo que una ruta te da en niveles, al pasar el ratón por su
--                ficha: un panel del Kit con la barra por niveles.
-- La tarjeta del motor espera su turno: al irse la de Alfa se llama a su
-- Cerrar(), y el motor deja pasar la siguiente.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = N.Textos(M.EN)
local Aviso = M.Aviso
local miles = M.miles

local floor, max, min, format, ipairs, type, pcall = math.floor, math.max, math.min, string.format, ipairs, type, pcall
local DOT = "  \194\183  "

local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a = pcall(fn, ...)
	if ok then return a end
	return nil
end

local function ruta() return rawget(_G, "AlfaRuta") end

---------------------------------------------------------------------------
-- Mientras estás aquí
---------------------------------------------------------------------------
local aqui = { aviso = nil, turno = nil }

local function avisoVivo()
	local a = aqui.aviso
	return a and a.alfaVivo and a.alfaTurno == aqui.turno and a or nil
end

local function cerrarAqui()
	local a = avisoVivo()
	aqui.aviso, aqui.turno = nil, nil
	if a and a.Cerrar and a.Cerrar.Click then a.Cerrar:Click() end
end

local function rastreadorLoMuestra()
	local R = ruta()
	return type(R) == "table" and llamar(R.RastreadorVisible) == true
end

N.Reemplazar("WHILE_HERE", function(p)
	if p.accion == "ocultar" then
		cerrarAqui()
		return
	end
	if p.accion == "actualizar" then
		local a = avisoVivo()
		if a and type(p.texto) == "string" then K.Escribir(a.Texto, p.texto) end
		return
	end
	if rastreadorLoMuestra() or (A.Hidden and A.Hidden()) then return end
	local guiar = p.Guiar
	local a = K.Aviso({
		titulo = L["Mientras estás aquí"], texto = p.texto, icono = "ic-huella", tono = "acento", duracion = 8,
		accion = { texto = L["Llévame"], alClic = function() llamar(guiar) end },
	})
	aqui.aviso, aqui.turno = a, a and a.alfaTurno
end, function() return avisoVivo() ~= nil end)

---------------------------------------------------------------------------
-- La misión de clase y la versión nueva
---------------------------------------------------------------------------

-- El nombre de la recompensa: hechizo u objeto, como lo dice el cliente;
-- varios a elegir, unidos con "o".
local function nombreRecompensa(r)
	if type(r) ~= "table" then return nil end
	local CC = A.UI and A.UI.ClassCard
	if r.items and r.choice and #r.items > 1 then
		local nombres = {}
		for i, id in ipairs(r.items) do
			local n = C_Item and C_Item.GetItemNameByID and llamar(C_Item.GetItemNameByID, id)
			n = type(n) == "string" and n ~= "" and n or (r.itemNames and r.itemNames[i])
			if type(n) == "string" then nombres[#nombres + 1] = n end
		end
		if #nombres > 1 then
			local ultimo = table.remove(nombres)
			return format(L["%s o %s"], table.concat(nombres, ", "), ultimo)
		end
		return nombres[1]
	end
	local n = CC and llamar(CC.RewardName, r)
	return type(n) == "string" and n ~= "" and n or nil
end

local function misionDeClase(p, m)
	local UI = A.UI or {}
	local recompensa = nombreRecompensa(m.reward)
	local clase = llamar(UI.ClassName, m.class)
	local partes = {}
	if type(m.level) == "number" then partes[#partes + 1] = format(L["Nivel %d"], m.level) end
	if type(clase) == "string" and clase ~= "" then partes[#partes + 1] = clase end
	local donde = m.map and llamar(UI.MapName, m.map)
	local texto
	if type(m.who) == "string" and m.who ~= "" then
		texto = type(donde) == "string" and format(L["Te la da %s, en %s."], m.who, donde) or format(L["Te la da %s."], m.who)
	end
	if m.step then texto = (texto and (texto .. " ") or "") .. L["Tu ruta pasa por ahí."] end
	local botones = {}
	if m.guideId then
		botones[1] = { texto = L["Abrir su guía"], fn = p.Abrir }
	elseif m.map and m.x and m.y then
		botones[1] = { texto = L["Llévame"], fn = p.Mostrarme }
	end
	botones[#botones + 1] = { texto = L["Ahora no"], fn = p.Despues }
	return {
		tipo = "info", textura = m.icon, icono = "ic-misiones",
		titulo = recompensa and format(L["Misión de clase: %s"], recompensa) or L["Tienes una misión de clase"],
		linea = #partes > 0 and table.concat(partes, DOT) or nil,
		texto = texto, botones = botones, segundos = 20,
	}
end

local function actualizacion(p, m)
	local U = A.Update
	local n = U and llamar(U.Notice)
	local s = { tipo = "info", lobo = "atento", segundos = 16,
		texto = L["Actualízala con la app de CurseForge o con el zip más reciente y luego usa /reload."],
		botones = { { texto = L["Entendido"], fn = p.Despues } } }
	if type(n) == "table" and n.kind == "old" then
		s.titulo = L["Busca una versión nueva de Alfa"]
		s.linea = type(n.weeks) == "number" and format(L["La tuya tiene %d semanas: salen seguido."], n.weeks) or nil
	else
		local nueva = type(n) == "table" and n.latest or (m.update ~= "old" and m.update) or nil
		s.titulo = nueva and format(L["Ya salió Alfa %s"], tostring(nueva)) or L["Ya salió una versión nueva de Alfa"]
		if type(n) == "table" and n.mine then
			s.linea = (tonumber(n.behind) or 0) >= 2 and format(L["Tienes la %s, %d versiones atrás."], tostring(n.mine), n.behind)
				or format(L["Tienes la %s."], tostring(n.mine))
		end
	end
	return s
end

local function tarjetaDelMotor(p)
	local clave = "motor:" .. tostring(p.tipo)
	if p.accion == "ocultar" then
		Aviso.Quitar(clave)
		return
	end
	local m = type(p.modelo) == "table" and p.modelo or {}
	local spec = p.tipo == "UPDATE_CARD" and actualizacion(p, m) or misionDeClase(p, m)
	spec.clave = clave
	spec.alCerrar = p.Cerrar
	Aviso.Mostrar(spec)
end

local function tarjetaVisible(tipo)
	return function() return Aviso.Visible() == "motor:" .. tipo end
end

N.Reemplazar("CLASS_TOAST", tarjetaDelMotor, tarjetaVisible("CLASS_TOAST"))
N.Reemplazar("UPDATE_CARD", tarjetaDelMotor, tarjetaVisible("UPDATE_CARD"))

---------------------------------------------------------------------------
-- Lo que una ruta te da en niveles (la ficha de niveles)
---------------------------------------------------------------------------
local ANCHO_TIP, PAD_TIP, CELDAS = 300, 14, 6
local tip

local function armarTip()
	local t = CreateFrame("Frame", nil, K.Raiz())
	t:SetFrameStrata("TOOLTIP")
	t:SetClampedToScreen(true)
	t:SetWidth(ANCHO_TIP)
	t.caja = K.Caja(t, { fondo = "panel", borde = "lineaFuerte", corte = K.CORTE.control })
	t.Marca = K.Marca(t, K.CORTE.control, "acento")
	t.Sobre = K.Texto(t, "mayus", "acento")
	t.Necesita = K.Texto(t, "nota", "aviso")
	t.Niveles = K.Texto(t, "cifra", "acento")
	t.XP = K.Texto(t, "numero", "textoSuave")
	t.XP:SetJustifyH("RIGHT")
	t.Barra = CreateFrame("Frame", nil, t)
	t.Barra:SetHeight(10)
	t.Celdas, t.Marcas = {}, {}
	for i = 1, CELDAS do
		local c = CreateFrame("Frame", nil, t.Barra)
		c:SetHeight(10)
		c.Pista = K.Plano(c, "hundido", "BACKGROUND", 0)
		c.Pista:SetAllPoints(c)
		c.Hecho = K.Plano(c, "textoTenue", "ARTWORK", 0)
		c.Hecho:SetPoint("TOPLEFT", c, "TOPLEFT", 0, 0)
		c.Hecho:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 0)
		c.Gana = K.Plano(c, "acento", "ARTWORK", 1)
		t.Celdas[i] = c
	end
	for i = 1, CELDAS + 1 do t.Marcas[i] = K.Texto(t, "pequeno", "textoTenue") end
	t.Ahora = K.Texto(t, "pequeno", "textoSuave")
	t.Despues = K.Texto(t, "pequeno", "texto")
	t.Linea = K.Linea(t, "linea")
	t.Notas = K.Texto(t, "nota", "textoTenue")
	t:Hide()
	return t
end

local function pct(x) return x.need and x.need > 0 and floor((x.xp or 0) / x.need * 100) or 0 end

local function textoNiveles(n)
	n = tonumber(n) or 0
	if n >= 0.995 then
		local s = format("%.1f", n)
		if N.espanol then s = s:gsub("%.", ",") end
		return format(L["+%s niveles"], s)
	end
	return format(L["+%d %% de un nivel"], max(1, floor(n * 100 + 0.5)))
end

local function notas(s)
	local t = { (s.quests or 0) == 1 and L["1 misión que aún no haces."] or format(L["%d misiones que aún no haces."], s.quests or 0) }
	if (s.kills or 0) > 0 then
		t[#t + 1] = format(L["%s XP de misiones y unos %s de %d enemigos que pide la guía."], miles(s.questXP or 0), miles(s.killXP or 0), s.kills)
	end
	if (s.killsUnknown or 0) > 0 then
		t[#t + 1] = s.killsUnknown == 1 and L["1 meta de caza o botín sin calcular."] or format(L["%d metas de caza o botín sin calcular."], s.killsUnknown)
	end
	if (s.reduced or 0) > 0 then
		t[#t + 1] = s.reduced == 1 and L["1 da menos XP: para entonces le sacas 6 niveles o más."] or format(L["%d dan menos XP: para entonces les sacas 6 niveles o más."], s.reduced)
	end
	if (s.unknown or 0) > 0 then
		t[#t + 1] = s.unknown == 1 and L["1 más sin XP conocida: no cuenta."] or format(L["%d más sin XP conocida: no cuentan."], s.unknown)
	end
	if (s.done or 0) > 0 then t[#t + 1] = L["Las que ya hiciste no cuentan."] end
	return table.concat(t, "\n")
end

local function pintarCeldas(t, s, ancho)
	local MAXN = (A.Levels and A.Levels.MAX_LEVEL) or 60
	local desde = s.from.level
	local hasta = min(s.to.level, MAXN - 1, desde + CELDAS - 1)
	local n = max(1, hasta - desde + 1)
	local gap = 3
	local cw = (ancho - gap * (n - 1)) / n
	for i, c in ipairs(t.Celdas) do
		if i > n then
			c:Hide()
		else
			local nivel = desde + i - 1
			local a = i == 1 and (s.from.need > 0 and s.from.xp / s.from.need or 0) or 0
			local b = 1
			if nivel == s.to.level then b = s.to.need > 0 and s.to.xp / s.to.need or 0 end
			c:ClearAllPoints()
			c:SetPoint("TOPLEFT", t.Barra, "TOPLEFT", (i - 1) * (cw + gap), 0)
			c:SetWidth(cw)
			c.Hecho:SetWidth(max(0.01, cw * a))
			c.Hecho:SetShown(a > 0)
			c.Gana:ClearAllPoints()
			c.Gana:SetPoint("TOPLEFT", c, "TOPLEFT", cw * a, 0)
			c.Gana:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", cw * a, 0)
			c.Gana:SetWidth(max(0.01, cw * (b - a)))
			c.Gana:SetShown(b > a)
			c:Show()
		end
	end
	for i, m in ipairs(t.Marcas) do
		if i > n + 1 then
			m:Hide()
		else
			m:SetText(tostring(desde + i - 1))
			m:ClearAllPoints()
			if i == n + 1 then
				m:SetPoint("TOPRIGHT", t.Barra, "BOTTOMRIGHT", 0, -4)
			else
				m:SetPoint("TOPLEFT", t.Barra, "BOTTOMLEFT", (i - 1) * (cw + gap), -4)
			end
			m:Show()
		end
	end
	return K.AltoTexto(t.Marcas[1])
end

local function acomodarTip(t, s)
	local MAXN = (A.Levels and A.Levels.MAX_LEVEL) or 60
	local ancho = ANCHO_TIP
	local dentro = ancho - 2 * PAD_TIP
	t:SetWidth(ancho)
	local y = PAD_TIP
	K.Escribir(t.Sobre, L["Si la terminas"]:upper())
	t.Sobre:ClearAllPoints()
	t.Sobre:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	y = y + K.AltoTexto(t.Sobre) + 6
	t.Necesita:SetShown(s.below ~= nil)
	if s.below then
		K.Escribir(t.Necesita, format(L["Eres nivel %d y se recomienda el %d: desde ahí cuenta así."], (s.now and s.now.level) or 0, s.below))
		t.Necesita:ClearAllPoints()
		t.Necesita:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
		y = y + K.Parrafo(t.Necesita, dentro, 3) + 8
	end
	K.Escribir(t.Niveles, textoNiveles(s.levels))
	K.Escribir(t.XP, format(L["%s XP"], miles(s.xp or 0)))
	t.Niveles:ClearAllPoints()
	t.Niveles:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	t.XP:ClearAllPoints()
	t.XP:SetPoint("BOTTOMRIGHT", t.Niveles, "BOTTOMRIGHT", 0, 0)
	t.XP:SetPoint("RIGHT", t, "RIGHT", -PAD_TIP, 0)
	y = y + K.AltoTexto(t.Niveles) + 10
	t.Barra:ClearAllPoints()
	t.Barra:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	t.Barra:SetWidth(dentro)
	local hm = pintarCeldas(t, s, dentro)
	y = y + 10 + 4 + hm + 10
	K.Escribir(t.Ahora, s.below and format(L["Empiezas: nivel %d"], s.below) or format(L["Ahora: %d %% del nivel %d"], pct(s.from), s.from.level))
	K.Escribir(t.Despues, s.to.level >= MAXN and format(L["Después: nivel %d"], s.to.level) or format(L["Después: %d %% del nivel %d"], pct(s.to), s.to.level))
	t.Ahora:ClearAllPoints()
	t.Ahora:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	y = y + K.AltoTexto(t.Ahora) + 2
	t.Despues:ClearAllPoints()
	t.Despues:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	y = y + K.AltoTexto(t.Despues) + 10
	t.Linea:ClearAllPoints()
	t.Linea:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	t.Linea:SetPoint("TOPRIGHT", t, "TOPRIGHT", -PAD_TIP, -y)
	y = y + 10
	K.Escribir(t.Notas, notas(s))
	t.Notas:ClearAllPoints()
	t.Notas:SetPoint("TOPLEFT", t, "TOPLEFT", PAD_TIP, -y)
	y = y + K.Parrafo(t.Notas, dentro, 8) + PAD_TIP
	t:SetHeight(floor(y + 0.5))
end

N.Reemplazar("LEVEL_TIP", function(p)
	if p.accion == "ocultar" then
		if tip then tip:Hide() end
		return
	end
	local chip, s = p.chip, p.resumen
	if not (chip and type(s) == "table" and type(s.from) == "table" and type(s.to) == "table") then return end
	tip = tip or armarTip()
	tip:SetParent(chip.psHost or K.Raiz())
	tip:SetFrameStrata("TOOLTIP")
	acomodarTip(tip, s)
	tip:ClearAllPoints()
	tip:SetPoint("TOPLEFT", chip, "BOTTOMLEFT", chip.psTipX or 0, -8)
	tip:Show()
end, function() return tip ~= nil and tip:IsShown() end)
