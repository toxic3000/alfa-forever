-- Alfa - Rutas: «Lo que sigues» (1.3.7), todo lo que tienes en curso
-- (toxic3000 / La Jauría). GPL-3.0.
--
-- El motor deja abiertas hasta Engine.MAX_TABS guías a la vez (12 desde la
-- 1.3.7; tools/parches.py): las que abres tú, y también los planes, rutas,
-- circuitos y recogidas que arma Alfa (cada uno es una guía en su pestaña).
-- Se ven y se manejan en la sección Planes de la ventana de Alfa
-- (PaginaPlanes.lua): cuánto llevas de cada una, cuándo la tocaste, Seguir,
-- Fijar y Quitar (con Deshacer). Tu plan de metas (Mis planes) sale también,
-- aunque no ocupa pestaña.
--
-- Con las 12 ocupadas, abrir otra no se bloquea: el motor llama a
-- Engine.HacerLugar (EC.HacerLugar) y Alfa quita la que tocaste hace más
-- tiempo (a igual, la que da menos experiencia), nunca la que sigues ni las
-- fijadas, con un aviso «Quité "X" para hacer lugar» y su Deshacer. Solo si
-- todas están fijadas sale el cuadro «¿cuál quitas?» (EC.Elegir).
--
--   EC.Lista() -> { { tipo = "guia" | "plan", id, nombre, activa, fijada, paso, pasos, hechos, total, tocada }, ... }
--   EC.Cuantas() -> guías abiertas, máximo, ¿lleno?     EC.CuentaTexto() -> "10/12", tono | nil
--   EC.Abrir()  EC.Seguir(it)  EC.Quitar(it)  EC.QuitarOtras(sinPreguntar)  EC.Deshacer()
--   EC.Fijada(id)  EC.Fijar(id, si)  EC.Candidata() -> la que se quitaría sola
--   EC.HacerLugar(nuevoId) -> true   EC.Elegir(nuevoId)   el cuadro de elegir
--   EC.AvisoLleno(texto)  ya no cabe otra (todas fijadas): el cuadro, o el aviso
--   EC.AccionLleno() -> { texto, alClic }  «Editar planes», para quien arma su aviso
--   EC.AbandonarMision(qid)  con confirmación (Grises.lua)
-- AlfaRuta.EnCurso(), AlfaRuta.AvisoLleno(texto), AlfaRuta.AccionLleno(),
-- AlfaRuta.CuentaPlanes(), AlfaRuta.TextoLleno().

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K

local EC = {}
M.EnCurso = EC

local type, ipairs, pairs, tostring, tonumber, pcall = type, ipairs, pairs, tostring, tonumber, pcall
local format, floor, max, min, concat = string.format, math.floor, math.max, math.min, table.concat

local PAGINA = "planes" -- la sección Planes (PaginaPlanes.lua)

local function E() return M.Motor("Engine") end
local function ahora() return (GetServerTime and GetServerTime()) or (time and time()) or 0 end
local function llamar(fn, ...)
	if type(fn) ~= "function" then return nil end
	local ok, a, b = pcall(fn, ...)
	if ok then return a, b end
	if geterrorhandler then geterrorhandler()(a) end
	return nil
end

---------------------------------------------------------------------------
-- Cuándo tocaste cada cosa (por personaje): rutas.tocadas[id] = hora
-- Y las que fijaste (nunca se quitan solas): rutas.fijadas[id] = true
---------------------------------------------------------------------------
local MAX_TOCADAS = 40
local function tocadas()
	local d = M.Personaje()
	if type(d.tocadas) ~= "table" then d.tocadas = {} end
	return d.tocadas
end
local function tocar(id)
	if type(id) ~= "string" or id == "" then return end
	local t = tocadas()
	t[id] = ahora()
	-- Que no crezca sin fin: fuera las más viejas.
	local n, vieja, cual = 0, nil, nil
	for k, v in pairs(t) do
		n = n + 1
		if not vieja or (tonumber(v) or 0) < vieja then vieja, cual = tonumber(v) or 0, k end
	end
	if n > MAX_TOCADAS and cual then t[cual] = nil end
