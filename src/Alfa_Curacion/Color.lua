-- Alfa - Curación: el color de los marcos (toxic3000 / La Jauría). GPL-3.0.
--
-- 1.3.8 (pedido de Toxic: «ese color rojo se ve horrible; poder asignar un
-- color, pero por default por clases y la opción de personalizarlo»):
--   * curacion.colorModo: "clase" (de fábrica: el color de la clase, apagado
--     y elegante), "unico" (un solo color que tú eliges con el selector de
--     colores del juego) o "vida" (verde, amarillo y rojo según la vida que le
--     queda; con la vida secreta, una curva de color del juego).
--   * curacion.colorIntensidad: "apagado", "normal" (de fábrica) o "vivo".
--   * curacion.colorUnico: { r, g, b } para «Un solo color».
-- El ajuste viejo curacion.colorClase sigue valiendo: quien lo apagó (barra
-- verde, nombre con su color) ve «Un solo color» con el verde de antes, sin
-- migración; al elegir un modo nuevo se ajusta solo (SETTING_CHANGED).
-- Nada aquí lee la vida ni la clase si llegan secretas: van directo a la
-- barra (C_ClassColor y UnitHealthPercent con su curva).

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local L = M.L
local ID = M.ID
local secreto = M.Secreto

M.AJUSTES.colorModo = "clase"
M.AJUSTES.colorIntensidad = "normal"
M.AJUSTES.colorUnico = { 0.545, 0.878, 0.306 } -- el verde de Alfa (el de antes con «Color de clase» apagado)

local function opt(k) return N.Get(ID, k) end

-- color de la barra = color * k + base. (alfa: con la clase secreta el color no
-- se puede multiplicar: se apaga con la opacidad sobre el hueco oscuro.)
M.INTENSIDADES = {
	apagado = { k = 0.38, base = 0.05, alfa = 0.5 },
	normal = { k = 0.5, base = 0.04, alfa = 0.62 },
	vivo = { k = 0.72, base = 0.03, alfa = 0.85 },
}
M.MODOS_COLOR = { clase = true, unico = true, vida = true }

function M.IntensidadColor()
	local i = opt("colorIntensidad")
	return M.INTENSIDADES[i] and i or "normal"
end

-- -> k, base (para PintarBarra de Marcos.lua)
function M.FactorColor()
	local t = M.INTENSIDADES[M.IntensidadColor()]
	return t.k, t.base
end

function M.ModoColor()
	local m = opt("colorModo")
	if not M.MODOS_COLOR[m or ""] then m = "clase" end
	-- (de antes de la 1.3.8: «Color de clase» apagado era la barra verde)
	if m == "clase" and opt("colorClase") == false then m = "unico" end
	return m
end

local function canal(v, d)
	v = tonumber(v)
	if not v or v ~= v then return d end
	return math.max(0, math.min(1, v))
end

-- -> r, g, b (el que elegiste, sin apagar)
function M.ColorUnico()
	local t = opt("colorUnico")
	local d = M.AJUSTES.colorUnico
	if type(t) ~= "table" then t = d end
	return canal(t[1], d[1]), canal(t[2], d[2]), canal(t[3], d[3])
end

-- Según la vida: rojo abajo, amarillo a la mitad, verde arriba (sin apagar).
M.COLORES_VIDA = {
	{ 0, 0.92, 0.3, 0.24 },
	{ 0.5, 0.95, 0.8, 0.28 },
	{ 1, 0.42, 0.85, 0.36 },
}

