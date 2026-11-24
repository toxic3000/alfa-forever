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
-- 1.3.0: «Tus clics» va primero: «Curar y seleccionar» y una fila por cada
-- clic principal (izquierdo, derecho, central, Mayús y Ctrl) con la lista de
-- tus hechizos por tipo (curas, quitar perjuicios, buffs, revivir, otros), la
-- venda, seleccionar y el menú. Arriba avisa si tu clase quita algo que
-- ningún clic quita.

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
	-- 1.3.7: con «Curar y seleccionar», una ranura sin acción al menos selecciona (Mapa.lua).
	if type(e) ~= "table" or e.t == "nada" then return M.CurarSelecciona() and L["selecciona"] or L["no hace nada"] end
	if e.t == "spell" then return M.NombreHechizo(e.id) or L["un hechizo"] end
	if e.t == "target" then return L["selecciona"] end
	if e.t == "menu" then return L["abre su menú"] end
	if e.t == "venda" then return L["le pone una venda"] end
	return L["no hace nada"]
end
M.QueHace = queHace

-- Lo que hace, para una frase: "lanza Sanar", "selecciona", "abre su menú".
local function frase(e)
	if type(e) == "table" and e.t == "spell" then
		local n = M.NombreHechizo(e.id) or L["un hechizo"]
		if M.CurarSelecciona() then return format(L["lanza %s y lo selecciona"], n) end
		return format(L["lanza %s"], n)
	end
	if type(e) == "table" and e.t == "venda" and M.CurarSelecciona() then return L["le pone una venda y lo selecciona"] end
	return queHace(e)
end
M.Frase = frase

-- Lo que hace, como título: "Sanar", "Seleccionar objetivo", "Menú del jugador".
function M.NombreAccion(e)
	local t = type(e) == "table" and e.t or "nada"
	if t == "spell" then return M.NombreHechizo(e.id) or L["Hechizo desconocido"] end
	if t == "target" then return L["Seleccionar objetivo"] end
	if t == "menu" then return L["Menú del jugador"] end
	if t == "venda" then return L["Usar una venda"] end
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

