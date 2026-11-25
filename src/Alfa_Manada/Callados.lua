-- Alfa - La Jauría: silenciar a un lobo (1.4.0, 56). toxic3000 / La Jauría.
-- GPL-3.0.
--
-- Desde su ficha («Silenciar sus avisos») o con /alfa manada silenciar
-- <nombre>: lo que ese lobo dispara (sus citas, sus llamados, sus raros, sus
-- logros, «anda cerca», «cazar juntos», sus tarjetas de plan o de guía, la
-- plática de su Lya con la tuya) ya no te sale como aviso. Lo demás sigue
-- igual: lo ves en el mapa y en la página de La Jauría, y lo que responde a
-- algo que tú pediste (te abre la puerta, va a tu cita, viene a tu llamado)
-- sí sale. Nadie se entera: no se manda nada. Se guarda en la cuenta
-- (N.Datos("manada").callados), hasta TOPE lobos.
--
--   Ca.Esta(nombre o clave) -> bool      Ca.Poner(nombre, si) -> bool
--   Ca.Alternar(nombre) -> si            Ca.Lista() -> { { clave, nombre, t } }
--   Ca.QuitarTodos() -> n                Ca.Contar() ; Ca.Ocultos() -> n (esta sesión)
--   AlfaManada.Callado(nombre) -> bool   (para Lya)

local ADDON, M = ...
local N = AlfaNucleo
local U, L, ID = M.U, M.L, M.ID

local type, pairs, ipairs, tostring, sort, format, next = type, pairs, ipairs, tostring, table.sort, string.format, next

local Ca = {}
M.Callados = Ca

local TOPE = 100
local ocultos = 0
Ca.version = 0

local function lista()
	local d = N.Datos(ID)
	if type(d.callados) ~= "table" then d.callados = {} end
	return d.callados
end

local function clave(nombre)
	if type(nombre) ~= "string" or U.Secreto(nombre) then return nil end
	-- Una clave ya hecha («ana smith») se queda como está.
	return U.Clave(nombre)
end

function Ca.Esta(nombre)
	local d = N.Datos(ID).callados
	if type(d) ~= "table" or next(d) == nil then return false end
	local k = clave(nombre)
	return k ~= nil and d[k] ~= nil
end

function Ca.Poner(nombre, si)
	local k = clave(nombre)
	if not k or k == U.MiClave() then return false end
	local d = lista()
	if si then
		if not d[k] then
			local n = 0
			for _ in pairs(d) do n = n + 1 end
			if n >= TOPE then return false end
		end
		d[k] = { n = U.Mostrar(nombre) or nombre, t = U.Reloj() }
	else
		if not d[k] then return false end
		d[k] = nil
	end
	Ca.version = Ca.version + 1
	if M.Avisar then M.Avisar() end
	return true
end

function Ca.Alternar(nombre)
	local si = not Ca.Esta(nombre)
	if not Ca.Poner(nombre, si) then return Ca.Esta(nombre) end
	local quien = U.Mostrar(nombre) or tostring(nombre)
	U.Decir(si and format(L["Silenciaste a %s: sus avisos ya no te salen. Lo sigues viendo en el mapa y en La Jauría."], quien)
		or format(L["%s ya no está silenciado: sus avisos te vuelven a salir."], quien))
	return si
end

