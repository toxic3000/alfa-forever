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
-- 1.3.1: cada perfil (guardado o en texto) lleva de dónde viene: «_alfa.esquema»
-- (la última migración de los ajustes, N.Esquema) y «_alfa.version». No son
-- ajustes: al ponerlo, sus ajustes se mudan con las migraciones que les faltan
-- (N.MigrarDesde). Uno de antes, sin número, conserva tu modo (sencillo o
-- completo) si no trae el suyo.
-- 1.3.1: al leer el texto, una línea que no sirve (una ruta con un pedazo
-- vacío, un número que no es finito o un valor de otro tipo que el del ajuste,
-- A.GetDefault) se salta y se cuenta como ignorada; lo demás entra.
--
--   Pf.Guardar(nombre) -> ok      Pf.Aplicar(nombre) -> ok      Pf.Borrar(nombre)
--   Pf.Lista() -> { nombre, ... } Pf.Exportar() -> texto        Pf.Importar(texto) -> ok, n, ignoradas | false, por qué
--   Pf.Leer(texto) -> ok, n, plano, ignoradas | false, "vacio" | "formato"
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

-- 1.3.1: lo que dice de dónde viene un perfil (no son ajustes).
local META = "_alfa."
local ESQUEMA, VERSION = META .. "esquema", META .. "version"
local function esMeta(ruta) return type(ruta) == "string" and ruta:sub(1, #META) == META end

-- Tus ajustes de ahora como perfil, con su número de migración y su versión.
local function foto()
	local plano = aplanar(ajustes())
	for ruta in pairs(plano) do if esMeta(ruta) then plano[ruta] = nil end end
	plano[ESQUEMA] = N.Esquema and N.Esquema() or nil
	plano[VERSION] = tostring(N.version or "dev")
	return plano
end
Pf.Foto = foto

function Pf.Lista()
	local out = {}
	for nombre in pairs(guardados()) do out[#out + 1] = nombre end
	sort(out)
	return out
end

function Pf.Guardar(nombre)
	if type(nombre) ~= "string" or nombre == "" then return false end
	guardados()[nombre] = foto()
	return true
end

local function poner(plano)
	local db = A.DB and A.DB()
	if type(db) ~= "table" then return false end
	-- 1.3.1: de dónde viene (sin pasarlo a los ajustes).
	local esquema = tonumber(plano[ESQUEMA])
	local limpio = {}
	for ruta, v in pairs(plano) do if not esMeta(ruta) then limpio[ruta] = v end end
	-- Un perfil de antes de la 1.3.1 (sin número) que no trae tu modo: el de ahora.
	if not esquema and limpio["bienvenida.modo"] == nil then
		local b = type(db.settings) == "table" and db.settings.bienvenida
		local modo = type(b) == "table" and b.modo or nil
		if modo ~= nil then limpio["bienvenida.modo"] = modo end
	end
	db.settings = armar(limpio)
	if esquema and type(N.MigrarDesde) == "function" then pcall(N.MigrarDesde, esquema) end
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
	local plano = foto()
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

-- 1.3.1: lo que se revisa de cada línea.
local function rutaBuena(ruta) return not (ruta:find("^%.") or ruta:find("%.$") or ruta:find("..", 1, true)) end
local function finito(x) return x == x and x ~= math.huge and x ~= -math.huge end
local function tipoBueno(ruta, v)
	if esMeta(ruta) or not A.GetDefault then return true end
	local def = A.GetDefault(ruta)
	return def == nil or type(def) == type(v)
end

-- -> ok, cuántos ajustes, plano, cuántas líneas se ignoraron | false, "vacio" | "formato"
function Pf.Leer(texto)
	if type(texto) ~= "string" or texto == "" then return false, "vacio" end
	texto = texto:gsub("\r", "")
	local plano, n, ignoradas, lineas, primera = {}, 0, 0, 0, true
	for linea in (texto .. "\n"):gmatch("([^\n]*)\n") do
		linea = linea:match("^%s*(.-)%s*$")
		if primera and linea ~= "" then
			if linea ~= CABECERA then return false, "formato" end
			primera = false
		elseif linea ~= "" then
			lineas = lineas + 1
			if lineas > MAX_LINEAS then return false, "formato" end
			local ruta, tipo, valor = linea:match("^([%w_%.]+)=([bns]):(.*)$")
			if not ruta then return false, "formato" end
			local v
			if tipo == "b" then v = valor == "1"
			elseif tipo == "n" then
				v = tonumber(valor)
				if v == nil then return false, "formato" end
			else v = desescapar(valor) end
			if not rutaBuena(ruta) or (tipo == "n" and not finito(v)) or not tipoBueno(ruta, v) then
				ignoradas = ignoradas + 1
			else
				if plano[ruta] == nil and not esMeta(ruta) then n = n + 1 end
				plano[ruta] = v
			end
		end
	end
	if primera then return false, "vacio" end
	return true, n, plano, ignoradas
end

function Pf.Importar(texto)
	local ok, n, plano, ignoradas = Pf.Leer(texto)
	if not ok then return false, n end
	-- 1.3.1: si no quedó nada bueno, no se borra lo de ahora.
	if n == 0 and ignoradas > 0 then return false, "formato" end
	-- Antes de cambiar nada, lo de ahora queda guardado por si acaso.
	guardados()[L["Antes de importar"]] = foto()
	poner(plano)
	return true, n, ignoradas
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
		local ok, n, ignoradas = Pf.Importar(caja:GetText() or "")
		if ok then
			v:Cerrar()
			-- 1.3.1: cuántas líneas no servían y se dejaron fuera.
			local t = (tonumber(ignoradas) or 0) > 0 and format(L["Se pusieron %d ajustes. Las líneas que no eran válidas (%d) se dejaron fuera."], n, ignoradas)
				or format(L["Se pusieron %d ajustes. Algunas cosas se ven completas al recargar."], n)
			K.Aviso({ titulo = L["Ajustes importados"], texto = t,
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
-- /alfa rendimiento: la memoria y el procesador de cada parte de Alfa
---------------------------------------------------------------------------
-- Las partes de Alfa cargadas, por nombre.
local function partesCargadas()
	local CA = C_AddOns
	local out = {}
	local cuantos = CA and CA.GetNumAddOns and CA.GetNumAddOns() or 0
	for i = 1, cuantos do
		local nombre = CA.GetAddOnInfo(i)
		if type(nombre) == "string" and nombre:find("^Alfa") and CA.IsAddOnLoaded(nombre) then out[#out + 1] = nombre end
	end
	return out
end

-- El procesador (1.2.9): el perfilador del juego (C_AddOnProfiler, siempre
-- encendido en los clientes nuevos) o, si no, el de scriptProfile.
-- -> "perfilador" | "script" | nil, { { nombre, ms } }, total
local function procesador(nombres)
	local P = C_AddOnProfiler
	local metrica = Enum and Enum.AddOnProfilerMetric and Enum.AddOnProfilerMetric.RecentAverageTime
	if P and P.GetAddOnMetric and metrica ~= nil then
		local ok, on = pcall(function() return not P.IsEnabled or P.IsEnabled() end)
		if ok and on then
			local lista, total = {}, 0
			for _, n in ipairs(nombres) do
				local ok2, ms = pcall(P.GetAddOnMetric, n, metrica)
				ms = ok2 and tonumber(ms) or 0
				total = total + ms
				lista[#lista + 1] = { n, ms }
			end
			sort(lista, function(a, b) return a[2] > b[2] end)
			return "perfilador", lista, total
		end
	end
	local perfil = GetCVar and GetCVar("scriptProfile")
	if (perfil == "1" or perfil == 1) and GetAddOnCPUUsage then
		if UpdateAddOnCPUUsage then pcall(UpdateAddOnCPUUsage) end
		local lista, total = {}, 0
		for _, n in ipairs(nombres) do
			local ok, ms = pcall(GetAddOnCPUUsage, n)
			ms = ok and tonumber(ms) or 0
			total = total + ms
			lista[#lista + 1] = { n, ms }
		end
		sort(lista, function(a, b) return a[2] > b[2] end)
		return "script", lista, total
	end
	return nil, {}, 0
end
Pf.Procesador = procesador

-- 1.3.5: lo que Alfa deja de basura (memoria nueva) por segundo, por parte,
-- medido durante MIDE_SEG segundos justo después de soltar la memoria. Si algo
-- se pasa (BASURA_MUCHA en total o CPU_MUCHO ms por cuadro en una parte), Lya
-- te lo dice y te sugiere el modo ligero.
local MIDE_SEG, BASURA_MUCHA, CPU_MUCHO = 10, 40, 1.5
local function memorias(nombres)
	local out = {}
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
	for _, n in ipairs(nombres) do
		local ok, kb = pcall(GetAddOnMemoryUsage, n)
		out[n] = ok and tonumber(kb) or 0
	end
	return out
end

function Pf.Pasado(basura, cpu)
	local peor
	for _, x in ipairs(cpu or {}) do
		if x[2] > CPU_MUCHO then peor = format(L["%s usa %.1f ms por cuadro"], x[1], x[2]) break end
	end
	if not peor and basura and basura.total > BASURA_MUCHA and basura.lista[1] then
		peor = format(L["%s junta %.0f KB de memoria por segundo"], basura.lista[1][1], basura.lista[1][2])
	end
	return peor
end

function Pf.MedirBasura(nombres, cpu, alTerminar)
	if not (GetAddOnMemoryUsage and N.Una) then return false end
	local antes = memorias(nombres)
	N.Una("bienvenida.basura", MIDE_SEG, function()
		local despues = memorias(nombres)
		local lista, total = {}, 0
		for n, kb in pairs(despues) do
			local d = math.max(0, (kb - (antes[n] or kb)) / MIDE_SEG)
			total = total + d
			lista[#lista + 1] = { n, d }
		end
		sort(lista, function(a, b) return a[2] > b[2] end)
		local basura = { total = total, lista = lista }
		N.Imprimir(format(L["En %d segundos, Alfa fue juntando %.1f KB de memoria por segundo. Lo que más junta:"], MIDE_SEG, total))
		for i = 1, math.min(3, #lista) do
			DEFAULT_CHAT_FRAME:AddMessage(format("  %s: %.1f KB/s", lista[i][1], lista[i][2]))
		end
		local peor = Pf.Pasado(basura, cpu)
		if peor and K.Aviso then
			K.Aviso({ titulo = L["Alfa está trabajando de más"], icono = "ic-aviso",
				texto = format(L["%s. Si notas el juego lento, prueba el «Modo ligero» en Ajustes > Estilo y sonido."], peor) })
		end
		if alTerminar then alTerminar(basura, peor) end
	end)
	return true
end

local function rendimiento()
	-- 1.3.5: cuánto tardó Alfa al entrar (el motor lo mide: Core/Init.lua).
	local rc = A.loadClock
	if type(rc) == "table" and rc.start and rc.last then
		N.Imprimir(format(L["Al entrar, Alfa tardó %.0f ms en cargar sus archivos y %.0f ms en arrancar."], rc.last - rc.start, rc.login or 0))
	end
	if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
	local nombres = partesCargadas()
	local total, lista = 0, {}
	for _, nombre in ipairs(nombres) do
		if GetAddOnMemoryUsage then
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
	-- 1.2.9: el procesador.
	local como, cpu, cpuTotal = procesador(nombres)
	local info = { memoria = total, como = como, cpu = cpu, cpuTotal = cpuTotal }
	if como == "perfilador" then
		N.Imprimir(format(L["Procesador: Alfa usa %.2f ms por cuadro ahora. Lo que más usa:"], cpuTotal))
	elseif como == "script" then
		N.Imprimir(format(L["Procesador: Alfa usó %.0f ms desde que entraste o recargaste. Lo que más usa:"], cpuTotal))
	else
		N.Imprimir(L["Para ver cuánto procesador usa cada parte, escribe /console scriptProfile 1 y luego /reload. Hace el juego un poco más lento: cuando termines, /console scriptProfile 0 y /reload."])
	end
	if como then
		for i = 1, math.min(4, #cpu) do
			DEFAULT_CHAT_FRAME:AddMessage(format(como == "perfilador" and "  %s: %.2f ms" or "  %s: %.0f ms", cpu[i][1], cpu[i][2]))
		end
	end
	-- 1.2.9: las tareas del reloj de Alfa (Alfa_Nucleo/Reloj.lua).
	local tareas = N.Tareas and N.Tareas() or {}
	info.tareas = #tareas
	if #tareas > 0 then
		local t = tareas[1]
		N.Imprimir(format(L["El reloj de Alfa mueve %d tareas. La que más tarda: %s (%.1f ms en %d veces)."], #tareas, t.clave, t.ms, t.veces))
	end
	if collectgarbage then
		local antes = total
		pcall(collectgarbage, "collect")
		if UpdateAddOnMemoryUsage then pcall(UpdateAddOnMemoryUsage) end
		N.Imprimir(L["Listo: Alfa soltó la memoria que ya no ocupaba."])
		-- 1.3.5: y ahora mide la basura de los próximos segundos.
		if Pf.MedirBasura(nombres, como == "perfilador" and cpu or nil) then
			N.Imprimir(format(L["Midiendo cuánta memoria va juntando Alfa durante %d segundos..."], MIDE_SEG))
		end
		return antes, info
	end
	return total, info
end
Pf.Rendimiento = rendimiento
A.RegisterCommand("rendimiento", function() rendimiento() end, L["cuánta memoria y procesador usa cada parte de Alfa"])