-- Tu clase, tu preajuste y tu grupo, en insignias.
local function insignias(nombreClase)
	local t = {}
	if nombreClase then t[#t + 1] = { nombreClase, "clase" } end
	local pre = M.Datos().preajuste
	if M.PREAJUSTES[pre or ""] then
		local nombre = M.NombrePreajuste(pre)
		t[#t + 1] = { aMano() and format(L["%s, a tu gusto"], nombre) or nombre, "acento" }
	end
	local g, tono = grupo()
	t[#t + 1] = { g, tono }
	return t
end

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
	-- 1.3.2: sin grupo (y sin «Verte a ti estando solo») no hay marcos que ver:
	-- se dice y se ofrecen los de ejemplo.
	local enGrupo = IsInGroup and IsInGroup() and true or false
	if not enGrupo and not N.Get(ID, "solo") then
		d.tono, d.titulo = "acento", L["Tus marcos aparecen al entrar a un grupo"]
		d.texto = L["Mientras vas solo no hay a quién mostrar. Míralos ahora con marcos de ejemplo, o prende «Verte a ti estando solo», abajo en Marcos."]
		d.insignias = insignias(nombreClase)
		d.accion = { texto = L["Ver cómo se ven"], icono = "ic-seguir", alClic = function() M.Prueba(5) end }
		d.secundaria = { texto = L["Configurar con el asistente"], alClic = abrirAsistente }
		return d
	end
	d.tono = "exito"
	d.titulo = M.EsCurandero(clase) and L["Listo para curar"] or L["Listo para ayudar a tu grupo"]
	d.texto = format(L["Pasa el ratón sobre un compañero y haz clic: el izquierdo %s y el derecho %s."], frase(mapa["1"]), frase(mapa["2"]))
	local sinClic = M.QuitarSinClic()
	if #sinClic > 0 then
		local nombres = {}
		for _, tipo in ipairs(sinClic) do nombres[#nombres + 1] = M.TIPOS[tipo].nombre:lower() end
		d.tono = "aviso"
		d.texto = d.texto .. " " .. format(L["Ojo: puedes quitar %s, pero ningún clic lo hace. Elígelo en Tus clics."], table.concat(nombres, ", "))
	end
	if M.EnCombate() then d.texto = d.texto .. " " .. L["Estás en combate: lo que cambies se aplica al salir."] end
	d.insignias = insignias(nombreClase)
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
	elseif t == "venda" then
		K.SetIcono(icono, "ic-curacion", "acento")
		K.Escribir(nombre, L["Usar una venda"])
		K.ColorTexto(nombre, "texto")
		if tipo then K.Escribir(tipo, M.venda and L["La mejor de tus bolsas"] or L["No llevas vendas"]) end
	else
		K.SetIcono(icono, "ic-mas", "textoTenue")
		K.Escribir(nombre, L["Sin acción"])
		K.ColorTexto(nombre, "textoTenue")
		if tipo then K.Escribir(tipo, L["Clic para elegir"]) end
	end
end

local function valorDe(e)
	if type(e) ~= "table" then return "nada" end
	if e.t == "spell" then return "spell:" .. tostring(e.id) end
	return e.t or "nada"
end

local ICONO_CAT = { cura = "ic-curacion", quitar = "ic-exito", buff = "ic-huella", revivir = "ic-seguir", otro = "ic-curacion" }

-- 1.3.1: las categorías de un repintado, calculadas una sola vez (las 7 filas
-- de «Tus clics» las comparten); fuera de un repintado se calculan al momento.
local catsRepintado
local function categorias() return catsRepintado or M.HechizosPorCategoria() end

-- 1.3.0: tus hechizos por tipo (curas, quitar perjuicios, buffs, revivir y
-- otros de tu libro), con un separador entre tipos. El de ahora siempre está.
local function opcionesDe(r)
	local lista = {
		{ valor = "nada", texto = L["Sin acción"], icono = "ic-cerrar" },
		{ valor = "target", texto = L["Seleccionar objetivo"], icono = "ic-raros" },
	}
	if M.PermiteMenu(r) then lista[#lista + 1] = { valor = "menu", texto = L["Menú del jugador"], icono = "ic-lista" } end
	lista[#lista + 1] = { valor = "venda", texto = L["Usar una venda"], icono = "ic-curacion" }
	local hay = {}
	for _, o in ipairs(lista) do hay[o.valor] = true end
	for _, cat in ipairs(categorias()) do
		lista[#lista + 1] = { separador = true }
		for _, h in ipairs(cat.lista) do
			local v = "spell:" .. h.id
			if not hay[v] then
				hay[v] = true
				lista[#lista + 1] = { valor = v, texto = format(L["%s (%s)"], h.nombre, cat.nombre:lower()), icono = ICONO_CAT[cat.categoria] or "ic-curacion" }
			end
		end
	end
	local actual = valorDe(M.Mapa()[r])
	if not hay[actual] then
		local e = M.Mapa()[r]
		lista[#lista + 1] = { valor = actual, texto = M.NombreAccion(e), icono = "ic-curacion" }
	end
	return lista
end
M.OpcionesDe = opcionesDe

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
	b.Copiar = K.Boton(b.Panel, L["Copiar mis atajos de Blizzard al mapa de Alfa"], function()
		if M.EnCombate() then
			N.Imprimir(L["Tus clics de Curación se aplican al salir de combate."])
			return
		end
		local n = M.CopiarBlizzard()
		if n > 0 then
			N.Imprimir(N.Plural(n, L["Listo: copié %d atajo de Blizzard a tu mapa de Alfa."], L["Listo: copié %d atajos de Blizzard a tu mapa de Alfa."]))
		end
		M.Avisar()
	end, { tipo = "secundario", tam = "chico" })
	b.Copiar:Hide()
	function b:Llenar()
		local mapa = M.Mapa()
		for r, c in pairs(self.celdas) do M.PintarRanura(c.Icono, c.Nombre, c.Tipo, mapa[r]) end
		K.Escribir(self.Nota, L["Clic en una casilla para elegir qué hace sobre el compañero bajo tu ratón; clic derecho la deja sin acción. Los cambios se aplican fuera de combate."])
		-- 1.3.7: los marcos de Alfa ya no obedecen al clic para lanzar de
		-- Blizzard (botones de acción, Mapa.lua): aquí manda solo tu mapa. Si
		-- tienes atajos de Blizzard en esos mismos clics, se avisa, y los que
		-- se pueden copiar (hechizos, seleccionar, menú) se copian con un botón.
		self.alfaChoques = M.ChoquesBlizzard()
		self.alfaCopiables = self.alfaChoques > 0 and (M.CopiarBlizzard(true)) or 0
		K.Escribir(self.Aviso, self.alfaChoques > 0 and L["En los marcos de Alfa manda tu mapa de clics; tus atajos de Blizzard no aplican aquí."] or "")
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
		self.Copiar:SetShown(self.Aviso:IsShown() and (self.alfaCopiables or 0) > 0)
		if self.Copiar:IsShown() then
			y = y + ESP.s
			self.Copiar:ClearAllPoints()
			self.Copiar:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad, -y)
			y = y + K.num(self.Copiar:GetHeight(), 24)
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

-- 1.3.0: los clics que más se usan, cada uno con su lista.
M.PRINCIPALES = { "1", "2", "3", "shift-1", "shift-2", "ctrl-1", "ctrl-2" }

local function filaClic(grupo, r)
	return grupo:Fila({ titulo = M.NombreRanura(r), control = function(fila)
		local d = K.Desplegable(fila, { ancho = 210, opciones = opcionesDe(r),
			get = function() return valorDe(M.Mapa()[r]) end,
			set = function(v) elegir(r, v) end })
		local leer = d.Leer
		function d:Leer()
			self.opciones = opcionesDe(r)
			leer(self)
		end
		d.alfaRanura = r
		return d
	end })
end

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

---------------------------------------------------------------------------
-- 1.3.8: Color de los marcos (Color.lua): el modo, tu color, la intensidad y
-- una vista previa con tres barras (llena, a media y baja).
---------------------------------------------------------------------------

-- La muestra de «Tu color»: un cuadrito con el color (ya con la intensidad) y
-- el botón que abre el selector de colores del juego.
local function controlTuColor(fila)
	local f = CreateFrame("Frame", nil, fila)
	local chip = CreateFrame("Frame", nil, f)
	chip:SetSize(30, 18)
	chip.caja = K.Caja(chip, { fondo = "hundido", borde = "linea", corte = K.CORTE.chico })
	chip.color = chip:CreateTexture(nil, "ARTWORK")
	chip.color:SetTexture("Interface\\Buttons\\WHITE8x8")
	chip.color:SetPoint("TOPLEFT", chip, "TOPLEFT", 3, -3)
	chip.color:SetPoint("BOTTOMRIGHT", chip, "BOTTOMRIGHT", -3, 3)
	local b = K.Boton(f, L["Elegir color"], function() M.ElegirColor() end, { tipo = "secundario", tam = "chico" })
	chip:SetPoint("LEFT", f, "LEFT", 0, 0)
	b:SetPoint("LEFT", chip, "RIGHT", ESP.s, 0)
	f.Chip, f.Boton = chip, b
	local function medir()
		f:SetSize(30 + ESP.s + K.num(b:GetWidth(), 90), max(18, K.num(b:GetHeight(), 22)))
	end
	medir()
	function f:Leer()
		local k, base = M.FactorColor()
		local r, g, bb = M.ColorUnico()
		self.Chip.color:SetVertexColor(r * k + base, g * k + base, bb * k + base, 1)
		medir()
	end
	function f:SetActivo(on)
		if on == false then self.Boton:Disable() else self.Boton:Enable() end
		self:SetAlpha(on == false and 0.45 or 1)
	end
	f:Leer()
	return f
end

-- Así se ven: tres barras chicas con el modo y la intensidad de ahora.
local MUESTRAS = { { "WARRIOR", 1 }, { "PRIEST", 0.6 }, { "MAGE", 0.25 } }
local function controlVista(fila)
	local f = CreateFrame("Frame", nil, fila)
	local W, H = 64, 20
	f:SetSize(3 * W + 2 * ESP.s, H)
	f.minis = {}
	for i, m in ipairs(MUESTRAS) do
		local c = CreateFrame("Frame", nil, f)
		c:SetSize(W, H)
		c:SetPoint("LEFT", f, "LEFT", (i - 1) * (W + ESP.s), 0)
		c.fondo = c:CreateTexture(nil, "BACKGROUND")
		c.fondo:SetTexture("Interface\\Buttons\\WHITE8x8")
		c.fondo:SetAllPoints(c)
		c.fondo:SetVertexColor(0.03, 0.035, 0.04, 0.9)
		c.hueco = c:CreateTexture(nil, "BORDER")
		c.hueco:SetTexture("Interface\\Buttons\\WHITE8x8")
		c.hueco:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
		c.hueco:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -1, 1)
		c.vida = c:CreateTexture(nil, "ARTWORK")
		c.vida:SetTexture("Interface\\Buttons\\WHITE8x8")
		c.vida:SetPoint("TOPLEFT", c, "TOPLEFT", 1, -1)
		c.vida:SetPoint("BOTTOMLEFT", c, "BOTTOMLEFT", 1, 1)
		c.vida:SetWidth(max(1, (W - 2) * m[2]))
		c.borde = {}
		for j = 1, 4 do
			local t = c:CreateTexture(nil, "OVERLAY")
			t:SetTexture("Interface\\Buttons\\WHITE8x8")
			c.borde[j] = t
		end
		c.borde[1]:SetPoint("TOPLEFT") c.borde[1]:SetPoint("TOPRIGHT") c.borde[1]:SetHeight(2)
		c.borde[2]:SetPoint("BOTTOMLEFT") c.borde[2]:SetPoint("BOTTOMRIGHT") c.borde[2]:SetHeight(2)
		c.borde[3]:SetPoint("TOPLEFT") c.borde[3]:SetPoint("BOTTOMLEFT") c.borde[3]:SetWidth(2)
		c.borde[4]:SetPoint("TOPRIGHT") c.borde[4]:SetPoint("BOTTOMRIGHT") c.borde[4]:SetWidth(2)
		c.alfaMuestra = m
		f.minis[i] = c
	end
	function f:Leer()
		local P = M.PELIGRO
		for _, c in ipairs(self.minis) do
			local clase, vida = c.alfaMuestra[1], c.alfaMuestra[2]
			local r, g, b = M.ColorPara(clase, vida)
			c.vida:SetVertexColor(r, g, b, 1)
			local cr, cg, cb = M.ColorDeClase(clase)
			if M.ModoColor() ~= "clase" or not cr then cr, cg, cb = r, g, b end
			c.hueco:SetVertexColor(cr * 0.1 + 0.02, cg * 0.1 + 0.02, cb * 0.1 + 0.025, 0.75)
			local peligro = N.Get(ID, "peligro") and vida < M.UMBRAL_PELIGRO
			for j = 1, 4 do
				c.borde[j]:SetVertexColor(P.borde[1], P.borde[2], P.borde[3], P.borde[4])
				c.borde[j]:SetShown(peligro and true or false)
			end
		end
	end
	f:Leer()
	return f
end

function M.GrupoColor(padre, activo)
	local g = K.GrupoAjustes(padre, { titulo = L["Color de los marcos"] })
	g:Fila({ titulo = L["Color de la barra"], activa = activo,
		texto = L["Por clase: el color de la clase de cada uno, apagado para que no canse. Un solo color: el que tú elijas. Según la vida: verde, amarillo y rojo según lo que le queda."],
		control = function(fila)
			return K.Desplegable(fila, { ancho = 180, opciones = {
				{ valor = "clase", texto = L["Por clase"] }, { valor = "unico", texto = L["Un solo color"] }, { valor = "vida", texto = L["Según la vida"] } },
				get = function() return M.ModoColor() end,
				set = function(v) N.Set(ID, "colorModo", v) end })
		end })
	g:Fila({ titulo = L["Tu color"], hija = true,
		activa = function() return activo() and M.ModoColor() == "unico" end,
		texto = L["El color de todas las barras con «Un solo color», con el selector de colores del juego."],
		control = controlTuColor })
	g:Fila({ titulo = L["Intensidad"], activa = activo,
		texto = L["Qué tan vivo se ve el color de las barras."],
		control = function(fila)
			return K.Desplegable(fila, { clave = ID .. ".colorIntensidad", ancho = 180, opciones = {
				{ valor = "apagado", texto = L["Apagado [color]"] }, { valor = "normal", texto = L["Normal [color]"] }, { valor = "vivo", texto = L["Vivo [color]"] } } })
		end })
	g:Fila({ titulo = L["Así se ven"], activa = activo,
		texto = L["Llena, a media y baja (con el borde de «En peligro»)."],
		control = controlVista })
	return g
end

local function grupos(ui, padre)
	local clics = K.GrupoAjustes(padre, { titulo = L["Tus clics"] })
	ui.clics = clics
	clics:Fila({ titulo = L["Curar y seleccionar"],
		texto = L["Cada clic que cura también selecciona a ese compañero, para seguir con otro poder, un buff o quitarle una maldición o un veneno."],
		control = function(fila)
			local s = K.Interruptor(fila, { valor = M.CurarSelecciona(), alCambiar = function(v) M.FijarCurarSelecciona(v == true) end })
			function s:Leer() self:SetValor(M.CurarSelecciona()) end
			return s
		end })
	ui.filasClic = {}
	for _, r in ipairs(M.PRINCIPALES) do ui.filasClic[#ui.filasClic + 1] = filaClic(clics, r) end
	clics:Fila({ titulo = L["Cambiar de mapa con tus talentos"], control = interruptor("mapaPorRama"),
		texto = L["Si guardaste un mapa de clics con otros talentos, al cambiarlos Alfa pone ese mapa solo (fuera de combate)."] })
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
	marcos:Fila({ titulo = L["En banda, un grupo por columna"], control = interruptor("porGrupos"), hija = true,
		activa = function() return activo() and (N.Get(ID, "orden") or "grupo") == "grupo" end,
		texto = L["Cada grupo de la banda en su propia columna (o fila), como en la ventana de banda. Con el orden por grupo."] })
	marcos:Fila({ titulo = L["Volver a su lugar"], texto = L["Pone los marcos donde estaban al instalar Alfa."], activa = activo,
		control = function(fila) return K.Boton(fila, L["Reiniciar"], function() M.ReiniciarPosicion() end, { tipo = "secundario", tam = "chico" }) end })

	local color = M.GrupoColor(padre, activo)

	local muestran = K.GrupoAjustes(padre, { titulo = L["Qué muestran"] })
	local function fila(titulo, clave, texto)
		muestran:Fila({ titulo = titulo, texto = texto, control = interruptor(clave), activa = activo })
	end
	-- 1.3.7: maná, furia o energía bajo la vida (Marcos.lua).
	fila(L["Maná, furia o energía"], "recurso", L["Una barra delgada bajo la vida con el maná, la furia o la energía de cada uno, en su color."])
	fila(L["Curas que van llegando"], "entrantes", L["Una franja verde clara muestra las curas que ya vienen en camino."])
	fila(L["Amenaza"], "amenaza", L["Una línea roja arriba avisa cuando un enemigo va por ese compañero; si no es el tanque, su marco brilla en naranja por fuera."])
	fila(L["Perjuicios que puedes quitar"], "disipar", L["El borde toma el color del perjuicio (magia, maldición, enfermedad o veneno) cuando tú lo puedes quitar."])
	muestran:Fila({ titulo = L["Ícono del tipo de perjuicio"], control = interruptor("tipoPerjuicio"), hija = true,
		activa = function() return activo() and N.Get(ID, "disipar") and true or false end,
		texto = L["Arriba a la derecha, el ícono de magia, maldición, veneno o enfermedad. Al pasar el ratón te dice qué clic lo quita."] })
	-- 1.3.6: «hechizo de apoyo» en vez de «buff».
	fila(L["Le falta tu hechizo de apoyo"], "buffs", L["Un punto azul abajo a la derecha si a ese compañero le falta tu hechizo de apoyo (el que le das antes de pelear). Se revisa fuera de combate."])
	fila(L["Tanque en apuros"], "tanque", L["El marco del tanque late en rojo cuando le queda menos del 40 % de vida."])
	-- 1.3.7 (Peligro.lua)
	fila(L["En peligro"], "peligro", L["Un borde rojo suave respira alrededor de quien baja del 35 % de vida, para verlo a la primera."])
	fila(L["Maná de los curanderos"], "mana", L["Arriba de tus marcos, el maná de quienes curan en tu grupo. Se destaca al terminar cada pelea."])
	fila(L["Porcentaje de vida"], "porcentaje", L["Muestra la vida en número, debajo del nombre."])
	fila(L["Atenuar a quien está lejos"], "alcance", L["Si está fuera de tu alcance, su marco se ve más tenue."])
	fila(L["Detalle al pasar el ratón"], "descripcion", L["El cuadro del jugador al pasar el ratón. En combate no sale, para no estorbar."])
	fila(L["Cuadro corto en combate"], "descripcionCombate", L["En combate, solo lo que dice Alfa: con qué clic quitas el perjuicio de ese compañero. Sin el detalle del juego, para no estorbar."])
	-- 1.3.7 (Listos.lua): no depende de los marcos.
	muestran:Fila({ titulo = L["Lo que falta en «¿Listos?»"], control = interruptor("listos"),
		texto = L["Cuando alguien pregunta «¿Listos?»: tu comida, munición, equipo y espacio, y a quién le falta un hechizo de apoyo, con un botón para dar el tuyo. También con /alfa curacion listos."] })
	return { clics, marcos, color, muestran }
end

---------------------------------------------------------------------------
-- La página
---------------------------------------------------------------------------

local function construir(view)
	local ui = {}
	local t = K.Tablero(view, { margen = N.MargenPagina(), accion = "estado", tituloOpciones = L["Preajustes"], min = 240 })
	ui.grupos = grupos(ui, t.Extra)
	-- 1.3.0: primero «Tus clics» (lo más claro), luego todos los clics y lo demás.
	t:AgregarBloque(ui.grupos[1])
	ui.raton = t:AgregarBloque(nuevoRaton(t.Extra))
	-- 1.3.9: tus mapas de clics guardados (Perfiles.lua).
	ui.mapas = t:AgregarBloque(M.BloqueMapas(t.Extra))
	for i = 2, #ui.grupos do t:AgregarBloque(ui.grupos[i]) end
	local function repintar()
		filaIzquierdo(ui)
		t:SetAccion(estado())
		t:SetOpciones(preajustes(), L["Preajustes"])
		ui.raton:Llenar()
		ui.mapas:Llenar()
		local r = M.Datos().blizzard
		ui.filaBlizzard.alfaDatos.texto = BASE_BLIZZARD .. ((type(r) == "table" and type(r.texto) == "string") and ("\n" .. r.texto) or "")
		for _, g in ipairs(ui.grupos) do g:Refrescar() end
	end
	K.EnPagina(view, t, function()
		-- 1.3.1: tus hechizos por tipo, una vez para todo el repintado.
		catsRepintado = M.HechizosPorCategoria()
		local ok, err = pcall(repintar)
		catsRepintado = nil
		if not ok then error(err, 0) end
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

---------------------------------------------------------------------------
-- Para la búsqueda de ajustes de la ventana de Alfa (la página es propia):
-- los mismos ajustes de arriba, con su texto y atenuados igual. "Usar
-- también en los marcos de Blizzard" no va: su botón es seguro (lo abre el
-- juego) y solo se puede hacer en la página.
---------------------------------------------------------------------------
local function clave(k) return ID .. "." .. k end
local function apagado() return not activo() end

local function toggle(k, label, help, search, hija)
	return { kind = "toggle", key = clave(k), label = label, help = help, search = search, child = hija, disabled = apagado }
end

local CONTROLES = {
	-- No es un ajuste (va por personaje, en M.Datos): se cambia solo si es otro valor,
	-- así "Restablecer la página" no vuelve a aplicar tu preajuste sin motivo.
	{ kind = "toggle", label = L["El clic izquierdo solo selecciona"],
		help = L["Para quien prefiere seleccionar con el izquierdo: la cura de ese clic pasa al botón central. Se vuelve a aplicar tu preajuste."],
		disabled = function() return M.Datos().preajuste ~= "curar" end,
		get = function() return M.IzquierdoSelecciona() end,
		set = function(v)
			if (v == true) ~= M.IzquierdoSelecciona() then M.FijarIzquierdoSelecciona(v == true) end
		end,
		search = "left click select, click casting, middle button" },
	{ kind = "toggle", label = L["Curar y seleccionar"],
		help = L["Cada clic que cura también selecciona a ese compañero, para seguir con otro poder, un buff o quitarle una maldición o un veneno."],
		get = function() return M.CurarSelecciona() end,
		set = function(v)
			if (v == true) ~= M.CurarSelecciona() then M.FijarCurarSelecciona(v == true) end
		end,
		search = "heal and target, select on click, click casting" },
	{ kind = "toggle", key = clave("mapaPorRama"), label = L["Cambiar de mapa con tus talentos"],
		help = L["Si guardaste un mapa de clics con otros talentos, al cambiarlos Alfa pone ese mapa solo (fuera de combate)."],
		search = "click profiles, spec, talents, saved click maps, mapas de clics" },
	{ kind = "toggle", key = clave("activo"), label = L["Usar los marcos de Alfa"],
		help = L["Tu grupo y tu banda con su vida, para curar con un clic. Se cambia fuera de combate."],
		search = "raid frames, party frames, healing frames, click to heal" },
	toggle("solo", L["Verte a ti estando solo"], L["Tu propio marco aparece aunque no estés en grupo, para curarte con un clic."], "solo, player frame", true),
	toggle("ocultarBlizzard", L["Ocultar los marcos de grupo de Blizzard"], L["Para no ver dos veces a tu grupo. Se cambia fuera de combate."], "hide blizzard raid frames", true),
	{ kind = "slider", key = clave("ancho"), label = L["Ancho"], min = 50, max = 200, step = 2, format = px, child = true, disabled = apagado, search = "frame width" },
	{ kind = "slider", key = clave("alto"), label = L["Alto"], min = 20, max = 80, step = 1, format = px, child = true, disabled = apagado, search = "frame height" },
	{ kind = "slider", key = clave("porColumna"), label = L["Compañeros por columna"], min = 1, max = 40, step = 1, format = entero, child = true, disabled = apagado,
		help = L["Cuántos van en cada columna (o fila) antes de empezar otra. 5 es un grupo por columna."], search = "per column, layout" },
	{ kind = "dropdown", key = clave("crecer"), label = L["Crecen hacia"], child = true, disabled = apagado,
		choices = { { value = "abajo", label = L["Abajo"] }, { value = "derecha", label = L["La derecha"] } }, search = "grow direction, layout" },
	{ kind = "dropdown", key = clave("orden"), label = L["Orden"], child = true, disabled = apagado,
		choices = { { value = "grupo", label = L["Por grupo"] }, { value = "rol", label = L["Por rol"] },
			{ value = "clase", label = L["Por clase"] }, { value = "nombre", label = L["Por nombre"] } }, search = "sort, order, role, class" },
	toggle("porGrupos", L["En banda, un grupo por columna"], L["Cada grupo de la banda en su propia columna (o fila), como en la ventana de banda. Con el orden por grupo."], "raid groups, layout", true),
	{ kind = "button", label = L["Volver a su lugar"], button = L["Reiniciar"], icon = "window", disabled = apagado,
		help = L["Pone los marcos donde estaban al instalar Alfa."], onClick = function() M.ReiniciarPosicion() end, search = "reset position" },
	-- 1.3.8: «Color de los marcos» (antes, «Color de clase» prendido o apagado).
	{ kind = "dropdown", key = clave("colorModo"), label = L["Color de la barra"], disabled = apagado,
		help = L["Por clase: el color de la clase de cada uno, apagado para que no canse. Un solo color: el que tú elijas. Según la vida: verde, amarillo y rojo según lo que le queda."],
		get = function() return M.ModoColor() end, set = function(v) N.Set(ID, "colorModo", v) end,
		choices = { { value = "clase", label = L["Por clase"] }, { value = "unico", label = L["Un solo color"] }, { value = "vida", label = L["Según la vida"] } },
		search = "class colours, frame colour, health colour, custom colour, color de clase" },
	{ kind = "button", label = L["Tu color"], button = L["Elegir color"], icon = "window", child = true,
		disabled = function() return apagado() or M.ModoColor() ~= "unico" end,
		help = L["El color de todas las barras con «Un solo color», con el selector de colores del juego."], onClick = function() M.ElegirColor() end,
		search = "custom colour, color picker" },
	{ kind = "dropdown", key = clave("colorIntensidad"), label = L["Intensidad"], disabled = apagado,
		help = L["Qué tan vivo se ve el color de las barras."],
		choices = { { value = "apagado", label = L["Apagado [color]"] }, { value = "normal", label = L["Normal [color]"] }, { value = "vivo", label = L["Vivo [color]"] } },
		search = "colour intensity, brightness, saturation" },
	toggle("recurso", L["Maná, furia o energía"], L["Una barra delgada bajo la vida con el maná, la furia o la energía de cada uno, en su color."], "power bar, mana bar, rage, energy, runic power"),
	toggle("entrantes", L["Curas que van llegando"], L["Una franja verde clara muestra las curas que ya vienen en camino."], "incoming heals, heal prediction"),
	toggle("amenaza", L["Amenaza"], L["Una línea roja arriba avisa cuando un enemigo va por ese compañero; si no es el tanque, su marco brilla en naranja por fuera."], "threat, aggro"),
	toggle("disipar", L["Perjuicios que puedes quitar"], L["El borde toma el color del perjuicio (magia, maldición, enfermedad o veneno) cuando tú lo puedes quitar."], "dispel, debuffs, decurse"),
	toggle("tipoPerjuicio", L["Ícono del tipo de perjuicio"], L["Arriba a la derecha, el ícono de magia, maldición, veneno o enfermedad. Al pasar el ratón te dice qué clic lo quita."], "debuff type icon, dispel", true),
	-- 1.3.6: «hechizo de apoyo» en vez de «buff».
	toggle("buffs", L["Le falta tu hechizo de apoyo"], L["Un punto azul abajo a la derecha si a ese compañero le falta tu hechizo de apoyo (el que le das antes de pelear). Se revisa fuera de combate."], "missing buffs, buff, hechizo de apoyo, fortitude, mark of the wild, arcane intellect, blessing"),
	toggle("tanque", L["Tanque en apuros"], L["El marco del tanque late en rojo cuando le queda menos del 40 % de vida."], "tank alert, low health"),
	toggle("peligro", L["En peligro"], L["Un borde rojo suave respira alrededor de quien baja del 35 % de vida, para verlo a la primera."], "low health, danger, red, alert"),
	toggle("mana", L["Maná de los curanderos"], L["Arriba de tus marcos, el maná de quienes curan en tu grupo. Se destaca al terminar cada pelea."], "healer mana, group mana"),
	toggle("porcentaje", L["Porcentaje de vida"], L["Muestra la vida en número, debajo del nombre."], "health percent"),
	toggle("alcance", L["Atenuar a quien está lejos"], L["Si está fuera de tu alcance, su marco se ve más tenue."], "range, out of range fade"),
	toggle("descripcion", L["Detalle al pasar el ratón"], L["El cuadro del jugador al pasar el ratón. En combate no sale, para no estorbar."], "tooltip, mouseover"),
	toggle("descripcionCombate", L["Cuadro corto en combate"], L["En combate, solo lo que dice Alfa: con qué clic quitas el perjuicio de ese compañero. Sin el detalle del juego, para no estorbar."], "combat tooltip, dispel click"),
	{ kind = "toggle", key = clave("listos"), label = L["Lo que falta en «¿Listos?»"],
		help = L["Cuando alguien pregunta «¿Listos?»: tu comida, munición, equipo y espacio, y a quién le falta un hechizo de apoyo, con un botón para dar el tuyo. También con /alfa curacion listos."],
		search = "ready check, missing buffs, food, ammo, repair, bag space, fortitude, mark of the wild, intellect" },
}

N.Modulo({
	id = ID, nombre = L["Curación"], icono = "ic-curacion", orden = 16,
	-- 1.3.6: subtítulo corto (la ventana esconde los de más de 60 letras).
	subtitulo = L["Marcos de grupo y banda para curar con un clic."],
	comando = "curacion",
	ajustes = M.AJUSTES,
	controles = CONTROLES,
	construir = construir,
})

-- Para la página Hoy (Alfa_Inicio): el asistente, a la vista de quien cura.
AlfaCuracion = {
	Asistente = abrirAsistente,
	AsistentePendiente = function() return M.AsistentePendiente() end,
	Omitir = function() M.OmitirAsistente() end,
	-- 1.3.0
	CurarSelecciona = function() return M.CurarSelecciona() end,
	QuitarSinClic = function() return M.QuitarSinClic() end,
	-- 1.3.1: para «Acomodar la pantalla» (Alfa_Bienvenida/Acomodar.lua).
	Mover = function(si) M.Mover(si) end,
	Moviendo = function() return M.Moviendo() end,
}

-- 1.3.0: Lya sabe contar lo nuevo de Curación (Pregúntale a Lya).
A.OnLogin(function()
	local Lya = rawget(_G, "AlfaLya")
	if type(Lya) ~= "table" or type(Lya.Ensenar) ~= "function" then return end
	for _, p in ipairs({
		{ id = "curacion.seleccionar", icono = "ic-curacion", pregunta = L["¿Cómo curo y selecciono a la vez?"],
			respuesta = L["En Curación, «Curar y seleccionar» viene prendido: cada clic que cura en tus marcos también deja a ese compañero como tu objetivo, para seguir con un buff o quitarle una maldición. En «Tus clics» eliges qué hace cada clic."] },
		{ id = "curacion.perjuicios", icono = "ic-curacion", pregunta = L["¿Cómo le quito un veneno o una maldición a alguien?"],
			respuesta = L["Si tu clase lo puede quitar, su marco se pinta del color del perjuicio y sale su ícono arriba a la derecha. Pasa el ratón y te digo con qué clic se quita; si ningún clic lo hace, elígelo en «Tus clics»."] },
		-- 1.3.6: sin «buff».
		{ id = "curacion.buffs", icono = "ic-curacion", pregunta = L["¿Qué es el punto azul en mis marcos?"],
			respuesta = L["Que a ese compañero le falta tu hechizo de apoyo (el que le das antes de pelear). Pasa el ratón sobre su marco: te digo con qué clic se lo das."] },
	}) do
		p.modulo = ID
		pcall(Lya.Ensenar, p)
	end
end)

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
	-- 1.3.7: lo que te falta y los apoyos del grupo antes de jalar (Listos.lua).
	listos = function() if not M.Listos.Mostrar("manual") then N.Imprimir(L["Se puede al salir de combate."]) end end,
	bufos = function() if not M.Listos.Mostrar("manual") then N.Imprimir(L["Se puede al salir de combate."]) end end,
}

function M.Comando(resto)
	resto = (type(resto) == "string" and resto or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
	local fn = ACCIONES[resto]
	if fn then fn() else N.Abrir(ID) end
end

A.RegisterCommand("curacion", M.Comando, L["abre Curación (también: asistente, prueba, prueba20, mover, listo, listos, blizzard, on, off, reiniciar)"])