end
EC.Tocar = tocar

local function fijadas()
	local d = M.Personaje()
	if type(d.fijadas) ~= "table" then d.fijadas = {} end
	return d.fijadas
end
function EC.Fijada(id) return type(id) == "string" and fijadas()[id] == true end

local function guiaActiva()
	local e = E()
	local g = e and e.GetGuide and llamar(e.GetGuide)
	return type(g) == "table" and g.id or nil
end

---------------------------------------------------------------------------
-- La lista
---------------------------------------------------------------------------
function EC.Maximo()
	local e = E()
	return (e and tonumber(e.MAX_TABS)) or 12
end

local function pestanas(conCuentas)
	local e = E()
	if not (e and e.GetTabs) then return {}, 0 end
	local ok, tabs, activa = pcall(e.GetTabs, conCuentas)
	if not ok or type(tabs) ~= "table" then return {}, 0 end
	return tabs, tonumber(activa) or 0
end

local function guiaDe(id)
	local Gd = M.Motor("Guides")
	return Gd and Gd.Get and llamar(Gd.Get, id) or nil
end

local function nombreDe(t)
	local g = guiaDe(t.guideId)
	local n = g and M.NombreGuia and M.NombreGuia(g)
	if type(n) == "string" and n ~= "" then return n end
	return type(t.title) == "string" and t.title ~= "" and t.title or tostring(t.guideId or "?")
end

function EC.Cuantas()
	local tabs = pestanas(false)
	local maxi = EC.Maximo()
	return #tabs, maxi, #tabs >= maxi
end

-- El número de la sección Planes: «10/12» cuando está casi llena (te faltan
-- dos o menos), con su tono. -> texto, tono | nil
function EC.CuentaTexto()
	local n, maxi, lleno = EC.Cuantas()
	if n < maxi - 2 or n == 0 then return nil end
	return format("%d/%d", n, maxi), lleno and "peligro" or "aviso"
end

function EC.Lista()
	local out = {}
	local tabs, activa = pestanas(true)
	local toc, fij = tocadas(), fijadas()
	for i, t in ipairs(tabs) do
		if type(t) == "table" and t.guideId then
			out[#out + 1] = { tipo = "guia", indice = i, id = t.guideId, nombre = nombreDe(t), activa = i == activa,
				fijada = fij[t.guideId] == true,
				paso = tonumber(t.stepNumber), pasos = tonumber(t.stepTotal), hechos = tonumber(t.done), total = tonumber(t.total),
				tocada = tonumber(toc[t.guideId]) }
		end
	end
	local Pl = M.Planes
	local pl = Pl and Pl.Activo and Pl.Activo()
	if pl then
		local n, total = Pl.Avance(pl)
		out[#out + 1] = { tipo = "plan", id = pl.id, nombre = pl.nombre or L["Mi plan"], hechos = n, total = total,
			tocada = tonumber(toc["plan:" .. tostring(pl.id)]) }
	end
	return out
end

-- «Paso 12 de 40 · 30 % · la tocaste hace 5 min»
local function hace(t)
	if not t then return nil end
	local s = ahora() - t
	if s < 60 then return L["hace un momento"] end
	if s >= 86400 then
		local d = floor(s / 86400)
		return N.Plural(d, L["hace %d día"], L["hace %d días"])
	end
	return format(L["hace %s"], N.Duracion(s, true))
