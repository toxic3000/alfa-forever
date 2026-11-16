-- Alfa - Mundo: la página del módulo, sus comandos y su tecla (Toxic / La
-- Jauría). GPL-3.0.
--
-- La página tiene arriba el mapa y el modo limpio, después las capas por
-- grupo (lo más importante: todo lo que se pinta en tus mapas, en un solo
-- lugar) y al final los ajustes del mapa de Alfa y cómo se usa.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = N.Textos(M.EN)
local W, T = A.Widgets, A.Theme
local Capas, V, Lz = M.Capas, M.Ventana, M.Lienzo

local type, ipairs, pairs, tonumber, max, floor, format = type, ipairs, pairs, tonumber, math.max, math.floor, string.format

local ID = "mundo"

-- La tecla propia (Bindings.xml) en Opciones > Teclado > Alfa.
BINDING_NAME_ALFA_MUNDO_MAPA = L["Abrir o cerrar el mapa de Alfa"]

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function anchoCuerpo()
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	return tonumber(win and win.BodyWidth) or 640
end

local function margen()
	local SH = W.SHELL
	return tonumber(SH and SH.pad) or 24
end

local function rearmar(view)
	if not (view and view.Refresh) then return end
	local h = view.Refresh()
	view:SetHeight(h)
	local O = A.UI and A.UI.Options
	local win = O and O.frame
	if win and view:IsShown() and W.ShellBody then W.ShellBody(win, h) end
end

-- "|T...|t  Nombre": el ícono de la capa en su color, delante del nombre.
local function etiqueta(e)
	local icono = e.icono
	if type(icono) ~= "string" then return e.nombre end
	local r, g, b = 1, 1, 1
	if e.color and T and type(T.Color) == "function" then r, g, b = T.Color(e.color) end
	r, g, b = tonumber(r) or 1, tonumber(g) or 1, tonumber(b) or 1
	return format("|T%s:16:16:0:0:64:64:0:64:0:64:%d:%d:%d|t  %s", icono, floor(r * 255 + 0.5), floor(g * 255 + 0.5), floor(b * 255 + 0.5), e.nombre)
end

-- Un control de las filas estándar de la ventana de Alfa para una capa.
local controles = {}
local function control(e)
	local c = controles[e]
	if c then return c end
	local ayuda = e.ayuda
	if e.esencial then ayuda = (ayuda and (ayuda .. " ") or "") .. L["Se queda en el modo limpio."] end
	c = {
		kind = "toggle", key = Capas.Ruta(e), label = etiqueta(e), help = ayuda,
		get = function() return Capas.Valor(e) end,
		set = function(v)
			if v == nil then v = Capas.PorOmision(e) end
			Capas.Poner(e, v)
		end,
		disabled = function() return not Capas.Disponible(e) end,
	}
	controles[e] = c
	return c
end

local AJUSTES = {
	{ kind = "toggle", key = "mundo.teclaM", label = L["Abrir el mapa de Alfa con la tecla del mapa (M)"],
		help = L["La tecla que abre el mapa del juego abre el de Alfa. Apágalo y vuelve a abrir el del juego. También puedes darle una tecla propia en Opciones > Teclado > Alfa."] },
	{ kind = "toggle", key = "mundo.botonMapa", label = L["Botones de Alfa en el mapa del juego"],
		help = L["Junto a la lupa del mapa del juego: las capas, el modo limpio y el mapa de Alfa."] },
	{ kind = "toggle", key = "mundo.menuMapa", label = L["Capas en la lupa del mapa del juego"],
		help = L["El menú de la lupa del mapa del juego tiene también todas las capas de Alfa."] },
	{ kind = "dropdown", key = "maps.reveal", label = L["Cómo se ven las zonas sin descubrir"],
		help = L["Ocultas como en el juego, reveladas, o reveladas con un tono más frío para saber dónde no has estado."],
		choices = { { value = "off", label = L["Ocultas"] }, { value = "on", label = L["Reveladas"] }, { value = "tint", label = L["Reveladas con otro tono"] } } },
	{ kind = "toggle", key = "mundo.detalle", label = L["Detalle fino de cada zona"],
		help = L["Dibuja el arte completo de cada zona recortado a su forma, con las texturas de detalle incluidas. Sin ellas el mapa sigue completo, solo más suave entre zona y zona."],
		disabled = function() return not Lz.HayTexturas() end },
}

