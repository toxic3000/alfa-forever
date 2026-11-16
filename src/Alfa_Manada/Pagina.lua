-- Alfa - La Jauría: la página del módulo en la ventana de Alfa, la cara del
-- clan. Toxic / La Jauría. GPL-3.0.
--
-- Arriba, la insignia de La Jauría con su lema y cuántos lobos hay
-- conectados. Debajo, tres secciones:
--   Manada    tu grupo, tu hermandad y tus amigos: nivel, clase, zona,
--             distancia, si usa Alfa y hace cuánto lo viste, con Seguir,
--             Susurrar e Invitar al grupo
--   El clan   quiénes somos (Clan.lua), el Discord para copiar y, para quien
--             aún no es de la manada, "Quiero unirme"
--   Ajustes   qué compartes y con quién, qué se ve en el mapa y el estado
-- Mientras la página está a la vista se rehace cada REFRESCO segundos (las
-- distancias cambian al caminar). La primera vez se pregunta, con un diálogo
-- claro, si compartes tu ubicación con tu hermandad.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local U, L, ID = M.U, M.L, M.ID
local W, T = A.Widgets, A.Theme

local P = {}
M.Pagina = P

local REFRESCO = 2
local FILA_H = 48
local MAX_DESCONECTADOS = 60
local DOT = "  ·  "

local floor, max, min = math.floor, math.max, math.min

local function num(v, d) return tonumber(v) or d end

local function anchoCuerpo()
	local UI = A.UI
	local win = UI and UI.Options and UI.Options.frame
	return num(win and win.BodyWidth, 566)
end

local function margen() return num(W.SHELL and W.SHELL.pad, 32) end

local function hexColor(r, g, b)
	return ("|cff%02x%02x%02x"):format(floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5))
end

local function hexTema(nombre)
	local ok, h = pcall(T.Hex, nombre)
	if ok and type(h) == "string" then return "|c" .. h end
	return "|cffffffff"
end

local function colocar(f, view, x, y)
	f:ClearAllPoints()
	f:SetPoint("TOPLEFT", view, "TOPLEFT", x, -y)
end

local function altoTexto(fs, extra)
	return math.ceil(num(fs:GetStringHeight(), 14)) + (extra or 0)
end

local function texto(parent, rol, color, envolver)
	local fs = W.Text(parent, rol, color)
	if envolver then
		fs:SetWordWrap(true)
		fs:SetJustifyH("LEFT")
		fs:SetJustifyV("TOP")
		fs:SetSpacing(3)
	end
	return fs
end

---------------------------------------------------------------------------
-- Rehacer la página donde está
---------------------------------------------------------------------------

local function rehacer()
	local view = P.view
	if not (view and view.Refresh) then return end
	-- Oculta no hace falta: la ventana la rehace al mostrarla.
	if not view:IsVisible() then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local UI = A.UI
	local win = UI and UI.Options and UI.Options.frame
	if win and view:IsShown() then W.ShellBody(win, h) end
end
P.Rehacer = rehacer

---------------------------------------------------------------------------
-- La pregunta de privacidad (una sola vez)
---------------------------------------------------------------------------

function P.Preguntar(siempre)
	local d = N.Datos(ID)
	if d.preguntado and not siempre then return false end
	if not N.Get(ID, "red") then return false end
	if not W.Modal then return false end
	N.FueraDeCombate(function()
		local d2 = N.Datos(ID)
		if d2.preguntado and not siempre then return end
		if W.ModalShown and W.ModalShown() then return end
		d2.preguntado = true
		W.Modal({
			title = L["¿Le muestras a tu manada dónde estás?"],
			icon = "flag",
			text = L["Alfa puede compartir tu posición en el mapa con tu hermandad, para que te encuentren y te puedan seguir. Solo la ve tu hermandad: nunca canales públicos, nunca desde mazmorras. Lo apagas cuando quieras en La Jauría > Ajustes."],
			action = L["Sí, con mi hermandad"],
			cancel = L["Ahora no"],
			onAccept = function()
				N.Set(ID, "compartir", true)
				U.Decir(L["Compartes tu ubicación con tu hermandad. Lo cambias en /alfa manada."])
			end,
			onCancel = function()
				N.Set(ID, "compartir", false)
			end,
		})
	end)
	return true
end

---------------------------------------------------------------------------
-- La insignia (arriba)
---------------------------------------------------------------------------

local HERO_H = 128

local function construirInsignia(view)
	local h = CreateFrame("Frame", nil, view)
	h:SetHeight(HERO_H)
	T.Skin(h, "panel")
	-- Una línea del color de Alfa arriba: el estandarte de la manada.
	h.Top = W.Tex(h, "ARTWORK")
	h.Top:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
	h.Top:SetPoint("TOPRIGHT", h, "TOPRIGHT", -1, -1)
	h.Top:SetHeight(2)
	W.Color(h.Top, "accent")
	h.Glow = W.Tex(h, "BACKGROUND", "glow")
	h.Glow:SetSize(150, 150)
	h.Emblem = W.Tex(h, "ARTWORK", "emblem", "accent")
	h.Emblem:SetSize(60, 60)
	h.Emblem:SetPoint("TOPLEFT", h, "TOPLEFT", 16, -20)
	h.Glow:SetPoint("CENTER", h.Emblem, "CENTER", 0, 0)
	W.Painter(h.Glow, function(t)
		local r, g, b = T.Accent()
		t:SetVertexColor(r, g, b, 0.14)
	end)
	h.Title = W.Text(h, "hero", "text")
	h.Title:SetPoint("TOPLEFT", h, "TOPLEFT", 92, -18)
	h.Lema = W.Text(h, "note", "textDim")
	h.Lema:SetPoint("TOPLEFT", h, "TOPLEFT", 92, -52)
	h.Con = W.Chip(h)
	h.Con:SetPoint("TOPLEFT", h, "TOPLEFT", 92, -74)
	h.Alfa = W.Chip(h)
	h.Alfa:SetPoint("LEFT", h.Con, "RIGHT", 6, 0)
	h.Yo = W.Chip(h)
	h.Yo:SetPoint("LEFT", h.Alfa, "RIGHT", 6, 0)
	h.Dot = W.Tex(h, "ARTWORK", "circle")
	h.Dot:SetSize(7, 7)
	h.Dot:SetPoint("TOPLEFT", h, "TOPLEFT", 93, -107)
	h.Estado = W.Text(h, "small", "textDim")
	h.Estado:SetPoint("LEFT", h.Dot, "RIGHT", 7, 0)
	h.Estado:SetPoint("RIGHT", h, "RIGHT", -16, 0)
	return h
