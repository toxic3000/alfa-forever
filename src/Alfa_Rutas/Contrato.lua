-- Alfa - Rutas: lo que esta área ofrece a las demás (toxic3000 / La Jauría).
-- GPL-3.0.
--
-- AlfaRuta (global), el contrato de docs/PLAN-1.0.md:
--   AlfaRuta.Asistente(camino)       "¿Qué quieres hacer?"; camino: "nivel" | "profesiones" | "oro" | "mazmorras" | "planes" | nil
--   AlfaRuta.Liberar(filtro)         arma y abre el plan para cerrar tus misiones (filtro: "todas" | "listas" | "zona"; sin él, el que eligió el jugador)
--   AlfaRuta.Recoger()               toma las mejores misiones de cerca
--   AlfaRuta.AgregarObjeto(itemID)   un tramo para conseguir ese objeto en tu ruta (la Enciclopedia: "Agregar a mi ruta")
-- y además:
--   AlfaRuta.Entregar()              solo las listas para entregar (= Liberar("listas"))
--   AlfaRuta.AgregarMision(questID)  a tu plan de misiones (con lo que pide antes) -> ok, por qué
--   AlfaRuta.QuitarMision(questID)   fuera de tu plan
--   AlfaRuta.EnPlan(questID) -> bool
--   AlfaRuta.Desbloquear(questID)    guía con lo que pide una misión que aún no puedes tomar
--   AlfaRuta.Disponible(questID) -> ok, texto   si ya se puede tomar y, si no, qué falta ("Disponible a nivel 20")
--   AlfaRuta.EsDeMiRuta(questID, verbo) -> bool  si una guía abierta la toma ("accept") o la entrega ("turnin")
--       en algún paso de aquí en adelante, o si está en tu plan de misiones (Comodidades lo consulta
--       con ruta.soloRuta encendido)
--   AlfaRuta.EnRuta(questID, verbo)  lo mismo (el nombre que usa Comodidades)
--   AlfaRuta.SoloRuta() -> bool      el ajuste ruta.soloRuta
--   AlfaRuta.Listas() -> n           misiones listas para entregar (al momento)
--   AlfaRuta.Biblioteca()            la biblioteca de guías
--   AlfaRuta.MostrarGuia()           muestra el rastreador
--   AlfaRuta.RastreadorVisible() -> bool  si el rastreador está a la vista (Hoy no repite "Mientras estás aquí")
--   AlfaRuta.Pagina()                la página Ruta
-- Buscar cerca (AlfaCerca, Cerca.lua) y Mis planes (AlfaPlanes, Planes.lua)
-- tienen su propio global.
-- Las misiones también se agregan y se quitan del plan desde el menú del
-- registro de misiones del juego (clic derecho en una misión) y del
-- seguimiento de objetivos.

local ADDON, M = ...
local A, L, N = M.A, M.L, M.N
local Cr = M.Cerrar

local type, tonumber, ipairs = type, tonumber, ipairs

local R = AlfaRuta or {}
AlfaRuta = R

function R.Asistente(camino) M.Asistente.Abrir(camino) end
function R.Liberar(filtro) Cr.Ahora(filtro) end
function R.Entregar() Cr.Ahora("listas") end
function R.Recoger() M.Recoger.Ahora() end
function R.AgregarObjeto(itemID) return M.AgregarObjeto(itemID) end

function R.AgregarMision(qid)
	local ok, por = Cr.Agregar(qid)
	if ok then
		M.Aviso(L["Agregada a tu plan de misiones"], M.TituloMision(qid), {
			icono = "ic-misiones", accion = { texto = L["Armar mi plan"], alClic = function() Cr.Ahora() end } })
	else
		M.Aviso(L["No la agregué"], por, { icono = "ic-aviso", tono = "aviso" })
	end
	return ok, por
end

function R.QuitarMision(qid)
	local ok = Cr.Quitar(qid)
	if ok then M.Aviso(L["Fuera de tu plan de misiones"], M.TituloMision(qid), { icono = "ic-misiones" }) end
	return ok
end

function R.EnPlan(qid) return Cr.EnPlan(qid) end
function R.Desbloquear(qid) M.Recoger.Desbloquear(qid) end

function R.Disponible(qid)
	local ok, motivo, info = M.Disp.Estado(qid)
	if ok then return true, nil end
	return false, M.Disp.Texto(motivo, info)
end

function R.EsDeMiRuta(qid, verbo)
	qid = tonumber(qid)
	if not qid then return false end
	local E = A.Engine
	if E and E.WantsQuest then
		local verbos = verbo and { verbo } or { "accept", "turnin" }
		for _, v in ipairs(verbos) do
			local ok, si = pcall(E.WantsQuest, v, qid, 9999)
			if ok and si then return true end
		end
	end
	return Cr.EnPlan(qid)
end
-- El nombre con que la busca Comodidades (área H).
function R.EnRuta(qid, verbo) return R.EsDeMiRuta(qid, verbo) end

function R.SoloRuta() return A.Get("ruta.soloRuta") ~= false end
function R.Listas() return Cr.ListasAhora() end
function R.Biblioteca() M.Biblioteca.Abrir() end
function R.MostrarGuia() M.Empezar() end
function R.RastreadorVisible() return M.Rastreador.Visible() and true or false end
function R.Pagina() N.Abrir(M.ID) end

---------------------------------------------------------------------------
-- El menú del registro de misiones y del seguimiento de objetivos
---------------------------------------------------------------------------

local function mision(v)
	local C = M.Motor("Compat")
	if C and C.Readable then v = C.Readable(v) end
	if type(v) == "number" and v > 0 and v < math.huge and v % 1 == 0 then return v end
	return nil
end

-- El seguimiento de objetivos no dice de qué misión es su menú: la del
-- bloque bajo el ratón.
local function misionDelSeguimiento()
	if not GetMouseFoci then return nil end
	for _, foco in ipairs(GetMouseFoci() or {}) do
		local f = foco
		while f do
			if f.IsForbidden and f:IsForbidden() then break end
			local mod = f.parentModule
			if mod and (mod == QuestObjectiveTracker or mod == CampaignQuestObjectiveTracker) then
				local id = mision(f.id)
				if id and mod.GetExistingBlock and mod:GetExistingBlock(id) == f then return id end
			end
			f = f.GetParent and f:GetParent()
		end
	end
	return nil
end

local function agregarAlMenu(root, qid)
	if not qid or (A.Hidden and A.Hidden()) then return end
	root:CreateDivider()
	if Cr.EnPlan(qid) then
		root:CreateButton(L["Alfa: quitar de mi plan de misiones"], function() R.QuitarMision(qid) end)
	else
		root:CreateButton(L["Alfa: agregar a mi plan de misiones"], function() R.AgregarMision(qid) end)
	end
	root:CreateButton(L["Alfa: cerrar mis misiones"], function() Cr.Ahora() end)
end

A.OnLogin(function()
	if (A.GamepadUI and A.GamepadUI()) or not (Menu and Menu.ModifyMenu) then return end
	Menu.ModifyMenu("MENU_QUEST_MAP_LOG_TITLE", function(owner, root)
		agregarAlMenu(root, mision(owner and owner.questID))
	end)
	Menu.ModifyMenu("MENU_QUEST_OBJECTIVE_TRACKER", function(_, root)
		agregarAlMenu(root, misionDelSeguimiento())
	end)
end)
