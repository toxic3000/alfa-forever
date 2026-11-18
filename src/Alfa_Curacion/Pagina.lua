-- Alfa - Curación: su página en la ventana de Alfa (toxic3000 / La Jauría). GPL-3.0.
--
-- Hecha con el Kit (docs/KIT.md, K.Tablero con la tarjeta de estado):
--   1. El estado y qué hacer ahora: apagados (Encenderlos), en prueba
--      (Listo), sin preparar si curas (el asistente de 3 pasos, Asistente.lua)
--      o listo para curar, con lo que hacen tus dos clics principales.
--   2. Los preajustes de tu clase, en tarjetas: el que usas, marcado.
--   3. Tu ratón: la cuadrícula de 12 clics (izquierdo, central y derecho, sin
--      tecla y con Mayús, Ctrl y Alt). Clic en una casilla para elegir qué
--      hace; clic derecho la deja sin acción.
--   4. Los ajustes, en grupos de filas: tus clics, los marcos, qué muestran.
-- Los marcos (Marcos.lua) y el mapa (Mapa.lua) no cambian: esta página solo
-- los muestra y los ajusta.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local floor, max, min, format = math.floor, math.max, math.min, string.format
local ipairs, pairs, type, tostring = ipairs, pairs, type, tostring
local ESP = K.ESP

local DOT = "  \194\183  "

---------------------------------------------------------------------------
-- Textos de estado
---------------------------------------------------------------------------

local function queHace(e)
	if type(e) ~= "table" or e.t == "nada" then return L["no hace nada"] end
	if e.t == "spell" then return M.NombreHechizo(e.id) or L["un hechizo"] end
	if e.t == "target" then return L["selecciona"] end
	if e.t == "menu" then return L["abre su menú"] end
	return L["no hace nada"]
end
M.QueHace = queHace

-- Lo que hace, para una frase: "lanza Sanar", "selecciona", "abre su menú".
local function frase(e)
	if type(e) == "table" and e.t == "spell" then return format(L["lanza %s"], M.NombreHechizo(e.id) or L["un hechizo"]) end
	return queHace(e)
end
M.Frase = frase

-- Lo que hace, como título: "Sanar", "Seleccionar objetivo", "Menú del jugador".
function M.NombreAccion(e)
	local t = type(e) == "table" and e.t or "nada"
	if t == "spell" then return M.NombreHechizo(e.id) or L["Hechizo desconocido"] end
	if t == "target" then return L["Seleccionar objetivo"] end
	if t == "menu" then return L["Menú del jugador"] end
	return L["Sin acción"]
end

local function grupo()
	local n = 0
	if GetNumGroupMembers then
		local ok, v = pcall(GetNumGroupMembers)
		n = ok and tonumber(v) or 0
	end
	if IsInRaid and IsInRaid() then return format(L["Banda de %d"], n), "acento" end
	if IsInGroup and IsInGroup() then return format(L["Grupo de %d"], n), "acento" end
	return L["Sin grupo"], "neutro"
end

-- ¿Cambiaste algo a mano después del preajuste?
local function aMano()
	for _, e in pairs(M.Mapa()) do
		if type(e) == "table" and not e.p then return true end
	end
	return false
end
M.AMano = aMano

-- El asistente de 3 pasos (Asistente.lua): ¿le falta a este personaje?
function M.AsistentePendiente()
	local d = M.Datos()
	return M.EsCurandero() and d.asistente ~= true and d.asistenteOmitido ~= true
end

function M.OmitirAsistente()
	M.Datos().asistenteOmitido = true
	A.Fire("ALFA_CURACION_ASISTENTE")
	M.Avisar()
end

local function abrirAsistente() if M.AbrirAsistente then M.AbrirAsistente() end end

