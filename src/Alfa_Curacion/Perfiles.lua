-- Alfa - Curación: tus mapas de clics guardados (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Hasta seis mapas de clics por personaje (uno por especialización, o los que
-- quieras): «Guardar este» copia tus clics de ahora; un clic en uno lo usa.
-- Cada mapa recuerda la rama de talentos con la que se guardó (A.Gear.GetSpec
-- del motor): con curacion.mapaPorRama (de fábrica, sí), al cambiar tus
-- talentos a esa rama, Alfa pone su mapa solo y te lo dice. Todo cambio de
-- clics se aplica fuera de combate (M.AplicarMapa ya espera).
-- Datos por personaje (M.Datos()): mapas = { { id, nombre, rama, mapa, preajuste, izqSel, t } }, mapaActivo.
--   M.MapasGuardados() ; M.GuardarMapa(nombre) -> id ; M.UsarMapa(id, porRama) ; M.BorrarMapa(id)
--   M.ActualizarMapa(id) ; M.RamaActual() -> clave, nombre ; M.BloqueMapas(padre) (para la página)

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L
local ID = M.ID

local type, ipairs, pairs, tostring, format, floor, max = type, ipairs, pairs, tostring, string.format, math.floor, math.max
local ESP = K.ESP

M.MAX_MAPAS = 6

local function copiar(t)
	if type(t) ~= "table" then return t end
	local o = {}
	for k, v in pairs(t) do o[k] = copiar(v) end
	return o
end

function M.MapasGuardados()
	local d = M.Datos()
	if type(d.mapas) ~= "table" then d.mapas = {} end
	return d.mapas
end

local function buscar(id)
	for i, x in ipairs(M.MapasGuardados()) do if type(x) == "table" and x.id == id then return x, i end end
	return nil
end
M.MapaGuardado = buscar

-- La rama de talentos de ahora (la del motor, por tus puntos) -> clave, nombre | nil
function M.RamaActual()
	local G = A.Gear
	if type(G) ~= "table" or type(G.GetSpec) ~= "function" then return nil end
	local ok, k, nombre, fuente = pcall(G.GetSpec)
	if not ok or type(k) ~= "string" or fuente == "default" then return nil end
	if type(nombre) ~= "string" or nombre == "" then nombre = nil end
	if nombre then nombre = nombre:gsub("%s*%b()", "") end
	return k, nombre
end

-- -> id del mapa guardado (o nil si ya hay seis)
function M.GuardarMapa(nombre)
	local lista = M.MapasGuardados()
	local d = M.Datos()
	local rama, nombreRama = M.RamaActual()
	-- Ya hay uno de esta rama: se le pone tu mapa de ahora (aunque ya tengas
	-- seis: no es uno más; 1.3.9, revisión 9).
	if rama and not nombre then
		for _, x in ipairs(lista) do
			if x.rama == rama then M.ActualizarMapa(x.id) return x.id end
		end
	end
	if #lista >= M.MAX_MAPAS then return nil, "lleno" end
	d.mapasSig = (tonumber(d.mapasSig) or 0) + 1
	local id = "m" .. d.mapasSig
	if type(nombre) ~= "string" or nombre == "" then nombre = nombreRama or format(L["Mapa %d"], #lista + 1) end
	lista[#lista + 1] = { id = id, nombre = nombre, rama = rama, mapa = copiar(M.Mapa()), preajuste = d.preajuste,
		izqSel = d.izqSel == true or nil, t = time() }
	d.mapaActivo = id
	M.Avisar()
	return id
end

function M.ActualizarMapa(id)
	local x = buscar(id)
	if not x then return false end
	local d = M.Datos()
	x.mapa, x.preajuste, x.izqSel, x.t = copiar(M.Mapa()), d.preajuste, d.izqSel == true or nil, time()
	d.mapaActivo = id
	M.Avisar()
	return true
end

function M.UsarMapa(id, porRama)
	local x = buscar(id)
	if not (x and type(x.mapa) == "table") then return false end
	local d = M.Datos()
	d.mapa = copiar(x.mapa)
	d.preajuste = x.preajuste or d.preajuste
	d.izqSel = x.izqSel == true
	d.rechazos = {}
	d.mapaActivo = id
	M.AplicarMapa()
	if K.Aviso then
		K.Aviso({ id = "curacion.mapa", icono = "ic-curacion", tono = "acento", duracion = 5,
			titulo = format(L["Tus clics: %s"], x.nombre or "?"),
			texto = porRama and L["Cambiaste de talentos: puse el mapa de clics que guardaste para ellos."]
				or (M.EnCombate() and L["Tus clics de Curación se aplican al salir de combate."] or L["Listo: tus marcos ya curan con estos clics."]) })
	end
	return true
end

function M.BorrarMapa(id)
	local _, i = buscar(id)
	if not i then return false end
	table.remove(M.MapasGuardados(), i)
	local d = M.Datos()
	if d.mapaActivo == id then d.mapaActivo = nil end
	M.Avisar()
	return true
end

function M.RenombrarMapa(id, nombre)
	local x = buscar(id)
	if not x or type(nombre) ~= "string" then return false end
	nombre = nombre:gsub("^%s+", ""):gsub("%s+$", "")
	if nombre == "" then return false end
	x.nombre = nombre:sub(1, 40)
	M.Avisar()
	return true
end

-- ¿Tus clics de ahora son los del mapa guardado activo? (cambiaste algo a mano)
function M.MapaActivo()
	local d = M.Datos()
	local x = d.mapaActivo and buscar(d.mapaActivo)
	return x
end

---------------------------------------------------------------------------
-- Al cambiar tus talentos: el mapa de esa rama (si guardaste uno)
---------------------------------------------------------------------------
local ultimaRama
function M.RevisarRama()
	if N.Get(ID, "mapaPorRama") == false then return false end
	local rama = M.RamaActual()
	if not rama then return false end
	if ultimaRama == nil then ultimaRama = rama return false end -- la primera lectura solo anota
	if rama == ultimaRama then return false end
	ultimaRama = rama
	local d = M.Datos()
	for _, x in ipairs(M.MapasGuardados()) do
		if x.rama == rama and x.id ~= d.mapaActivo then return M.UsarMapa(x.id, true) end
	end
	return false
end
function M.OlvidarRama() ultimaRama = nil end

local function revisar() N.Una("curacion.rama", 2, M.RevisarRama, { fueraDeCombate = true }) end
for _, ev in ipairs({ "CHARACTER_POINTS_CHANGED", "PLAYER_TALENT_UPDATE", "ACTIVE_TALENT_GROUP_CHANGED", "PLAYER_ENTERING_WORLD" }) do
	pcall(A.RegisterEvent, ev, revisar)
end

---------------------------------------------------------------------------
-- El bloque de la página: «Tus mapas de clics»
---------------------------------------------------------------------------
function M.BloqueMapas(padre)
	local b = CreateFrame("Frame", nil, padre)
	b.Seccion = K.Seccion(b, L["Tus mapas de clics"])
	b.Panel = CreateFrame("Frame", nil, b)
	b.Panel.caja = K.Caja(b.Panel, { fondo = "panel", borde = "linea", corte = K.CORTE.panel })
	b.Texto = K.Texto(b.Panel, "nota", "textoSuave")
	b.botones = {}
	b.Guardar = K.Boton(b.Panel, L["Guardar mis clics de ahora"], function()
		local id, motivo = M.GuardarMapa()
		if not id and motivo == "lleno" then
			N.Imprimir(format(L["Ya tienes %d mapas guardados: borra uno para guardar otro."], M.MAX_MAPAS))
		end
	end, { tipo = "secundario", tam = "chico", icono = "ic-mas" })
	local function menu(boton, x)
		local ops = {
			{ valor = "usar", texto = L["Usar este mapa"], icono = "ic-seguir" },
			{ valor = "actualizar", texto = L["Guardar aquí mis clics de ahora"], icono = "ic-exito" },
			{ separador = true },
			{ valor = "borrar", texto = L["Borrar"], icono = "ic-cerrar" },
		}
		K.Menu(boton, ops, nil, function(v)
			if v == "usar" then M.UsarMapa(x.id)
			elseif v == "actualizar" then M.ActualizarMapa(x.id)
			elseif v == "borrar" then
				K.Dialogo({ titulo = format(L["¿Borrar «%s»?"], x.nombre or "?"), peligro = true,
					texto = L["Tus clics de ahora se quedan como están; solo se borra este mapa guardado."],
					aceptar = L["Borrar"], alAceptar = function() M.BorrarMapa(x.id) end })
			end
		end)
	end
	function b:Llenar()
		local lista = M.MapasGuardados()
		local activo = M.Datos().mapaActivo
		for i, x in ipairs(lista) do
			local bt = self.botones[i] or K.Boton(self.Panel, "", nil, { tipo = "secundario", tam = "chico" })
			self.botones[i] = bt
			bt:SetTexto(x.nombre or "?")
			bt:SetTipo(x.id == activo and "primario" or "secundario")
			bt:SetIcono(x.id == activo and "ic-exito" or "ic-curacion")
			local este = x
			-- Un clic usa ese mapa; en el que ya usas, sus opciones.
			bt.alClic = function(self2) if este.id == M.Datos().mapaActivo then menu(self2, este) else M.UsarMapa(este.id) end end
			K.ConInfo(bt, x.nombre, x.id == activo and L["El que usas ahora. Clic: guardar aquí tus clics, o borrarlo."]
				or L["Clic: usar estos clics."])
			bt:Show()
		end
		for i = #lista + 1, #self.botones do self.botones[i]:Hide() end
		self.Guardar:SetActivo(#lista < M.MAX_MAPAS)
		local rama, nombre = M.RamaActual()
		local t
		if #lista == 0 then
			t = L["Guarda tus clics para cada especialización (o para sanar y para pelear) y cambia entre ellos con un clic."]
		else
			t = L["Un clic en uno lo usa."]
			if N.Get(ID, "mapaPorRama") ~= false then t = t .. " " .. L["Al cambiar de talentos, Alfa pone solo el mapa que guardaste para ellos."] end
		end
		if rama and nombre then t = t .. " " .. format(L["Tus talentos ahora: %s."], nombre) end
		K.Escribir(self.Texto, t)
	end
	function b:Acomodar(ancho)
		self.Seccion:ClearAllPoints()
		self.Seccion:SetPoint("TOPLEFT", self, "TOPLEFT", 0, 0)
		self.Seccion:SetWidth(ancho)
		local top = self.Seccion:Acomodar(ancho) + ESP.s
		local pad = ESP.base
		local dentro = ancho - 2 * pad
		local y = pad
		self.Texto:ClearAllPoints()
		self.Texto:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad, -y)
		y = y + K.Parrafo(self.Texto, dentro, 3) + ESP.s
		local x = 0
		local lista = {}
		for _, bt in ipairs(self.botones) do if bt:IsShown() then lista[#lista + 1] = bt end end
		lista[#lista + 1] = self.Guardar
		for _, bt in ipairs(lista) do
			local w = bt:AnchoNatural()
			if x > 0 and x + w > dentro then x, y = 0, y + K.ALTO.botonChico + ESP.s end
			bt:ClearAllPoints()
			bt:SetPoint("TOPLEFT", self.Panel, "TOPLEFT", pad + x, -y)
			x = x + w + ESP.s
		end
		y = y + K.ALTO.botonChico + pad
		self.Panel:ClearAllPoints()
		self.Panel:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -top)
		self.Panel:SetSize(ancho, y)
		self:SetSize(ancho, top + y)
		return top + y
	end
	return b
end
