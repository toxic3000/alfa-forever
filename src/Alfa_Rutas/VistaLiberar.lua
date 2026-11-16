-- Alfa - Rutas: la pestaña "Liberar misiones". Tus misiones abiertas, cada
-- una con lo que falta y si vale la pena (gris, muy lejos, de grupo, de
-- mazmorra, fallida); marcas cuáles dejar fuera o abandonar, y Alfa arma
-- una guía con el orden más corto para terminarlas y entregarlas.
-- Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local W, Th, K = M.W, M.T, M.Kit
local P, I = M.Plan, M.Indice
local VL = {}
M.VistaLiberar = VL

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local floor, max, min, format, concat = math.floor, math.max, math.min, string.format, table.concat
local num = M.num

local c
local ui = {}
local est = { lista = nil, cargando = false, motivo = nil }

local function marcas() return M.Personaje().marcas end

local function cuentas()
	local listas, faltan, malas, abandonar, dentro = 0, 0, 0, 0, 0
	local m = marcas()
	for _, it in ipairs(est.lista or {}) do
		if it.listo then listas = listas + 1 else faltan = faltan + 1 end
		if it.sugerencia == "abandonar" then malas = malas + 1 end
		if m[it.id] == "abandonar" then abandonar = abandonar + 1 end
		if not m[it.id] and it.pm then dentro = dentro + 1 end
	end
	return listas, faltan, malas, abandonar, dentro
end

function VL.Cargar()
	if est.cargando then return end
	est.cargando, est.motivo = true, nil
	P.Registro(function(lista, motivo)
		est.cargando = false
		est.lista = lista
		est.motivo = not lista and motivo or nil
		VL.Refrescar()
	end)
	VL.Refrescar()
end

-- Las que no valen la pena quedan marcadas para abandonar; las de mazmorra
-- o de grupo, fuera de la ruta.
local function marcarSugeridas()
	local m = marcas()
	local n = 0
	for _, it in ipairs(est.lista or {}) do
		if it.sugerencia and not m[it.id] then
			m[it.id] = it.sugerencia
			n = n + 1
		end
	end
	K.Aviso(n > 0 and format(L["Marqué %d misiones. Revisa la lista antes de abandonar."], n) or L["No encontré misiones que convenga dejar."])
	VL.Refrescar()
end

