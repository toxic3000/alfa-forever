-- Alfa - Rutas: la página del módulo (tres pestañas: Mi ruta, Liberar
-- misiones y Catálogo de objetos), las acciones que comparten (seguir una
-- ruta, agregarle un objeto, liberar las misiones) y el comando /alfa rutas.
-- Toxic / La Jauría. GPL-3.0.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local W, Th, K = M.W, M.T, M.Kit
local P, I, G = M.Plan, M.Indice, M.Guias

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local floor, max, min, format = math.floor, math.max, math.min, string.format
local num = M.num

local function citar(s)
	if A.Quoted then
		local ok, r = pcall(A.Quoted, s)
		if ok and type(r) == "string" then return r end
	end
	return tostring(s)
end

-- La ventana de opciones de Alfa, donde vive la página.
function M.Ventana()
	local UI = M.Motor("UI")
	local O = UI and UI.Options
	local win = type(O) == "table" and O.frame
	if type(win) == "table" then return win end
	return nil
end

local function cerrarVentana()
	local win = M.Ventana()
	if win and win.Hide then win:Hide() end
end

---------------------------------------------------------------------------
-- Seguir una ruta: plan (si falta) -> pasos -> guía del motor -> pestaña
---------------------------------------------------------------------------

function M.Seguir(r, silencioso)
	if not r then return end
	if #r.tramos == 0 then return K.Aviso(L["Tu ruta no tiene tramos todavía."]) end
	local function compilarCon(plan)
		P.Compilar(r, plan, function(def, motivo, avisos)
			if not def then
				return K.Aviso(motivo == "vacio" and L["La ruta quedó sin pasos: agrega tramos o recalcula."] or I.TextoMotivo(motivo))
			end
			local ok, err = G.Instalar(def)
			if not ok then return K.Aviso(format(L["El motor no aceptó la guía: %s"], tostring(err))) end
			local p = M.Personaje()
			local previo = p.progreso[r.id]
			p.activa = r.id
			p.progreso[r.id] = { firma = M.Firma(r), inicio = previo and previo.inicio or (time and time() or 0),
				nivel = previo and previo.nivel or I.Jugador().level }
			for _, a in ipairs(avisos or {}) do K.Aviso(a) end
			M.Avisar("SEGUIR", r.id)
			if silencioso then
				if G.Abierta(def.id) then K.Aviso(format(L["Tu ruta %s se actualizó."], citar(r.nombre))) end
				return
			end
			local i, por = G.Abrir(def.id)
			if i then
				K.Aviso(format(L["Ruta en marcha: %s. Sigue la flecha."], citar(r.nombre)))
				cerrarVentana()
			elseif por == "tabs" then
				K.Aviso(L["Tienes 6 guías abiertas: cierra una pestaña para abrir tu ruta."])
			else
				K.Aviso(L["Tu ruta está lista en el menú de guías, en Mis rutas."])
			end
		end)
	end
	local plan = P.De(r)
	if plan then return compilarCon(plan) end
	K.Aviso(L["Alfa está armando tu ruta..."])
	P.Armar(r, function(nuevo, motivo)
		if nuevo then compilarCon(nuevo) else K.Aviso(I.TextoMotivo(motivo)) end
		if M.VistaRuta and M.VistaRuta.Visible() then M.VistaRuta.Refrescar() end
	end)
end