-- f: 0..1 -> r, g, b (sin apagar)
function M.ColorSegunVida(f)
	f = canal(f, 1)
	local P = M.COLORES_VIDA
	for i = 2, #P do
		local a, b = P[i - 1], P[i]
		if f <= b[1] then
			local t = (b[1] > a[1]) and (f - a[1]) / (b[1] - a[1]) or 0
			return a[2] + (b[2] - a[2]) * t, a[3] + (b[3] - a[3]) * t, a[4] + (b[4] - a[4]) * t
		end
	end
	local u = P[#P]
	return u[2], u[3], u[4]
end

-- Con la vida secreta: una curva lineal por intensidad (los puntos ya apagados;
-- un color secreto no se multiplica). Se arma al primer uso.
local curvasVida = {}
local function curvaVida(int)
	if curvasVida[int] ~= nil then return curvasVida[int] or nil end
	curvasVida[int] = false
	local CU = rawget(_G, "C_CurveUtil")
	if not (CU and CU.CreateColorCurve and CreateColor) then return nil end
	local ok, c = pcall(CU.CreateColorCurve)
	if not (ok and c) then return nil end
	local t = M.INTENSIDADES[int]
	local e = M.EscalaVida and M.EscalaVida() or 1 -- (1.3.8 revisión: 0–1 o 0–100)
	local bien = pcall(function()
		if c.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Linear then c:SetType(Enum.LuaCurveType.Linear) end
		for _, p in ipairs(M.COLORES_VIDA) do
			c:AddPoint(p[1] * e, CreateColor(p[2] * t.k + t.base, p[3] * t.k + t.base, p[4] * t.k + t.base, 1))
		end
	end)
	if bien then curvasVida[int] = c return c end
	return nil
end
M.CurvaVida = curvaVida
function M.OlvidarCurvasColor() curvasVida = {} end

-- El nombre: blanco sobre el color de clase; en los otros modos, con un toque
-- del color de su clase (para saber quién es quién) sin perder contraste.
local function colorNombre(c, r, g, b)
	if r then
		c.nombre:SetTextColor(r * 0.6 + 0.4, g * 0.6 + 0.4, b * 0.6 + 0.4, 1)
	else
		c.nombre:SetTextColor(0.96, 0.97, 0.98, 1)
	end
end

-- El hueco de la barra con un color secreto (no se multiplica).
local function huecoNeutro(c)
	c.barra.fondo:SetVertexColor(0.05, 0.055, 0.065, 0.85)
end

-- La vida, si se puede leer: -> fracción (0..1) | nil
local function fraccion(u)
	local okV, v = pcall(UnitHealth, u)
	local okM, mx = pcall(UnitHealthMax, u)
	if not (okV and okM) or secreto(v) or secreto(mx) or type(v) ~= "number" or type(mx) ~= "number" or mx <= 0 then
		return nil
	end
	return math.max(0, math.min(1, v / mx))
end
M.FraccionVida = fraccion

-- Color de clase de un compañero de verdad. -> true si pintó
local function porClase(b, okC, clase, r, g, bb)
	local c = b.cuerpo
	if r then
		M.PintarBarra(c, r, g, bb)
		return true
	end
	if okC and secreto(clase) then
		-- Un compañero cuya clase llega secreta: el color va sin leerse.
		local alfa = M.INTENSIDADES[M.IntensidadColor()].alfa
		local bien = pcall(function()
			local col = C_ClassColor.GetClassColor(clase)
			c.barra:SetStatusBarColor(col.r, col.g, col.b, alfa)
			huecoNeutro(c)
		end)
		if bien then return true end
	end
	local v = M.VERDE
	M.PintarBarra(c, v[1], v[2], v[3])
	return false
end

-- Según la vida, un compañero de verdad (también con cada UNIT_HEALTH).
function M.ColorVida(b)
	local c, u = b and b.cuerpo, b and b.unidad
	if not (c and u) or b.alfaEstado or M.ModoColor() ~= "vida" then return end
	local f = fraccion(u)
	if f then
		local r, g, bb = M.ColorSegunVida(f)
		M.PintarBarra(c, r, g, bb)
		return
	end
	local curva = curvaVida(M.IntensidadColor())
	if curva and UnitHealthPercent then
		local ok = pcall(function()
			local col = UnitHealthPercent(u, true, curva)
			local r, g, bb = col:GetRGB()
			c.barra:SetStatusBarColor(r, g, bb, 1)
			huecoNeutro(c)
		end)
		if ok then return end
	end
	-- Sin curva y con la vida secreta: el color de su clase (nunca un rojo fijo).
	local okC, _, clase = pcall(UnitClass, u)
	local r, g, bb
	if okC and not secreto(clase) and type(clase) == "string" then r, g, bb = M.ColorDeClase(clase) end
	porClase(b, okC, clase, r, g, bb)
end

-- Un compañero de verdad, vivo y conectado (desde aspecto() de Marcos.lua).
function M.PintarColor(b)
	local c, u = b.cuerpo, b.unidad
	local okC, _, clase = pcall(UnitClass, u)
	local r, g, bb
	if okC and not secreto(clase) and type(clase) == "string" then r, g, bb = M.ColorDeClase(clase) end
	local modo = M.ModoColor()
	if modo == "unico" then
		M.PintarBarra(c, M.ColorUnico())
		colorNombre(c, r, g, bb)
	elseif modo == "vida" then
		colorNombre(c, r, g, bb)
		M.ColorVida(b)
	else
		porClase(b, okC, clase, r, g, bb)
		c.nombre:SetTextColor(1, 1, 1, 1)
	end
end

-- -> r, g, b de la barra (ya con la intensidad) para una clase y una vida: la
-- vista previa de la página y los marcos de prueba.
function M.ColorPara(clase, vida)
	local modo = M.ModoColor()
	local r, g, b
	if modo == "unico" then
		r, g, b = M.ColorUnico()
	elseif modo == "vida" then
		r, g, b = M.ColorSegunVida(vida or 1)
	else
		r, g, b = M.ColorDeClase(clase or "")
		if not r then local v = M.VERDE r, g, b = v[1], v[2], v[3] end
	end
	local k, base = M.FactorColor()
	return r * k + base, g * k + base, b * k + base
end

-- Un marco de prueba (pintarFalso de Marcos.lua): e = { nombre, clase, vida, ... }
function M.ColorFalso(c, e)
	local r, g, b = M.ColorDeClase(e[2] or "")
	local modo = M.ModoColor()
	if modo == "unico" then
		M.PintarBarra(c, M.ColorUnico())
		colorNombre(c, r, g, b)
	elseif modo == "vida" then
		M.PintarBarra(c, M.ColorSegunVida(tonumber(e[3]) or 1))
		colorNombre(c, r, g, b)
	else
		if r then M.PintarBarra(c, r, g, b) else local v = M.VERDE M.PintarBarra(c, v[1], v[2], v[3]) end
		c.nombre:SetTextColor(1, 1, 1, 1)
	end
end

-- Volver a pintar todos los marcos (al cambiar el color): sin rehacer la
-- cabecera ni tocar atributos (se puede en combate: solo son colores).
function M.RepintarColor()
	for _, b in ipairs(M.botones or {}) do
		if b.unidad and b.cuerpo and M.ActualizarTodo then
			b.alfaPintado = false
			pcall(M.ActualizarTodo, b)
		end
	end
	if M.EnPrueba and M.EnPrueba() and M.RepintarPrueba then M.RepintarPrueba() end
	if M.alRepintarColor then pcall(M.alRepintarColor) end
end

---------------------------------------------------------------------------
-- El selector de colores del juego (fuera de combate: es una ventana del juego)
---------------------------------------------------------------------------
function M.ElegirColor()
	if M.EnCombate() then
		N.Imprimir(L["Se puede al salir de combate."])
		return false
	end
	local CP = rawget(_G, "ColorPickerFrame")
	if type(CP) ~= "table" then return false end
	local r, g, b = M.ColorUnico()
	local antes = { r, g, b }
	local function poner()
		local ok, nr, ng, nb = pcall(CP.GetColorRGB, CP)
		if ok and type(nr) == "number" then N.Set(ID, "colorUnico", { nr, ng, nb }) end
	end
	local function cancelar() N.Set(ID, "colorUnico", antes) end
	-- Elegir un color ya es querer «Un solo color».
	if M.ModoColor() ~= "unico" then N.Set(ID, "colorModo", "unico") end
	if CP.SetupColorPickerAndShow then
		local ok = pcall(CP.SetupColorPickerAndShow, CP, { r = r, g = g, b = b, hasOpacity = false,
			swatchFunc = poner, cancelFunc = cancelar })
		return ok
	end
	-- El selector de antes (sin SetupColorPickerAndShow).
	CP.func, CP.swatchFunc, CP.cancelFunc, CP.hasOpacity, CP.previousValues = poner, poner, cancelar, false, antes
	if CP.SetColorRGB then pcall(CP.SetColorRGB, CP, r, g, b) end
	if CP.Hide then CP:Hide() end
	if ShowUIPanel then pcall(ShowUIPanel, CP) elseif CP.Show then CP:Show() end
	return true
end

-- Un cambio de color: solo se repinta (no se rehace nada). Elegir un modo
-- deja el ajuste viejo («Color de clase») de acuerdo con él.
M.CLAVES_COLOR = { [ID .. ".colorModo"] = true, [ID .. ".colorIntensidad"] = true, [ID .. ".colorUnico"] = true, [ID .. ".colorClase"] = true }
A.On("SETTING_CHANGED", function(path)
	if type(path) ~= "string" or not M.CLAVES_COLOR[path] then return end
	if path == ID .. ".colorModo" then
		local m = opt("colorModo")
		local quiere = (m == nil or m == "clase")
		if (opt("colorClase") ~= false) ~= quiere then N.Set(ID, "colorClase", quiere) end
	end
	M.RepintarColor()
end)