local function abandonarMarcadas()
	local ids, nombres = {}, {}
	local m = marcas()
	for _, it in ipairs(est.lista or {}) do
		if m[it.id] == "abandonar" then
			ids[#ids + 1] = it.id
			if #nombres < 8 then nombres[#nombres + 1] = "\194\183 " .. (it.titulo or "") end
		end
	end
	if #ids == 0 then
		K.Aviso(L["No marcaste misiones para abandonar: toca la X de una misión."])
		return
	end
	if #ids > #nombres then nombres[#nombres + 1] = format(L["y %d más"], #ids - #nombres) end
	W.Modal({
		title = format(#ids == 1 and L["¿Abandonar %d misión?"] or L["¿Abandonar %d misiones?"], #ids),
		icon = "close", danger = true, action = L["Abandonar"],
		text = concat(nombres, "\n") .. "\n\n" .. L["Salen de tu registro. Para hacerlas otra vez tendrías que volver a pedirlas."],
		onAccept = function()
			local n = P.Abandonar(ids)
			K.Aviso(format(L["Abandonaste %d misiones."], n))
			A.After(0.8, VL.Cargar)
		end,
	})
end

local function armarRuta()
	if not est.lista then return VL.Cargar() end
	P.Liberar(est.lista, function(def, motivo)
		if not def then
			K.Aviso(motivo == "nada" and L["No queda ninguna misión en la ruta: quita algunas marcas."] or L["No pude armar la ruta para tus misiones."])
			return
		end
		local ok, err = M.Guias.Instalar(def)
		if not ok then
			K.Aviso(format(L["El motor no aceptó la guía: %s"], tostring(err)))
			return
		end
		local i, por = M.Guias.Abrir(def.id)
		if i then
			K.Aviso(L["Listo: sigue la flecha para terminar y entregar tus misiones."])
			local win = M.Ventana and M.Ventana()
			if win and win.Hide then win:Hide() end
		else
			K.Aviso(por == "tabs" and L["Tienes 6 guías abiertas: cierra una pestaña para abrir la ruta."] or L["La ruta quedó en el menú de guías, en Mis rutas."])
		end
	end)
end
VL.ArmarRuta = armarRuta

---------------------------------------------------------------------------
-- Filas
---------------------------------------------------------------------------

local function fila(lista)
	local b = K.Fila(lista)
	b.Caja = W.Checkbox(b, function(self)
		local it = b.indice and est.lista and est.lista[b.indice]
		if not it then return end
		local m = marcas()
		if self:GetChecked() then m[it.id] = nil else m[it.id] = "fuera" end
		VL.Refrescar()
	end)
	b.Caja:SetPoint("LEFT", b, "LEFT", 8, 0)
	b.Caja.psTip = L["En la ruta"]
	b.Caja:SetScript("OnEnter", W.SimpleTip)
	b.Caja:SetScript("OnLeave", W.HideTip)
	b.Nivel = K.Texto(b, "number", "text")
	b.Nivel:SetPoint("LEFT", b, "LEFT", 32, 0)
	b.Nivel:SetWidth(24)
	b.Nivel:SetJustifyH("CENTER")
	b.Quitar = W.IconButton(b, "close", 22, L["Marcar para abandonar"], function()
		local it = b.indice and est.lista and est.lista[b.indice]
		if not it then return end
		local m = marcas()
		m[it.id] = m[it.id] ~= "abandonar" and "abandonar" or nil
		VL.Refrescar()
	end, 11)
	b.Quitar:SetPoint("RIGHT", b, "RIGHT", -6, 0)
	b.Lejos = K.Texto(b, "small", "textMuted")
	b.Lejos:SetPoint("RIGHT", b.Quitar, "LEFT", -8, 0)
	b.Lejos:SetJustifyH("RIGHT")
	b.Titulo = K.Texto(b, "body", "text")
	b.Titulo:SetPoint("TOPLEFT", b, "TOPLEFT", 62, -5)
	b.Titulo:SetPoint("RIGHT", b.Lejos, "LEFT", -8, 0)
	b.Estado = K.Texto(b, "small", "textDim")
	b.Estado:SetPoint("TOPLEFT", b.Titulo, "BOTTOMLEFT", 0, -3)
	b.Estado:SetPoint("RIGHT", b.Lejos, "LEFT", -8, 0)
	b:SetScript("OnClick", function(self)
		local it = self.indice and est.lista and est.lista[self.indice]
		local Lk = M.Motor("Lookup")
		if it and Lk and Lk.Show then Lk.Show(nil, "quest", it.id) end
	end)
	b:SetScript("OnEnter", function(self)
		local it = self.indice and est.lista and est.lista[self.indice]
		if not it then return end
		local lineas = {}
		if #it.razones > 0 then lineas[#lineas + 1] = concat(it.razones, ", ") end
		lineas[#lineas + 1] = L["Clic: ver la misión en el Buscador."]
		W.Tooltip(self, "ANCHOR_LEFT", it.titulo, lineas)
	end)
	b:SetScript("OnLeave", W.HideTip)
	return b
end

local function pintar(b, i)
	local it = est.lista and est.lista[i]
	if not it then return b:Hide() end
	local m = marcas()[it.id]
	b.Caja:SetChecked(m == nil and it.pm ~= nil)
	if it.pm then b.Caja:Enable() else b.Caja:Disable() end
	b.Nivel:SetText(it.nivel and tostring(it.nivel) or "?")
	if it.nivel then K.Tinte(b.Nivel, M.VistaRuta.ColorNivel(it.nivel)) else W.Color(b.Nivel, "textMuted") end
	b.Titulo:SetText(it.titulo or "")
	W.Color(b.Titulo, (m == "abandonar") and "danger" or ((m or not it.pm) and "textMuted" or "text"))
	local estado
	if m == "abandonar" then
		estado = L["Para abandonar"]
	elseif it.listo then
		estado = L["Lista para entregar"]
	else
		local Cp = M.Motor("Compat")
		local objs = Cp and Cp.GetQuestObjectives and Cp.GetQuestObjectives(it.id)
		local hechos, total = 0, 0
		for _, o in ipairs(objs or {}) do
			total = total + 1
			if o.finished then hechos = hechos + 1 end
		end
		estado = total > 0 and format(L["Objetivos: %d de %d"], hechos, total) or L["Por terminar"]
	end
	if #it.razones > 0 then estado = estado .. "  \194\183  " .. concat(it.razones, ", ") end
	b.Estado:SetText(estado)
	W.Color(b.Estado, (it.sugerencia == "abandonar" or m == "abandonar") and "warning" or (it.listo and "success" or "textDim"))
	b.Lejos:SetText(it.viaje and it.viaje < I.LEJOS and ("~" .. M.Minutos(it.viaje)) or "")
	W.SetIconState(b.Quitar, m == "abandonar", true)
	if m == "abandonar" then W.Color(b.Quitar.Icon, "danger") end
end

---------------------------------------------------------------------------
-- Construcción y pintura
---------------------------------------------------------------------------

function VL.Construir(parent)
	c = CreateFrame("Frame", nil, parent)
	ui.titulo = K.Texto(c, "heading", "text")
	ui.titulo:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -4)
	ui.titulo:SetText(L["Tus misiones abiertas"])
	ui.chips = {}
	for i = 1, 3 do ui.chips[i] = W.Chip(c) end
	ui.actualizar = W.Button(c, L["Actualizar"], function() VL.Cargar() end, { ghost = true, icon = "reload" })
	ui.actualizar:SetPoint("TOPRIGHT", c, "TOPRIGHT", 0, 0)
	ui.intro = K.Texto(c, "note", "textDim", true)
	ui.intro:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -32)
	ui.intro:SetText(L["Alfa arma una guía con el orden más corto para terminar y entregar todas. Quita la marca de las que no quieras hacer, o tócales la X para abandonarlas."])
	ui.panel = W.RowPanel(c)
	ui.lista = K.Lista(ui.panel, 40, fila, pintar)
	ui.lista:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 4, -4)
	ui.lista:SetPoint("BOTTOMRIGHT", ui.panel, "BOTTOMRIGHT", -2, 4)
	ui.vacio = K.Texto(ui.panel, "note", "textDim", true)
	ui.vacio:SetPoint("TOPLEFT", ui.panel, "TOPLEFT", 20, -24)
	ui.vacio:SetPoint("RIGHT", ui.panel, "RIGHT", -20, 0)
	ui.armar = W.Button(c, L["Armar mi ruta"], armarRuta, { primary = true, icon = "icon-goto" })
	ui.armar.psTip = L["Una guía del motor: la flecha te lleva a cada objetivo y a cada entrega."]
	ui.abandonar = W.Button(c, L["Abandonar marcadas"], abandonarMarcadas, { danger = true })
	ui.sugerir = W.Button(c, L["Marcar las que no valen la pena"], marcarSugeridas, { ghost = true, icon = "skip" })
	ui.sugerir.psTip = L["Fallidas, grises (ya no dan XP) o muy lejos: las marca para abandonar. Las de grupo o mazmorra quedan fuera de la ruta."]
	return c