local AYUDA = {
	L["Rueda del ratón: acercar o alejar donde está el cursor."],
	L["Arrastrar: mover el mapa. Doble clic: acercar. Clic derecho: alejar."],
	L["Mayús+clic en el mapa: la flecha te lleva a ese punto."],
	L["/alfa mapa abre el mapa, /alfa limpio cambia el modo limpio y /alfa mundo abre esta página."],
}

local function construir(view)
	view.cache, view.headers, view.panels = view.cache or {}, view.headers or {}, view.panels or {}
	local tAbrir = W.ActionTile(view, "icon-explore", L["Abrir el mapa del mundo"],
		L["Un solo mapa continuo: acerca, aleja y pasa de una zona a otra sin cambiar de mapa."], function() V.Abrir() end)
	local tLimpio = W.ActionTile(view, "compact", L["Activar el modo limpio"], "", function() Capas.AlternarLimpio() end)
	local nota = W.Text(view, "note", "textDim")
	nota:SetWordWrap(true)
	nota:SetJustifyV("TOP")
	nota:SetText(L["Aquí decides qué se pinta en tus mapas: el de Alfa, el del juego y el minimapa. Si algo te estorba, apágalo aquí; los otros módulos de Alfa agregan sus capas a esta misma lista."])
	local ayuda = W.Text(view, "note", "textDim")
	ayuda:SetWordWrap(true)
	ayuda:SetJustifyV("TOP")
	ayuda:SetSpacing(4)
	ayuda:SetText("·  " .. table.concat(AYUDA, "\n·  "))
	local O = A.UI and A.UI.Options
	local sinTexturas = W.Text(view, "small", "textMuted")
	sinTexturas:SetWordWrap(true)

	local function seccion(n, nombre, controlesSec, y, ancho, pad)
		local h = view.headers[n]
		if not h then
			h = W.SectionHeader(view, { plain = true })
			view.headers[n] = h
		end
		local panel = view.panels[n]
		if not panel then
			panel = W.RowPanel(view)
			view.panels[n] = panel
		end
		W.SetSection(h, nombre)
		h:ClearAllPoints()
		h:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -y)
		h:SetWidth(ancho)
		h:Show()
		y = y + (tonumber(W.PLAIN_SECTION_H) or 30)
		if O and O.Rows then
			y = tonumber(O.Rows(view, controlesSec, y, view.cache, panel)) or y
		end
		return y + 22
	end

	view.Refresh = function()
		local ancho, pad = anchoCuerpo(), margen()
		for _, w in pairs(view.cache) do w:Hide() end
		local y = 10
		-- El mapa y el modo limpio
		local cw = floor((ancho - 16) / 2)
		local limpio = Capas.Limpio()
		tLimpio.Title:SetText(limpio and L["Salir del modo limpio"] or L["Activar el modo limpio"])
		tLimpio.psTitle = tLimpio.Title:GetText()
		local n = Capas.CuantasOcultas()
		tLimpio.Desc:SetText(limpio and (n > 0 and format(L["%d capas ocultas. Al salir vuelven como estaban."], n) or L["Solo tú, tu grupo y el siguiente paso de la guía."])
			or L["Un clic y queda solo lo esencial: tú, tu grupo y el siguiente paso de la guía."])
		tAbrir:ClearAllPoints()
		tAbrir:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -y)
		tLimpio:ClearAllPoints()
		tLimpio:SetPoint("TOPLEFT", view, "TOPLEFT", pad + cw + 16, -y)
		local h = max(tonumber(W.LayoutTile(tAbrir, cw)) or 60, tonumber(W.LayoutTile(tLimpio, cw)) or 60)
		tAbrir:SetHeight(h)
		tLimpio:SetHeight(h)
		tAbrir:Show()
		tLimpio:Show()
		y = y + h + 18
		nota:ClearAllPoints()
		nota:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -y)
		nota:SetWidth(ancho)
		y = y + (tonumber(nota:GetStringHeight()) or 30) + 16
		-- Las capas, grupo por grupo
		local s = 0
		for _, g in ipairs(Capas.Grupos()) do
			local lista = {}
			for _, e in ipairs(g.capas) do lista[#lista + 1] = control(e) end
			s = s + 1
			y = seccion(s, g.nombre, lista, y, ancho, pad)
		end
		-- El mapa de Alfa
		s = s + 1
		y = seccion(s, L["El mapa de Alfa"], AJUSTES, y, ancho, pad)
		if not Lz.HayTexturas() then
			sinTexturas:SetText(L["Faltan las texturas de detalle en la carpeta Media de Alfa_Mundo: el mapa se dibuja solo con el arte del juego."])
			sinTexturas:ClearAllPoints()
			sinTexturas:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -(y - 14))
			sinTexturas:SetWidth(ancho)
			sinTexturas:Show()
			y = y + (tonumber(sinTexturas:GetStringHeight()) or 14) + 8
		else
			sinTexturas:Hide()
		end
		for i = s + 1, #view.headers do view.headers[i]:Hide() end
		for i = s + 1, #view.panels do view.panels[i]:Hide() end
		-- Cómo se usa
		local hAyuda = view.ayudaH
		if not hAyuda then
			hAyuda = W.SectionHeader(view, { plain = true })
			view.ayudaH = hAyuda
		end
		W.SetSection(hAyuda, L["Cómo se usa"])
		hAyuda:ClearAllPoints()
		hAyuda:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -y)
		hAyuda:SetWidth(ancho)
		y = y + (tonumber(W.PLAIN_SECTION_H) or 30)
		ayuda:ClearAllPoints()
		ayuda:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -y)
		ayuda:SetWidth(ancho)
		y = y + (tonumber(ayuda:GetStringHeight()) or 60)
		return y + 28
	end

	-- Capas nuevas (de módulos que cargan después) o el modo limpio: la
	-- página se rearma si está a la vista.
	local version, limpio = Capas.version, Capas.Limpio()
	Capas.AlCambiar(function()
		if not view:IsShown() then return end
		if Capas.version ~= version or Capas.Limpio() ~= limpio then
			version, limpio = Capas.version, Capas.Limpio()
			rearmar(view)
		end
	end)
	view:HookScript("OnShow", function()
		if Capas.version ~= version then
			version = Capas.version
			rearmar(view)
		end
	end)
