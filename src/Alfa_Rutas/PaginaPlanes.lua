-- Alfa - Rutas: la sección Planes de la ventana de Alfa (1.3.7, toxic3000 /
-- La Jauría). GPL-3.0.
--
-- Va entre Hoy y Aventura (motor/Alfa/UI/Options.lua, SECCIONES) y sale
-- también en Alfa sencillo (N.ESENCIALES). Es «Lo que sigues» (EnCurso.lua)
-- hecho página: cada guía o plan con su nombre, su avance (paso N de M,
-- barra y %), cuándo lo tocaste y «La sigues ahora»; Seguir, Fijar y Quitar
-- (con Deshacer), «Quitar todas menos la actual» y, abajo, tus misiones con
-- «Abandonar una misión…» (con confirmación).

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local K = M.K
local EC = M.EnCurso

local format, ipairs, max = string.format, ipairs, math.max

local ID = "planes"
local vista, t, ui = nil, nil, {}

local function parrafo(p, color, rol)
	local f = CreateFrame("Frame", nil, p)
	f.Texto = K.Texto(f, rol or "nota", color or "textoSuave")
	f.Texto:SetPoint("TOPLEFT")
	function f:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
	return f
end

-- Una fila de botones (de izquierda a derecha, los que están a la vista).
local function filaBotones(p, botones)
	local f = CreateFrame("Frame", nil, p)
	f.botones = botones
	for _, b in ipairs(botones) do K.Adoptar(b, f) end
	function f:Acomodar(ancho)
		local x, y, alto = 0, 0, 0
		for _, b in ipairs(self.botones) do
			if b:IsShown() then
				local w = b:AnchoNatural()
				if x > 0 and x + w > ancho then x, y = 0, y + alto + K.ESP.s end
				b:SetAncho(nil)
				b:ClearAllPoints()
				b:SetPoint("TOPLEFT", self, "TOPLEFT", x, -y)
				x = x + w + K.ESP.s
				alto = max(alto, K.num(b:GetHeight(), 32))
			end
		end
		local h = alto > 0 and (y + alto) or 1
		self:SetHeight(h)
		return h
	end
	return f
end

local function resumen(lista)
	local guias, plan = 0, nil
	for _, it in ipairs(lista) do
		if it.tipo == "guia" then guias = guias + 1 else plan = it end
	end
	local maxi = EC.Maximo()
	local tx = format(L["Sigues %d de %d guías a la vez."], guias, maxi)
	if plan then tx = tx .. " " .. format(L["Y tu plan «%s»."], plan.nombre) end
	if guias >= maxi then
		tx = tx .. " " .. L["Si abres otra, Alfa quita sola la que tocaste hace más tiempo (nunca la que sigues ni las fijadas)."]
	elseif guias > 1 then
		tx = tx .. " " .. L["Quita las que ya no uses: la manada va más ligera."]
	end
	return tx
end

