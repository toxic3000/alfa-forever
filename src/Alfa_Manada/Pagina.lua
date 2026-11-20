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

-- Algo cambió: la página se rehace si está a la vista. (1.3.1) Una sola vez
-- por ráfaga, AVISAR segundos después: treinta respuestas de «¿Quién
-- tiene...?» o las guaridas de todo el canal eran treinta páginas rehechas
-- seguidas. (Con la tarea ya anotada no se reemplaza: si no, un goteo
-- constante la aplazaría para siempre.)
local AVISAR = 0.2
local function rehacer()
	local view = P.view
	if view then N.RehacerPagina(view) end
end
function M.Avisar()
	if not P.view or N.HayTarea("manada.avisar") then return end
	N.Una("manada.avisar", AVISAR, rehacer)
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

-- El nombre con el lobo de su insignia al lado (Insignias.lua), si tiene.
local function conInsignia(f, nombre)
	nombre = nombre or "?"
	local tipo = M.Insignias.DeFila(f)
	if not tipo then return nombre end
	return nombre .. " " .. M.Insignias.Icono(tipo)
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
			titulo = format(L["Vas tras %s"], f and conInsignia(f, s.nombre) or (s.nombre or "?")),
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
		local nombre = conInsignia(f, f.nombre)
		if f.dist then
			titulo = format(L["%s anda a %s"], nombre, U.TextoDistancia(f.dist))
		elseif f.zona then
			titulo = format(L["%s anda por %s"], nombre, f.zona)
		else
			titulo = nombre
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
	local ins = M.Insignias.DeFila(f)
	-- 1.2.7: las misiones que hace contigo (Juntos.lua), si anda en tu zona.
	local J = M.Juntos
	local comunes = J and f.tipo ~= "grupo" and J.Comunes(f.clave) or 0
	local juntos = comunes == 1 and L["Hacen 1 misión contigo"] or (comunes > 1 and format(L["Hacen %d misiones contigo"], comunes)) or nil
	return {
		variante = "normal", icono = "ic-huella",
		sobre = U.Mayus(siguiendo and L["Siguiendo"] or (f.tipo == "grupo" and L["Tu grupo"] or L["La Jauría"])),
		titulo = conInsignia(f, f.nombre),
		-- Al pasar el ratón por la tarjeta: qué es el lobo junto al nombre.
		ayuda = ins and (M.Insignias.Linea(ins)) or nil,
		texto = (nc ~= "" and (nc .. "\n") or "") .. lugar(f) .. (juntos and ("\n" .. juntos) or ""),
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
	-- El juego no deja copiar al portapapeles desde un addon: el enlace queda
	-- elegido y se dice cómo copiarlo (1.2.2; antes no se notaba nada).
	local dicho = 0
	function c:Copiar()
		e:SetFocus()
		e:HighlightText()
		local t = GetTime and GetTime() or 0
		if t - dicho > 5 then
			dicho = t
			U.Decir(L["El enlace del Discord ya está elegido: cópialo con Ctrl+C y pégalo en tu navegador."])
		end
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
	-- El motor rechaza las invitaciones (Ajustes > Comodidades > Social): un clic lo apaga.
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
			and L["Tienes activado «Rechazar invitaciones a hermandad» en Ajustes > Comodidades > Social: apágalo para que te llegue la invitación."] or "")
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
-- Las guaridas (1.2.4, Guaridas.lua): en qué capa andas y a cuál de la
-- manada puedes pedir entrar.
---------------------------------------------------------------------------

local MOTIVO_PEDIR = {
	compartir = "Para ver las guaridas de la manada, deja que te vean en el mapa.",
	grupo = "Sal de tu grupo primero: el juego te pasa a la guarida de quien te invita.",
	instancia = "En una mazmorra no hay guaridas.",
	mapa = "Alfa no sabe en qué zona estás.",
	ya = "Ya estás en esa guarida.",
	nadie = "Nadie tiene esa guarida abierta ahora.",
}

local function pedir(capa)
	local ok, por = M.Guaridas.Pedir(capa)
	if not ok and MOTIVO_PEDIR[por] then U.Decir(L[MOTIVO_PEDIR[por]]) end
end