end

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = ID, nombre = L["Mundo"], icono = "icon-explore", orden = 31,
	subtitulo = L["Un mapa limpio con un solo control para todo lo que se pinta."],
	comando = "mundo",
	ajustes = {
		grupo = true,       -- tu grupo en el mapa de Alfa (esencial)
		nombres = true,     -- nombres de zona en el mapa de Alfa
		detalle = true,     -- arte base de cada zona con las texturas de detalle
		botonMapa = true,   -- botones de Alfa junto a la lupa del mapa del juego
		menuMapa = true,    -- las capas en el menú de la lupa
		teclaM = false,     -- la tecla del mapa abre el de Alfa
		ventana = false,    -- { "CENTER", x, y, ancho, alto } al moverla
	},
	construir = construir,
})

A.RegisterCommand("mapa", function() V.Alternar() end, L["Abre o cierra el mapa de Alfa"])
A.RegisterCommand("limpio", function()
	Capas.AlternarLimpio()
	N.Imprimir(Capas.Limpio() and L["Modo limpio encendido: solo tú, tu grupo y la guía."] or L["Modo limpio apagado: tus capas volvieron como estaban."])
end, L["Cambia el modo limpio del mapa"])

-- La primera vez: las entradas de mazmorras se marcan (el motor las trae
-- apagadas). Si después las apagas, se quedan apagadas.
if type(A.OnLogin) == "function" then
	A.OnLogin(function()
		local d = N.Datos(ID)
		if d.iniciado then return end
		d.iniciado = 1
		if A.Get("maps.dungeonPins") == false then A.Set("maps.dungeonPins", true) end
	end)
end