local function estado()
	local clase, nombreClase = M.Clase()
	local d = { icono = "ic-curacion" }
	if not N.Get(ID, "activo") then
		d.tono, d.titulo = "neutro", L["Tus marcos de curación están apagados"]
		d.texto = L["Enciéndelos para ver a tu grupo con su vida y curar con un clic."]
		d.estado = { texto = L["Apagados"], tono = "neutro" }
		d.accion = { texto = L["Encenderlos"], icono = "ic-seguir", alClic = function() N.Set(ID, "activo", true) end }
		return d
	end
	if M.EnPrueba() then
		d.tono, d.titulo = "aviso", L["Modo prueba"]
		d.texto = L["Así se verán tus marcos. Arrástralos para moverlos y cambia su tamaño abajo, en Marcos. Pulsa Listo cuando termines."]
		d.estado = { texto = L["Prueba"], tono = "aviso" }
		d.accion = { texto = L["Listo"], icono = "ic-exito", alClic = function() M.Prueba(nil) M.Mover(false) end }
		return d
	end
	if M.AsistentePendiente() then
		d.tono, d.sobre, d.titulo = "acento", L["Recomendado"], L["Prepara tus marcos en 3 pasos"]
		d.texto = L["Elige tus clics, acomoda tus marcos y pruébalos. Te toma un minuto."]
		d.accion = { texto = L["Empezar"], icono = "ic-seguir", alClic = abrirAsistente }
		d.secundaria = { texto = L["Ahora no"], alClic = M.OmitirAsistente }
		return d
	end
	local mapa = M.Mapa()
	d.tono = "exito"
	d.titulo = M.EsCurandero(clase) and L["Listo para curar"] or L["Listo para ayudar a tu grupo"]
	d.texto = format(L["Pasa el ratón sobre un compañero y haz clic: el izquierdo %s y el derecho %s."], frase(mapa["1"]), frase(mapa["2"]))
	if M.EnCombate() then d.texto = d.texto .. " " .. L["Estás en combate: lo que cambies se aplica al salir."] end
	local insignias = {}
	if nombreClase then insignias[#insignias + 1] = { nombreClase, "clase" } end
	local pre = M.Datos().preajuste
	if M.PREAJUSTES[pre or ""] then
		local nombre = M.NombrePreajuste(pre)
		insignias[#insignias + 1] = { aMano() and format(L["%s, a tu gusto"], nombre) or nombre, "acento" }
	end
	local g, tono = grupo()
	insignias[#insignias + 1] = { g, tono }
	d.insignias = insignias
	d.accion = { texto = L["Configurar con el asistente"], icono = "ic-seguir", alClic = abrirAsistente }
	d.secundaria = { texto = M.Moviendo() and L["Fijar marcos"] or L["Mover marcos"], alClic = function() M.Mover(not M.Moviendo()) end }
	return d
end

---------------------------------------------------------------------------
-- Preajustes
---------------------------------------------------------------------------

local ICONO_PRE = { curar = "ic-curacion", buffs = "ic-huella", cero = "ic-mas" }
M.ICONO_PRE = ICONO_PRE

function M.DescripcionPreajuste(pre)
	local mapa = M.Resolver(pre, M.IzquierdoSelecciona())
	local resumen = M.ResumenDe(mapa, 4)
	if pre == "cero" then return L["El izquierdo selecciona y el derecho abre el menú. Tú eliges el resto."] end
	if pre == "buffs" then
		if resumen == "" then
			if not M.TieneBuffs() then return L["El izquierdo selecciona y el derecho abre el menú: lo básico, porque tu clase no lanza hechizos sobre sus compañeros."] end
			return L["El izquierdo selecciona y el derecho abre el menú. Tus buffs para otros se suman aquí al aprenderlos."]
		end
		return L["El izquierdo selecciona y el derecho abre el menú."] .. DOT .. resumen
	end
	if resumen == "" then return L["Todavía no conoces sus hechizos: se llenan al aprenderlos."] end
	return resumen
end

function M.TituloPreajuste(pre)
	local titulo = M.NombrePreajuste(pre)
	if pre == "curar" then
		local _, nombreClase = M.Clase()
		if nombreClase then titulo = format(L["%s (%s)"], titulo, nombreClase) end
	end
	return titulo
end

-- Usa un preajuste; si cambiaste clics a mano, pregunta antes.
function M.UsarPreajuste(pre, luego)
	local P = M.PREAJUSTES[pre]
	if not P then return end
	local function usar()
		M.AplicarPreajuste(pre)
		if luego then luego() end
	end
	if aMano() and M.Datos().preajuste ~= pre then
		K.Dialogo({
			titulo = format(L["¿Usar «%s»?"], M.NombrePreajuste(pre)), icono = "ic-curacion",
			texto = L["Tus clics vuelven a los del preajuste. Lo que cambiaste a mano se pierde."],
			aceptar = L["Usarlo"], alAceptar = usar,
		})
	else
		usar()
	end
end

local function preajustes()
	local lista = {}
	local actual = M.Datos().preajuste
	for _, pre in ipairs(M.PreajustesDe()) do
		local enUso = actual == pre
		local p = pre
		lista[#lista + 1] = {
			icono = ICONO_PRE[pre] or "ic-curacion", tono = enUso and "exito" or nil,
			titulo = M.TituloPreajuste(pre), texto = M.DescripcionPreajuste(pre),
			insignias = enUso and { { aMano() and L["En uso, a tu gusto"] or L["En uso"], "exito", "ic-exito" } } or nil,
			alClic = not enUso and function() M.UsarPreajuste(p) end or nil,
			secundaria = not enUso and { texto = L["Usar"], alClic = function() M.UsarPreajuste(p) end } or nil,
		}
	end
	return lista
end

---------------------------------------------------------------------------
-- Tu ratón: la cuadrícula
---------------------------------------------------------------------------

local CELDA_H, ETIQ = 48, 88

-- El ícono y las palabras de una ranura.
function M.PintarRanura(icono, nombre, tipo, e)
	local t = type(e) == "table" and e.t or "nada"
	icono:SetTexCoord(0, 1, 0, 1)
	if t == "spell" then
		local tex = M.IconoHechizo(e.id)
		if tex then
			icono:SetTexture(tex)
			icono.alfaColor = nil
			icono:SetVertexColor(1, 1, 1, 1)
			icono:SetTexCoord(0.08, 0.92, 0.08, 0.92)
		else
			K.SetIcono(icono, "ic-curacion", "acento")
		end
		K.Escribir(nombre, M.NombreHechizo(e.id) or L["Hechizo desconocido"])
		K.ColorTexto(nombre, "texto")
		if tipo then K.Escribir(tipo, e.p and L["Del preajuste"] or L["Elegido por ti"]) end
	elseif t == "target" then
		K.SetIcono(icono, "ic-raros", "acento")
		K.Escribir(nombre, L["Seleccionar objetivo"])
		K.ColorTexto(nombre, "texto")
		if tipo then K.Escribir(tipo, L["Lo marca como tu objetivo"]) end
	elseif t == "menu" then
		K.SetIcono(icono, "ic-lista", "acento")
		K.Escribir(nombre, L["Menú del jugador"])
		K.ColorTexto(nombre, "texto")
		if tipo then K.Escribir(tipo, L["Invitar, comerciar, susurrar…"]) end
	else
		K.SetIcono(icono, "ic-mas", "textoTenue")
		K.Escribir(nombre, L["Sin acción"])
		K.ColorTexto(nombre, "textoTenue")
		if tipo then K.Escribir(tipo, L["Clic para elegir"]) end
	end
end

local function opcionesDe(r)
	local lista = {
		{ valor = "nada", texto = L["Sin acción"], icono = "ic-cerrar" },
		{ valor = "target", texto = L["Seleccionar objetivo"], icono = "ic-raros" },
	}
	if M.PermiteMenu(r) then lista[#lista + 1] = { valor = "menu", texto = L["Menú del jugador"], icono = "ic-lista" } end
	for _, h in ipairs(M.HechizosDelLibro()) do
		lista[#lista + 1] = { valor = "spell:" .. h.id, texto = h.nombre, icono = "ic-curacion" }
	end
	return lista
end

local function valorDe(e)
	if type(e) ~= "table" then return "nada" end
	if e.t == "spell" then return "spell:" .. tostring(e.id) end
	return e.t or "nada"
end

local function elegir(r, v)
	if type(v) ~= "string" then return end
	local id = tonumber(v:match("^spell:(%d+)$"))
	if id then M.FijarRanura(r, { t = "spell", id = id }) else M.FijarRanura(r, { t = v }) end
end

local function pintarCelda(c)
	local sobre = c.alfaSobre
	c.caja:Estilo({ borde = sobre and "lineaFuerte" or "linea" })
	c.velo:SetShown(sobre and true or false)
end

local function nuevaCelda(padre, r)
	local c = CreateFrame("Button", nil, padre)
	c.ranura = r
	c:SetHeight(CELDA_H)
	c:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	c.caja = K.Caja(c, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	c.velo = K.Velo(c, K.CORTE.control, 0.05)
	c.Icono = K.Icono(c, "ic-mas", 26)
	c.Icono:SetPoint("LEFT", c, "LEFT", 10, 0)
	c.Nombre = K.Texto(c, "cuerpo", "texto")
	c.Nombre:SetPoint("TOPLEFT", c.Icono, "TOPRIGHT", 8, 1)
	c.Nombre:SetPoint("RIGHT", c, "RIGHT", -8, 0)
	c.Tipo = K.Texto(c, "pequeno", "textoTenue")
	c.Tipo:SetPoint("BOTTOMLEFT", c.Icono, "BOTTOMRIGHT", 8, -1)
	c.Tipo:SetPoint("RIGHT", c, "RIGHT", -8, 0)
	c:SetScript("OnClick", function(self, boton)
		K.OcultarInfo(self)
		if boton == "RightButton" then
			K.CerrarMenu()
			M.FijarRanura(self.ranura, { t = "nada" })
			return
		end
		local ranura = self.ranura
		K.Menu(self, opcionesDe(ranura), valorDe(M.Mapa()[ranura]), function(v) elegir(ranura, v) end, max(220, K.num(self:GetWidth(), 0)))
	end)
	c:SetScript("OnEnter", function(self) self.alfaSobre = true pintarCelda(self) end)
	c:SetScript("OnLeave", function(self) self.alfaSobre = nil pintarCelda(self) end)
	K.ConInfo(c, function(self)
		return M.NombreRanura(self.ranura), format(L["Ahora: %s."], M.NombreAccion(M.Mapa()[self.ranura])) .. "\n" .. L["Clic: elegir qué hace. Clic derecho: dejarla sin acción."]
	end)
	K.Pintar(c, pintarCelda)
	return c
end

local function nuevoRaton(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Tu ratón"])
	b.Panel = CreateFrame("Frame", nil, b)
	b.Panel.caja = K.Caja(b.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.cols, b.filas, b.celdas = {}, {}, {}
	for i, bt in ipairs(M.BOTONES) do
		b.cols[i] = K.Texto(b.Panel, "etiqueta", "textoSuave")
		K.Escribir(b.cols[i], bt.nombre)
	end
	for i, md in ipairs(M.MODS) do
		b.filas[i] = K.Texto(b.Panel, "etiqueta", i == 1 and "textoSuave" or "texto")
		K.Escribir(b.filas[i], i == 1 and md.nombre or (md.nombre .. " +"))
		for _, bt in ipairs(M.BOTONES) do
			local r = md.p .. bt.s
			b.celdas[r] = nuevaCelda(b.Panel, r)
		end
	end
	b.Nota = K.Texto(b.Panel, "nota", "textoTenue")
	b.Aviso = K.Texto(b.Panel, "nota", "aviso")
	function b:Llenar()
		local mapa = M.Mapa()
		for r, c in pairs(self.celdas) do M.PintarRanura(c.Icono, c.Nombre, c.Tipo, mapa[r]) end
		K.Escribir(self.Nota, L["Clic en una casilla para elegir qué hace sobre el compañero bajo tu ratón; clic derecho la deja sin acción. Los cambios se aplican fuera de combate."])
		local choques = M.ChoquesBlizzard()
		self.alfaChoques = choques
		K.Escribir(self.Aviso, choques > 0 and format(L["Ojo: tu clic para lanzar de Blizzard usa %d de estas teclas, y ese manda también aquí. Para igualarlos, usa «Usar también en los marcos de Blizzard»."], choques) or "")
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local top = self.Seccion:Acomodar(ancho) + ESP.s
		local pad = ESP.base
		local dentro = ancho - 2 * pad
		local colW = floor((dentro - ETIQ - 2 * ESP.s) / 3)
		local y = pad
		for i, t in ipairs(self.cols) do
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad + ETIQ + (i - 1) * (colW + ESP.s), -y)
		end
		y = y + 18 + ESP.s
		for i, md in ipairs(M.MODS) do
			local t = self.filas[i]
			t:ClearAllPoints()
			t:SetPoint("LEFT", self.Panel, "TOPLEFT", pad, -(y + CELDA_H / 2))
			t:SetWidth(ETIQ - 8)
			for j, bt in ipairs(M.BOTONES) do
				local c = self.celdas[md.p .. bt.s]
				c:ClearAllPoints()
				c:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad + ETIQ + (j - 1) * (colW + ESP.s), -y)
				c:SetWidth(colW)
			end
			y = y + CELDA_H + ESP.s
		end
		y = y + ESP.xs
		self.Nota:ClearAllPoints()
		self.Nota:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad, -y)
		y = y + K.Parrafo(self.Nota, dentro, 3)
		self.Aviso:SetShown((self.alfaChoques or 0) > 0)
		if self.Aviso:IsShown() then
			y = y + ESP.s
			self.Aviso:ClearAllPoints()
			self.Aviso:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad, -y)
			y = y + K.Parrafo(self.Aviso, dentro, 3)
		end
		y = y + pad
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
		self.Panel:SetSize(ancho, y)
		local alto = top + y
		self:SetSize(ancho, alto)
		return alto
	end
	return b
end

---------------------------------------------------------------------------
-- Ajustes
---------------------------------------------------------------------------

local function activo() return N.Get(ID, "activo") and true or false end
local function interruptor(clave) return function(fila) return K.Interruptor(fila, { clave = ID .. "." .. clave }) end end
local function deslizador(clave, a, b, paso, formato)
	return function(fila)
		local d = K.Deslizador(fila, { min = a, max = b, paso = paso, clave = ID .. "." .. clave, formato = formato })
		d.alfaAnchoFila = 220
		return d
	end
end
local function px(v) return format(L["%d px"], floor((tonumber(v) or 0) + 0.5)) end
local function entero(v) return tostring(floor((tonumber(v) or 0) + 0.5)) end
M.Px, M.Entero = px, entero

local BASE_BLIZZARD = L["Abre la ventana de clic para lanzar de Blizzard para que armes ahí los mismos clics y cures igual en sus marcos de grupo (el juego no deja que un addon los copie)."]

-- "El clic izquierdo solo selecciona" no es un ajuste (va por personaje, en
-- M.Datos): su fila se crea al mostrar la página por primera vez y queda
-- primera en su grupo.
local function filaIzquierdo(ui)
	if ui.filaIzq then return end
	local clics = ui.clics
	ui.filaIzq = clics:Fila({ titulo = L["El clic izquierdo solo selecciona"],
		texto = L["Para quien prefiere seleccionar con el izquierdo: la cura de ese clic pasa al botón central. Se vuelve a aplicar tu preajuste."],
		activa = function() return M.Datos().preajuste == "curar" end,
		control = function(fila)
			local s = K.Interruptor(fila, { valor = M.IzquierdoSelecciona(), alCambiar = function(v) M.FijarIzquierdoSelecciona(v == true) end })
			function s:Leer() self:SetValor(M.IzquierdoSelecciona()) end
			return s
		end })
	table.remove(clics.filas)
	table.insert(clics.filas, 1, ui.filaIzq)
end

local function grupos(ui, padre)
	local clics = K.GrupoAjustes(padre, { titulo = L["Tus clics"] })
	ui.clics = clics
	ui.filaBlizzard = clics:Fila({ titulo = L["Usar también en los marcos de Blizzard"], texto = BASE_BLIZZARD,
		control = function(fila)
			local b = K.Boton(fila, L["Abrir clic para lanzar"], function() M.UsarEnBlizzard() end, { tipo = "secundario", tam = "chico" })
			-- El juego abre su ventana (K.Seguro): Alfa no la abre desde su código.
			K.Seguro(b, M.SeguroBlizzard)
			b.alfaTrasClic = function() M.TrasAbrirBlizzard() end
			return b
		end })

	local marcos = K.GrupoAjustes(padre, { titulo = L["Marcos"] })
	marcos:Fila({ titulo = L["Usar los marcos de Alfa"], control = interruptor("activo"),
		texto = L["Tu grupo y tu banda con su vida, para curar con un clic. Se cambia fuera de combate."] })
	marcos:Fila({ titulo = L["Verte a ti estando solo"], control = interruptor("solo"), hija = true, activa = activo,
		texto = L["Tu propio marco aparece aunque no estés en grupo, para curarte con un clic."] })
	marcos:Fila({ titulo = L["Ocultar los marcos de grupo de Blizzard"], control = interruptor("ocultarBlizzard"), hija = true, activa = activo,
		texto = L["Para no ver dos veces a tu grupo. Se cambia fuera de combate."] })
	marcos:Fila({ titulo = L["Ancho"], control = deslizador("ancho", 50, 200, 2, px), hija = true, activa = activo })
	marcos:Fila({ titulo = L["Alto"], control = deslizador("alto", 20, 80, 1, px), hija = true, activa = activo })
	marcos:Fila({ titulo = L["Compañeros por columna"], control = deslizador("porColumna", 1, 40, 1, entero), hija = true, activa = activo,
		texto = L["Cuántos van en cada columna (o fila) antes de empezar otra. 5 es un grupo por columna."] })
	marcos:Fila({ titulo = L["Crecen hacia"], hija = true, activa = activo, control = function(fila)
		return K.Desplegable(fila, { clave = ID .. ".crecer", ancho = 160, opciones = {
			{ valor = "abajo", texto = L["Abajo"] }, { valor = "derecha", texto = L["La derecha"] } } })
	end })
	marcos:Fila({ titulo = L["Orden"], hija = true, activa = activo, control = function(fila)
		return K.Desplegable(fila, { clave = ID .. ".orden", ancho = 160, opciones = {
			{ valor = "grupo", texto = L["Por grupo"] }, { valor = "rol", texto = L["Por rol"] },
			{ valor = "clase", texto = L["Por clase"] }, { valor = "nombre", texto = L["Por nombre"] } } })
	end })
	marcos:Fila({ titulo = L["Volver a su lugar"], texto = L["Pone los marcos donde estaban al instalar Alfa."], activa = activo,
		control = function(fila) return K.Boton(fila, L["Reiniciar"], function() M.ReiniciarPosicion() end, { tipo = "secundario", tam = "chico" }) end })

	local muestran = K.GrupoAjustes(padre, { titulo = L["Qué muestran"] })
	local function fila(titulo, clave, texto)
		muestran:Fila({ titulo = titulo, texto = texto, control = interruptor(clave), activa = activo })
	end
	fila(L["Color de clase"], "colorClase", L["La barra de vida con el color de la clase de cada uno. Apagado: barra verde y el nombre con su color."])
	fila(L["Curas que van llegando"], "entrantes", L["Una franja verde clara muestra las curas que ya vienen en camino."])
	fila(L["Amenaza"], "amenaza", L["Una línea roja arriba avisa cuando un enemigo va por ese compañero."])
	fila(L["Perjuicios que puedes quitar"], "disipar", L["El borde toma el color del perjuicio (magia, maldición, enfermedad o veneno) cuando tú lo puedes quitar."])
	fila(L["Porcentaje de vida"], "porcentaje", L["Muestra la vida en número, debajo del nombre."])
	fila(L["Atenuar a quien está lejos"], "alcance", L["Si está fuera de tu alcance, su marco se ve más tenue."])
	fila(L["Detalle al pasar el ratón"], "descripcion", L["El cuadro del jugador al pasar el ratón. En combate no sale, para no estorbar."])
	return { clics, marcos, muestran }
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Preajustes"], min = 240 })
	ui.raton = t:AgregarBloque(nuevoRaton(t.Extra))
	ui.grupos = grupos(ui, t.Extra)
	for _, g in ipairs(ui.grupos) do t:AgregarBloque(g) end
	K.EnPagina(view, t, function()
		filaIzquierdo(ui)
		t:SetAccion(estado())
		t:SetOpciones(preajustes(), L["Preajustes"])
		ui.raton:Llenar()
		local r = M.Datos().blizzard
		ui.filaBlizzard.alfaDatos.texto = BASE_BLIZZARD .. ((type(r) == "table" and type(r.texto) == "string") and ("\n" .. r.texto) or "")
		for _, g in ipairs(ui.grupos) do g:Refrescar() end
	end)
	M.vista = view
end

-- Algo cambió (tu grupo, tu mapa, la prueba, un ajuste...): la página y el
-- asistente se rehacen si están a la vista.
M.alCambiar = function()
	if M.vista then N.RehacerPagina(M.vista) end
	if M.RefrescarAsistente then M.RefrescarAsistente() end
end

A.On("SETTING_CHANGED", function(path)
	if type(path) == "string" and path:sub(1, #ID + 1) == ID .. "." then M.Avisar() end
end)

N.Modulo({
	id = ID, nombre = L["Curación"], icono = "ic-curacion", orden = 16,
	subtitulo = L["Marcos de grupo y banda para curar con un clic, con preajustes por clase."],
	comando = "curacion",
	ajustes = M.AJUSTES,
	construir = construir,
})

-- Para la página Hoy (Alfa_Inicio): el asistente, a la vista de quien cura.
AlfaCuracion = {
	Asistente = abrirAsistente,
	AsistentePendiente = function() return M.AsistentePendiente() end,
	Omitir = function() M.OmitirAsistente() end,
}

---------------------------------------------------------------------------
-- /alfa curacion [prueba | prueba20 | mover | blizzard | on | off | reiniciar | asistente]
---------------------------------------------------------------------------

local ACCIONES = {
	prueba = function() M.Prueba(5) end, prueba5 = function() M.Prueba(5) end,
	prueba20 = function() M.Prueba(20) end,
	listo = function() M.Prueba(nil) M.Mover(false) end,
	mover = function() M.Mover(not M.Moviendo()) end,
	blizzard = function()
		local _, texto = M.UsarEnBlizzard()
		if texto then N.Imprimir(texto) end
	end,
	on = function() N.Set(ID, "activo", true) N.Imprimir(L["Marcos de Curación encendidos."]) end,
	off = function() N.Set(ID, "activo", false) N.Imprimir(L["Marcos de Curación apagados."]) end,
	reiniciar = function() M.ReiniciarPosicion() end,
	asistente = abrirAsistente,
}

function M.Comando(resto)
	resto = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local fn = ACCIONES[resto]
	if fn then fn() else N.Abrir(ID) end
end

A.RegisterCommand("curacion", M.Comando, L["abre Curación (también: asistente, prueba, prueba20, mover, listo, blizzard, on, off, reiniciar)"])
