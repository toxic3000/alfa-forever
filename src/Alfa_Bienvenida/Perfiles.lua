-- Alfa - Bienvenida: tus perfiles y la copia de tus ajustes (1.2.7).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Los ajustes de Alfa son de la cuenta (AlfaDB.settings): todos tus
-- personajes los comparten. Un perfil guarda cómo los tienes ahora con un
-- nombre («Mi sacerdote curador», «Mi guerrero») para volver a ellos con un
-- clic. La copia es el mismo perfil como texto: lo copias, lo guardas o se lo
-- pasas a la manada, y lo pegas para traerlo de vuelta.
--
-- El texto: una primera línea «Alfa:perfil:1» y una línea por ajuste,
-- «ruta=tipo:valor» (b = sí/no, n = número, s = texto con \n y \\ escapados).
-- Al leerlo no se ejecuta nada: solo se aceptan esas líneas.
--
--   Pf.Guardar(nombre) -> ok      Pf.Aplicar(nombre) -> ok      Pf.Borrar(nombre)
--   Pf.Lista() -> { nombre, ... } Pf.Exportar() -> texto        Pf.Importar(texto) -> ok, n | false, por qué
--   /alfa rendimiento: cuánta memoria usa cada parte de Alfa ahora.

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local Pf = {}
M.Perfiles = Pf

local type, pairs, ipairs, tostring, tonumber, format = type, pairs, ipairs, tostring, tonumber, string.format
local sort, concat = table.sort, table.concat

local CABECERA = "Alfa:perfil:1"
local MAX_LINEAS = 6000

local function guardados()
	local d = N.Datos(M.ID)
	d.perfiles = type(d.perfiles) == "table" and d.perfiles or {}
	return d.perfiles
end

-- Los ajustes como { ["ruta.del.ajuste"] = valor } (solo sí/no, números y textos).
local function aplanar(t, prefijo, out, profundidad)
	out = out or {}
	if (profundidad or 0) > 8 then return out end
	for k, v in pairs(t) do
		local ks = tostring(k)
		if ks:match("^[%w_]+$") then
			local ruta = prefijo and (prefijo .. "." .. ks) or ks
			local tv = type(v)
			if tv == "table" then aplanar(v, ruta, out, (profundidad or 0) + 1)
			elseif tv == "boolean" or tv == "number" or tv == "string" then out[ruta] = v end
		end
	end
	return out
end