end

-- Lo que dice la insignia sobre tu ubicación.
local function estadoUbicacion()
	local R = M.Red
	if not N.Get(ID, "red") then return L["Sin conexión con la manada: Alfa no envía ni recibe nada."], "textMuted" end
	local compartir, amigos = N.Get(ID, "compartir"), N.Get(ID, "compartirAmigos")
	if not (compartir or amigos) then return L["Tu ubicación es privada: no la compartes con nadie."], "textMuted" end
	local puede, por = R.PuedeEnviar()
	if not puede then
		if por == "instancia" then return L["En pausa: dentro de una instancia no se comparte nada."], "warning" end
		if por == "prueba" then return L["Las cuentas de prueba no pueden enviar mensajes: tu ubicación no sale."], "warning" end
		if por == "bloqueo" then return L["En pausa: el juego no deja enviar mensajes ahora mismo."], "warning" end
		return L["El juego no deja enviar mensajes de addon aquí."], "warning"
	end
	local con
	if compartir and amigos then
		con = L["con tu hermandad y tus amigos"]
	elseif compartir then
		con = L["con tu hermandad"]
	else
		con = L["con tus amigos"]
	end
	if compartir and not U.EnHermandad() and not amigos then return L["Compartirías con tu hermandad, pero no estás en una."], "textMuted" end
	return L["Compartes tu ubicación %s."]:format(con), "success"
end

local function pintarInsignia(h, ancho)
	h:SetWidth(ancho)
	h.Title:SetText(U.TextoClan("nombre") or L["La Jauría"])
	h.Lema:SetText(U.TextoClan("lema") or "")
	local G = M.Gente
	local con, usan = G.Cuentas()
	if U.EnHermandad() then
		W.SetChip(h.Con, con == 1 and L["1 lobo conectado"] or L["%d lobos conectados"]:format(con), "success")
		W.SetChip(h.Alfa, usan == 1 and L["1 con Alfa"] or L["%d con Alfa"]:format(usan), "accent")
		h.Alfa:Show()
	else
		W.SetChip(h.Con, L["Sin hermandad"], "neutral")
		h.Alfa:Hide()
	end
	h.Yo:ClearAllPoints()
	h.Yo:SetPoint("LEFT", h.Alfa:IsShown() and h.Alfa or h.Con, "RIGHT", 6, 0)
	if U.EnElClan() then
		W.SetChip(h.Yo, L["Eres de la manada"], "neutral")
	else
		W.SetChip(h.Yo, L["Aún no eres de la manada"], "warning")
	end
	local s, color = estadoUbicacion()
	h.Estado:SetText(s)
	W.Color(h.Dot, color == "textMuted" and "textMuted" or color)
end

---------------------------------------------------------------------------
-- Las secciones (Manada, El clan, Ajustes)
---------------------------------------------------------------------------

local SECCIONES = {
	{ key = "manada", label = "Manada" },
	{ key = "clan", label = "El clan" },
	{ key = "ajustes", label = "Ajustes" },
}
local actual -- la sección a la vista

local function construirBarra(view)
	local b = CreateFrame("Frame", nil, view)
	b:SetHeight(34)
	b.Rule = W.Divider(b)
	b.Rule:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 0, 0)
	b.Rule:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 0, 0)
	b.Line = W.Tex(b, "OVERLAY")
	b.Line:SetHeight(2)
	W.Color(b.Line, "accent")
	b.botones = {}
	local x = 0
	for i, s in ipairs(SECCIONES) do
		local btn = W.Button(b, L[s.label], function()
			actual = s.key
			rehacer()
		end, { ghost = true, height = 32 })
		btn.psKey = s.key
		btn:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", x, 1)
		x = x + num(btn:GetWidth(), 90) + 4
		b.botones[i] = btn
	end
	return b
end

local function pintarBarra(b, ancho)
	b:SetWidth(ancho)
	for _, btn in ipairs(b.botones) do
		local sel = btn.psKey == actual
		W.Color(btn.Label, sel and "text" or "textDim")
		if sel then
			b.Line:ClearAllPoints()
			b.Line:SetPoint("BOTTOMLEFT", btn, "BOTTOMLEFT", 8, -1)
			b.Line:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -8, -1)
		end
	end
end

---------------------------------------------------------------------------
-- Manada: las filas
---------------------------------------------------------------------------

local filas = {} -- grupo de filas reutilizables

