-- Alfa - Comodidades: «Copiar el nombre» en el clic derecho de un jugador (1.4.2).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Para invitar desde otra ventana, buscarlo en la subasta o pasarlo a un
-- amigo, había que escribir el nombre letra por letra (y con los nombres con
-- acento, adivinar). Con «copiarNombre» (de fábrica, sí), el menú del clic
-- derecho de un jugador (su retrato, su nombre en el chat, tu grupo o banda,
-- la lista de un canal o de tu hermandad) trae «Copiar el nombre»: abre el
-- cuadro de copiar de Alfa con el nombre ya seleccionado (Ctrl+C). Nada se
-- envía. Con la vía oficial de los menús (Menu.ModifyMenu); un nombre secreto
-- no se lee y la opción no sale.
--
--   Cn.Nombre(contexto) -> nombre | nil ; Cn.Copiar(nombre) ; Cn.Armar(etiqueta, raiz, contexto)

local ADDON, M = ...
local N, A, L = M.N, M.A, M.L

local Cn = {}
M.CopiarNombre = Cn

local type, pcall, ipairs = type, pcall, ipairs

Cn.MENUS = {
	"MENU_UNIT_PLAYER", "MENU_UNIT_FOCUS", "MENU_UNIT_PARTY", "MENU_UNIT_RAID_PLAYER", "MENU_UNIT_RAID",
	"MENU_UNIT_FRIEND", "MENU_UNIT_CHAT_ROSTER", "MENU_UNIT_COMMUNITIES_WOW_MEMBER",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER", "MENU_UNIT_GUILD",
}

local secreto = N.Secreto
local function texto(v) return type(v) == "string" and not secreto(v) and v ~= "" and v or nil end

function Cn.Nombre(contexto)
	if type(contexto) ~= "table" then return nil end
	local unit = texto(contexto.unit)
	if unit then
		if not N.SiJuego(rawget(_G, "UnitIsPlayer"), unit) then return nil end
		local C = A.Compat
		local fn = C and C.UnitFullName or rawget(_G, "UnitName")
		if type(fn) ~= "function" then return nil end
		local ok, nombre = pcall(fn, unit)
		return ok and texto(nombre) or nil
	end
	local nombre = texto(contexto.name)
	local reino = texto(contexto.server)
	if nombre and reino and not nombre:find("-", 1, true) then nombre = nombre .. "-" .. reino end
	return nombre
end

function Cn.Copiar(nombre)
	nombre = texto(nombre)
	if not nombre then return false end
	if Ambiguate then
		local ok, v = pcall(Ambiguate, nombre, "none")
		if ok and texto(v) then nombre = v end
	end
	local Ch = M.Charla
	if Ch and Ch.MostrarCopia and Ch.MostrarCopia(L["Copiar el nombre"], nombre,
		L["Ya está seleccionado: cópialo con Ctrl+C y pégalo donde quieras con Ctrl+V. Esc para cerrar."]) then
		return true
	end
	N.Imprimir(nombre)
	return false
end

-- Una sola línea antes de lo de Alfa en el menú, aunque varias partes de Alfa
-- agreguen lo suyo (1.4.2): la primera la pone, las demás no.
local function lineaAlfa(raiz)
	local t = rawget(_G, "AlfaMenuLinea")
	if not t then t = setmetatable({}, { __mode = "k" }) AlfaMenuLinea = t end
	if t[raiz] then return end
	t[raiz] = true
	if raiz.CreateDivider then raiz:CreateDivider() end
end

function Cn.Armar(_, raiz, contexto)
	if not M.Get("copiarNombre") then return end
	if type(raiz) ~= "table" or type(raiz.CreateButton) ~= "function" then return end
	local nombre = Cn.Nombre(contexto)
	if not nombre then return end
	lineaAlfa(raiz)
	raiz:CreateButton(L["Copiar el nombre"], function() Cn.Copiar(nombre) end)
end

local enganchado = false
function Cn.Enganchar()
	if enganchado then return end
	if A.GamepadUI and A.GamepadUI() then return end
	local Menu = rawget(_G, "Menu")
	if not (type(Menu) == "table" and type(Menu.ModifyMenu) == "function") then return end
	enganchado = true
	for _, etiqueta in ipairs(Cn.MENUS) do
		Menu.ModifyMenu(etiqueta, function(_, raiz, contexto) pcall(Cn.Armar, etiqueta, raiz, contexto) end)
	end
end

M.AlCambiar({ "copiarNombre" }, function() if M.Get("copiarNombre") then Cn.Enganchar() end end)