function Ca.Lista()
	local out = {}
	for k, x in pairs(lista()) do
		if type(x) == "table" then out[#out + 1] = { clave = k, nombre = x.n or k, t = x.t } end
	end
	sort(out, function(a, b) return tostring(a.nombre) < tostring(b.nombre) end)
	return out
end

function Ca.QuitarTodos()
	local d, n = lista(), 0
	for k in pairs(d) do d[k] = nil n = n + 1 end
	if n > 0 then
		Ca.version = Ca.version + 1
		if M.Avisar then M.Avisar() end
	end
	return n
end

function Ca.Contar() ocultos = ocultos + 1 end
function Ca.Ocultos() return ocultos end

-- /alfa manada silenciados: quiénes y cuántos avisos se callaron.
function Ca.Decir()
	local l = Ca.Lista()
	if #l == 0 then U.Decir(L["No silenciaste a ningún lobo."]) return end
	local nombres = {}
	for i, x in ipairs(l) do nombres[i] = x.nombre end
	U.Decir(format(L["Lobos silenciados (%d): %s."], #l, table.concat(nombres, ", ")))
	if ocultos > 0 then U.Decir(N.Plural(ocultos, L["En esta sesión te callé %d aviso de ellos."], L["En esta sesión te callé %d avisos de ellos."])) end
end

AlfaManada = type(rawget(_G, "AlfaManada")) == "table" and rawget(_G, "AlfaManada") or {}
function AlfaManada.Callado(nombre) return Ca.Esta(nombre) end

---------------------------------------------------------------------------
-- 1.4.0 (116): «Lobos silenciados» a la vista (Ajustes de La Jauría): quién
-- está silenciado, desde cuándo, y «Quitar el silencio» sin tener que
-- encontrarlo conectado para abrir su ficha.
---------------------------------------------------------------------------
local v, ui = nil, {}

local function desde(t)
	t = tonumber(t)
	if not (t and t > 0 and date) then return nil end
	local ok, s = pcall(date, "%d/%m/%Y", t)
	return ok and s or nil
end

-- Un renglón por lobo: su nombre, desde cuándo y «Quitar el silencio» a la derecha.
local llenarVentana
local function nuevaFila(padre)
	local K = N.Kit
	local f = CreateFrame("Frame", nil, padre)
	f.caja = K.Caja(f, { fondo = "elevado", borde = "linea", corte = K.CORTE.control })
	f.Icono = K.Icono(f, "ic-manada", 16, "textoSuave")
	f.Nombre = K.Texto(f, "cuerpo", "texto")
	f.Desde = K.Texto(f, "pequeno", "textoTenue")
	f.Quitar = K.Boton(f, L["Quitar el silencio"], function()
		if f.alfaClave then Ca.Poner(f.alfaClave, false) end
		llenarVentana()
	end, { tipo = "secundario" })
	return f
end

local function nuevaLista(padre)
	local K = N.Kit
	local l = CreateFrame("Frame", nil, padre)
	l.filas, l.datos = {}, {}
	function l:Llenar(datos) self.datos = datos or {} end
	function l:Acomodar(ancho)
		local y = 0
		for i, x in ipairs(self.datos) do
			local f = self.filas[i] or nuevaFila(self)
			self.filas[i] = f
			f.alfaClave = x.clave
			K.Escribir(f.Nombre, tostring(x.nombre))
			local d = desde(x.t)
			K.Escribir(f.Desde, d and format(L["Silenciado desde el %s"], d) or "")
			local bw = K.num(f.Quitar:AnchoNatural(), 140)
			local tw = math.max(80, ancho - 2 * K.ESP.m - 16 - K.ESP.s - bw - K.ESP.m)
			local th = K.Parrafo(f.Nombre, tw) + ((f.Desde:GetText() or "") ~= "" and (2 + K.Parrafo(f.Desde, tw)) or 0)
			local alto = math.max(K.ALTO.boton, th) + 2 * K.ESP.s
			f.Icono:ClearAllPoints()
			f.Icono:SetPoint("LEFT", f, "LEFT", K.ESP.m, 0)
			f.Nombre:ClearAllPoints()
			f.Nombre:SetPoint("TOPLEFT", f, "TOPLEFT", K.ESP.m + 16 + K.ESP.s, -math.floor((alto - th) / 2))
			f.Desde:ClearAllPoints()
			f.Desde:SetPoint("TOPLEFT", f.Nombre, "BOTTOMLEFT", 0, -2)
			f.Quitar:ClearAllPoints()
			f.Quitar:SetPoint("RIGHT", f, "RIGHT", -K.ESP.s, 0)
			f:ClearAllPoints()
			f:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -y)
			f:SetSize(ancho, alto)
			f:Show()
			y = y + alto + K.ESP.s
		end
		for i = #self.datos + 1, #self.filas do self.filas[i]:Hide() end
		y = math.max(1, y - K.ESP.s)
		self:SetSize(ancho, y)
		return y
	end
	return l
end

llenarVentana = function()
	if not (v and ui.rejilla) then return end
	local K = N.Kit
	local items = Ca.Lista()
	ui.rejilla:Llenar(items)
	K.Mostrar(ui.rejilla, #items > 0)
	K.Escribir(ui.nota.Texto, #items > 0 and (L["Sus avisos no te salen; los sigues viendo en el mapa y en La Jauría. Nadie se entera."]
		.. (ocultos > 0 and (" " .. N.Plural(ocultos, L["En esta sesión te callé %d aviso de ellos."], L["En esta sesión te callé %d avisos de ellos."])) or ""))
		or "")
	K.Mostrar(ui.nota, #items > 0)
	K.Mostrar(ui.vacio, #items == 0)
	if ui.todos then ui.todos:SetActivo(#items > 0, L["No silenciaste a ningún lobo."]) end
	if v.alAcomodar then v.alAcomodar() end
end

local function acomodar()
	if not (v and v:IsShown() and ui.pila) then return end
	local ancho = v:AnchoCuerpo()
	local h = ui.pila:Acomodar(ancho)
	ui.pila:ClearAllPoints()
	ui.pila:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	v:SetAltoContenido(h + 2 * v.margen)
end

function Ca.Ventana()
	local K = N.Kit
	if not K then return nil end
	if not v then
		v = K.Ventana({ nombre = "AlfaManadaCallados", titulo = L["Lobos silenciados"], icono = "ic-manada", ancho = 520, alto = 440, desplazar = true })
		v:SetTitulo(L["Lobos silenciados"], L["Los lobos cuyos avisos no te salen"], "ic-manada")
		v.alAcomodar = acomodar
		local p = K.Pila(v.Cuerpo, { espacio = K.ESP.base })
		ui.pila = p
		local nota = CreateFrame("Frame", nil, p)
		nota.Texto = K.Texto(nota, "nota", "textoSuave")
		nota.Texto:SetPoint("TOPLEFT")
		function nota:Acomodar(ancho) local h = K.Parrafo(self.Texto, ancho) self:SetHeight(h) return h end
		ui.nota = p:Agregar(nota)
		ui.rejilla = p:Agregar(nuevaLista(p), { espacio = K.ESP.s })
		ui.vacio = p:Agregar(K.Vacio(p, { lobo = "dormido", titulo = L["No silenciaste a ningún lobo"],
			texto = L["Si los avisos de un lobo te cansan, abre su ficha en La Jauría y elige «Silenciar sus avisos». Aquí lo puedes quitar cuando quieras."] }), { espacio = K.ESP.l })
		ui.todos = K.Boton(v, L["Quitar a todos"], function()
			K.Dialogo({ titulo = L["¿Quitar el silencio a todos?"], texto = L["Sus avisos te vuelven a salir. Puedes silenciarlos otra vez desde su ficha."],
				aceptar = L["Quitar a todos"], alAceptar = function() Ca.QuitarTodos() llenarVentana() end })
		end, { tipo = "fantasma" })
		v:SetPie({ K.Boton(v, L["Cerrar"], function() v:Cerrar() end, { tipo = "primario" }) }, { ui.todos })
	end
	v:Abrir()
	llenarVentana()
	return v
end
