-- Alfa - La Jauría: su página en la ventana de Alfa, hecha con el Kit.
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Un Tablero (docs/KIT.md) que guía de arriba abajo:
--   1. Lo que toca ahora, en grande: compartir tu rastro, a quién sigues, en
--      pausa, quién anda más cerca (Seguir con la flecha, Invitar) o, si no hay
--      nadie, cómo invitar a la manada.
--   2. La manada a la vista: tu grupo y los usuarios de Alfa que comparten, en
--      tarjetas con su color de clase, dónde andan y a qué distancia, con
--      Seguir e Invitar. Si no hay nadie, la sección no sale.
--   3. El clan: La Jauría, su lema, lo que ofrece, su Discord para copiar y
--      "Quiero unirme".
--   4. En memoria de Lya: la tarjeta de su recuerdo (Alfa_Lya). Las donaciones no
--      van en el juego (reglas de Blizzard): viven en CurseForge, GitHub y Discord.
--   5. Los ajustes: tu rastro (compartir) y qué se ve en el mapa.
-- Mientras la página está a la vista se revisa cada REFRESCO segundos y se
-- rehace solo si algo de lo que muestra cambió (distancias, quién, dónde).
--
-- La pregunta de compartir (P.Preguntar) es un diálogo del Kit; la usa
-- AlfaManada.PreguntarCompartir() (Manada.lua) y el botón de la página.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local U, L, ID = M.U, M.L, M.ID

local P = {}
M.Pagina = P

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ESP = K.ESP

local REFRESCO = 2
local VISIBLES = 6 -- tarjetas antes de "Ver todos"
local DOT = "  \194\183  "

local function on(clave) return N.Get(ID, clave) and true or false end

-- Algo cambió: la página se rehace si está a la vista.
function M.Avisar()
	local view = P.view
	if view then N.RehacerPagina(view) end
end
P.Rehacer = M.Avisar

---------------------------------------------------------------------------
-- Textos de una persona
---------------------------------------------------------------------------

