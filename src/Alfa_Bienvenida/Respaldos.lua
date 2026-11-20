-- Alfa - Bienvenida: tus respaldos y los errores atrapados (1.2.9).
-- toxic3000 / La Jauría. GPL-3.0.
--
-- Los respaldos los hace el núcleo (Alfa_Nucleo/Respaldos.lua): cada semana
-- y antes de una migración, los últimos 3. Aquí:
--   * tus perfiles van en cada respaldo (N.RespaldoExtra "perfiles"); al
--     restaurar vuelven los que faltan, sin borrar los de ahora;
--   * restaurar pregunta primero y guarda lo de ahora como el perfil
--     «Antes de restaurar»;
--   * si al entrar tus ajustes llegaron vacíos (ALFA_AJUSTES_DANADOS), un
--     aviso ofrece volver al último respaldo;
--   * los errores atrapados (Alfa_Nucleo/Errores.lua) para copiar o borrar.
--
--   Rs.Texto(r) -> "18/11/2026 20:15 · Alfa 1.2.9 · cada semana"
--   Rs.Restaurar(i)        con su pregunta        Rs.Ahora() respalda ya
--   Rs.CopiarErrores()     la ventana para copiar  Rs.BorrarErrores()

local ADDON, M = ...
local N = AlfaNucleo
local A = N.A
local K = N.Kit
local L = M.L

local format = string.format

local Rs = {}
M.Respaldos = Rs

local MOTIVOS = { semanal = "cada semana", migracion = "antes de actualizar", manual = "lo hiciste tú" }

-- Tus perfiles (Perfiles.lua) van en cada respaldo.
local function perfiles()
	local d = N.Datos(M.ID)
	d.perfiles = type(d.perfiles) == "table" and d.perfiles or {}
	return d.perfiles
end
if N.RespaldoExtra then
	N.RespaldoExtra("perfiles", perfiles, function(x)
		local cur = perfiles()
		for nombre, p in pairs(x) do
			if cur[nombre] == nil and type(p) == "table" then cur[nombre] = p end
		end
	end)
end

function Rs.Lista() return N.Respaldos and N.Respaldos() or {} end

function Rs.Texto(r)
	if type(r) ~= "table" then return "" end
	local motivo = MOTIVOS[r.motivo] and L[MOTIVOS[r.motivo]] or tostring(r.motivo or "")
	return format(L["%s · Alfa %s · %s"], tostring(r.cuando or "?"), tostring(r.v or "?"), motivo)
end

function Rs.Ahora()
	if not N.Respaldar then return false end
	local ok, r = N.Respaldar("manual")
	if ok then
		K.Aviso({ titulo = L["Respaldo hecho"], texto = format(L["Tus ajustes quedaron guardados: %s."], Rs.Texto(r)), icono = "ic-exito" })
		if M.alCambiar then M.alCambiar() end
	end
	return ok
end

local function restaurarYa(i)
	-- Lo de ahora, por si acaso.
	if M.Perfiles and M.Perfiles.Guardar then M.Perfiles.Guardar(L["Antes de restaurar"]) end
	local ok, r = N.RestaurarRespaldo(i)
	if ok then
		K.Aviso({ titulo = L["Respaldo restaurado"], texto = format(L["Tus ajustes volvieron a como estaban: %s. Algunas cosas se ven completas al recargar."], Rs.Texto(r)),
			icono = "ic-exito", accion = { texto = L["Recargar ahora"], alClic = function() if ReloadUI then ReloadUI() end end } })
		if M.alCambiar then M.alCambiar() end
	else
		K.Aviso({ titulo = L["No se pudo restaurar"], texto = L["Ese respaldo ya no está."], icono = "ic-aviso", tono = "aviso" })
	end
	return ok
end
Rs.RestaurarYa = restaurarYa

function Rs.Restaurar(i)
	local r = Rs.Lista()[i]
	if not (r and N.RestaurarRespaldo) then return false end
	K.Dialogo({
		titulo = L["¿Restaurar este respaldo?"], icono = "ic-reloj",
		texto = format(L["Tus ajustes vuelven a como estaban: %s. Lo de ahora queda guardado como el perfil «%s»."], Rs.Texto(r), L["Antes de restaurar"]),
		aceptar = L["Restaurar"], alAceptar = function() restaurarYa(i) end,
	})
	return true
end

-- Al entrar, si los ajustes llegaron vacíos: un aviso con «Restaurar».
local function ofrecer(r)
	local lista = Rs.Lista()
	local i
	for j, x in ipairs(lista) do if x == r then i = j end end
	if not i then return end
	-- 1.3.3: importante = "siempre": sale aunque se esté entrando en silencio.
	K.Aviso({ titulo = L["Tus ajustes de Alfa llegaron vacíos"], icono = "ic-alerta", tono = "aviso", duracion = 30, lya = false, importante = "siempre",
		texto = format(L["Puede que el archivo se dañara. Tienes un respaldo del %s."], tostring(r.cuando or "?")),
		accion = { texto = L["Restaurar"], alClic = function() Rs.Restaurar(i) end } })
end
A.On("ALFA_AJUSTES_DANADOS", function(r)
	-- Unos segundos después de entrar, cuando ya salió lo demás.
	if C_Timer and C_Timer.After then
		C_Timer.After(10, function() if N.AjustesDanados() == r then ofrecer(r) end end)
	else
		ofrecer(r)
	end
end)

---------------------------------------------------------------------------
-- Los errores atrapados
---------------------------------------------------------------------------
function Rs.ResumenErrores()
	local l = N.Errores and N.Errores() or {}
	if #l == 0 then return L["Ninguno: todo en orden."] end
	local ult = l[#l]
	return format(L["%d guardados. El último: %s."], #l, tostring(ult and ult.cuando or "?"))
end

function Rs.CopiarErrores()
	local texto = N.ErroresTexto and N.ErroresTexto() or ""
	if texto == "" then
		K.Aviso({ titulo = L["Errores atrapados"], texto = L["Ninguno: todo en orden."], icono = "ic-exito" })
		return false
	end
	local UI = A.UI
	if UI and UI.ShowCopy then
		pcall(UI.ShowCopy, L["Errores atrapados"], texto, { hint = L["Cópialos con Ctrl+C y pégalos en tu reporte. «Reportar» ya los lleva."] })
	end
	return true
end

function Rs.BorrarErrores()
	if N.BorrarErrores then N.BorrarErrores() end
	K.Aviso({ titulo = L["Lista de errores borrada"], icono = "ic-cerrar" })
	if M.alCambiar then M.alCambiar() end
end