-- Y de vuelta: las claves que son números vuelven a ser números (posiciones).
local function armar(plano)
	local t = {}
	for ruta, v in pairs(plano) do
		local nodo, partes = t, {}
		for p in ruta:gmatch("[^%.]+") do partes[#partes + 1] = tonumber(p) or p end
		for i = 1, #partes - 1 do
			local k = partes[i]
			if type(nodo[k]) ~= "table" then nodo[k] = {} end
			nodo = nodo[k]
		end
		nodo[partes[#partes]] = v
	end
	return t
end

local function ajustes()
	local db = A.DB and A.DB()
	return type(db) == "table" and type(db.settings) == "table" and db.settings or {}
end

function Pf.Lista()
	local out = {}
	for nombre in pairs(guardados()) do out[#out + 1] = nombre end
	sort(out)
	return out
end

function Pf.Guardar(nombre)
	if type(nombre) ~= "string" or nombre == "" then return false end
	guardados()[nombre] = aplanar(ajustes())
	return true
end

local function poner(plano)
	local db = A.DB and A.DB()
	if type(db) ~= "table" then return false end
	db.settings = armar(plano)
	-- Todos los módulos escuchan el cambio general ("" = todo).
	A.Fire("SETTING_CHANGED", "")
	if K.Repintar then pcall(K.Repintar) end
	return true
end

function Pf.Aplicar(nombre)
	local p = guardados()[nombre]
	if type(p) ~= "table" then return false end
	return poner(p)
end

function Pf.Borrar(nombre) guardados()[nombre] = nil end

local function escapar(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n")) end
local function desescapar(s) return (s:gsub("\\(.)", function(c) return c == "n" and "\n" or c end)) end

function Pf.Exportar()
	local plano = aplanar(ajustes())
	local rutas = {}
	for r in pairs(plano) do rutas[#rutas + 1] = r end
	sort(rutas)
	local lineas = { CABECERA }
	for _, r in ipairs(rutas) do
		local v = plano[r]
		local tv = type(v)
		if tv == "boolean" then lineas[#lineas + 1] = r .. "=b:" .. (v and "1" or "0")
		elseif tv == "number" then lineas[#lineas + 1] = r .. "=n:" .. tostring(v)
		else lineas[#lineas + 1] = r .. "=s:" .. escapar(v) end
	end
	return concat(lineas, "\n")
end

-- -> ok, cuántos ajustes | false, "vacio" | "formato"
function Pf.Leer(texto)
	if type(texto) ~= "string" or texto == "" then return false, "vacio" end
	texto = texto:gsub("\r", "")
	local plano, n, primera = {}, 0, true
	for linea in (texto .. "\n"):gmatch("([^\n]*)\n") do
		linea = linea:match("^%s*(.-)%s*$")
		if primera and linea ~= "" then
			if linea ~= CABECERA then return false, "formato" end
			primera = false
		elseif linea ~= "" then
			n = n + 1
			if n > MAX_LINEAS then return false, "formato" end
			local ruta, tipo, valor = linea:match("^([%w_%.]+)=([bns]):(.*)$")
			if not ruta then return false, "formato" end
			if tipo == "b" then plano[ruta] = valor == "1"
			elseif tipo == "n" then
				local x = tonumber(valor)
				if not x or x ~= x then return false, "formato" end
				plano[ruta] = x
			else plano[ruta] = desescapar(valor) end
		end
	end
	if primera then return false, "vacio" end
	return true, n, plano
end

function Pf.Importar(texto)
	local ok, n, plano = Pf.Leer(texto)
	if not ok then return false, n end
	-- Antes de cambiar nada, lo de ahora queda guardado por si acaso.
	guardados()[L["Antes de importar"]] = aplanar(ajustes())
	poner(plano)
	return true, n
end

---------------------------------------------------------------------------
-- La ventana para pegar un perfil
---------------------------------------------------------------------------
local v, caja

local function armarVentana()
	v = K.Ventana({ nombre = "AlfaPerfilImportar", titulo = L["Importar ajustes"], icono = "ic-ajustes", ancho = 560, alto = 420 })
	v:SetTitulo(L["Importar ajustes"], L["Pega aquí el texto que copiaste con «Exportar»"], "ic-ajustes")
	local marco = CreateFrame("Frame", nil, v.Cuerpo)
	marco:SetPoint("TOPLEFT", v.Cuerpo, "TOPLEFT", v.margen, -v.margen)
	marco:SetPoint("BOTTOMRIGHT", v.Cuerpo, "BOTTOMRIGHT", -v.margen, v.margen + K.ALTO.boton + K.ESP.m)
	marco.caja = K.Caja(marco, { fondo = "hundido", borde = "lineaFuerte", corte = K.CORTE.control })
	local sf = CreateFrame("ScrollFrame", nil, marco, "UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", marco, "TOPLEFT", 8, -8)
	sf:SetPoint("BOTTOMRIGHT", marco, "BOTTOMRIGHT", -28, 8)
	caja = CreateFrame("EditBox", nil, sf)
	caja:SetMultiLine(true)
	caja:SetAutoFocus(false)
	caja:SetWidth(460)
	caja:SetMaxLetters(0)
	K.FuenteSegura(caja, K.Cara("medium"), K.Tamano("nota"), "")
	caja:SetTextColor(K.Color("texto"))
	caja:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	sf:SetScrollChild(caja)
	local b = K.Boton(v.Cuerpo, L["Importar"], function()
		local ok, n = Pf.Importar(caja:GetText() or "")
		if ok then
			v:Cerrar()
			K.Aviso({ titulo = L["Ajustes importados"], texto = format(L["Se pusieron %d ajustes. Algunas cosas se ven completas al recargar."], n),
				icono = "ic-exito", accion = { texto = L["Recargar ahora"], alClic = function() if ReloadUI then ReloadUI() end end } })
		else
			K.Aviso({ titulo = L["No se pudo importar"], texto = n == "vacio" and L["No pegaste nada."]
				or L["Ese texto no es un perfil de Alfa. Copia el que da «Exportar» completo."], icono = "ic-aviso", tono = "aviso", lya = false })
		end
	end, { tipo = "primario", icono = "ic-exito" })
	b:SetPoint("BOTTOMRIGHT", v.Cuerpo, "BOTTOMRIGHT", -v.margen, v.margen)
end

function Pf.AbrirImportar()
	if not v then armarVentana() end
	caja:SetText("")
	v:Abrir()
	caja:SetFocus()
end

function Pf.MostrarExportar()
	local UI = A.UI
	local texto = Pf.Exportar()
	if UI and UI.ShowCopy then
		pcall(UI.ShowCopy, L["Exportar ajustes"], texto, { hint = L["Cópialo con Ctrl+C y guárdalo, o pásaselo a la manada. Para traerlo de vuelta: «Importar»."] })
	else
		N.Imprimir(L["Exportar ajustes"])
	end
end

-- El nombre que se propone para un perfil nuevo: tu personaje y su clase.
function Pf.NombreSugerido()
	local n = UnitName and UnitName("player")
	local _, clase = UnitClass and UnitClass("player")
	n = type(n) == "string" and not (issecretvalue and issecretvalue(n)) and n or "Alfa"
	local nombreClase = clase and (LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[clase]) or nil
	return nombreClase and format("%s (%s)", n, nombreClase) or n
end

---------------------------------------------------------------------------
-- /alfa rendimiento: la memoria de cada parte de Alfa
---------------------------------------------------------------------------
local function rendimiento()
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
	local CA = C_AddOns
	local total, lista = 0, {}
	local cuantos = CA and CA.GetNumAddOns and CA.GetNumAddOns() or 0
	for i = 1, cuantos do
		local nombre = CA.GetAddOnInfo(i)
		if type(nombre) == "string" and nombre:find("^Alfa") and CA.IsAddOnLoaded(nombre) and GetAddOnMemoryUsage then
			local ok, kb = pcall(GetAddOnMemoryUsage, nombre)
			kb = ok and tonumber(kb) or 0
			total = total + kb
			lista[#lista + 1] = { nombre, kb }
		end
	end
	sort(lista, function(a, b) return a[2] > b[2] end)
	N.Imprimir(format(L["Alfa usa %.1f MB de memoria ahora. Lo que más usa:"], total / 1024))
	for i = 1, math.min(6, #lista) do
		DEFAULT_CHAT_FRAME:AddMessage(format("  %s: %.1f MB", lista[i][1], lista[i][2] / 1024))
	end
	if collectgarbage then
		local antes = total
		pcall(collectgarbage, "collect")
		if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
		N.Imprimir(L["Listo: Alfa soltó la memoria que ya no ocupaba."])
		return antes
	end
	return total
end
Pf.Rendimiento = rendimiento
A.RegisterCommand("rendimiento", function() rendimiento() end, L["cuánta memoria usa cada parte de Alfa"])