local function nivelClase(f)
	local partes = {}
	if f.nivel then partes[#partes + 1] = format(L["Nivel %d"], f.nivel) end
	local c = U.NombreClase(f.clase)
	if c then partes[#partes + 1] = c end
	return table.concat(partes, " \194\183 ")
end

-- `sinDistancia`: cuando el título ya la dice.
local function lugar(f, sinDistancia)
	if f.conectado == false then return L["Desconectado"] end
	if not f.map then
		return f.tipo == "grupo" and L["Sin ubicación ahora: en una instancia o fuera del mapa"] or L["Sin ubicación"]
	end
	local partes = {}
	if f.zona then partes[#partes + 1] = f.zona end
	if f.dist then
		if not sinDistancia then partes[#partes + 1] = U.TextoDistancia(f.dist) end
	elseif f.otro then
		partes[#partes + 1] = L["otro continente"]
	end
	if f.tipo ~= "grupo" and f.edad and f.edad >= M.Gente.VIEJA then partes[#partes + 1] = format(L["ubicación de %s"], U.Hace(f.edad)) end
	if f.muerto then partes[#partes + 1] = L["Muerto"] end
	return table.concat(partes, DOT)
end

local function puedeSeguir(f)
	return f ~= nil and f.conectado ~= false and f.map ~= nil and not U.EnInstancia()
end

local function invitable(f)
	return f ~= nil and f.conectado ~= false and f.tipo ~= "grupo" and not U.EnMiGrupo(f.envio or f.nombre)
end

local function invitar(f)
	if U.Invitar(f.envio or f.nombre) then
		U.Decir(format(L["Invitaste a %s a tu grupo."], f.nombre or "?"))
	end
end

local function seguir(f)
	local S = M.Seguir
	if S.Sigue(f.clave) then S.Parar() else S.A(f) end
	M.Avisar()
end

---------------------------------------------------------------------------
-- 1. Lo que toca ahora
---------------------------------------------------------------------------

local function buscar(gente, clave)
	for _, f in ipairs(gente) do if f.clave == clave then return f end end
	return nil
end

local PAUSA = {
	instancia = { "En pausa dentro de la instancia", "Aquí el juego no deja compartir nada. Al salir, tu rastro vuelve a salir solo." },
	bloqueo = { "En pausa por ahora", "El juego no deja enviar mensajes en este momento (un encuentro o una partida). Tu rastro vuelve a salir solo cuando termine." },
	prueba = { "Una cuenta de prueba no puede compartir", "El juego no deja que las cuentas de prueba envíen mensajes de addon ni usen canales propios. Tu grupo sí se ve." },
	sinapi = { "Este cliente no deja compartir", "Falta la función del juego para enviar mensajes de addon. Tu grupo sí se ve." },
}

local function accion(ui, gente)
	local S, R = M.Seguir, M.Red
	local n = #gente

	-- A quién sigues.
	local s = S.Actual()
	if s then
		local f = buscar(gente, s.clave)
		return {
			icono = "ic-seguir", tono = "exito", sobre = U.Mayus(L["Siguiendo el rastro"]),
			titulo = format(L["Vas tras %s"], s.nombre or "?"),
			texto = (f and f.map and (lugar(f) .. ". ") or (L["Buscando su rastro..."] .. " "))
				.. L["La flecha se mueve con su rastro y se detiene al llegar."],
			accion = { texto = L["Dejar de seguir"], icono = "ic-cerrar", alClic = function() S.Parar() M.Avisar() end },
			secundaria = invitable(f) and { texto = L["Invitar al grupo"], alClic = function() invitar(f) end } or nil,
		}
	end

	-- No compartes: lo primero es decidirlo.
	if not on("compartir") then
		return {
			lobo = "atento", tono = "acento", sobre = U.Mayus(L["La Jauría"]),
			titulo = L["Deja que la manada te vea en el mapa"],
			texto = L["Si quieres, tu personaje aparece en el mapa del juego de los lobos que usan Alfa, y ellos en el tuyo: quién anda cerca, dónde y, con un clic, la flecha te lleva. Solo es el lugar de tu personaje dentro de WoW, nunca tu ubicación real. Tu grupo se ve siempre."],
			accion = { texto = L["Que me vean en el mapa"], icono = "ic-manada", alClic = function() P.Preguntar() end },
		}
	end

	-- Compartes, pero el juego no deja enviar ahora.
	local puede, por = R.PuedeEnviar()
	if not puede and PAUSA[por] then
		return { icono = (por == "instancia" or por == "bloqueo") and "ic-reloj" or "ic-aviso", tono = "aviso",
			sobre = U.Mayus(L["Tu rastro"]), titulo = L[PAUSA[por][1]], texto = L[PAUSA[por][2]],
			estado = { texto = L["En pausa"], tono = "aviso" } }
	end

	-- Lo más cerca: el primero de la lista con posición.
	local f = gente[1]
	if f and f.map then
		local titulo
		if f.dist then
			titulo = format(L["%s anda a %s"], f.nombre or "?", U.TextoDistancia(f.dist))
		elseif f.zona then
			titulo = format(L["%s anda por %s"], f.nombre or "?", f.zona)
		else
			titulo = f.nombre or "?"
		end
		local partes = {}
		local nc, lg = nivelClase(f), lugar(f, f.dist ~= nil)
		if nc ~= "" then partes[#partes + 1] = nc end
		if lg ~= "" then partes[#partes + 1] = lg end
		local texto = table.concat(partes, DOT)
		texto = (texto ~= "" and (texto .. ". ") or "")
			.. (n == 1 and L["Es el único lobo a la vista."] or format(L["%d lobos a la vista: los ves abajo y en tu mapa."], n))
		local ins = { { f.tipo == "grupo" and L["Tu grupo"] or L["La Jauría"], f.tipo == "grupo" and "clase" or "acento" } }
		return {
			icono = "ic-huella", tono = "acento", sobre = U.Mayus(L["Lo más cerca"]), titulo = titulo, texto = texto, insignias = ins,
			accion = { texto = format(L["Seguir a %s"], M.Mapa.Corto(f.nombre)), icono = "ic-seguir", alClic = function() seguir(f) end },
			secundaria = invitable(f) and { texto = L["Invitar al grupo"], alClic = function() invitar(f) end } or nil,
		}
	end

	-- Sin camino para compartir todavía.
	local via, porVia = R.Via()
	if not via then
		if porVia == "entrando" then
			return { icono = "ic-reloj", tono = "neutro", sobre = U.Mayus(L["Tu rastro"]), titulo = L["Buscando a la manada…"],
				texto = L["Alfa se está uniendo al canal oculto de La Jauría. En unos segundos ves a quien comparte."] }
		end
		return {
			icono = "ic-aviso", tono = "aviso", sobre = U.Mayus(L["Tu rastro"]), titulo = L["No pudimos unirnos al canal de la manada"],
			texto = L["El juego no dejó entrar al canal oculto de Alfa y, sin hermandad, no hay otro camino para compartir. Alfa lo vuelve a intentar sola en unos minutos. Tu grupo sí se ve."],
			accion = { texto = L["Intentar ahora"], icono = "ic-seguir", alClic = function() M.Canal.Querer(true) M.Avisar() end },
		}
	end

	-- Gente sin ubicación (tu grupo en una mazmorra, desconectados).
	if n > 0 then
		return { icono = "ic-manada", tono = "neutro", sobre = U.Mayus(L["Tu rastro"]), titulo = L["Tu manada está fuera del mapa"],
			texto = L["Nadie a la vista tiene ubicación ahora: en una instancia o desconectados. Cuando vuelvan al mundo, aparecen aquí y en tu mapa."] }
	end

	-- Nadie a la vista: cómo hacer crecer la manada.
	return {
		lobo = "dormido", tono = "neutro", sobre = U.Mayus(L["La manada te ve en el mapa"]),
		titulo = L["Nadie de la manada a la vista"],
		texto = L["Cuando otro lobo con Alfa comparta su ubicación, aparece aquí y en tu mapa. Para que la manada crezca, invita a tus amigos: que instalen Alfa, acepten compartir y entren al Discord de La Jauría."],
		accion = { texto = L["Copiar el Discord"], icono = "ic-manada", alClic = function() if ui.clan then ui.clan:IrAlDiscord() end end },
	}
end

---------------------------------------------------------------------------
-- 2. La manada a la vista
---------------------------------------------------------------------------

local function datoPersona(f)
	local S = M.Seguir
	local siguiendo = S.Sigue(f.clave)
	local nc = nivelClase(f)
	return {
		variante = "normal", icono = "ic-huella",
		sobre = U.Mayus(siguiendo and L["Siguiendo"] or (f.tipo == "grupo" and L["Tu grupo"] or L["La Jauría"])),
		titulo = f.nombre or "?",
		texto = (nc ~= "" and (nc .. "\n") or "") .. lugar(f),
		accion = { texto = siguiendo and L["Dejar de seguir"] or L["Seguir"], icono = siguiendo and "ic-cerrar" or "ic-seguir", alClic = function() seguir(f) end },
		secundaria = invitable(f) and { texto = L["Invitar"], alClic = function() invitar(f) end } or nil,
		persona = f,
	}
end

-- Las tarjetas toman el color de la clase de cada uno (huella y nombre).
local function pintarPersonas(rejilla, lista)
	for i, c in ipairs(rejilla.elementos or {}) do
		local d = lista[i]
		local f = d and d.persona
		if f then
			local fuera = f.conectado == false
			local r, g, b = U.ColorClase(f.clase)
			c.Icono.alfaColor = { r, g, b, fuera and 0.4 or 1 }
			c.Icono:SetVertexColor(r, g, b, fuera and 0.4 or 1)
			local tr, tg, tb = U.ColorTexto(f.clase)
			K.ColorTexto(c.Titulo, fuera and "textoTenue" or { tr, tg, tb, 1 })
			if c.Accion then c.Accion:SetActivo(M.Seguir.Sigue(f.clave) or puedeSeguir(f)) end
		end
	end
end

---------------------------------------------------------------------------
-- 3. El clan
---------------------------------------------------------------------------

local function enlaceDiscord()
	local d = M.Clan and M.Clan.discord
	if type(d) == "string" and d ~= "" then return d end
	return type(A.DiscordURL) == "string" and A.DiscordURL or ""
end

-- Un enlace para copiar: se elige todo al hacer clic y no se puede cambiar.
local function campoCopiar(padre)
	local c = CreateFrame("Frame", nil, padre)
	c:SetHeight(K.ALTO.control)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, c)
	c.Campo = e
	e:SetAutoFocus(false)
	e:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	e:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
	e:SetHeight(K.ALTO.control - 4)
	K.Pintar(e, function(x)
		x:SetFont(K.Cara("medium"), K.Tamano("cuerpo"), "")
		x:SetTextColor(K.Color("texto"))
	end)
	e:SetScript("OnTextChanged", function(self, usuario)
		if usuario and self:GetText() ~= (c.texto or "") then
			self:SetText(c.texto or "")
			self:HighlightText()
		end
	end)
	e:SetScript("OnEditFocusGained", function(self)
		self:HighlightText()
		c.caja:Estilo({ borde = "acento", alfaBorde = 0.8 })
	end)
	e:SetScript("OnEditFocusLost", function(self)
		self:HighlightText(0, 0)
		c.caja:Estilo({ borde = "lineaFuerte", alfaBorde = 1 })
	end)
	e:SetScript("OnMouseUp", function(self) self:HighlightText() end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	function c:Set(t)
		self.texto = t or ""
		e:SetText(self.texto)
		e:SetCursorPosition(0)
	end
	function c:Copiar()
		e:SetFocus()
		e:HighlightText()
	end
	return c
end

local function alUnirse(ui)
	if U.EnElClan() then return end
	local R = M.Red
	if R.Buscando() then return end
	local u = ui.unirse
	local oficiales = (M.Clan and M.Clan.oficiales) or {}
	-- Sin oficiales anotados (Clan.lua): "Quiero unirme" lleva al Discord.
	if #oficiales == 0 then
		if ui.clan then ui.clan:IrAlDiscord() end
		return
	end
	local mensaje = U.TextoClan("mensajeUnirse") or ""
	u.estado, u.quien = "buscando", nil
	R.BuscarOficial(oficiales, function(nombre, por)
		if nombre then
			u.estado, u.quien = "listo", U.Mostrar(nombre)
			U.Susurrar(nombre, mensaje)
			U.Decir(format(L["Te abrimos un susurro para %s con tu mensaje. Revísalo y pulsa Intro para enviarlo."], U.Mostrar(nombre)))
		else
			u.estado = por == "nopuede" and "nopuede" or "nadie"
		end
		M.Avisar()
	end)
	M.Avisar()
end

local function bloqueClan(ui, padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Marca = K.Marca(b, K.CORTE.panel)
	b.Lobo = b:CreateTexture(nil, "ARTWORK")
	b.Lobo:SetSize(72, 72)
	b.Lobo:SetTexture(K.Lobo("aullando"))
	K.Pintar(b.Lobo, function(t) t:SetVertexColor(K.Color("acento")) end)
	b.Sobre = K.Texto(b, "mayus", "acento")
	b.Nombre = K.Texto(b, "portada", "texto")
	b.Lema = K.Texto(b, "texto", "textoSuave")
	b.Miembro = K.Insignia(b, "", "exito")
	b.Desc = K.Texto(b, "texto", "textoSuave")
	b.OfreceT = K.Texto(b, "encabezado", "texto")
	b.ofrece = {}
	b.Linea1 = K.Linea(b, "linea")
	b.DiscordIcono = K.Icono(b, "discord", 20, "texto")
	b.DiscordT = K.Texto(b, "cuerpo", "texto")
	b.DiscordN = K.Texto(b, "nota", "textoSuave")
	b.Campo = campoCopiar(b)
	b.Copiar = K.Boton(b, L["Copiar"], function() b.Campo:Copiar() end, { tipo = "secundario" })
	b.Linea2 = K.Linea(b, "linea")
	b.UnirseT = K.Texto(b, "texto", "textoSuave")
	b.Unirse = K.Boton(b, L["Quiero unirme"], function() alUnirse(ui) end, { tipo = "primario", icono = "ic-manada" })
	b.Estado = K.Texto(b, "nota", "textoSuave")
	b.escribir = {}
	b.Oficiales = K.Texto(b, "pequeno", "textoTenue")
	b.Aviso = K.Texto(b, "nota", "aviso")
	-- El motor rechaza las invitaciones (Ajustes > Calidad de vida > Social): un clic lo apaga.
	b.Apagar = K.Boton(b, L["Apagarlo"], function()
		if A.Set then A.Set("qol.declineGuildInvites", false) end
		M.Avisar()
	end, { tipo = "secundario", tam = "chico" })

	function b:Llenar()
		K.Escribir(self.Sobre, U.Mayus(L["El clan"]))
		K.Escribir(self.Nombre, U.TextoClan("nombre") or L["La Jauría"])
		K.Escribir(self.Lema, U.TextoClan("lema") or "")
		local miembro = U.EnElClan()
		self.Miembro:Set(miembro and L["Eres de la manada"] or nil, "exito", "ic-exito")
		local desc = U.TextoClan("descripcion")
		if type(desc) == "table" then desc = table.concat(desc, "\n\n") end
		K.Escribir(self.Desc, desc or "")
		local ofrece = U.TextoClan("ofrecemos")
		ofrece = type(ofrece) == "table" and ofrece or {}
		K.Escribir(self.OfreceT, #ofrece > 0 and L["Lo que encuentras en la manada"] or "")
		for i, t in ipairs(ofrece) do
			local o = self.ofrece[i]
			if not o then
				o = { Icono = K.Icono(self, "ic-huella", 14, "acento"), Texto = K.Texto(self, "nota", "texto") }
				self.ofrece[i] = o
			end
			K.Escribir(o.Texto, t)
			o.Icono:Show()
			o.Texto:Show()
		end
		for i = #ofrece + 1, #self.ofrece do
			self.ofrece[i].Icono:Hide()
			self.ofrece[i].Texto:Hide()
		end
		self.nOfrece = #ofrece
		K.Escribir(self.DiscordT, L["El Discord de La Jauría"])
		K.Escribir(self.DiscordN, L["Ahí nos organizamos para todo. Haz clic en el enlace y cópialo con Ctrl+C."])
		self.Campo:Set(enlaceDiscord())
		-- Unirse: solo para quien aún no es de la hermandad del clan.
		self.alfaUnirse = not miembro
		local u = ui.unirse
		local buscando = M.Red.Buscando()
		K.Escribir(self.UnirseT, L["¿Quieres cazar con nosotros? Pulsa el botón: Alfa busca a un oficial conectado y te abre un susurro con tu mensaje listo para que lo envíes con Intro."])
		self.Unirse:SetTexto(buscando and L["Buscando a un oficial..."] or L["Quiero unirme"])
		self.Unirse:SetActivo(not buscando)
		local como = U.TextoClan("comoUnirse") or ""
		local estado = ""
		if u.estado == "listo" then
			estado = format(L["Listo: te abrimos un susurro para %s. Revisa el mensaje y pulsa Intro."], u.quien or "?")
		elseif u.estado == "nadie" then
			estado = format(L["Ningún oficial respondió ahora. %s"], como)
		elseif u.estado == "nopuede" then
			estado = format(L["Ahora no se pueden enviar mensajes (en una instancia o con una cuenta de prueba). %s"], como)
		end
		K.Escribir(self.Estado, estado)
		-- Nadie respondió: escribirles a mano, con un clic.
		local of = (M.Clan and M.Clan.oficiales) or {}
		local manual = u.estado == "nadie" or u.estado == "nopuede"
		self.nEscribir = 0
		for i = 1, 3 do
			local nombre = of[i]
			local bt = self.escribir[i]
			if manual and nombre and U.Clave(nombre) ~= U.MiClave() then
				if not bt then
					bt = K.Boton(self, "", function(x) U.Susurrar(x.alfaNombre, U.TextoClan("mensajeUnirse") or "") end,
						{ tipo = "secundario", tam = "chico", ayuda = L["Abre un susurro con tu mensaje listo. Si no está conectado, el juego te lo dirá."] })
					self.escribir[i] = bt
				end
				bt.alfaNombre = nombre
				bt:SetTexto(format(L["Escribir a %s"], U.Mostrar(nombre)))
				bt:Show()
				self.nEscribir = self.nEscribir + 1
			elseif bt then
				bt:Hide()
			end
		end
		local nombres = {}
		for i, nm in ipairs(of) do nombres[i] = U.Mostrar(nm) end
		K.Escribir(self.Oficiales, #nombres > 0 and format(L["Oficiales: %s"], table.concat(nombres, ", ")) or "")
		local rechaza = A.Get and A.Get("qol.declineGuildInvites") and true or false
		K.Escribir(self.Aviso, rechaza
			and L["Tienes activado «Rechazar invitaciones a hermandad» en Ajustes > Calidad de vida > Social: apágalo para que te llegue la invitación."] or "")
		for _, x in ipairs({ self.Linea2, self.UnirseT, self.Unirse, self.Estado, self.Oficiales, self.Aviso }) do x:SetShown(self.alfaUnirse) end
		self.Apagar:SetShown(self.alfaUnirse and rechaza or false)
		if not self.alfaUnirse then for _, bt in ipairs(self.escribir) do bt:Hide() end end
	end

	local function en(x, px, py)
		x:ClearAllPoints()
		x:SetPoint("TOPLEFT", b, "TOPLEFT", px, -py)
	end

	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		local pad = ESP.l
		local w = ancho - 2 * pad
		-- La cabeza: el lobo aullando, el nombre y el lema.
		en(self.Lobo, pad, pad)
		local xt = pad + 72 + ESP.base
		local tw = max(80, ancho - xt - pad)
		self.Sobre:SetWidth(tw)
		local hs = K.AltoTexto(self.Sobre)
		local mw = self.Miembro:IsShown() and (K.num(self.Miembro:GetWidth(), 0) + ESP.m) or 0
		K.Ajustar(self.Nombre, tw - mw)
		local hn = K.AltoTexto(self.Nombre)
		local hl = (self.Lema:GetText() or "") ~= "" and K.Parrafo(self.Lema, tw, 2) or 0
		local total = hs + 4 + hn + (hl > 0 and (4 + hl) or 0)
		local yt = pad + max(0, floor((72 - total) / 2))
		en(self.Sobre, xt, yt)
		yt = yt + hs + 4
		en(self.Nombre, xt, yt)
		self.Miembro:ClearAllPoints()
		self.Miembro:SetPoint("LEFT", self.Nombre, "RIGHT", ESP.m, 0)
		yt = yt + hn
		if hl > 0 then
			en(self.Lema, xt, yt + 4)
			yt = yt + 4 + hl
		end
		local y = max(pad + 72, yt) + ESP.l
		-- Quiénes somos.
		if (self.Desc:GetText() or "") ~= "" then
			en(self.Desc, pad, y)
			y = y + K.Parrafo(self.Desc, min(w, 720)) + ESP.l
		end
		-- Lo que encuentras: en dos columnas si cabe.
		if (self.nOfrece or 0) > 0 then
			en(self.OfreceT, pad, y)
			K.Ajustar(self.OfreceT, w)
			y = y + K.AltoTexto(self.OfreceT) + ESP.m
			local cols = w >= 560 and 2 or 1
			local cw = floor((w - (cols - 1) * ESP.l) / cols)
			for i = 1, self.nOfrece do
				local o = self.ofrece[i]
				local c, r = (i - 1) % cols, floor((i - 1) / cols)
				local ox, oy = pad + c * (cw + ESP.l), y + r * 24
				en(o.Icono, ox, oy + 1)
				en(o.Texto, ox + 22, oy)
				K.Ajustar(o.Texto, cw - 22)
			end
			y = y + math.ceil(self.nOfrece / cols) * 24 + ESP.s
		end
		-- El Discord, para copiar.
		self.Linea1:ClearAllPoints()
		self.Linea1:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
		self.Linea1:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
		y = y + ESP.l
		en(self.DiscordIcono, pad, y)
		en(self.DiscordT, pad + 30, y + 2)
		K.Ajustar(self.DiscordT, w - 30)
		local yd = y + 2 + K.AltoTexto(self.DiscordT) + 3
		en(self.DiscordN, pad + 30, yd)
		yd = yd + K.Parrafo(self.DiscordN, w - 30)
		y = max(y + 24, yd) + ESP.m
		local bw = self.Copiar:AnchoNatural()
		self.Copiar:ClearAllPoints()
		self.Copiar:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
		en(self.Campo, pad, y)
		self.Campo:SetWidth(max(120, w - bw - ESP.s))
		y = y + K.ALTO.control
		-- Unirse.
		if self.alfaUnirse then
			y = y + ESP.l
			self.Linea2:ClearAllPoints()
			self.Linea2:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -y)
			self.Linea2:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
			y = y + ESP.l
			en(self.UnirseT, pad, y)
			y = y + K.Parrafo(self.UnirseT, min(w, 720)) + ESP.m
			en(self.Unirse, pad, y)
			y = y + K.num(self.Unirse:GetHeight(), K.ALTO.boton)
			if (self.Estado:GetText() or "") ~= "" then
				y = y + ESP.m
				en(self.Estado, pad, y)
				y = y + K.Parrafo(self.Estado, min(w, 720))
			end
			if (self.nEscribir or 0) > 0 then
				y = y + ESP.m
				local bx = pad
				for _, bt in ipairs(self.escribir) do
					if bt:IsShown() then
						en(bt, bx, y)
						bx = bx + bt:AnchoNatural() + ESP.s
					end
				end
				y = y + K.ALTO.botonChico
			end
			if (self.Oficiales:GetText() or "") ~= "" then
				y = y + ESP.m
				en(self.Oficiales, pad, y)
				y = y + K.Parrafo(self.Oficiales, w)
			end
			if (self.Aviso:GetText() or "") ~= "" then
				y = y + ESP.s
				en(self.Aviso, pad, y)
				y = y + K.Parrafo(self.Aviso, w)
			end
			if self.Apagar:IsShown() then
				y = y + ESP.s
				en(self.Apagar, pad, y)
				y = y + K.ALTO.botonChico
			end
		end
		y = y + pad
		self:SetHeight(y)
		return y
	end

	-- Lleva la página al enlace del Discord y lo deja elegido para copiar.
	function b:IrAlDiscord()
		local O = A.UI and A.UI.Options
		local win = O and O.frame
		local sc = win and win.Scroll
		pcall(function()
			local vt, ct = P.view:GetTop(), self.Campo:GetTop()
			if sc and vt and ct then
				local rango = sc.GetVerticalScrollRange and sc:GetVerticalScrollRange() or 0
				sc:SetVerticalScroll(max(0, min(rango, vt - ct - 160)))
			end
		end)
		self.Campo:Copiar()
	end

	return b
end

---------------------------------------------------------------------------
-- 4. En memoria de Lya (Alfa_Lya): una tarjeta corta con su recuerdo.
-- Las donaciones no van dentro del juego (reglas de Blizzard para addons):
-- viven en CurseForge, GitHub y el Discord.
---------------------------------------------------------------------------

local function recuerdoLya()
	local Lya = rawget(_G, "AlfaLya")
	if not (Lya and type(Lya.Recuerdo) == "function") then return nil end
	local ok, titulo, texto, pie = pcall(Lya.Recuerdo)
	if not (ok and texto and texto ~= "") then return nil end
	return titulo, texto, pie
end

local function bloqueLya(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Icono = K.Icono(b, "ic-lobo", 24, "acento")
	b.Sobre = K.Texto(b, "mayus", "textoTenue")
	b.Titulo = K.Texto(b, "subtitulo", "texto")
	b.Texto = K.Texto(b, "texto", "textoSuave")
	b.Pie = K.Texto(b, "nota", "textoTenue")

	function b:Llenar()
		local titulo, texto, pie = recuerdoLya()
		self.alfaHay = texto ~= nil
		K.Mostrar(self, self.alfaHay)
		if not self.alfaHay then return end
		K.Escribir(self.Sobre, U.Mayus(L["En memoria"]))
		K.Escribir(self.Titulo, titulo or "Lya")
		K.Escribir(self.Texto, texto)
		K.Escribir(self.Pie, pie or "")
	end

	local function en(x, px, py)
		x:ClearAllPoints()
		x:SetPoint("TOPLEFT", b, "TOPLEFT", px, -py)
	end

	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		if not self.alfaHay then
			self:SetHeight(1)
			return 1
		end
		local pad = ESP.l
		local xt = pad + 24 + ESP.base
		local w = ancho - xt - pad
		en(self.Icono, pad, pad + 2)
		local y = pad
		en(self.Sobre, xt, y)
		self.Sobre:SetWidth(w)
		y = y + K.AltoTexto(self.Sobre) + 4
		en(self.Titulo, xt, y)
		K.Ajustar(self.Titulo, w)
		y = y + K.AltoTexto(self.Titulo) + ESP.s
		en(self.Texto, xt, y)
		y = y + K.Parrafo(self.Texto, min(w, 720)) + ESP.s
		en(self.Pie, xt, y)
		y = y + K.Parrafo(self.Pie, w) + pad
		self:SetHeight(y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- 5. Los ajustes
---------------------------------------------------------------------------

local function interruptor(clave, alCambiar)
	return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave, alCambiar = alCambiar }) end
end

-- Lo que dice la fila de compartir: qué se envía y por dónde va ahora.
local function textoCompartir()
	local t = L["Quienes usan Alfa y comparten te ven en su mapa y pueden seguirte, y tú a ellos. Se envía tu zona, tu posición, tu nivel y tu clase cada 10 segundos mientras te mueves (cada 4 minutos si estás quieto), nunca dentro de mazmorras ni por canales públicos."]
	if not on("compartir") then return t end
	local via = M.Red.Via()
	local ahora
	if via == "canal" then
		ahora = L["Ahora va por el canal oculto de Alfa."]
	elseif via == "hermandad" then
		ahora = L["Ahora va por tu hermandad: el canal oculto de Alfa no está disponible, así que solo te ven quienes comparten en tu hermandad."]
	else
		ahora = L["Ahora no sale: Alfa busca cómo unirse a la manada."]
	end
	return t .. " " .. ahora
end

local function grupos(ui, padre)
	local rastro = K.GrupoAjustes(padre, { titulo = L["Tu rastro"] })
	ui.filaCompartir = rastro:Fila({
		titulo = L["Que la manada vea a mi personaje en el mapa"], texto = "",
		control = interruptor("compartir", function() N.Datos(ID).preguntado = true end),
	})
	local mapa = K.GrupoAjustes(padre, { titulo = L["En el mapa"] })
	mapa:Fila({ titulo = L["Tu grupo en el mapa"], control = interruptor("capaGrupo"),
		texto = L["Tu grupo o banda en el mapa y el minimapa, con el color de su clase."] })
	mapa:Fila({ titulo = L["La Jauría en el mapa"], control = interruptor("capaJauria"), activa = function() return on("compartir") end,
		texto = L["Los lobos que se dejan ver en el mapa. Un clic en su marca y la flecha te lleva."] })
	mapa:Fila({ titulo = L["También en el minimapa"], control = interruptor("minimapa"),
		texto = L["Las marcas de la manada también en el minimapa, no solo en el mapa del mundo."] })
	return { rastro, mapa }
end

---------------------------------------------------------------------------
-- La pregunta: ¿compartes tu ubicación con La Jauría?
---------------------------------------------------------------------------

local pendiente -- { alTerminar }: la pregunta a la vista
local vigilado = false

local function terminar(si)
	local p = pendiente
	pendiente = nil
	N.Datos(ID).preguntado = true
	N.Set(ID, "compartir", si and true or false)
	if si then U.Decir(L["La manada ya ve a tu personaje en el mapa del juego. Lo cambias cuando quieras en /alfa manada."]) end
	if p and p.alTerminar then K.Llamar(p.alTerminar, si and true or false) end
end

-- Cerrar con Esc no cambia nada: solo se avisa a quien preguntó.
local function vigilarEsc()
	if vigilado then return end
	local velo = rawget(_G, "AlfaKitVelo")
	if not (velo and velo.HookScript) then return end
	vigilado = true
	velo:HookScript("OnHide", function()
		local p = pendiente
		if not p then return end
		A.After(0, function()
			if pendiente ~= p then return end
			-- Escondido por el combate (K.Dialogo): la pregunta sigue y vuelve al terminar.
			if K.DialogoAbierto and K.DialogoAbierto() then return end
			pendiente = nil
			if p.alTerminar then K.Llamar(p.alTerminar, on("compartir")) end
		end)
	end)
end

-- opts = { alTerminar = fn(comparte) }. Sale fuera de combate.
function P.Preguntar(opts)
	opts = opts or {}
	N.FueraDeCombate(function()
		N.Datos(ID).preguntado = true
		pendiente = { alTerminar = opts.alTerminar }
		K.Dialogo({
			lobo = "aullando", ancho = 480,
			titulo = L["¿Quieres que la manada te vea en el mapa del juego?"],
			texto = L["Es opcional: tu personaje aparece en el mapa de WoW de los lobos de La Jauría que usan Alfa, y ellos en el tuyo, para encontrarse y llegar con la flecha. Solo se comparte dónde anda tu personaje dentro del juego (zona, punto en el mapa, nivel y clase), nunca tu ubicación real ni nada de tu computadora, y nunca dentro de mazmorras. Tu grupo se ve siempre. Lo cambias cuando quieras en La Jauría."],
			aceptar = L["Sí, que me vean"],
			cancelar = L["Ahora no"],
			alAceptar = function() terminar(true) end,
			alCancelar = function() terminar(false) end,
		})
		vigilarEsc()
	end)
	return true
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

-- Lo que la página muestra, en corto: si cambia, se rehace.
local function firma(ui, gente)
	local via = M.Red.Via()
	local _, por = M.Red.PuedeEnviar()
	local canal = M.Canal.Estado()
	local partes = { on("compartir") and "c" or "-", tostring(via), tostring(por),
		tostring(ui.verTodo), tostring(ui.unirse.estado), tostring(M.Red.Buscando()), tostring(canal) }
	local s = M.Seguir.Actual()
	partes[#partes + 1] = s and s.clave or ""
	for i = 1, min(#gente, ui.verTodo and 60 or VISIBLES) do
		local f = gente[i]
		partes[#partes + 1] = format("%s:%s:%s:%s:%s", f.clave or "", f.map or "", f.dist and floor(f.dist / 10) or "",
			f.edad and f.edad >= M.Gente.VIEJA and floor(f.edad / 60) or "", f.conectado == false and "x" or "")
	end
	partes[#partes + 1] = #gente
	return table.concat(partes, "|")
end

local function llenar(ui)
	local t = ui.tablero
	local gente = M.Gente.Manada()
	t:SetAccion(accion(ui, gente))
	local n = ui.verTodo and #gente or min(#gente, VISIBLES)
	local lista = {}
	for i = 1, n do lista[i] = datoPersona(gente[i]) end
	local enlace
	if #gente > VISIBLES then
		enlace = { texto = ui.verTodo and L["Ver menos"] or format(L["Ver todos (%d)"], #gente),
			alClic = function() ui.verTodo = not ui.verTodo M.Avisar() end }
	end
	t:SetOpciones(lista, L["La manada a la vista"], { cuenta = #gente > 0 and #gente or nil, enlace = enlace })
	pintarPersonas(t.Rejilla, lista)
	ui.clan:Llenar()
	ui.lya:Llenar()
	ui.filaCompartir.alfaDatos.texto = textoCompartir()
	for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	ui.firma = firma(ui, gente)
end

local ticker

local function alMostrar()
	if ticker then return end
	ticker = A.NewTicker(REFRESCO, function()
		local view, ui = P.view, P.ui
		if not (view and ui and view:IsVisible()) then return end
		if firma(ui, M.Gente.Manada()) ~= ui.firma then N.RehacerPagina(view) end
	end)
end

local function alOcultar()
	if ticker then
		ticker:Cancel()
		ticker = nil
	end
end

function P.Construir(view)
	local ui = { unirse = {} }
	P.ui = ui
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "accion", tituloOpciones = L["La manada a la vista"], min = 256 })
	ui.tablero = t
	ui.clan = t:AgregarBloque(bloqueClan(ui, t.Extra))
	ui.lya = t:AgregarBloque(bloqueLya(t.Extra), { espacio = ESP.l })
	ui.ajustes = grupos(ui, t.Extra)
	for i, g in ipairs(ui.ajustes) do t:AgregarBloque(g, { espacio = i == 1 and ESP.xl or ESP.l }) end
	K.EnPagina(view, t, function() llenar(ui) end)
	P.view = view
	view:HookScript("OnShow", alMostrar)
	view:HookScript("OnHide", alOcultar)
	alMostrar()
end

-- Abre la página de La Jauría.
function P.Abrir()
	N.Abrir(ID)
	M.Avisar()
end