-- Desde el catálogo: un objeto a la ruta en seguimiento (o la que editas).
function M.AgregarObjeto(itemId)
	local VR = M.VistaRuta
	local nombre = M.NombreObjeto(itemId)
	if VR and VR.ElegidoPara() and VR.UsarObjeto(itemId) then
		K.Aviso(format(L["Tu tramo de profesión ahora junta %s."], nombre))
		if M.Vista then M.Vista.Mostrar("ruta") end
		return
	end
	local p = M.Personaje()
	local r = M.RutaActiva() or M.RutaEditada() or M.NuevaRuta(L["Mi ruta"], {})
	local t = M.NuevoTramo({ rama = "objeto", item = itemId, cantidad = 1 })
	r.tramos[#r.tramos + 1] = t
	p.editando = r.id
	M.Cambio(r)
	K.Aviso(format(L["%s se agregó a tu ruta %s (tramo %d)."], nombre, citar(r.nombre), #r.tramos))
	if p.activa == r.id and p.guias[r.id] then M.Seguir(r, true) end
end

-- /alfa rutas liberar: revisa el registro y abre la guía, sin pasar por la página.
function M.LiberarAhora()
	P.Registro(function(lista, motivo)
		if not lista then return K.Aviso(I.TextoMotivo(motivo)) end
		P.Liberar(lista, function(def, por)
			if not def then
				return K.Aviso(por == "nada" and L["No tienes misiones que Alfa pueda guiar ahora."] or L["No pude armar la ruta para tus misiones."])
			end
			if not G.Instalar(def) then return K.Aviso(L["No pude armar la ruta para tus misiones."]) end
			local i, por2 = G.Abrir(def.id)
			K.Aviso(i and L["Listo: sigue la flecha para terminar y entregar tus misiones."]
				or (por2 == "tabs" and L["Tienes 6 guías abiertas: cierra una pestaña para abrir la ruta."] or L["La ruta quedó en el menú de guías, en Mis rutas."]))
		end)
	end)
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local V = {}
M.Vista = V
local raiz, pestanas
local paginas, vistas = {}, {}
local actual = "ruta"

local PESTANAS = {
	{ clave = "ruta", texto = L["Mi ruta"], icono = "guides", tip = L["Arma tu árbol de tramos y síguelo con la flecha."] },
	{ clave = "liberar", texto = L["Liberar misiones"], icono = "icon-turnin", tip = L["La ruta más corta para entregar las misiones que ya tienes."] },
	{ clave = "catalogo", texto = L["Catálogo de objetos"], icono = "search", tip = L["Todos los objetos del juego: busca, filtra y consíguelos."] },
}

-- El espacio de la página dentro de la ventana de Alfa.
-- El ancho, del núcleo (N.AnchoPagina); el alto visible del cuerpo de la
-- ventana (psViewH, lo que deja la cabecera y el pie), para que la página no
-- se desplace entera: cada lista se desplaza sola.
local function medidas()
	local win = M.Ventana()
	local ancho = num(N.AnchoPagina and N.AnchoPagina(), nil) or num(win and win.BodyWidth, 654)
	local alto = num(win and win.psViewH, 512) - 14
	return max(560, ancho), max(400, alto)
end

function V.Construir(view)
	local pad = num(W.SHELL and W.SHELL.pad, 32)
	raiz = CreateFrame("Frame", nil, view)
	raiz:SetPoint("TOPLEFT", view, "TOPLEFT", pad, -6)
	pestanas = K.Pestanas(raiz, PESTANAS, function(clave) V.Mostrar(clave) end)
	pestanas:SetPoint("TOPLEFT", raiz, "TOPLEFT", 0, 0)
	pestanas:SetPoint("TOPRIGHT", raiz, "TOPRIGHT", 0, 0)
	vistas.ruta, vistas.liberar, vistas.catalogo = M.VistaRuta, M.VistaLiberar, M.VistaCatalogo
	for clave, v in pairs(vistas) do
		local f = v.Construir(raiz)
		f:SetPoint("TOPLEFT", raiz, "TOPLEFT", 0, -44)
		f:Hide()
		paginas[clave] = f
	end
	view.Refresh = function() return V.Refrescar() end
end

function V.Refrescar()
	if not raiz then return 400 end
	local ancho, alto = medidas()
	raiz:SetSize(ancho, alto)
	for clave, f in pairs(paginas) do
		f:SetSize(ancho, alto - 44)
		f:SetShown(clave == actual)
	end
	pestanas:Marcar(actual)
	local v = vistas[actual]
	if v then v.Refrescar(ancho, alto - 44) end
	return alto + 10
end

function V.Mostrar(clave)
	if not vistas[clave] then clave = "ruta" end
	local cambia = clave ~= actual
	actual = clave
	local v = vistas[clave]
	if cambia and v and v.AlMostrar then v.AlMostrar() end
	if raiz and raiz:IsVisible() then
		V.Refrescar()
	else
		N.Abrir(M.ID)
	end
end

function V.Actual() return actual end

-- Lo que cambia en el juego se ve en la página abierta.
local pendiente = false
local function refrescarLuego()
	if pendiente or not (raiz and raiz:IsVisible()) then return end
	pendiente = true
	A.After(0.5, function()
		pendiente = false
		if raiz and raiz:IsVisible() and actual ~= "liberar" then V.Refrescar() end
	end)
end
A.RegisterEvent("QUEST_TURNED_IN", refrescarLuego)
A.RegisterEvent("BAG_UPDATE_DELAYED", refrescarLuego)
A.On("GUIDE_CHANGED", refrescarLuego)
M.Escuchar("NIVEL", refrescarLuego)
M.Escuchar("SEGUIR", refrescarLuego)

---------------------------------------------------------------------------
-- El módulo
---------------------------------------------------------------------------

N.Modulo({
	id = M.ID, nombre = L["Rutas"], icono = "guides", orden = 12,
	subtitulo = L["Arma tu propia ruta, libera tus misiones y encuentra cualquier objeto del juego."],
	comando = "rutas",
	ajustes = { margen = 2, evitarGrupo = true, soloUsables = false, verRetirados = false },
	construir = function(view) V.Construir(view) end,
})

-- /alfa rutas [liberar | catalogo | seguir | ayuda]
local function ayuda()
	K.Aviso(L["Comandos de Rutas:"])
	K.Aviso("  /alfa rutas  \194\183  " .. L["abre tu ruta"])
	K.Aviso("  /alfa rutas liberar  \194\183  " .. L["arma la ruta para entregar tus misiones abiertas"])
	K.Aviso("  /alfa rutas catalogo  \194\183  " .. L["abre el catálogo de objetos"])
	K.Aviso("  /alfa rutas seguir  \194\183  " .. L["sigue (o actualiza) tu ruta"])
end

A.RegisterCommand("rutas", function(resto)
	local sub = (type(resto) == "string" and resto:match("^%s*(%S+)") or ""):lower()
	if sub == "" or sub == "ruta" then
		V.Mostrar("ruta")
	elseif sub == "liberar" then
		M.LiberarAhora()
	elseif sub == "catalogo" or sub == "objetos" or sub == "catálogo" then
		V.Mostrar("catalogo")
	elseif sub == "seguir" then
		M.Seguir(M.RutaActiva() or M.RutaEditada())
	else
		ayuda()
	end
end, L["Tu ruta, liberar misiones y el catálogo de objetos (/alfa rutas ayuda)."])