end
function EC.Linea(it, sinTocada)
	local partes = {}
	if it.tipo == "plan" then
		partes[#partes + 1] = format(L["%d de %d metas"], it.hechos or 0, it.total or 0)
	elseif it.paso and it.pasos and it.pasos > 0 then
		partes[#partes + 1] = format(L["Paso %d de %d"], min(it.paso, it.pasos), it.pasos)
	elseif it.total and it.total > 0 then
		partes[#partes + 1] = format(L["%d de %d pasos hechos"], it.hechos or 0, it.total)
	elseif it.pasos and it.pasos > 0 then
		partes[#partes + 1] = M.Plural(it.pasos, L["%d paso"], L["%d pasos"])
	end
	if it.total and it.total > 0 then
		partes[#partes + 1] = format(L["%d %%"], floor(100 * (it.hechos or 0) / it.total + 0.5))
	end
	if not sinTocada then
		local h = hace(it.tocada)
		partes[#partes + 1] = h and format(L["la tocaste %s"], h) or L["todavía sin tocar"]
	end
	return concat(partes, "  \194\183  ")
end

---------------------------------------------------------------------------
-- Seguir, fijar, quitar y deshacer
---------------------------------------------------------------------------
local refrescar
local deshacer -- { guias = { { id, at } }, activa = id, plan = id } | { lugar = { id, at }, nueva = id, activa = id }

local function indiceDe(id)
	for i, t in ipairs((pestanas(false))) do
		if t.guideId == id then return i end
	end
	return nil
end

-- La pone como la guía que sigues (la flecha y el rastreador van con ella).
function EC.Seguir(it)
	if type(it) ~= "table" then return false end
	if it.tipo == "plan" then
		if AlfaPlanes and AlfaPlanes.Abrir then AlfaPlanes.Abrir(it.id) end
		return true
	end
	local e = E()
	local i = indiceDe(it.id)
	if not (e and e.SelectTab and i) then return false end
	llamar(e.SelectTab, i)
	tocar(it.id)
	if A.Set then A.Set("ui.shown", true) end
	if refrescar then refrescar() end
	M.Avisar("SEGUIR", "encurso")
	return true
end

function EC.Fijar(id, si)
	if type(id) ~= "string" then return false end
	if si == nil then si = not EC.Fijada(id) end
	fijadas()[id] = si and true or nil
	if refrescar then refrescar() end
	return si
end

local function avisoDeshacer(titulo, texto, conPlanes)
	local acs = { { texto = L["Deshacer"], alClic = function() EC.Deshacer() end } }
	if conPlanes then acs[2] = { texto = L["Ver Planes"], alClic = function() EC.Abrir() end } end
	M.Aviso(titulo, texto, { icono = "ic-lista", pedido = true, lya = false, historial = false, acciones = acs })
end

-- Quita la pestaña del motor que ya no está en la ventana de guía: el aviso de
-- «pestaña cerrada» de esa ventana sobra (ya va el de Alfa, con su Deshacer).
local function sinAvisoDelMotor()
	local UI = A.UI
	local GF = UI and UI.GuideFrame
	if GF and type(GF.notices) == "table" then GF.notices.closedTab = nil end
end

-- Cierra la pestaña de la guía `id` (como la X del motor: queda entre las
-- cerradas, para volver a abrirla en su lugar). -> true
local function cerrarGuia(id)
	local e = E()
	local i = indiceDe(id)
	if not (e and e.CloseTab and i) then return false end
	llamar(e.CloseTab, i)
	sinAvisoDelMotor()
	return indiceDe(id) == nil
end

function EC.Quitar(it)
	if type(it) ~= "table" then return false end
	if it.tipo == "plan" then
		local Pl = M.Planes
		if not (Pl and Pl.Dejar) then return false end
		Pl.Dejar()
		deshacer = { plan = it.id }
		avisoDeshacer(L["Dejaste de seguir tu plan"], it.nombre)
	else
		local activa = guiaActiva()
		local at = indiceDe(it.id)
		if not cerrarGuia(it.id) then return false end
		deshacer = { guias = { { id = it.id, at = at } }, activa = activa ~= it.id and activa or it.id }
		avisoDeshacer(L["Guía quitada"], it.nombre)
	end
	if refrescar then refrescar() end
	M.Avisar("SEGUIR", "encurso")
	return true
end

-- Todas las guías menos la que sigues ahora y las fijadas (tu plan se
-- queda). -> cuántas
function EC.QuitarOtras(sinPreguntar)
	local activa = guiaActiva()
	local otras = {}
	for _, it in ipairs(EC.Lista()) do
		if it.tipo == "guia" and not it.activa and not it.fijada then otras[#otras + 1] = it end
	end
	if #otras == 0 then return 0 end
	local function hacer()
		local hechas = {}
		for _, it in ipairs(otras) do
			local at = indiceDe(it.id)
			if cerrarGuia(it.id) then hechas[#hechas + 1] = { id = it.id, at = at } end
		end
		if #hechas > 0 then
			deshacer = { guias = hechas, activa = activa }
			avisoDeshacer(L["Guías quitadas"], N.Plural(#hechas, L["Quitaste %d guía; sigues con la de ahora."], L["Quitaste %d guías; sigues con la de ahora."]))
		end
		if refrescar then refrescar() end
		M.Avisar("SEGUIR", "encurso")
		return #hechas
	end
	if sinPreguntar then return hacer() end
	local nombres = {}
	for i, it in ipairs(otras) do
		if i > 8 then nombres[#nombres + 1] = format(L["y %d más"], #otras - 8) break end
		nombres[#nombres + 1] = "- " .. it.nombre
	end
	K.Dialogo({
		titulo = N.Plural(#otras, L["¿Quitar %d guía?"], L["¿Quitar %d guías?"]),
		texto = concat(nombres, "\n") .. "\n\n" .. L["Sigues con la de ahora, con las que fijaste y con tu plan, si tienes. Puedes deshacerlo enseguida."],
		aceptar = L["Quitar"], peligro = true, alAceptar = hacer, pedido = true,
	})
	return #otras
end

function EC.PuedeDeshacer() return deshacer ~= nil end

-- Vuelve lo último que quitaste, en su lugar. -> true
function EC.Deshacer()
	local d = deshacer
	if not d then return false end
	deshacer = nil
	local hizo = false
	if d.plan then
		local Pl = M.Planes
		if Pl and Pl.Seguir then hizo = Pl.Seguir(d.plan) and true or false end
	end
	local e = E()
	-- La que se quitó para hacer lugar: se va la nueva y vuelve ella.
	if d.lugar and e and e.ReopenClosedTab then
		if d.nueva and indiceDe(d.nueva) then cerrarGuia(d.nueva) end
		if not indiceDe(d.lugar.id) and llamar(e.ReopenClosedTab, d.lugar.id) then hizo = true end
		local i = d.activa and indiceDe(d.activa)
		if i and e.SelectTab then llamar(e.SelectTab, i) end
	end
	if d.guias and e and e.ReopenClosedTab then
		-- En el orden en que estaban (de izquierda a derecha), cada una a su lugar.
		table.sort(d.guias, function(a, b) return (a.at or 99) < (b.at or 99) end)
		for _, g in ipairs(d.guias) do
			if not indiceDe(g.id) and llamar(e.ReopenClosedTab, g.id) then hizo = true end
		end
		-- Reabrir activa la guía: se vuelve a la que seguías.
		local i = d.activa and indiceDe(d.activa)
		if i and e.SelectTab then llamar(e.SelectTab, i) end
	end
	if refrescar then refrescar() end
	M.Avisar("SEGUIR", "encurso")
	return hizo
end

---------------------------------------------------------------------------
-- Hacer lugar: con las 12 ocupadas, la que se va sola
---------------------------------------------------------------------------
-- Cuánta experiencia da todavía una guía (para desempatar): una de subir de
-- nivel, sus pasos que faltan; las demás (profesiones, un objeto, una
-- mazmorra...) casi nada.
local function experienciaDe(it)
	if type(it.id) == "string" and it.id:find("^lookup/") then return 0 end
	local g = guiaDe(it.id)
	local cat = g and g.category
	if cat ~= nil and cat ~= "" and cat ~= "Leveling" then return 0 end
	if it.pasos and it.paso then return max(0, it.pasos - it.paso) + 1 end
	if it.total then return max(0, it.total - (it.hechos or 0)) + 1 end
	return 1
end

-- La que se quitaría sola: la que tocaste hace más tiempo (nunca tocada:
-- la más vieja) y, a igual, la que da menos experiencia; nunca la que sigues
-- ni una fijada. -> it | nil (todas fijadas)
function EC.Candidata()
	local mejor
	for _, it in ipairs(EC.Lista()) do
		if it.tipo == "guia" and not it.activa and not it.fijada then
			it.xp = experienciaDe(it)
			local t = it.tocada or 0
			if not mejor or t < (mejor.tocada or 0) or (t == (mejor.tocada or 0) and it.xp < mejor.xp) then mejor = it end
		end
	end
	return mejor
end

local pendiente -- la guía que no cupo (todas fijadas): la abre EC.Elegir

function EC.HacerLugar(nuevoId)
	local n, maxi = EC.Cuantas()
	if n < maxi then return true end
	local it = EC.Candidata()
	if not it then
		pendiente = type(nuevoId) == "string" and nuevoId or nil
		return false
	end
	local activa = guiaActiva()
	local at = indiceDe(it.id)
	if not cerrarGuia(it.id) then return false end
	deshacer = { lugar = { id = it.id, at = at }, nueva = nuevoId, activa = activa }
	avisoDeshacer(format(L["Quité «%s» para hacer lugar"], it.nombre),
		format(L["Ya seguías %d guías: quité la que tocaste hace más tiempo. Las que fijas en Planes nunca se quitan solas."], maxi), true)
	if refrescar then refrescar() end
	return true
end
EC.Pendiente = function() return pendiente end

---------------------------------------------------------------------------
-- El cuadro de elegir (todas fijadas): «¿cuál quitas para seguir esta?»
---------------------------------------------------------------------------
local elegir, elegirUi = nil, {}

-- Tras abrir la guía nueva: la flecha y el rastreador con ella, y las
-- ventanas de Alfa se cierran (la Enciclopedia, si su ajuste lo pide).
local function empezarNueva()
	local Enc = rawget(_G, "AlfaEnciclopediaVentana")
	local deEnc = Enc and Enc.IsShown and Enc:IsShown()
	if deEnc and A.Get and A.Get("enciclopedia.cerrarAlGuiar") == false then
		if A.Set then A.Set("ui.shown", true) end
		return
	end
	M.Empezar()
end

local function elegida(it, nuevoId)
	local e = E()
	if not (e and e.OpenTab) then return false end
	local activa = guiaActiva()
	local at = indiceDe(it.id)
	fijadas()[it.id] = nil
	if not cerrarGuia(it.id) then return false end
	if elegir then elegir:Cerrar() end
	pendiente = nil
	local i = llamar(e.OpenTab, nuevoId, true)
	deshacer = { lugar = { id = it.id, at = at }, nueva = i and nuevoId or nil, activa = activa }
	avisoDeshacer(format(L["Quité «%s» para hacer lugar"], it.nombre), i and L["La nueva ya arrancó: sigue la flecha."] or nil, true)
	if i then
		tocar(nuevoId)
		empezarNueva()
	end
	if refrescar then refrescar() end
	M.Avisar("SEGUIR", "encurso")
	return i ~= nil
end

local function filaElegir(p)
	local f = CreateFrame("Frame", nil, p)
	f.caja = K.Caja(f, { fondo = "panel", borde = "linea", corte = K.CORTE.control })
	f.Titulo = K.Texto(f, "cuerpo", "texto")
	f.Texto = K.Texto(f, "pequeno", "textoTenue")
	f.Boton = K.Boton(f, L["Quitar esta"], nil, { tipo = "secundario", tam = "chico" })
	function f:Acomodar(ancho)
		local pad = K.ESP.m
		local bw = self.Boton:AnchoNatural()
		self.Boton:ClearAllPoints()
		self.Boton:SetPoint("RIGHT", self, "RIGHT", -pad, 0)
		local tw = max(60, ancho - 3 * pad - bw)
		self.Titulo:ClearAllPoints()
		self.Titulo:SetPoint("TOPLEFT", self, "TOPLEFT", pad, -pad)
		self.Titulo:SetWordWrap(true)
		local h1 = K.Parrafo(self.Titulo, tw, 2)
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self.Titulo, "BOTTOMLEFT", 0, -2)
		local h2 = K.Parrafo(self.Texto, tw, 2)
		local h = max(pad * 2 + h1 + 2 + h2, K.num(self.Boton:GetHeight(), 26) + 2 * pad)
		self:SetHeight(h)
		return h
	end
	return f
end

local function llenarElegir(nuevoId)
	local lista = {}
	for _, it in ipairs(EC.Lista()) do if it.tipo == "guia" then lista[#lista + 1] = it end end
	K.Escribir(elegirUi.intro.Texto, L["Todas están fijadas. Elige cuál quitas y la nueva arranca enseguida; puedes deshacerlo en el aviso."])
	for i, it in ipairs(lista) do
		local f = elegirUi.filas[i]
		if not f then
			f = elegirUi.pila:Agregar(filaElegir(elegirUi.pila))
			elegirUi.filas[i] = f
		end
		local extra = {}
		if it.activa then extra[#extra + 1] = L["La sigues ahora"] end
		if it.fijada then extra[#extra + 1] = L["Fijada"] end
		K.Escribir(f.Titulo, it.nombre)
		extra[#extra + 1] = EC.Linea(it)
		K.Escribir(f.Texto, concat(extra, "  \194\183  "))
		f.Boton.alClic = function() elegida(it, nuevoId) end
		f:Show()
	end
	for i = #lista + 1, #elegirUi.filas do elegirUi.filas[i]:Hide() end
	local ancho = elegir:AnchoCuerpo()
	local h = elegirUi.pila:Acomodar(ancho)
	elegirUi.pila:ClearAllPoints()
	elegirUi.pila:SetPoint("TOPLEFT", elegir.Cuerpo, "TOPLEFT", elegir.margen, -elegir.margen)
	elegir:SetAltoContenido(h + 2 * elegir.margen)
end

function EC.Elegir(nuevoId)
	nuevoId = nuevoId or pendiente
	if not (K and type(nuevoId) == "string") then return nil end
	pendiente = nuevoId
	if not elegir then
		elegir = K.Ventana({ nombre = "AlfaRutasElegir", titulo = L["¿Cuál quitas?"], icono = "ic-lista", ancho = 480, alto = 520, desplazar = true })
		local p = K.Pila(elegir.Cuerpo, { espacio = K.ESP.s })
		elegirUi.pila, elegirUi.filas = p, {}
		elegirUi.intro = p:Agregar((function()
			local f = CreateFrame("Frame", nil, p)
			f.Texto = K.Texto(f, "nota", "textoSuave")
			f.Texto:SetPoint("TOPLEFT")
			function f:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
			return f
		end)())
		local editar = K.Boton(elegir, L["Editar planes"], function() elegir:Cerrar() EC.Abrir() end, { tipo = "secundario" })
		local cancelar = K.Boton(elegir, L["Cancelar"], function() pendiente = nil elegir:Cerrar() end, { tipo = "fantasma" })
		elegir:SetPie({ cancelar }, { editar })
		elegir.alAcomodar = function() if elegir:IsShown() and pendiente then pcall(llenarElegir, pendiente) end end
	end
	local g = guiaDe(nuevoId)
	local nombre = g and M.NombreGuia and M.NombreGuia(g) or (g and g.title) or nuevoId
	elegir:SetTitulo(format(L["Ya sigues %d guías"], EC.Maximo()), format(L["¿Cuál quitas para seguir «%s»?"], nombre), "ic-lista")
	elegir:Abrir()
	local ok, err = pcall(llenarElegir, nuevoId)
	if not ok and geterrorhandler then geterrorhandler()(err) end
	return elegir
end

---------------------------------------------------------------------------
-- El aviso de «ya no cabe otra guía» (todas fijadas, o algo automático)
---------------------------------------------------------------------------
function EC.AccionLleno()
	return { texto = L["Editar planes"], alClic = function() EC.Abrir() end }
end

function EC.TextoLleno()
	return format(L["Ya sigues %d guías y todas están fijadas. Suelta una en Planes y vuelve a intentar."], EC.Maximo())
end

function EC.AvisoLleno(texto)
	-- La que no cupo se elige ahí mismo: ¿cuál quitas?
	if pendiente and EC.Elegir(pendiente) then return true end
	return M.Aviso(format(L["Ya sigues %d guías"], EC.Maximo()), texto or EC.TextoLleno(),
		{ icono = "ic-aviso", tono = "aviso", pedido = true, importante = true, lya = false,
			acciones = { EC.AccionLleno() } })
end

---------------------------------------------------------------------------
-- Abandonar una misión (con confirmación; el juego no la restringe)
---------------------------------------------------------------------------
function EC.AbandonarMision(qid)
	if InCombatLockdown and InCombatLockdown() then
		M.Aviso(L["Abandonar misión"], L["Se puede al salir de combate."], { icono = "ic-aviso", tono = "aviso", pedido = true })
		return false
	end
	local Gr = M.Grises
	if not (Gr and Gr.Abandonar) then return false end
	return Gr.Abandonar(qid)
end

---------------------------------------------------------------------------
-- La sección Planes (PaginaPlanes.lua la llena)
---------------------------------------------------------------------------
function EC.Abrir()
	if N.Abrir then N.Abrir(PAGINA) end
	return true
end

refrescar = function()
	if EC.alCambiar then pcall(EC.alCambiar) end
	if elegir and elegir:IsShown() and pendiente then pcall(llenarElegir, pendiente) end
end
EC.Refrescar = function() refrescar() end

---------------------------------------------------------------------------
-- Lo que cambia
---------------------------------------------------------------------------
if A.On then
	A.On("GUIDE_CHANGED", function(id)
		tocar(type(id) == "string" and id or guiaActiva())
		refrescar()
	end)
	A.On("STEP_CHANGED", function() tocar(guiaActiva()) end)
	A.On("TABS_CHANGED", function() refrescar() end)
end
M.Escuchar("PLAN_AVANCE", function()
	local Pl = M.Planes
	local pl = Pl and Pl.Activo and Pl.Activo()
	if pl then tocar("plan:" .. tostring(pl.id)) end
	refrescar()
end)

-- El motor pregunta aquí al abrir una guía con las 12 ocupadas (tools/parches.py).
do
	local e = E()
	if e then e.HacerLugar = function(id) return EC.HacerLugar(id) end end
end

-- AlfaRuta (Contrato.lua lo completa).
local R = AlfaRuta or {}
AlfaRuta = R
R.EnCurso = function() return EC.Abrir() end
R.AvisoLleno = function(texto) return EC.AvisoLleno(texto) end
R.AccionLleno = function() return EC.AccionLleno() end
R.TextoLleno = function() return EC.TextoLleno() end
R.ListaEnCurso = function() return EC.Lista() end
R.CuentaPlanes = function() return EC.CuentaTexto() end
-- ¿Cabe otra? (hay lugar, o una que se puede quitar sola)
R.PuedeAbrir = function()
	local n, maxi = EC.Cuantas()
	return n < maxi or EC.Candidata() ~= nil
end