local function infoFila(f)
	local G = M.Gente
	local partes = {}
	local nivel = M.Mapa.LineaNivel(f)
	if nivel then partes[#partes + 1] = nivel end
	if not f.conectado then
		partes[#partes + 1] = L["Desconectado"]
		local hace = f.desde or G.VistoHace(f.clave)
		if hace then partes[#partes + 1] = L["visto %s"]:format(U.Hace(hace)) end
		return table.concat(partes, DOT)
	end
	local map, x, y, edad = G.PosicionDe(f)
	local zona = (map and U.NombreMapa(U.ZonaDe(map))) or (f.zona and U.NombreMapa(f.zona)) or f.zonaTexto
	if zona then partes[#partes + 1] = zona end
	if map then
		local yd, otro = U.Distancia(map, x, y)
		if yd then
			partes[#partes + 1] = U.TextoDistancia(yd)
		elseif otro then
			partes[#partes + 1] = L["otro continente"]
		end
		if f.tipo ~= "grupo" and edad and edad >= G.VIEJA then partes[#partes + 1] = L["ubicación de %s"]:format(U.Hace(edad)) end
	end
	if f.muerto then partes[#partes + 1] = L["Muerto"] end
	if f.rango then partes[#partes + 1] = f.rango end
	return table.concat(partes, DOT)
end

local function alSeguir(btn)
	local f = btn:GetParent().psFila
	if not f then return end
	local S = M.Seguir
	if S.Sigue(f.clave) then S.Parar() else S.A(f) end
	rehacer()
end

local function alSusurrar(btn)
	local f = btn:GetParent().psFila
	if f then U.Susurrar(f.envio or f.nombre) end
end

local function alInvitar(btn)
	local f = btn:GetParent().psFila
	if not f then return end
	if U.Invitar(f.envio or f.nombre) then
		U.Decir(L["Invitaste a %s a tu grupo."]:format(f.nombre or "?"))
	end
end

local function nuevaFila(view)
	local r = CreateFrame("Button", nil, view)
	r:SetHeight(FILA_H)
	W.Hover(r, 0.6)
	r.Rule = W.Divider(r, false, 0.6)
	r.Rule:SetPoint("BOTTOMLEFT", r, "BOTTOMLEFT", 0, 0)
	r.Rule:SetPoint("BOTTOMRIGHT", r, "BOTTOMRIGHT", 0, 0)
	r.Dot = W.Tex(r, "ARTWORK", "circle")
	r.Dot:SetSize(10, 10)
	r.Dot:SetPoint("LEFT", r, "LEFT", 14, 0)
	r.Ring = W.Tex(r, "BORDER", "circle")
	r.Ring:SetSize(16, 16)
	r.Ring:SetPoint("CENTER", r.Dot, "CENTER", 0, 0)
	r.Seguir = W.Button(r, L["Seguir"], alSeguir, { height = 26, width = 86, icon = "icon-goto" })
	r.Seguir:SetPoint("RIGHT", r, "RIGHT", -10, 0)
	r.Invitar = W.IconButton(r, "plus", 26, L["Invitar al grupo"], alInvitar)
	r.Invitar:SetPoint("RIGHT", r.Seguir, "LEFT", -6, 0)
	r.Susurrar = W.IconButton(r, "icon-talk", 26, L["Susurrar"], alSusurrar)
	r.Susurrar:SetPoint("RIGHT", r.Invitar, "LEFT", -2, 0)
	r.Name = W.Text(r, "body", "text")
	r.Name:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -8)
	r.Chip = W.Chip(r)
	r.Chip:SetPoint("LEFT", r.Name, "RIGHT", 8, 0)
	r.Info = W.Text(r, "small", "textDim")
	r.Info:SetPoint("TOPLEFT", r, "TOPLEFT", 34, -28)
	r.Info:SetPoint("RIGHT", r.Susurrar, "LEFT", -8, 0)
	r:SetScript("OnEnter", function(self)
		local f = self.psFila
		if not f then return end
		local lineas = { infoFila(f) }
		if M.Gente.PosicionDe(f) and f.conectado then
			lineas[#lineas + 1] = L["Seguir: la flecha y la ruta de Alfa te llevan hasta su posición."]
		elseif f.conectado then
			lineas[#lineas + 1] = L["No sabemos dónde está: solo se puede seguir a tu grupo y a quien comparte su ubicación con Alfa."]
		end
		W.Tooltip(self, "ANCHOR_TOPLEFT", f.nombre or "?", lineas)
	end)
	r:SetScript("OnLeave", function(self) W.HideTooltip(self) end)
	return r
end

local function activar(b, si)
	if si then b:Enable() else b:Disable() end
	b:SetAlpha(si and 1 or 0.4)
end

local function pintarFila(r, f, ancho)
	r.psFila = f
	r:SetWidth(ancho)
	local cr, cg, cb = U.ColorClase(f.clase)
	r.Dot:SetVertexColor(cr, cg, cb, f.conectado and 1 or 0.35)
	local tr, tg, tb = U.ColorTexto(f.clase)
	W.Uncolor(r.Name)
	if f.conectado then
		r.Name:SetTextColor(tr, tg, tb, 1)
	else
		W.Color(r.Name, "textMuted")
	end
	r.Name:SetText(f.nombre or "?")
	local nombreMax = max(60, ancho - 34 - 8 - 70 - 140)
	r.Name:SetWidth(min(nombreMax, num(r.Name:GetStringWidth(), 100) + 2))
	local S, G = M.Seguir, M.Gente
	local siguiendo = S.Sigue(f.clave)
	-- El anillo: verde al seguirlo, tenue si usa Alfa.
	if siguiendo then
		local sr, sg, sb = T.Color("success")
		r.Ring:SetVertexColor(sr, sg, sb, 0.9)
		r.Ring:Show()
	elseif f.alfa then
		local ar, ag, ab = T.Accent()
		r.Ring:SetVertexColor(ar, ag, ab, 0.35)
		r.Ring:Show()
	else
		r.Ring:Hide()
	end
	if siguiendo then
		W.SetChip(r.Chip, L["Siguiendo"], "success")
	elseif f.alfa then
		W.SetChip(r.Chip, f.comparte and L["Alfa · comparte"] or L["Alfa"], "accent")
	else
		r.Chip:Hide()
	end
	r.Info:SetText(infoFila(f))
	local pos = f.conectado and G.PosicionDe(f) ~= nil
	activar(r.Seguir, pos or siguiendo)
	W.SetButtonText(r.Seguir, siguiendo and L["Parar"] or L["Seguir"])
	r.Seguir.psTip = siguiendo and L["Dejar de seguir"] or L["Seguir"]
	r.Seguir.psTipLines = { pos and L["La flecha y la ruta de Alfa te llevan hasta su posición, y se actualizan mientras se mueve."]
		or L["Solo se puede seguir a tu grupo y a quien comparte su ubicación con Alfa."] }
	activar(r.Susurrar, f.conectado)
	local enGrupo = f.tipo == "grupo" or U.EnMiGrupo(f.envio or f.nombre)
	activar(r.Invitar, f.conectado and not enGrupo)
	r.Invitar.psTip = enGrupo and L["Ya está en tu grupo"] or L["Invitar al grupo"]
	r:Show()
end

-- Las filas de cada lista, filtradas y en orden.
local function coincide(f, filtro)
	if filtro == "" then return true end
	local n = U.Plegar(f.nombre)
	return n:find(filtro, 1, true) ~= nil
end

local function ordenar(lista)
	local G = M.Gente
	for _, f in ipairs(lista) do
		local map, x, y = G.PosicionDe(f)
		f.psDist = (f.conectado and map and U.Distancia(map, x, y)) or nil
		f.psHace = (not f.conectado) and (f.desde or G.VistoHace(f.clave)) or nil
	end
	table.sort(lista, function(a, b)
		local ca, cb = a.conectado and true or false, b.conectado and true or false
		if ca ~= cb then return ca end
		if ca then
			if (a.psDist ~= nil) ~= (b.psDist ~= nil) then return a.psDist ~= nil end
			if a.psDist and b.psDist and a.psDist ~= b.psDist then return a.psDist < b.psDist end
			return (a.nombre or "") < (b.nombre or "")
		end
		local ha, hb = a.psHace or math.huge, b.psHace or math.huge
		if ha ~= hb then return ha < hb end
		return (a.nombre or "") < (b.nombre or "")
	end)
	return lista
end

local function listas(filtro, desconectados)
	local G = M.Gente
	local grupo, jauria, amigos = {}, {}, {}
	for _, f in ipairs(G.Grupo()) do
		if coincide(f, filtro) then grupo[#grupo + 1] = G.Completar(f) end
	end
	local vistos, fuera = {}, 0
	for clave, f in pairs(G.Hermandad()) do
		vistos[clave] = true
		if (f.conectado or desconectados) and coincide(f, filtro) and not G.EnGrupo(clave) then
			jauria[#jauria + 1] = G.Completar(f)
		end
	end
	-- Quien habla por la hermandad pero aún no sale en su lista.
	for _, p in ipairs(G.ParaElMapa()) do
		local f = p.fila
		if p.capa == "hermandad" and not vistos[f.clave] and coincide(f, filtro) then
			f.conectado = true
			jauria[#jauria + 1] = G.Completar(f)
		end
	end
	for clave, f in pairs(G.Amigos()) do
		if (f.conectado or desconectados) and coincide(f, filtro) and not G.EnGrupo(clave) and not G.DeHermandad(clave) then
			amigos[#amigos + 1] = G.Completar(f)
		end
	end
	ordenar(grupo)
	ordenar(jauria)
	ordenar(amigos)
	-- Los desconectados de la hermandad: solo los vistos más recientes.
	local con = 0
	for _, f in ipairs(jauria) do if f.conectado then con = con + 1 end end
	if #jauria > con + MAX_DESCONECTADOS then
		fuera = #jauria - con - MAX_DESCONECTADOS
		for i = #jauria, con + MAX_DESCONECTADOS + 1, -1 do table.remove(jauria, i) end
	end
	return grupo, jauria, amigos, fuera
end

---------------------------------------------------------------------------
-- Manada: la sección
---------------------------------------------------------------------------

local filtro = ""

local function construirManada(view)
	local m = {}
	-- A quién sigues (arriba, con "Dejar de seguir").
	m.Sigue = CreateFrame("Frame", nil, view)
	m.Sigue:SetHeight(56)
	T.Skin(m.Sigue, "tile")
	m.Sigue.Icon = W.Tex(m.Sigue, "ARTWORK", "icon-goto", "success")
	m.Sigue.Icon:SetSize(18, 18)
	m.Sigue.Icon:SetPoint("LEFT", m.Sigue, "LEFT", 16, 0)
	m.Sigue.Title = W.Text(m.Sigue, "body", "text")
	m.Sigue.Title:SetPoint("TOPLEFT", m.Sigue, "TOPLEFT", 46, -11)
	m.Sigue.Info = W.Text(m.Sigue, "small", "textDim")
	m.Sigue.Info:SetPoint("TOPLEFT", m.Sigue, "TOPLEFT", 46, -30)
	m.Sigue.Stop = W.Button(m.Sigue, L["Dejar de seguir"], function()
		M.Seguir.Parar()
		rehacer()
	end, { height = 28 })
	m.Sigue.Stop:SetPoint("RIGHT", m.Sigue, "RIGHT", -12, 0)
	m.Sigue.Title:SetPoint("RIGHT", m.Sigue.Stop, "LEFT", -10, 0)
	m.Sigue.Info:SetPoint("RIGHT", m.Sigue.Stop, "LEFT", -10, 0)
	-- Buscar y "ver desconectados".
	m.Buscar = W.SearchBox(view, L["Buscar por nombre"], function(t)
		local nuevo = U.Plegar(t or "")
		if nuevo == filtro then return end
		filtro = nuevo
		rehacer()
	end)
	m.Buscar:SetWidth(230)
	m.Desc = W.Switch(view, function() return N.Get(ID, "verDesconectados") end, function(v)
		N.Set(ID, "verDesconectados", v and true or false)
		rehacer()
	end, L["Ver también a quien no está conectado"])
	m.DescLabel = W.Text(view, "label", "textDim")
	m.DescLabel:SetText(L["Ver desconectados"])
	-- Las tres listas.
	m.secciones = {}
	for i, s in ipairs({ { "Tu grupo" }, { "La Jauría" }, { "Amigos" } }) do
		local h = W.SectionHeader(view)
		W.SetSection(h, L[s[1]])
		local vacio = texto(view, "note", "textMuted", true)
		-- Las filas van sobre un panel, como los ajustes de Alfa.
		m.secciones[i] = { h = h, vacio = vacio, panel = W.RowPanel(view) }
	end
	m.Mas = W.Text(view, "small", "textMuted")
	m.Nota = texto(view, "small", "textMuted", true)
	m.Nota:SetText(L["Seguir funciona con tu grupo y con quien comparte su ubicación con Alfa. Dentro de mazmorras el juego no da posiciones y no se comparte nada."])
	return m
end

local function pintarSigue(m, view, x, y, ancho)
	local S, G = M.Seguir, M.Gente
	local s = S.Actual()
	if not s then
		m.Sigue:Hide()
		return y
	end
	m.Sigue:SetWidth(ancho)
	colocar(m.Sigue, view, x, y)
	m.Sigue.Title:SetText(L["Siguiendo el rastro de %s"]:format(s.nombre or "?"))
	local map, px, py = G.PosicionDe({ clave = s.clave })
	if not map then
		local unit = G.UnidadDe(s.clave)
		if unit then map, px, py = U.PosUnidad(unit) end
	end
	local partes = {}
	if map then
		local zona = U.NombreMapa(U.ZonaDe(map))
		if zona then partes[#partes + 1] = zona end
		local yd, otro = U.Distancia(map, px, py)
		if yd then partes[#partes + 1] = U.TextoDistancia(yd) elseif otro then partes[#partes + 1] = L["otro continente"] end
	else
		partes[#partes + 1] = L["Buscando su rastro..."]
	end
	m.Sigue.Info:SetText(table.concat(partes, DOT))
	m.Sigue:Show()
	return y + 56 + 14
end

local function pintarManada(m, view, x, y, ancho)
	y = pintarSigue(m, view, x, y, ancho)
	colocar(m.Buscar, view, x, y)
	m.Buscar:Show()
	m.Desc:ClearAllPoints()
	m.Desc:SetPoint("TOPRIGHT", view, "TOPLEFT", x + ancho, -(y + 3))
	m.Desc:Refresh()
	m.Desc:Show()
	m.DescLabel:ClearAllPoints()
	m.DescLabel:SetPoint("RIGHT", m.Desc, "LEFT", -6, 0)
	m.DescLabel:Show()
	y = y + 30 + 6
	local okSkin, skin = pcall(T.SkinKey)
	local casa = not okSkin or skin == "alfa"
	local grupo, jauria, amigos, fuera = listas(filtro, N.Get(ID, "verDesconectados") and true or false)
	local datos = { grupo, jauria, amigos }
	local usadas = 0
	for i, s in ipairs(m.secciones) do
		local lista = datos[i]
		s.h:SetWidth(ancho)
		colocar(s.h, view, x, y)
		local conectados = 0
		for _, f in ipairs(lista) do if f.conectado then conectados = conectados + 1 end end
		local cuenta
		if i == 1 then
			cuenta = #lista > 0 and tostring(#lista) or nil
		else
			cuenta = conectados > 0 and L["%d conectados"]:format(conectados) or nil
		end
		W.SetSection(s.h, L[({ "Tu grupo", "La Jauría", "Amigos" })[i]], cuenta)
		s.h:Show()
		y = y + 44
		if #lista == 0 then
			local msg
			if filtro ~= "" then
				msg = L["Nadie con ese nombre."]
			elseif i == 1 then
				msg = L["No estás en un grupo. Invita a alguien de la manada desde la lista de abajo."]
			elseif i == 2 then
				msg = U.EnHermandad() and L["Nadie de tu hermandad está conectado ahora."]
					or L["No estás en una hermandad. Mira la sección El clan para unirte a La Jauría."]
			else
				msg = L["Ningún amigo conectado. Tus amigos con Alfa que te compartan su ubicación también salen en el mapa."]
			end
			s.vacio:SetWidth(ancho - 8)
			s.vacio:SetText(msg)
			colocar(s.vacio, view, x + 4, y)
			s.vacio:Show()
			s.panel:Hide()
			y = y + altoTexto(s.vacio, 10)
		else
			s.vacio:Hide()
			local arriba = y
			for j, f in ipairs(lista) do
				usadas = usadas + 1
				local r = filas[usadas]
				if not r then
					r = nuevaFila(view)
					filas[usadas] = r
				end
				colocar(r, view, x, y)
				pintarFila(r, f, ancho)
				r.Rule:SetShown(j < #lista)
				y = y + FILA_H
			end
			s.panel:ClearAllPoints()
			s.panel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -arriba)
			s.panel:SetSize(ancho, max(1, y - arriba))
			s.panel:SetShown(casa)
			if i == 2 and fuera > 0 then
				m.Mas:SetText(L["y %d más sin conectarse hace tiempo"]:format(fuera))
				colocar(m.Mas, view, x + 4, y + 6)
				m.Mas:Show()
				y = y + 24
			elseif i == 2 then
				m.Mas:Hide()
			end
		end
		y = y + 10
	end
	if not (fuera > 0) then m.Mas:Hide() end
	for k = usadas + 1, #filas do
		filas[k]:Hide()
		filas[k].psFila = nil
	end
	m.Nota:SetWidth(ancho)
	colocar(m.Nota, view, x, y + 6)
	m.Nota:Show()
	y = y + 6 + altoTexto(m.Nota, 12)
	return y
end

local function ocultarManada(m)
	m.Sigue:Hide()
	m.Buscar:Hide()
	m.Desc:Hide()
	m.DescLabel:Hide()
	for _, s in ipairs(m.secciones) do
		s.h:Hide()
		s.vacio:Hide()
		s.panel:Hide()
	end
	m.Mas:Hide()
	m.Nota:Hide()
	for _, r in ipairs(filas) do r:Hide() end
end

---------------------------------------------------------------------------
-- El clan
---------------------------------------------------------------------------

local unirse = { estado = nil } -- nil | "buscando" | "listo" | "nadie" | "nopuede"

local function alUnirse()
	if U.EnElClan() then return end
	local R = M.Red
	if R.Buscando() then return end
	local oficiales = (M.Clan and M.Clan.oficiales) or {}
	local mensaje = U.TextoClan("mensajeUnirse") or ""
	-- Un oficial que es tu amigo y está conectado: directo, sin preguntar.
	local G = M.Gente
	for _, nombre in ipairs(oficiales) do
		local f = G.Amigos()[U.Clave(nombre) or ""]
		if f and f.conectado then
			unirse.estado, unirse.quien = "listo", f.nombre
			U.Susurrar(f.envio or nombre, mensaje)
			U.Decir(L["Te abrimos un susurro para %s con tu mensaje. Revísalo y pulsa Intro para enviarlo."]:format(f.nombre))
			rehacer()
			return
		end
	end
	unirse.estado, unirse.quien = "buscando", nil
	R.BuscarOficial(oficiales, function(nombre, por)
		if nombre then
			unirse.estado, unirse.quien = "listo", U.Mostrar(nombre)
			U.Susurrar(nombre, mensaje)
			U.Decir(L["Te abrimos un susurro para %s con tu mensaje. Revísalo y pulsa Intro para enviarlo."]:format(U.Mostrar(nombre)))
		else
			unirse.estado = por == "nopuede" and "nopuede" or "nadie"
			U.Decir(L["Ningún oficial respondió ahora. %s"]:format(U.TextoClan("comoUnirse") or ""))
		end
		rehacer()
	end)
	rehacer()
end

local function construirClan(view)
	local c = {}
	c.QuienesH = W.SectionHeader(view)
	W.SetSection(c.QuienesH, L["Quiénes somos"])
	c.Quienes = texto(view, "body", "textDim", true)
	c.OfreceH = W.SectionHeader(view)
	W.SetSection(c.OfreceH, L["Lo que encuentras en la manada"])
	c.Ofrece = texto(view, "body", "text", true)
	c.DiscordH = W.SectionHeader(view)
	W.SetSection(c.DiscordH, L["Discord"])
	c.DiscordIcon = W.Tex(view, "ARTWORK", "discord", "discord")
	c.DiscordIcon:SetSize(20, 20)
	c.DiscordText = texto(view, "note", "textDim", true)
	c.DiscordText:SetText(L["Ahí nos organizamos para todo. Haz clic en el cuadro y copia el enlace con Ctrl+C."])
	c.Discord = W.CopyBox(view)
	c.UnirseH = W.SectionHeader(view)
	W.SetSection(c.UnirseH, L["Únete a La Jauría"])
	c.Unirse = texto(view, "note", "textDim", true)
	c.Oficiales = texto(view, "small", "textMuted", true)
	c.Boton = W.Button(view, L["Quiero unirme"], alUnirse, { primary = true, height = 32, icon = "flag" })
	c.Estado = texto(view, "note", "textDim", true)
	c.Aviso = texto(view, "note", "warning", true)
	c.Miembro = W.Chip(view)
	c.Escribir = {}
	return c
end

local function enlaceDiscord()
	local d = M.Clan and M.Clan.discord
	if type(d) == "string" and d ~= "" then return d end
	return type(A.DiscordURL) == "string" and A.DiscordURL or ""
end

local function bloque(view, h, fs, x, y, ancho, valor)
	h:SetWidth(ancho)
	colocar(h, view, x, y)
	h:Show()
	y = y + 44
	if fs then
		fs:SetWidth(ancho)
		if valor then fs:SetText(valor) end
		colocar(fs, view, x, y)
		fs:Show()
		y = y + altoTexto(fs, 8)
	end
	return y
end

local function pintarClan(c, view, x, y, ancho)
	local desc = U.TextoClan("descripcion")
	if type(desc) == "table" then desc = table.concat(desc, "\n\n") end
	y = bloque(view, c.QuienesH, c.Quienes, x, y, ancho, desc or "")
	local ofrece = U.TextoClan("ofrecemos")
	if type(ofrece) == "table" and #ofrece > 0 then
		local acc = hexTema("accent")
		local lineas = {}
		for i, t in ipairs(ofrece) do lineas[i] = acc .. "•|r  " .. t end
		y = bloque(view, c.OfreceH, c.Ofrece, x, y + 6, ancho, table.concat(lineas, "\n"))
	else
		c.OfreceH:Hide()
		c.Ofrece:Hide()
	end
	-- Discord, para copiar.
	y = bloque(view, c.DiscordH, nil, x, y + 6, ancho)
	colocar(c.DiscordIcon, view, x, y)
	c.DiscordIcon:Show()
	c.DiscordText:SetWidth(ancho - 30)
	colocar(c.DiscordText, view, x + 30, y + 2)
	c.DiscordText:Show()
	y = y + max(24, altoTexto(c.DiscordText, 6))
	c.Discord:SetWidth(ancho)
	W.SetCopyText(c.Discord, enlaceDiscord())
	colocar(c.Discord, view, x, y)
	c.Discord:Show()
	y = y + 30 + 14
	-- Unirse.
	y = bloque(view, c.UnirseH, nil, x, y, ancho)
	if U.EnElClan() then
		c.Unirse:SetWidth(ancho)
		c.Unirse:SetText(L["Ya eres parte de la manada. Comparte el Discord con tus amigos para que se unan: entre más lobos, mejor la cacería."])
		colocar(c.Unirse, view, x, y)
		c.Unirse:Show()
		y = y + altoTexto(c.Unirse, 10)
		W.SetChip(c.Miembro, L["Eres de la manada"], "success")
		colocar(c.Miembro, view, x, y)
		y = y + 28
		c.Boton:Hide()
		c.Oficiales:Hide()
		c.Estado:Hide()
		c.Aviso:Hide()
		for _, b in pairs(c.Escribir) do b:Hide() end
		return y
	end
	c.Miembro:Hide()
	c.Unirse:SetWidth(ancho)
	c.Unirse:SetText(L["¿Quieres cazar con nosotros? Pulsa el botón: Alfa busca a un oficial conectado y te abre un susurro con tu mensaje listo para que lo envíes con Intro."])
	colocar(c.Unirse, view, x, y)
	c.Unirse:Show()
	y = y + altoTexto(c.Unirse, 12)
	colocar(c.Boton, view, x, y)
	c.Boton:Show()
	local buscando = M.Red.Buscando()
	activar(c.Boton, not buscando)
	W.SetButtonText(c.Boton, buscando and L["Buscando a un oficial..."] or L["Quiero unirme"])
	y = y + 32 + 10
	local estado
	if unirse.estado == "listo" then
		estado = L["Listo: te abrimos un susurro para %s. Revisa el mensaje y pulsa Intro."]:format(unirse.quien or "?")
	elseif unirse.estado == "nadie" then
		estado = L["Ningún oficial respondió ahora. %s"]:format(U.TextoClan("comoUnirse") or "")
	elseif unirse.estado == "nopuede" then
		estado = L["Ahora no se pueden enviar mensajes (en una instancia o con una cuenta de prueba). %s"]:format(U.TextoClan("comoUnirse") or "")
	end
	if estado then
		c.Estado:SetWidth(ancho)
		c.Estado:SetText(estado)
		colocar(c.Estado, view, x, y)
		c.Estado:Show()
		y = y + altoTexto(c.Estado, 8)
	else
		c.Estado:Hide()
	end
	local of = (M.Clan and M.Clan.oficiales) or {}
	-- Nadie respondió (o un oficial sin Alfa): escribirle a mano, con un clic.
	local manual = unirse.estado == "nadie" or unirse.estado == "nopuede"
	local bx = x
	for i = 1, 3 do
		local nombre = of[i]
		local b = c.Escribir[i]
		if manual and nombre and U.Clave(nombre) ~= U.MiClave() then
			if not b then
				b = W.Button(view, "", function(self)
					U.Susurrar(self.psNombre, U.TextoClan("mensajeUnirse") or "")
				end, { ghost = true, height = 26, icon = "icon-talk" })
				c.Escribir[i] = b
			end
			b.psNombre = nombre
			W.SetButtonText(b, L["Escribir a %s"]:format(U.Mostrar(nombre)))
			b.psTip = L["Escribir a %s"]:format(U.Mostrar(nombre))
			b.psTipLines = { L["Abre un susurro con tu mensaje listo. Si no está conectado, el juego te lo dirá."] }
			colocar(b, view, bx, y)
			b:Show()
			bx = bx + num(b:GetWidth(), 120) + 6
		elseif b then
			b:Hide()
		end
	end
	if bx > x then y = y + 26 + 10 end
	if #of > 0 then
		local nombres = {}
		for i, n in ipairs(of) do nombres[i] = U.Mostrar(n) end
		c.Oficiales:SetWidth(ancho)
		c.Oficiales:SetText(L["Oficiales: %s"]:format(table.concat(nombres, ", ")))
		colocar(c.Oficiales, view, x, y)
		c.Oficiales:Show()
		y = y + altoTexto(c.Oficiales, 8)
	else
		c.Oficiales:Hide()
	end
	if A.Get and A.Get("qol.declineGuildInvites") then
		c.Aviso:SetWidth(ancho)
		c.Aviso:SetText(L["Tienes activado \"Rechazar invitaciones de hermandad\" en Comodidades: apágalo para que te llegue la invitación."])
		colocar(c.Aviso, view, x, y)
		c.Aviso:Show()
		y = y + altoTexto(c.Aviso, 8)
	else
		c.Aviso:Hide()
	end
	return y
end

local function ocultarClan(c)
	for _, k in ipairs({ "QuienesH", "Quienes", "OfreceH", "Ofrece", "DiscordH", "DiscordIcon", "DiscordText", "Discord",
		"UnirseH", "Unirse", "Oficiales", "Boton", "Estado", "Aviso", "Miembro" }) do
		c[k]:Hide()
	end
	for _, b in pairs(c.Escribir) do b:Hide() end
end

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------

local GRUPOS_AJUSTES = {
	{ titulo = "Tu ubicación", filas = {
		{ "red", "Conectar con la manada", "Avisa a tu hermandad que usas Alfa y escucha a los demás Alfa. Apagado, Alfa no envía ni recibe nada de nadie." },
		{ "compartir", "Compartir mi ubicación con la hermandad", "Tu hermandad te ve en el mapa y te puede seguir. Se envía tu posición, nivel y clase cada 10 segundos mientras te mueves.", "red" },
		{ "compartirAmigos", "Compartir mi ubicación con mis amigos", "Solo a los amigos de tu lista que usan Alfa y aceptan ver a sus amigos. Por susurro oculto, nunca por canales públicos.", "red" },
		{ "verAmigos", "Ver a mis amigos que me comparten", "Tus amigos con Alfa que te comparten su ubicación salen en tu mapa y los puedes seguir.", "red" },
	} },
	{ titulo = "En el mapa", filas = {
		{ "capaGrupo", "Mi grupo", "Tu grupo en el mapa y el minimapa, con el color de su clase." },
		{ "capaJauria", "La Jauría", "Tu hermandad: quienes comparten su ubicación con Alfa." },
		{ "capaAmigos", "Amigos", "Tus amigos que te comparten su ubicación." },
		{ "minimapa", "También en el minimapa", "Los pines de la manada también en el minimapa, no solo en el mapa del mundo." },
	} },
}

local function construirAjustes(view)
	local a = { grupos = {} }
	for gi, g in ipairs(GRUPOS_AJUSTES) do
		local grupo = { h = W.SectionHeader(view, { plain = true }), panel = W.RowPanel(view), filas = {} }
		W.SetSection(grupo.h, L[g.titulo])
		for i, f in ipairs(g.filas) do
			local row = W.Toggle(view, L[f[2]], ID .. "." .. f[1], L[f[3]], f[4] and (ID .. "." .. f[4]) or nil)
			W.RowDetails(row, { inset = 16 })
			grupo.filas[i] = row
		end
		a.grupos[gi] = grupo
	end
	a.EstadoH = W.SectionHeader(view, { plain = true })
	W.SetSection(a.EstadoH, L["Estado"])
	a.EstadoPanel = W.RowPanel(view)
	a.Ahora = W.InfoRow(view, L["Ahora"], nil)
	a.Alfa = W.InfoRow(view, L["Alfa en tu hermandad"], nil)
	a.Olvidar = W.ActionRow(view, L["Olvidar a quienes he visto"], L["Borra la lista de \"hace cuánto lo viste\" guardada en esta cuenta."],
		L["Olvidar"], function()
			M.Gente.OlvidarVistos()
			U.Decir(L["Listo: olvidamos a quienes habías visto."])
			rehacer()
		end)
	a.Preguntar = W.ActionRow(view, L["Volver a preguntar"], L["Muestra otra vez la pregunta de si compartes tu ubicación."],
		L["Preguntar"], function() P.Preguntar(true) end)
	a.Nota = texto(view, "small", "textMuted", true)
	a.Nota:SetText(L["Qué se envía: tu zona y posición en el mapa, tu nivel y tu clase. A quién: solo a tu hermandad y, si lo activas, a tus amigos con Alfa. Cuándo: cada 10 segundos mientras te mueves y cada 4 minutos si estás quieto. Nunca a canales públicos, nunca dentro de mazmorras. Lo que recibes de otros se borra solo a los 5 minutos."])
	return a
end

local function filasEnPanel(view, panel, filasLista, x, y, ancho)
	local top = y
	-- (Sin :Refresh aquí: los ajustes se repintan solos al cambiar, y uno de
	-- más cortaría la animación del interruptor.)
	for i, row in ipairs(filasLista) do
		colocar(row, view, x, y)
		row:Show()
		y = y + num(W.LayoutRow(row, ancho), 50)
		if row.Rule then row.Rule:SetShown(i < #filasLista) end
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", view, "TOPLEFT", x, -top)
	panel:SetSize(ancho, max(1, y - top))
	local ok, skin = pcall(T.SkinKey)
	panel:SetShown(not ok or skin == "alfa")
	return y
end

local function pintarAjustes(a, view, x, y, ancho)
	for _, g in ipairs(a.grupos) do
		g.h:SetWidth(ancho)
		colocar(g.h, view, x, y)
		g.h:Show()
		y = y + num(W.PLAIN_SECTION_H, 30)
		y = filasEnPanel(view, g.panel, g.filas, x, y, ancho) + 22
	end
	a.EstadoH:SetWidth(ancho)
	colocar(a.EstadoH, view, x, y)
	a.EstadoH:Show()
	y = y + num(W.PLAIN_SECTION_H, 30)
	local s = estadoUbicacion()
	local env = M.Red.UltimoEnvio()
	if env and N.Get(ID, "red") and (N.Get(ID, "compartir") or N.Get(ID, "compartirAmigos")) then
		s = s .. "  " .. L["Última posición enviada %s."]:format(U.Hace(env))
	end
	a.Ahora.Value:SetText("")
	a.Ahora.psDesc = s
	W.RowDetails(a.Ahora, { inset = 16 })
	local con, usan = M.Gente.Cuentas()
	a.Alfa.Value:SetText(U.EnHermandad() and L["%d con Alfa · %d conectados"]:format(usan, con) or L["Sin hermandad"])
	W.RowDetails(a.Alfa, { inset = 16 })
	W.RowDetails(a.Olvidar, { inset = 16 })
	W.RowDetails(a.Preguntar, { inset = 16 })
	y = filasEnPanel(view, a.EstadoPanel, { a.Ahora, a.Alfa, a.Preguntar, a.Olvidar }, x, y, ancho) + 16
	a.Nota:SetWidth(ancho)
	colocar(a.Nota, view, x, y)
	a.Nota:Show()
	y = y + altoTexto(a.Nota, 12)
	return y
end

local function ocultarAjustes(a)
	for _, g in ipairs(a.grupos) do
		g.h:Hide()
		g.panel:Hide()
		for _, row in ipairs(g.filas) do row:Hide() end
	end
	for _, k in ipairs({ "EstadoH", "EstadoPanel", "Ahora", "Alfa", "Olvidar", "Preguntar", "Nota" }) do a[k]:Hide() end
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local ticker

local function alMostrar()
	local G = M.Gente
	G.PedirHermandad()
	G.PedirAmigos()
	if not N.Datos(ID).preguntado and U.EnHermandad() then P.Preguntar() end
	if not ticker then
		local version, sigue = -1, nil
		ticker = A.NewTicker(REFRESCO, function()
			local view = P.view
			if not (view and view:IsVisible()) then return end
			-- Las distancias cambian al caminar: Manada y Ajustes se rehacen siempre.
			if actual == "clan" and version == G.version and sigue == M.Seguir.Actual() then return end
			version, sigue = G.version, M.Seguir.Actual()
			rehacer()
		end)
	end
end

local function alOcultar()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

function P.Construir(view)
	P.view = view
	-- Quien aún no es de la manada llega a la cara del clan; quien ya es, a su gente.
	actual = actual or (U.EnElClan() and "manada" or "clan")
	local hero = construirInsignia(view)
	local barra = construirBarra(view)
	local m = construirManada(view)
	local c = construirClan(view)
	local a = construirAjustes(view)
	view:HookScript("OnShow", alMostrar)
	view:HookScript("OnHide", alOcultar)
	view.Refresh = function()
		local x, ancho = margen(), anchoCuerpo()
		local y = 12
		colocar(hero, view, x, y)
		pintarInsignia(hero, ancho)
		y = y + HERO_H + 14
		colocar(barra, view, x, y)
		pintarBarra(barra, ancho)
		y = y + 34 + 16
		if actual == "manada" then
			ocultarClan(c)
			ocultarAjustes(a)
			y = pintarManada(m, view, x, y, ancho)
		elseif actual == "clan" then
			ocultarManada(m)
			ocultarAjustes(a)
			y = pintarClan(c, view, x, y, ancho)
		else
			ocultarManada(m)
			ocultarClan(c)
			y = pintarAjustes(a, view, x, y, ancho)
		end
		return y + 24
	end
	alMostrar()
end

-- Abre la página en una sección ("manada", "clan" o "ajustes").
function P.Abrir(seccion)
	if seccion then actual = seccion end
	N.Abrir(ID)
	rehacer()
end