local function bloqueGuaridas(padre)
	local Gu = M.Guaridas
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Icono = K.Icono(b, "ic-huella", 24, "acento")
	b.Sobre = K.Texto(b, "mayus", "textoTenue")
	b.Titulo = K.Texto(b, "subtitulo", "texto")
	b.Texto = K.Texto(b, "texto", "textoSuave")
	b.Abrir = K.Boton(b, "", function()
		Gu.Abrir(not Gu.Abierta())
		U.Decir(Gu.Abierta() and L["Tu guarida está abierta: si alguien de la manada pide entrar, Alfa lo invita a tu grupo."]
			or L["Cerraste tu guarida."])
	end, { tipo = "secundario", icono = "ic-manada" })
	b.AbrirNota = K.Texto(b, "nota", "textoSuave")
	-- 1.2.6: llamar a la manada.
	b.Llamar = K.Boton(b, L["Llamar a la manada"], function() if M.Llamado then M.Llamado.LlamarYDecir() end end,
		{ tipo = "secundario", icono = "ic-huella" })
	b.LlamarNota = K.Texto(b, "nota", "textoSuave")
	-- 1.2.9: cambiar de plano cuando está lleno (Plano.lua).
	b.Plano = K.Boton(b, L["Cambiar de plano"], function() if M.Plano then M.Plano.CambiarYDecir() end end,
		{ tipo = "secundario", icono = "ic-manada" })
	b.PlanoNota = K.Texto(b, "nota", "textoSuave")
	b.Linea = K.Linea(b, "linea")
	b.Vacio = K.Texto(b, "nota", "textoTenue")
	b.filas = {}

	local function fila(i)
		local f = b.filas[i]
		if f then return f end
		f = {
			Nombre = K.Texto(b, "cuerpo", "texto"),
			Dato = K.Texto(b, "nota", "textoSuave"),
			Ir = K.Boton(b, L["Pedir entrar"], function(x) pedir(x.alfaCapa) end, { tipo = "primario", tam = "chico", icono = "ic-huella" }),
		}
		b.filas[i] = f
		return f
	end

	function b:Llenar()
		local comparte = on("compartir")
		local mia = Gu.Actual()
		local pedido = Gu.Pedido()
		K.Escribir(self.Sobre, U.Mayus(L["Guaridas"]))
		K.Escribir(self.Titulo, mia and format(L["Estás en la %s"], Gu.Etiqueta(mia.capa))
			or L["Mira a una criatura y Alfa te dice en qué guarida estás"])
		K.Escribir(self.Texto, L["Cuando una zona se llena, el juego la parte en guaridas (capas): el mismo lugar con otra gente, otros raros y otros minerales. Pide entrar a la de alguien de la manada y el juego te pasa al unirte a su grupo."])
		self.Abrir:SetTexto(Gu.Abierta() and L["Cerrar mi guarida"] or L["Abrir mi guarida"])
		self.Abrir:SetActivo(comparte)
		self.Llamar:SetActivo(comparte)
		K.Escribir(self.LlamarNota, L["Pide ayuda con un élite o un raro: los lobos de tu zona reciben tu lugar y te avisa quién viene."])
		local Pl = M.Plano
		self.Plano:SetActivo(comparte and mia ~= nil and not pedido)
		K.Escribir(self.PlanoNota, mia and Pl and format(L["Cómo está tu plano: %s."], Pl.Texto())
			or L["¿Mucha gente? Te paso al plano de un lobo de la manada con su guarida abierta."])
		K.Escribir(self.AbrirNota, Gu.Abierta() and L["Abierta: si alguien de la manada pide entrar, Alfa lo invita a tu grupo (fuera de combate)."]
			or L["Cerrada: nadie te pide entrar. Ábrela para echarle la mano a la manada."])
		local lista = {}
		if comparte then
			for _, g in ipairs(Gu.Lista()) do if not g.mia then lista[#lista + 1] = g end end
		end
		for i, g in ipairs(lista) do
			if i > 6 then break end
			local f = fila(i)
			K.Escribir(f.Nombre, g.etiqueta)
			local dato = format(L["%d de la manada"], g.gente)
			if g.abiertas > 0 then dato = dato .. DOT .. format(L["%d con la puerta abierta"], g.abiertas) end
			if pedido and pedido.capa == g.capa then dato = dato .. DOT .. L["tocando a la puerta..."] end
			K.Escribir(f.Dato, dato)
			f.Ir.alfaCapa = g.capa
			f.Ir:SetActivo(g.abiertas > 0 and not pedido)
		end
		self.alfaN = math.min(#lista, 6)
		for i, f in ipairs(self.filas) do
			local v = i <= self.alfaN
			K.Mostrar(f.Nombre, v) K.Mostrar(f.Dato, v) K.Mostrar(f.Ir, v)
		end
		K.Escribir(self.Vacio, not comparte and L[MOTIVO_PEDIR.compartir]
			or (#lista == 0 and L["Nadie de la manada anda en otra guarida de esta zona ahora."]) or "")
	end

	local function en(x, px, py)
		x:ClearAllPoints()
		x:SetPoint("TOPLEFT", b, "TOPLEFT", px, -py)
	end

	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		local pad = ESP.l
		local xt = pad + 24 + ESP.base
		local w = ancho - xt - pad
		en(self.Icono, pad, pad + 2)
		local y = pad
		en(self.Sobre, xt, y)
		self.Sobre:SetWidth(w)
		y = y + K.AltoTexto(self.Sobre) + 4
		en(self.Titulo, xt, y)
		y = y + K.Parrafo(self.Titulo, w, 2) + ESP.s
		en(self.Texto, xt, y)
		y = y + K.Parrafo(self.Texto, min(w, 720)) + ESP.m
		en(self.Abrir, xt, y)
		local bw = K.num(self.Abrir:GetWidth(), 120)
		local bh = K.num(self.Abrir:GetHeight(), K.ALTO.boton)
		en(self.AbrirNota, xt + bw + ESP.m, y + 2)
		local hn = K.Parrafo(self.AbrirNota, w - bw - ESP.m, 3)
		y = y + max(bh, hn) + ESP.m
		en(self.Llamar, xt, y)
		local lw = K.num(self.Llamar:GetWidth(), 120)
		local lh = K.num(self.Llamar:GetHeight(), K.ALTO.boton)
		en(self.LlamarNota, xt + lw + ESP.m, y + 2)
		local ln = K.Parrafo(self.LlamarNota, w - lw - ESP.m, 3)
		y = y + max(lh, ln) + ESP.m
		en(self.Plano, xt, y)
		local pw = K.num(self.Plano:GetWidth(), 120)
		local ph = K.num(self.Plano:GetHeight(), K.ALTO.boton)
		en(self.PlanoNota, xt + pw + ESP.m, y + 2)
		local pn = K.Parrafo(self.PlanoNota, w - pw - ESP.m, 3)
		y = y + max(ph, pn) + ESP.m
		self.Linea:ClearAllPoints()
		self.Linea:SetPoint("TOPLEFT", self, "TOPLEFT", xt, -y)
		self.Linea:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
		y = y + 1 + ESP.m
		for i = 1, self.alfaN or 0 do
			local f = self.filas[i]
			local iw = K.num(f.Ir:GetWidth(), 100)
			local ih = K.num(f.Ir:GetHeight(), K.ALTO.botonChico)
			f.Ir:ClearAllPoints()
			f.Ir:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
			en(f.Nombre, xt, y)
			K.Ajustar(f.Nombre, w - iw - ESP.m)
			local hy = K.AltoTexto(f.Nombre)
			en(f.Dato, xt, y + hy + 2)
			K.Ajustar(f.Dato, w - iw - ESP.m)
			y = y + max(ih, hy + 2 + K.AltoTexto(f.Dato)) + ESP.m
		end
		if (self.Vacio:GetText() or "") ~= "" then
			en(self.Vacio, xt, y)
			y = y + K.Parrafo(self.Vacio, w) + ESP.s
		end
		y = y + pad - ESP.s
		self:SetHeight(y)
		return y
	end
	return b
end

---------------------------------------------------------------------------
-- 1.2.8: la manada se organiza. Tres bloques con la misma forma (bloqueLista):
-- la cabeza (icono, sobre, título, texto), unos controles propios y una
-- lista de filas con su nombre, su dato y hasta dos botones.
--   Citas de la manada (Cita.lua), Notas del lobo (Notas.lua) y Raros con
--   reloj (Reloj.lua).
---------------------------------------------------------------------------

local FILAS = 6

-- Un campo para escribir, con su ayuda tenue mientras está vacío.
local function campoTexto(padre, ayuda, alEnter)
	local c = CreateFrame("Frame", nil, padre)
	c:SetHeight(K.ALTO.control)
	c.caja = K.Caja(c, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local e = CreateFrame("EditBox", nil, c)
	c.Campo = e
	e:SetAutoFocus(false)
	e:SetMaxLetters(40)
	e:SetPoint("LEFT", c, "LEFT", ESP.m, 0)
	e:SetPoint("RIGHT", c, "RIGHT", -ESP.m, 0)
	e:SetHeight(K.ALTO.control - 4)
	K.Pintar(e, function(x) K.FuenteSegura(x, K.Cara("medium"), K.Tamano("cuerpo"), "") x:SetTextColor(K.Color("texto")) end)
	c.Ayuda = K.Texto(c, "nota", "textoTenue")
	c.Ayuda:SetPoint("LEFT", e, "LEFT", 1, 0)
	c.Ayuda:SetPoint("RIGHT", e, "RIGHT", 0, 0)
	K.Escribir(c.Ayuda, ayuda or "")
	e:SetScript("OnTextChanged", function(self) c.Ayuda:SetShown((self:GetText() or "") == "") end)
	e:SetScript("OnEditFocusGained", function() c.caja:Estilo({ borde = "acento", alfaBorde = 0.8 }) end)
	e:SetScript("OnEditFocusLost", function() c.caja:Estilo({ borde = "lineaFuerte", alfaBorde = 1 }) end)
	e:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	e:SetScript("OnEnterPressed", function(self) self:ClearFocus() if alEnter then alEnter() end end)
	c:EnableMouse(true)
	c:SetScript("OnMouseDown", function() e:SetFocus() end)
	function c:Texto() return ((e:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")) end
	function c:Vaciar() e:SetText("") e:ClearFocus() end
	function c:SetActivo(si)
		e:EnableMouse(si ~= false)
		if si == false then e:ClearFocus() end
		self:SetAlpha(si == false and 0.45 or 1)
	end
	return c
end

local function bloqueLista(padre, o)
	local b = CreateFrame("Frame", nil, padre)
	b.caja = K.Caja(b, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Icono = K.Icono(b, o.icono or "ic-huella", 24, "acento")
	b.Sobre = K.Texto(b, "mayus", "textoTenue")
	b.Titulo = K.Texto(b, "subtitulo", "texto")
	b.Texto = K.Texto(b, "texto", "textoSuave")
	b.Linea = K.Linea(b, "linea")
	b.Vacio = K.Texto(b, "nota", "textoTenue")
	b.filas = {}
	if o.controles then o.controles(b) end

	local function boton(x) if x.alfaFn then K.Llamar(x.alfaFn) end end
	local function fila(i)
		local f = b.filas[i]
		if f then return f end
		f = {
			Nombre = K.Texto(b, "cuerpo", "texto"),
			Dato = K.Texto(b, "nota", "textoSuave"),
			B1 = K.Boton(b, " ", boton, { tipo = "primario", tam = "chico" }),
			B2 = K.Boton(b, " ", boton, { tipo = "secundario", tam = "chico" }),
		}
		b.filas[i] = f
		return f
	end

	function b:Llenar()
		local d = o.llenar(self) or {}
		K.Escribir(self.Sobre, U.Mayus(o.sobre))
		K.Escribir(self.Titulo, d.titulo or "")
		K.Escribir(self.Texto, d.texto or "")
		local lista = d.filas or {}
		self.alfaN = min(#lista, FILAS)
		for i = 1, self.alfaN do
			local x, f = lista[i], fila(i)
			K.Escribir(f.Nombre, x.nombre or "")
			K.Escribir(f.Dato, x.dato or "")
			for j, bt in ipairs({ f.B1, f.B2 }) do
				local a = x.botones and x.botones[j]
				K.Mostrar(bt, a ~= nil)
				if a then
					bt:SetTexto(a.texto)
					bt.alfaFn = a.alClic
					bt:SetActivo(a.activo ~= false)
				end
			end
		end
		for i, f in ipairs(self.filas) do
			local v = i <= self.alfaN
			K.Mostrar(f.Nombre, v) K.Mostrar(f.Dato, v)
			if not v then K.Mostrar(f.B1, false) K.Mostrar(f.B2, false) end
		end
		K.Escribir(self.Vacio, #lista == 0 and (d.vacio or "") or "")
	end

	local function en(x, px, py)
		x:ClearAllPoints()
		x:SetPoint("TOPLEFT", b, "TOPLEFT", px, -py)
	end
	b.En = en

	function b:Acomodar(ancho)
		self:SetWidth(ancho)
		local pad = ESP.l
		local xt = pad + 24 + ESP.base
		local w = ancho - xt - pad
		en(self.Icono, pad, pad + 2)
		local y = pad
		en(self.Sobre, xt, y)
		self.Sobre:SetWidth(w)
		y = y + K.AltoTexto(self.Sobre) + 4
		en(self.Titulo, xt, y)
		y = y + K.Parrafo(self.Titulo, w, 2) + ESP.s
		if (self.Texto:GetText() or "") ~= "" then
			en(self.Texto, xt, y)
			y = y + K.Parrafo(self.Texto, min(w, 720)) + ESP.m
		end
		if o.acomodar then y = o.acomodar(self, xt, y, w) + ESP.m end
		self.Linea:ClearAllPoints()
		self.Linea:SetPoint("TOPLEFT", self, "TOPLEFT", xt, -y)
		self.Linea:SetPoint("TOPRIGHT", self, "TOPRIGHT", -pad, -y)
		y = y + 1 + ESP.m
		for i = 1, self.alfaN or 0 do
			local f = self.filas[i]
			local bw, bh = 0, 0
			local derecha = -pad
			for _, bt in ipairs({ f.B2, f.B1 }) do
				if bt:IsShown() then
					bt:ClearAllPoints()
					bt:SetPoint("TOPRIGHT", self, "TOPRIGHT", derecha, -y)
					local an = K.num(bt:GetWidth(), 90)
					derecha = derecha - an - ESP.s
					bw = bw + an + ESP.s
					bh = max(bh, K.num(bt:GetHeight(), K.ALTO.botonChico))
				end
			end
			local tw = max(80, w - bw - ESP.s)
			en(f.Nombre, xt, y)
			local hy = K.Parrafo(f.Nombre, tw, 2)
			en(f.Dato, xt, y + hy + 2)
			local hd = K.Parrafo(f.Dato, tw, 3)
			y = y + max(bh, hy + 2 + hd) + ESP.m
		end
		if (self.Vacio:GetText() or "") ~= "" then
			en(self.Vacio, xt, y)
			y = y + K.Parrafo(self.Vacio, w) + ESP.s
		end
		y = y + pad - ESP.s
		self:SetHeight(y)
		return y
	end
	return b
end

-- Citas de la manada (Cita.lua).
local function bloqueCitas(padre)
	local Ci = M.Cita
	local proponer
	local b = bloqueLista(padre, {
		icono = "ic-reloj", sobre = L["Citas de la manada"],
		controles = function(b)
			b.Que = campoTexto(b, L["¿Qué hacemos? Una mazmorra, una misión..."], function() proponer(b) end)
			b.Dia = K.Desplegable(b, { opciones = Ci.OpcionesDia(), valor = 0, ancho = 110 })
			b.Hora = K.Desplegable(b, { opciones = Ci.OpcionesHora(), valor = 21 * 60, ancho = 100 })
			b.Proponer = K.Boton(b, L["Proponer"], function() proponer(b) end, { tipo = "primario", icono = "ic-manada" })
		end,
		acomodar = function(b, xt, y, w)
			b.En(b.Que, xt, y)
			b.Que:SetWidth(min(w, 420))
			y = y + K.ALTO.control + ESP.s
			b.En(b.Dia, xt, y)
			b.En(b.Hora, xt + 110 + ESP.s, y)
			b.En(b.Proponer, xt + 210 + 2 * ESP.s, y)
			return y + max(K.ALTO.control, K.num(b.Proponer:GetHeight(), K.ALTO.boton))
		end,
		llenar = function(b)
			-- (1.3.2) Sin pedir compartir tu ubicación: basta tu hermandad.
			local hermandad = U.EnHermandad()
			local activo = N.Get(ID, "citas") ~= false
			b.Dia:SetOpciones(Ci.OpcionesDia())
			for _, x in ipairs({ b.Que, b.Dia, b.Hora, b.Proponer }) do x:SetActivo(hermandad and activo) end
			local filas = {}
			for _, c in ipairs(activo and Ci.Lista() or {}) do
				local cuando = Ci.CuandoTexto(c.cuando)
				local dato, botones
				if c.mia then
					local si, no = Ci.Quienes(c)
					local partes = { format(L["Tu cita, %s"], cuando) }
					partes[#partes + 1] = #si > 0 and format(L["Van: %s"], table.concat(si, ", ")) or L["Aún nadie responde"]
					if #no > 0 then partes[#partes + 1] = format(L["No pueden: %s"], table.concat(no, ", ")) end
					dato = table.concat(partes, DOT)
					botones = { { texto = L["Quitar"], alClic = function() Ci.Quitar(c.llave) end } }
				else
					local estado = c.mi == true and L["vas"] or (c.mi == false and L["no puedes"]) or nil
					dato = format(L["De %s, %s"], c.de or "?", cuando) .. (estado and (DOT .. estado) or "")
					botones = {
						{ texto = L["Voy"], activo = c.mi ~= true, alClic = function() Ci.Responder(c.llave, true) end },
						{ texto = L["No puedo"], activo = c.mi ~= false, alClic = function() Ci.Responder(c.llave, false) end },
					}
				end
				filas[#filas + 1] = { nombre = c.que, dato = dato, botones = botones }
			end
			local vacio
			if not activo then vacio = L[Ci.MOTIVOS.apagado]
			elseif not hermandad then vacio = L[Ci.MOTIVOS.hermandad]
			else vacio = L["No hay citas por ahora. ¡Propón la primera!"] end
			return {
				titulo = L["Junta a la manada para salir de caza"],
				texto = L["Propón qué, el día y la hora: a los lobos de tu hermandad con Alfa les llega con «Voy». Te recuerdo 15 minutos antes."],
				filas = filas, vacio = vacio,
			}
		end,
	})
	proponer = function(x)
		local que = x.Que:Texto()
		local cuando = Ci.Cuando(x.Dia:Valor() or 0, x.Hora:Valor() or 0)
		if Ci.ProponerYDecir(que, cuando) then x.Que:Vaciar() end
	end
	return b
end

-- Notas del lobo (Notas.lua).
local function bloqueNotas(padre)
	local No = M.Notas
	local dejar
	local b = bloqueLista(padre, {
		icono = "icon-note", sobre = L["Notas del lobo"],
		controles = function(b)
			b.Nota = campoTexto(b, L["¿Qué dice la nota?"], function() dejar(b) end)
			b.Dejar = K.Boton(b, L["Nota aquí"], function() dejar(b) end, { tipo = "primario", icono = "ic-mapa" })
			-- 1.3.0: un spot de farmeo (su propia capa del mapa).
			b.Spot = K.Boton(b, L["Spot aquí"], function() dejar(b, "spot") end, { tipo = "secundario", icono = "ic-recoleccion" })
		end,
		acomodar = function(b, xt, y, w)
			local bw = K.num(b.Dejar:GetWidth(), 110)
			local sw = K.num(b.Spot:GetWidth(), 110)
			b.En(b.Nota, xt, y)
			b.Nota:SetWidth(max(120, min(w - bw - sw - 2 * ESP.s, 420)))
			b.Dejar:ClearAllPoints()
			b.Dejar:SetPoint("LEFT", b.Nota, "RIGHT", ESP.s, 0)
			b.Spot:ClearAllPoints()
			b.Spot:SetPoint("LEFT", b.Dejar, "RIGHT", ESP.s, 0)
			return y + max(K.ALTO.control, K.num(b.Dejar:GetHeight(), K.ALTO.boton))
		end,
		llenar = function(b)
			local activo = N.Get(ID, "notas") ~= false
			b.Nota:SetActivo(activo)
			b.Dejar:SetActivo(activo)
			b.Spot:SetActivo(activo and N.Get(ID, "spots") ~= false)
			local filas = {}
			for _, x in ipairs(activo and No.Lista() or {}) do
				local zona = U.NombreMapa(U.ZonaDe(x.map)) or ""
				local partes = { x.de and format(L["De %s"], x.de) or L["Tuya"] }
				if No.EsSpot(x) then table.insert(partes, 1, L["Spot de farmeo"]) end
				if zona ~= "" then partes[#partes + 1] = zona end
				local hace = U.Hace(U.Reloj() - (x.at or U.Reloj()))
				if hace then partes[#partes + 1] = hace end
				filas[#filas + 1] = { nombre = x.texto, dato = table.concat(partes, DOT), botones = {
					{ texto = L["Llevarme"], alClic = function() No.Ir(x) end },
					{ texto = L["Borrar"], alClic = function() No.Borrar(x.id) end },
				} }
			end
			return {
				titulo = L["Tus notas en el mapa"],
				texto = L["Escribe algo y pulsa «Nota aquí»: queda en tu mapa donde estás parado. «Spot aquí» marca un buen lugar para farmear, en dorado. Un clic en la marca y la flecha te lleva."],
				filas = filas,
				vacio = activo and L["Aún no dejas notas. También sirve /alfa nota <texto>."] or L[No.MOTIVOS.apagado],
			}
		end,
	})
	dejar = function(x, tipo)
		if No.AgregarYDecir(x.Nota:Texto(), tipo) then x.Nota:Vaciar() end
	end
	return b
end

-- Raros con reloj (Reloj.lua).
local function bloqueCazados(padre)
	local Rl = M.Reloj
	return bloqueLista(padre, {
		icono = "ic-raros", sobre = L["Raros con reloj"],
		llenar = function()
			local filas = {}
			for _, x in ipairs(Rl.Lista()) do
				local t, volver = Rl.Texto(x.nombre)
				local partes = { t or "" }
				if volver then partes[#partes + 1] = volver end
				local zona = x.map and U.NombreMapa(U.ZonaDe(x.map))
				if zona then partes[#partes + 1] = zona end
				if x.por then partes[#partes + 1] = format(L["lo dijo %s"], x.por) end
				filas[#filas + 1] = { nombre = x.nombre, dato = table.concat(partes, DOT),
					botones = x.map and x.x and { { texto = L["Ir de caza"], alClic = function() Rl.Ir(x) end } } or nil }
			end
			return {
				titulo = L["Los raros que cayeron hace poco"],
				texto = L["Un raro vuelve más o menos entre media hora y una hora después de caer. Aquí ves hace cuánto lo cazaron tú o la manada."],
				filas = filas,
				vacio = N.Get(ID, "rarosReloj") == false and L["Apagado en los ajustes de abajo."] or L["Ningún raro cazado en las últimas horas."],
			}
		end,
	})
end

-- 1.2.9: «¿Quién tiene...?» (QuienTiene.lua).
local function bloqueQuienTiene(padre)
	local Qt = M.QuienTiene
	local buscar
	local b = bloqueLista(padre, {
		icono = "ic-bolsas", sobre = L["¿Quién tiene...?"],
		controles = function(b)
			b.Que = campoTexto(b, L["¿Qué buscas? Un objeto, un material..."], function() buscar(b) end)
			b.Buscar = K.Boton(b, L["Buscar"], function() buscar(b) end, { tipo = "primario", icono = "ic-manada" })
		end,
		acomodar = function(b, xt, y, w)
			local bw = K.num(b.Buscar:GetWidth(), 100)
			b.En(b.Que, xt, y)
			b.Que:SetWidth(max(120, min(w - bw - ESP.s, 420)))
			b.Buscar:ClearAllPoints()
			b.Buscar:SetPoint("LEFT", b.Que, "RIGHT", ESP.s, 0)
			return y + max(K.ALTO.control, K.num(b.Buscar:GetHeight(), K.ALTO.boton))
		end,
		llenar = function(b)
			local hermandad = U.EnHermandad()
			b.Que:SetActivo(hermandad)
			b.Buscar:SetActivo(hermandad)
			local c = Qt.Consulta()
			local filas = {}
			for _, r in ipairs(Qt.Resultados()) do
				filas[#filas + 1] = { nombre = r.nombre, dato = format(L["%s: %d"], r.objeto, r.cuantos),
					botones = { { texto = L["Susurrar"], alClic = function() Qt.Susurrar(r) end } } }
			end
			local vacio
			if not hermandad then vacio = L[Qt.MOTIVOS.hermandad]
			elseif c then vacio = format(L["Nadie de la manada dijo tener «%s» (todavía)."], c.texto)
			else vacio = L["Escribe un objeto y pulsa «Buscar»: te contestan los lobos de tu hermandad que lo permiten."] end
			return {
				titulo = c and format(L["Quién tiene «%s»"], c.texto) or L["Pregúntale a la manada"],
				texto = on("quienTiene") and L["Tú también contestas: si alguien busca algo que llevas, Alfa le dice cuántos tienes (solo eso)."]
					or L["Tú no contestas: actívalo en los ajustes de abajo si quieres ayudar a la manada."],
				filas = filas, vacio = vacio,
			}
		end,
	})
	buscar = function(x)
		if Qt.BuscarYDecir(x.Que:Texto()) then x.Que:Vaciar() end
	end
	return b
end

-- 1.2.9: la semana de la manada (Logros.lua). Sin primeros lugares.
local function bloqueSemana(padre)
	local Lo = M.Logros
	local orden = "nombre"
	return bloqueLista(padre, {
		icono = "ic-reloj", sobre = L["La semana de la manada"],
		controles = function(b)
			b.Orden = K.Boton(b, L["Ordenar por lo que aportó"], function()
				orden = orden == "nombre" and "aporte" or "nombre"
				M.Avisar()
			end, { tipo = "secundario", tam = "chico" })
		end,
		acomodar = function(b, xt, y)
			b.En(b.Orden, xt, y)
			return y + K.num(b.Orden:GetHeight(), K.ALTO.botonChico)
		end,
		llenar = function(b)
			pcall(Lo.PedirSemanas)
			b.Orden:SetTexto(orden == "nombre" and L["Ordenar por lo que aportó"] or L["Ordenar por nombre"])
			local lista, tot = Lo.Manada(orden)
			local filas = {}
			for _, x in ipairs(lista) do filas[#filas + 1] = { nombre = x.nombre, dato = Lo.TextoCuenta(x) } end
			local texto = on("semanaCompartir") and L["Tu semana se comparte con tu hermandad. Cada lobo suma; aquí nadie compite."]
				or L["Tu semana solo la ves tú. Compártela en los ajustes de abajo para sumar con la manada."]
			return {
				titulo = tot.lobos > 1 and format(L["Esta semana, entre %d lobos: %s"], tot.lobos, Lo.TextoCuenta(tot, ", "))
					or format(L["Tu semana: %s"], Lo.TextoCuenta(tot, ", ")),
				texto = texto, filas = filas,
			}
		end,
	})
end

---------------------------------------------------------------------------
-- 1.3.0: la manada crece. El tablón (Tablon.lua), el mentor (Mentor.lua),
-- el botín para la manada (Botin.lua), las guaridas en vivo (Guaridas.lua)
-- y el calendario de la semana (Cita.lua).
---------------------------------------------------------------------------

-- El tablón de la manada: quién busca grupo, para qué y a qué nivel.
local function bloqueTablon(padre)
	local Tb = M.Tablon
	local poner
	local function opciones()
		local out = {}
		for _, t in ipairs(Tb.TIPOS) do out[#out + 1] = { valor = t, texto = Tb.NombreTipo(t) } end
		return out
	end
	local b = bloqueLista(padre, {
		icono = "ic-lista", sobre = L["El tablón de la manada"],
		controles = function(b)
			b.Tipo = K.Desplegable(b, { opciones = opciones(), valor = "m", ancho = 120 })
			b.Que = campoTexto(b, L["¿Qué buscas? «Minas, falta sanador»"], function() poner(b) end)
			b.Poner = K.Boton(b, L["Publicar"], function() poner(b) end, { tipo = "primario", icono = "ic-manada" })
		end,
		acomodar = function(b, xt, y, w)
			local bw = K.num(b.Poner:GetWidth(), 100)
			b.En(b.Tipo, xt, y)
			b.En(b.Que, xt + 120 + ESP.s, y)
			b.Que:SetWidth(max(120, min(w - 120 - bw - 2 * ESP.s, 360)))
			b.Poner:ClearAllPoints()
			b.Poner:SetPoint("LEFT", b.Que, "RIGHT", ESP.s, 0)
			return y + max(K.ALTO.control, K.num(b.Poner:GetHeight(), K.ALTO.boton))
		end,
		llenar = function(b)
			local activo = N.Get(ID, "tablon") ~= false
			local hermandad = U.EnHermandad()
			for _, x in ipairs({ b.Tipo, b.Que, b.Poner }) do x:SetActivo(activo and hermandad) end
			local filas = {}
			for _, x in ipairs(Tb.Lista()) do
				local botones
				if x.mio then
					botones = { { texto = L["Quitar"], alClic = function() Tb.Quitar() end } }
				else
					botones = {
						{ texto = L["Susurrar"], alClic = function() Tb.Susurrar(x) end },
						{ texto = L["Invitar"], alClic = function() Tb.Invitar(x) end },
					}
				end
				filas[#filas + 1] = { nombre = format("%s: %s", x.nombre or "?", x.texto or ""), dato = Tb.Dato(x), botones = botones }
			end
			local vacio
			if not activo then vacio = L[Tb.MOTIVOS.apagado]
			elseif not hermandad then vacio = L[Tb.MOTIVOS.hermandad]
			else vacio = L["Nadie busca grupo ahora. ¡Pon tu anuncio!"] end
			return {
				titulo = L["¿Quién busca grupo?"],
				texto = L["Elige para qué, escribe qué buscas y pulsa «Publicar»: lo ven los lobos de tu hermandad con Alfa. Se quita solo en una hora."],
				filas = filas, vacio = vacio,
			}
		end,
	})
	poner = function(x)
		if Tb.PonerYDecir(x.Tipo:Valor() or "m", x.Que:Texto()) then x.Que:Vaciar() end
	end
	return b
end

-- El mentor: tu mentor, tus aprendices, quién te quiere adoptar y a quién
-- puedes adoptar tú.
local function bloqueMentor(padre)
	local Me = M.Mentor
	return bloqueLista(padre, {
		icono = "ic-manada", sobre = L["Mentor"],
		llenar = function()
			local activo = N.Get(ID, "mentor") ~= false
			local filas = {}
			if activo then
				for _, p in ipairs(Me.Propuestas()) do
					filas[#filas + 1] = { nombre = format(L["%s quiere ser tu mentor"], p.nombre),
						dato = format(L["Nivel %d"], p.nivel),
						botones = {
							{ texto = L["Aceptar"], alClic = function() Me.Aceptar(p.clave) end },
							{ texto = L["No, gracias"], alClic = function() Me.Rechazar(p.clave) end },
						} }
				end
				local m = Me.Mentor()
				if m then
					filas[#filas + 1] = { nombre = format(L["Tu mentor: %s"], m.nombre or "?"),
						dato = L["Solo él ve tu nivel, tu zona y tu misión de ahora."],
						botones = {
							{ texto = L["Susurrar"], alClic = function() U.Susurrar(m.destino, "") end },
							{ texto = L["Terminar"], alClic = function() Me.Terminar(m.clave) end },
						} }
				end
				for _, a in ipairs(Me.Aprendices()) do
					filas[#filas + 1] = { nombre = format(L["Tu aprendiz: %s"], a.nombre or "?"), dato = Me.Texto(a),
						botones = {
							{ texto = L["Susurrar"], alClic = function() U.Susurrar(a.destino, "") end },
							{ texto = L["Terminar"], alClic = function() Me.Terminar(a.clave) end },
						} }
				end
				for _, c in ipairs(Me.Candidatos()) do
					local ya = Me.Propuesto(c.clave)
					filas[#filas + 1] = { nombre = c.nombre, dato = ya and L["Esperando su respuesta"] or format(L["Nivel %d"], c.nivel),
						botones = { { texto = L["Adoptar"], activo = not ya, alClic = function() Me.AdoptarYDecir(c.destino, c.nivel) end } } }
				end
			end
			return {
				titulo = L["Échale la mano a un lobo nuevo"],
				texto = L["Adopta a un lobo 10 niveles menor que tú. Si acepta, ves su nivel, su zona y su misión (solo tú) y te aviso si se atora."],
				filas = filas,
				vacio = activo and L["Nadie para adoptar por ahora: los lobos salen aquí cuando la manada los ve."] or L[Me.MOTIVOS.apagado],
			}
		end,
	})
end

-- El botín para la manada: lo que levantaste y le sirve a otro lobo.
local function bloqueBotin(padre)
	local Bo = M.Botin
	return bloqueLista(padre, {
		icono = "ic-bolsas", sobre = L["Botín para la manada"],
		-- (1.3.2) Sin lobos que compartan su clase y nivel no hay a quién
		-- regalar: el bloque lo dice y deja prender el tuyo aquí mismo.
		controles = function(b)
			b.Compartir = K.Boton(b, L["Compartir mi clase y nivel"], function()
				N.Set(ID, "botinCompartir", true)
				U.Decir(L["Tu hermandad ya sabe tu clase y tu nivel: te avisarán si les sale algo que te sirve."])
			end, { tipo = "secundario", icono = "ic-manada" })
		end,
		acomodar = function(b, xt, y)
			if not b.Compartir:IsShown() then return y - ESP.m end
			b.En(b.Compartir, xt, y)
			return y + K.num(b.Compartir:GetHeight(), K.ALTO.boton)
		end,
		llenar = function(b)
			local activo = N.Get(ID, "botin") ~= false
			K.Mostrar(b.Compartir, activo and not on("botinCompartir"))
			local filas = {}
			for _, s in ipairs(activo and Bo.Sugerencias() or {}) do
				filas[#filas + 1] = { nombre = s.nombre or "?", dato = format(L["Le sirve a %s"], s.para.nombre or "?"),
					botones = { { texto = L["Regalárselo"], alClic = function() Bo.Regalar(s) end } } }
			end
			local n = #Bo.Conocidos()
			return {
				titulo = L["Lo que le sirve a otro lobo"],
				texto = n > 0 and format(L["Conozco la clase y el nivel de %d lobos conectados. Si levantas algo que les sirve, te lo digo."], n)
					or L["Cuando levantes algo que le sirve a un lobo conectado, te lo digo aquí. Ellos comparten su clase y nivel en los ajustes."],
				filas = filas,
				vacio = not activo and L["Apagado en los ajustes de abajo."]
					or (n == 0 and L["Aún no conozco a ningún lobo conectado que comparta su clase y su nivel. Pídeles que prendan «Compartir mi clase y nivel» en La Jauría."])
					or L["Nada por regalar por ahora."],
			}
		end,
	})
end

-- Las guaridas de la manada, zona por zona.
local function bloqueGuaridasVivo(padre)
	local Gu = M.Guaridas
	return bloqueLista(padre, {
		icono = "ic-huella", sobre = L["Las guaridas de la manada"],
		llenar = function()
			local filas = {}
			local comparte = on("compartir")
			for _, e in ipairs(comparte and Gu.PorZona() or {}) do
				if e.total > 0 or e.mia then
					local n = e.total == 1 and L["1 lobo"] or format(L["%d lobos"], e.total)
					filas[#filas + 1] = { nombre = format("%s (%s)", e.nombre, n), dato = Gu.TextoZona(e) }
				end
			end
			return {
				titulo = L["Dónde anda la manada"],
				texto = L["Cada zona con lobos y cuántos hay en cada guarida. En el mapa del mundo también sale."],
				filas = filas,
				vacio = comparte and L["Ningún lobo dice su guarida ahora."] or L["Comparte tu ubicación para ver las guaridas de la manada."],
			}
		end,
	})
end

-- El calendario de la semana: siete días con sus citas.
local function bloqueCalendario(padre)
	local Ci = M.Cita
	local b = bloqueLista(padre, {
		icono = "ic-reloj", sobre = L["El calendario de la manada"],
		controles = function(b)
			b.dias = {}
			for i = 1, 7 do
				local c = CreateFrame("Frame", nil, b)
				c.caja = K.Caja(c, { fondo = "hundido", borde = "linea", corte = K.CORTE.control })
				c.Titulo = K.Texto(c, "cuerpo", "texto")
				c.Fecha = K.Texto(c, "pequeno", "textoTenue")
				c.Citas = K.Texto(c, "nota", "textoSuave")
				b.dias[i] = c
			end
		end,
		acomodar = function(b, xt, y, w)
			if not b.dias[1]:IsShown() then return y end
			local cols = w >= 7 * 104 and 7 or (w >= 4 * 104 and 4 or 2)
			local esp = ESP.s
			local cw = floor((w - (cols - 1) * esp) / cols)
			local pad = ESP.s
			local alto = 0
			for i, c in ipairs(b.dias) do
				local col = (i - 1) % cols
				if col == 0 and i > 1 then
					y = y + alto + esp
					alto = 0
				end
				local h = pad + K.Parrafo(c.Titulo, cw - 2 * pad) + 2
				c.Titulo:ClearAllPoints()
				c.Titulo:SetPoint("TOPLEFT", c, "TOPLEFT", pad, -pad)
				c.Fecha:ClearAllPoints()
				c.Fecha:SetPoint("TOPLEFT", c, "TOPLEFT", pad, -h)
				h = h + K.Parrafo(c.Fecha, cw - 2 * pad) + ESP.s
				c.Citas:ClearAllPoints()
				c.Citas:SetPoint("TOPLEFT", c, "TOPLEFT", pad, -h)
				h = h + K.Parrafo(c.Citas, cw - 2 * pad) + pad
				c.alfaAlto = h
				alto = max(alto, h)
				b.En(c, xt + col * (cw + esp), y)
				c:SetWidth(cw)
			end
			-- La misma altura en cada fila.
			for i, c in ipairs(b.dias) do
				local inicio = floor((i - 1) / cols) * cols + 1
				local h = 0
				for j = inicio, min(inicio + cols - 1, #b.dias) do h = max(h, b.dias[j].alfaAlto or 0) end
				c:SetHeight(h)
			end
			return y + alto
		end,
		llenar = function(b)
			local activo = N.Get(ID, "citas") ~= false
			local semana = activo and Ci.Semana() or {}
			for i, c in ipairs(b.dias) do
				local d = semana[i]
				K.Mostrar(c, d ~= nil)
				if d then
					K.Escribir(c.Titulo, d.titulo)
					K.Escribir(c.Fecha, d.fecha)
					local lineas = {}
					for _, x in ipairs(d.citas) do
						lineas[#lineas + 1] = format("%s %s", x.hora, x.cita.que or "")
					end
					K.Escribir(c.Citas, #lineas > 0 and table.concat(lineas, "\n") or L["Libre"])
				end
			end
			return {
				titulo = L["La semana de caza"],
				texto = L["Las citas de la manada en los próximos siete días. Propón una arriba, en «Citas de la manada»."],
				filas = {},
				vacio = not activo and L[Ci.MOTIVOS.apagado] or nil,
			}
		end,
	})
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
	local t = L["Quienes usan Alfa y comparten te ven en su mapa y pueden seguirte, y tú a ellos. Se envía tu zona, tu posición, tu nivel y tu clase cada 10 segundos mientras te mueves (cada 4 minutos si estás quieto), nunca dentro de mazmorras. Va por un canal oculto de Alfa: no sale en el chat, pero alguien que entre a ese canal con otro addon podría leerlo."]
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
	local invitar = K.GrupoAjustes(padre, { titulo = L["Invitar"] })
	invitar:Fila({ titulo = L["«Invitar al clan» en el clic derecho"], control = interruptor("invitarMenu"),
		texto = L["Clic derecho en un jugador (su retrato, su nombre en el chat o tu grupo) y elige tu hermandad: la invitación le llega sin escribir su nombre. Para una comunidad, Alfa te deja el nombre listo para pegar en la ventana del juego."] })
	invitar:Fila({ titulo = L["Tu insignia en los retratos"], control = interruptor("insigniaRetrato"),
		texto = L["Quien lleva la insignia de La Jauría la luce en el borde de su retrato: en el tuyo, el de tu objetivo y el de tu foco."] })
	local guaridas = K.GrupoAjustes(padre, { titulo = L["Guaridas"] })
	guaridas:Fila({ titulo = L["Raros de la manada"], control = interruptor("rarosManada"), activa = function() return on("compartir") end,
		texto = L["Cuando un lobo encuentra un raro o un tesoro en tu zona, te avisa en qué guarida está. Si es la tuya, «Ir de caza»; si es otra, «Pedir entrar»."] })
	guaridas:Fila({ titulo = L["Llamados de la manada"], control = interruptor("llamados"), activa = function() return on("compartir") end,
		texto = L["Cuando un lobo de tu zona pide ayuda, te avisa dónde está con «¡Voy!»: la flecha te lleva y le dice que vas."] })
	guaridas:Fila({ titulo = L["Tu guarida a la vista"], control = interruptor("guaridaVisible"),
		texto = L["Tu guarida en el rastreador y en el cuadro de los lobos, y Lya te avisa si el juego te cambia de capa."] })
	-- 1.2.7: cazar en manada.
	local caza = K.GrupoAjustes(padre, { titulo = L["Cazar en manada"] })
	caza:Fila({ titulo = L["Marcar el raro para todos"], control = interruptor("marcarRaro"),
		texto = L["En grupo, al seleccionar un raro sin marca, Alfa te ofrece ponerle la calavera con un clic: todo tu grupo la ve. En banda, si eres líder o ayudante."] })
	caza:Fila({ titulo = L["Cazar juntos"], control = interruptor("cazarJuntos"), activa = function() return on("compartir") end,
		texto = L["La manada sabe qué misiones llevas (solo cuáles son) y tú las suyas. Si un lobo de tu zona hace una contigo, su tarjeta lo dice y Lya te propone invitarlo."] })
	caza:Fila({ titulo = L["El saludo de la manada"], control = interruptor("saludo"),
		texto = L["Al entrar al juego, Lya te dice quién de tu hermandad anda conectado y dónde."] })
	caza:Fila({ titulo = L["Un lobo de La Jauría anda cerca"], control = interruptor("lobosCerca"),
		texto = L["Cuando ves a alguien que también usa Alfa (y comparte con la manada), un anuncio corto te lo dice para que lo saludes."] })
	-- 1.2.8: la manada se organiza.
	local junta = K.GrupoAjustes(padre, { titulo = L["La manada se organiza"] })
	junta:Fila({ titulo = L["Citas de la manada"], control = interruptor("citas"),
		texto = L["Propón una salida con día y hora y recibe las de tu hermandad con «Voy». Lya te la recuerda 15 minutos antes."] })
	junta:Fila({ titulo = L["¿Quién va?"], control = interruptor("quienVa"), activa = function() return on("compartir") end,
		texto = L["Al llegar a una zona con una mazmorra para tu nivel, Lya te dice quién de la manada anda cerca y va a tu nivel, con «Invitar»."] })
	junta:Fila({ titulo = L["Raros con reloj"], control = interruptor("rarosReloj"),
		texto = L["Alfa recuerda cuándo cayó cada raro: su cuadro dice hace cuánto lo cazaron y si pudo volver ya."] })
	junta:Fila({ titulo = L["Notas del lobo"], control = interruptor("notas"),
		texto = L["Tus notas en el mapa, donde las dejas. Un clic en la marca y la flecha te lleva."] })
	junta:Fila({ titulo = L["Compartir con la manada"], control = interruptor("notasCompartir"),
		activa = function() return N.Get(ID, "notas") ~= false end,
		texto = L["Tus notas nuevas también salen en el mapa de los lobos de tu hermandad, y ves las suyas."] })
	-- 1.2.9: planos, ¿quién tiene...?, logros y la semana.
	local juntos = K.GrupoAjustes(padre, { titulo = L["La manada unida"] })
	juntos:Fila({ titulo = L["Cambiar de plano si está lleno"], control = interruptor("planoAviso"), activa = function() return on("compartir") end,
		texto = L["Si tu plano se llena de cazadores, Lya te propone pasarte al de un lobo de la manada con su guarida abierta. Una vez cada 15 minutos."] })
	juntos:Fila({ titulo = L["Contestar «¿Quién tiene...?»"], control = interruptor("quienTiene"),
		texto = L["Si un lobo de tu hermandad busca un objeto que llevas, Alfa le dice cuántos tienes. Solo eso y solo cuando pregunta."] })
	juntos:Fila({ titulo = L["Festejos de la manada"], control = interruptor("logros"),
		texto = L["Lya festeja cuando un lobo de tu hermandad llega al nivel 60, consigue su primera montura o caza un raro."] })
	juntos:Fila({ titulo = L["Compartir mis logros"], control = interruptor("logrosCompartir"),
		texto = L["Tu hermandad se entera cuando llegas al nivel 60, consigues tu primera montura o cazas un raro."] })
	juntos:Fila({ titulo = L["Compartir mi semana"], control = interruptor("semanaCompartir"),
		texto = L["Tus misiones, raros, mazmorras y niveles de la semana suman en «La semana de la manada» de tu hermandad."] })
	-- 1.3.0: la manada crece.
	local crece = K.GrupoAjustes(padre, { titulo = L["La manada crece"] })
	crece:Fila({ titulo = L["Spots de farmeo"], control = interruptor("spots"), activa = function() return N.Get(ID, "notas") ~= false end,
		texto = L["Tus spots de farmeo en el mapa, dorados y en su propia capa."] })
	crece:Fila({ titulo = L["Compartir mis spots"], control = interruptor("spotsCompartir"),
		activa = function() return N.Get(ID, "notas") ~= false and N.Get(ID, "spots") ~= false end,
		texto = L["Tus spots nuevos también salen en el mapa de los lobos de tu hermandad, y ves los suyos."] })
	crece:Fila({ titulo = L["El tablón de la manada"], control = interruptor("tablon"),
		texto = L["Ve quién de tu hermandad busca grupo y pon tu anuncio. Se quita solo en una hora."] })
	crece:Fila({ titulo = L["Mentor"], control = interruptor("mentor"),
		texto = L["Adopta a un lobo nuevo o deja que uno con más nivel te adopte. Lo que comparten queda entre los dos."] })
	crece:Fila({ titulo = L["Botín para la manada"], control = interruptor("botin"),
		texto = L["Si levantas algo que se puede regalar y le sirve a un lobo conectado, Alfa te lo dice con «Regalárselo»."] })
	crece:Fila({ titulo = L["Compartir mi clase y nivel"], control = interruptor("botinCompartir"),
		texto = L["Tu hermandad sabe tu clase y tu nivel, para que te avisen si les sale algo que te sirve."] })
	crece:Fila({ titulo = L["Guaridas en el mapa"], control = interruptor("guaridasMapa"), activa = function() return on("compartir") end,
		texto = L["En el mapa del mundo, cada zona con lobos dice cuántos hay en cada guarida."] })
	crece:Fila({ titulo = L["El calendario de la manada"], control = interruptor("calendario"), activa = function() return N.Get(ID, "citas") ~= false end,
		texto = L["Las citas de los próximos siete días, acomodadas por día."] })
	return { rastro, mapa, invitar, guaridas, caza, junta, juntos, crece }
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
			texto = L["Es opcional: tu personaje aparece en el mapa de WoW de los lobos de La Jauría que usan Alfa, y ellos en el tuyo, para encontrarse y llegar con la flecha. Solo se comparte dónde anda tu personaje dentro del juego (zona, punto en el mapa, nivel y clase), nunca tu ubicación real ni nada de tu computadora, y nunca dentro de mazmorras. Va por un canal oculto que no sale en el chat, aunque alguien que entre a él con otro addon podría verlo. Tu grupo se ve siempre. Lo cambias cuando quieras en La Jauría."],
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
	partes[#partes + 1] = M.Guaridas.version
	partes[#partes + 1] = M.Juntos and M.Juntos.version or 0 -- 1.2.7
	-- 1.2.8: citas, notas, raros con reloj y la hora (los «hace X min»).
	partes[#partes + 1] = (M.Cita and M.Cita.version or 0) .. ":" .. (M.Notas and M.Notas.version or 0) .. ":" .. (M.Reloj and M.Reloj.version or 0)
	partes[#partes + 1] = floor(U.Reloj() / 60)
	-- 1.2.9: el plano, ¿quién tiene...? y la semana.
	partes[#partes + 1] = (M.Plano and M.Plano.version or 0) .. ":" .. (M.QuienTiene and M.QuienTiene.version or 0) .. ":" .. (M.Logros and M.Logros.version or 0)
	-- 1.3.0: el tablón, el mentor, el botín y los ajustes nuevos.
	partes[#partes + 1] = (M.Tablon and M.Tablon.version or 0) .. ":" .. (M.Mentor and M.Mentor.version or 0) .. ":" .. (M.Botin and M.Botin.version or 0)
		.. ":" .. tostring(N.Get(ID, "calendario"))
	return table.concat(partes, "|")
end

-- (1.3.2) El bloque de cada función y su ajuste: apagada, su bloque no sale.
local BLOQUE_AJUSTE = {
	citas = "citas", tablon = "tablon", notas = "notas", cazados = "rarosReloj",
	mentor = "mentor", botin = "botin",
}

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
	ui.guaridas:Llenar()
	ui.citas:Llenar()
	ui.notas:Llenar()
	ui.cazados:Llenar()
	ui.quienTiene:Llenar()
	ui.semana:Llenar()
	ui.tablon:Llenar()
	ui.mentor:Llenar()
	ui.botin:Llenar()
	ui.guaridasVivo:Llenar()
	ui.calendario:Llenar()
	-- 1.3.2: lo que apagaste no ocupa la página (se prende en los ajustes de abajo).
	local citas = N.Get(ID, "citas") ~= false
	K.Mostrar(ui.calendario, citas and N.Get(ID, "calendario") ~= false)
	for bloque, clave in pairs(BLOQUE_AJUSTE) do
		if ui[bloque] then K.Mostrar(ui[bloque], N.Get(ID, clave) ~= false) end
	end
	ui.clan:Llenar()
	ui.lya:Llenar()
	ui.filaCompartir.alfaDatos.texto = textoCompartir()
	for _, g in ipairs(ui.ajustes) do g:Refrescar() end
	ui.firma = firma(ui, gente)
end

local ticker

local function alMostrar()
	if ticker then return end
	ticker = N.Ticker("manada.pagina", REFRESCO, function()
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
	ui.guaridas = t:AgregarBloque(bloqueGuaridas(t.Extra))
	ui.citas = t:AgregarBloque(bloqueCitas(t.Extra), { espacio = ESP.l })
	ui.calendario = t:AgregarBloque(bloqueCalendario(t.Extra), { espacio = ESP.l }) -- 1.3.0
	ui.tablon = t:AgregarBloque(bloqueTablon(t.Extra), { espacio = ESP.l })
	ui.guaridasVivo = t:AgregarBloque(bloqueGuaridasVivo(t.Extra), { espacio = ESP.l })
	ui.notas = t:AgregarBloque(bloqueNotas(t.Extra), { espacio = ESP.l })
	ui.cazados = t:AgregarBloque(bloqueCazados(t.Extra), { espacio = ESP.l })
	ui.quienTiene = t:AgregarBloque(bloqueQuienTiene(t.Extra), { espacio = ESP.l })
	ui.semana = t:AgregarBloque(bloqueSemana(t.Extra), { espacio = ESP.l })
	ui.mentor = t:AgregarBloque(bloqueMentor(t.Extra), { espacio = ESP.l }) -- 1.3.0
	ui.botin = t:AgregarBloque(bloqueBotin(t.Extra), { espacio = ESP.l })
	ui.clan = t:AgregarBloque(bloqueClan(ui, t.Extra), { espacio = ESP.l })
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