local function tarjeta(it)
	local plan = it.tipo == "plan"
	local ins = {}
	if it.activa then ins[#ins + 1] = { L["La sigues ahora"], "exito" } end
	if it.fijada then ins[#ins + 1] = { L["Fijada"], "acento" } end
	if plan then ins[#ins + 1] = { L["Tu plan"], "acento" } end
	local d = {
		icono = plan and "ic-lista" or "ic-guia",
		tono = it.activa and "acento" or "neutro",
		elegida = it.activa or nil,
		titulo = it.nombre,
		texto = EC.Linea(it, true),
		insignias = #ins > 0 and ins or nil,
		progreso = (it.total and it.total > 0) and { actual = it.hechos or 0, total = it.total, huellas = it.total <= 12 } or nil,
		secundaria = { texto = L["Quitar"], alClic = function() EC.Quitar(it) end },
		alfaIt = it,
	}
	-- Cuándo la tocaste, en su propio renglón (se lee mejor que todo junto).
	local tocada = EC.Linea({ tocada = it.tocada })
	d.texto = (d.texto ~= "" and (d.texto .. "\n") or "") .. tocada
	if plan then
		d.accion = { texto = L["Ver el plan"], alClic = function() EC.Seguir(it) end }
	elseif not it.activa then
		d.accion = { texto = L["Seguir"], icono = "ic-seguir", alClic = function() EC.Seguir(it) end }
	end
	return d
end

-- El botón «Fijar» de cada tarjeta de guía, al lado de «Quitar».
local function conFijar(c)
	if c.alfaConFijar then return end
	c.alfaConFijar = true
	c.Fijar = K.Boton(c, L["Fijar"], function(self)
		local d = self:GetParent().alfaDatos
		local it = d and d.alfaIt
		if it and it.id then EC.Fijar(it.id) end
	end, { tipo = "fantasma", tam = "chico",
		ayuda = L["Una guía fijada nunca se quita sola para hacer lugar a otra."] })
	local base = c.Acomodar
	function c:Acomodar(ancho, altoMin)
		local h = base(self, ancho, altoMin)
		local d = self.alfaDatos
		local it = d and d.alfaIt
		local es = it and it.tipo == "guia" and self.Secundaria and self.Secundaria:IsShown()
		K.Mostrar(self.Fijar, es and true or false)
		if es then
			self.Fijar:SetTexto(it.fijada and L["Soltar"] or L["Fijar"])
			self.Fijar:ClearAllPoints()
			self.Fijar:SetPoint("LEFT", self.Secundaria, "RIGHT", K.ESP.s, 0)
		end
		return h
	end
end

local function misiones()
	local Cp = M.Motor("Compat")
	local lista = Cp and Cp.GetLogQuests and Cp.GetLogQuests() or {}
	local out = {}
	for _, q in ipairs(lista) do
		out[#out + 1] = { valor = q, texto = M.TituloMision(q), icono = "ic-misiones" }
	end
	return out
end

local function llenar()
	local lista = EC.Lista()
	K.Escribir(ui.intro.Texto, format(L["Puedes seguir hasta %d guías a la vez. La que sigues ahora es la que marca la flecha."], EC.Maximo()))
	K.Escribir(ui.resumen.Texto, #lista > 0 and resumen(lista) or L["No sigues nada ahora. Elige una guía en la Biblioteca o pregúntale al asistente qué hacer."])
	local datos = {}
	for i, it in ipairs(lista) do datos[i] = tarjeta(it) end
	ui.rejilla:Llenar(datos)
	for _, c in ipairs(ui.rejilla.pool) do conFijar(c) end
	K.Mostrar(ui.rejilla, #lista > 0)
	local otras = 0
	for _, it in ipairs(lista) do if it.tipo == "guia" and not it.activa and not it.fijada then otras = otras + 1 end end
	K.Mostrar(ui.otras, otras > 0)
	K.Mostrar(ui.deshacer, EC.PuedeDeshacer())
	K.Mostrar(ui.botones, otras > 0 or EC.PuedeDeshacer())
	-- Tus misiones.
	local qs = misiones()
	ui.secMisiones:Set(L["Tus misiones"], { cuenta = #qs })
	K.Escribir(ui.misionesTexto.Texto, #qs > 0 and L["¿Una que ya no quieres? Abandónala aquí: te pregunto antes, y se puede volver a pedir."]
		or L["No tienes misiones en tu registro."])
	K.Mostrar(ui.abandonar, #qs > 0)
end

local function construir(view)
	t = K.Tablero(view, { margen = N.MargenPagina() })
	t:SetAccion(nil)
	ui.intro = t:AgregarBloque(parrafo(t.Extra, "texto", "texto"))
	ui.resumen = t:AgregarBloque(parrafo(t.Extra), { espacio = K.ESP.s })
	ui.rejilla = t:AgregarBloque(K.Rejilla(t.Extra, { min = 380, gap = K.ESP.base, variante = "normal" }))
	ui.otras = K.Boton(view, L["Quitar todas menos la actual"], function() EC.QuitarOtras() end, { tipo = "peligro" })
	ui.deshacer = K.Boton(view, L["Deshacer"], function() EC.Deshacer() end, { tipo = "secundario" })
	ui.botones = t:AgregarBloque(filaBotones(t.Extra, { ui.otras, ui.deshacer }))
	ui.secMisiones = t:AgregarBloque(K.Seccion(t.Extra, L["Tus misiones"]), { espacio = K.ESP.xl })
	ui.misionesTexto = t:AgregarBloque(parrafo(t.Extra), { espacio = K.ESP.s })
	ui.abandonar = K.Boton(view, L["Abandonar una misión…"], nil, { tipo = "secundario", icono = "ic-cerrar" })
	ui.abandonar.alClic = function(b)
		local op = misiones()
		if #op == 0 then return end
		K.Menu(b or ui.abandonar, op, nil, function(q) EC.AbandonarMision(q) end, 280)
	end
	t:AgregarBloque(filaBotones(t.Extra, { ui.abandonar }), { espacio = K.ESP.s })
	K.EnPagina(view, t, llenar)
	vista = view
end

EC.alCambiar = function()
	if vista then N.RehacerPagina(vista) end
	-- El número de la sección (10/12) sigue a las pestañas.
	local O = A.UI and A.UI.Options
	if O and O.frame and O.frame.IsShown and O.frame:IsShown() and O.RefreshNav then pcall(O.RefreshNav) end
end
if A.RegisterEvent then
	A.RegisterEvent("QUEST_LOG_UPDATE", function() if vista and vista:IsVisible() then N.RehacerPagina(vista) end end)
end

-- Lya lo sabe contar (Pregúntale a Lya).
A.RegisterEvent("PLAYER_LOGIN", function()
	local Lya = rawget(_G, "AlfaLya")
	if not (type(Lya) == "table" and type(Lya.Ensenar) == "function") then return end
	for _, p in ipairs({
		{ id = "planes.tope", icono = "ic-lista", pregunta = L["¿Cuántas guías puedo seguir a la vez?"],
			respuesta = L["Hasta 12. Las ves todas en Planes (junto a Hoy): la que sigues ahora es la que marca la flecha. Si abres otra con las 12 ocupadas, quito sola la que tocaste hace más tiempo, y te dejo deshacerlo."] },
		{ id = "planes.fijar", icono = "ic-lista", pregunta = L["¿Cómo hago que una guía no se quite sola?"],
			respuesta = L["En Planes, «Fijar» en su tarjeta. Las fijadas nunca se quitan solas para hacer lugar."] },
		{ id = "planes.abandonar", icono = "ic-misiones", pregunta = L["¿Cómo abandono una misión?"],
			respuesta = L["En Planes, abajo, «Abandonar una misión…»; o clic derecho en la meta del rastreador. Te pregunto antes de soltarla."] },
	}) do
		p.modulo = ID
		pcall(Lya.Ensenar, p)
	end
end)

N.Modulo({
	id = ID, nombre = L["Planes"], icono = "ic-lista", orden = 11, seccion = "planes",
	subtitulo = L["Las guías y planes que sigues, a un clic."],
	construir = construir,
})