end

function VL.Visible() return c ~= nil and c:IsVisible() end

function VL.Refrescar(ancho, alto)
	if not c then return end
	ancho = num(ancho, est.ancho or 640)
	alto = num(alto, est.alto or 440)
	est.ancho, est.alto = ancho, alto
	if not c:IsShown() then return end
	if not est.lista and not est.cargando and not est.motivo then return VL.Cargar() end
	ui.intro:SetWidth(ancho)
	local introH = max(14, K.Alto(ui.intro))
	local y = 32 + introH + 10
	ui.panel:ClearAllPoints()
	ui.panel:SetPoint("TOPLEFT", c, "TOPLEFT", 0, -y)
	ui.panel:SetSize(ancho, alto - y - 46)
	ui.armar:ClearAllPoints()
	ui.armar:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", 0, 4)
	ui.abandonar:ClearAllPoints()
	ui.abandonar:SetPoint("RIGHT", ui.armar, "LEFT", -8, 0)
	ui.sugerir:ClearAllPoints()
	ui.sugerir:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 0, 4)
	local listas, faltan, malas, abandonar, dentro = cuentas()
	local x = 12 + K.Ancho(ui.titulo)
	local textos = {
		{ format(L["%d listas"], listas), "success" },
		{ format(L["%d por terminar"], faltan), "neutral" },
		{ format(L["%d no valen la pena"], malas), malas > 0 and "warning" or "neutral" },
	}
	for i, chip in ipairs(ui.chips) do
		chip:ClearAllPoints()
		chip:SetPoint("LEFT", c, "TOPLEFT", x, -12)
		local w = num(W.SetChip(chip, textos[i][1], textos[i][2]), 60)
		chip:SetShown(est.lista ~= nil)
		x = x + w + 6
	end
	W.SetButtonText(ui.abandonar, abandonar > 0 and format(L["Abandonar marcadas (%d)"], abandonar) or L["Abandonar marcadas"])
	W.SetButtonText(ui.armar, dentro > 0 and format(L["Armar mi ruta (%d)"], dentro) or L["Armar mi ruta"])
	if dentro > 0 and not est.cargando then ui.armar:Enable() else ui.armar:Disable() end
	if abandonar > 0 then ui.abandonar:Enable() else ui.abandonar:Disable() end
	local vacio
	if est.cargando then
		vacio = L["Leyendo tu registro de misiones..."]
	elseif est.motivo then
		vacio = I.TextoMotivo(est.motivo)
	elseif est.lista and #est.lista == 0 then
		vacio = L["No tienes misiones abiertas. ¡Todo libre!"]
	end
	ui.vacio:SetText(vacio or "")
	ui.vacio:SetShown(vacio ~= nil)
	ui.lista:SetShown(vacio == nil)
	ui.lista:Datos(vacio and 0 or #(est.lista or {}))
end

-- Lo que pasa en el registro se ve aquí (un segundo después, para juntar avisos).
local pendiente = false
local function luego()
	if pendiente or not VL.Visible() then return end
	pendiente = true
	A.After(1, function()
		pendiente = false
		if VL.Visible() then VL.Cargar() end
	end)
end
for _, ev in ipairs({ "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN", "QUEST_LOG_UPDATE" }) do
	A.RegisterEvent(ev, luego)
end

function VL.AlMostrar()
	est.motivo = nil
	if est.lista and not est.cargando then VL.Cargar() end
end
