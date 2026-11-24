-- Alfa - Títulos de pasos de guía en tu idioma (1.3.9). toxic3000 / La Jauría. GPL-3.0.
--
-- Pedido de Toxic (mejora 42): en Hoy salía «Into Vallefresno». Las guías
-- traen la traducción de cada texto por guía (Core/GuideTexts.lua); cuando
-- una guía no tiene la de un título, salía el inglés con el nombre del lugar
-- ya traducido. Aquí van las formas que más se repiten en los títulos de los
-- pasos («Into X», «Back to X», «X: kill these as you meet them»...), con
-- sus huecos ({zone:1440}, {npc:3145}) intactos: GuideTexts los llena después
-- con el nombre del juego en tu idioma.
--   ns.TituloDeGuia(ingles, idioma) -> texto en tu idioma | nil
-- Solo frases cortas y completas (anclas ^...$): una nota larga no cambia.

local _, ns = ...

local type, ipairs = type, ipairs
local match, gsub = string.match, string.gsub

-- Cada forma: { patrón del inglés, { [idioma] = traducción con %1 } }.
-- «%1» es lo que el patrón captura (un lugar o una persona, con su hueco).
local FORMAS = {
	{ "^(.+): kill these as you meet them$", {
		es = "%1: derrótalos en el camino", de = "%1: unterwegs besiegen", fr = "%1 : à vaincre en chemin",
		pt = "%1: derrote pelo caminho", ru = "%1: побеждайте по пути", ko = "%1: 가는 길에 처치",
		zhCN = "%1：沿途击败", zhTW = "%1：沿途擊敗" } },
	{ "^(.+): hand in again$", {
		es = "%1: entrega otra vez", de = "%1: erneut abgeben", fr = "%1 : rendre à nouveau",
		pt = "%1: entregue de novo", ru = "%1: снова сдать задания", ko = "%1: 다시 완료하기",
		zhCN = "%1：再次交任务", zhTW = "%1：再次交任務" } },
	{ "^(.+): hand in$", {
		es = "%1: entrega", de = "%1: abgeben", fr = "%1 : rendre les quêtes",
		pt = "%1: entregue", ru = "%1: сдать задания", ko = "%1: 완료하기",
		zhCN = "%1：交任务", zhTW = "%1：交任務" } },
	{ "^(.+): first hand%-in$", {
		es = "%1: primera entrega", de = "%1: erste Abgabe", fr = "%1 : premier rendu",
		pt = "%1: primeira entrega", ru = "%1: первая сдача", ko = "%1: 첫 완료",
		zhCN = "%1：首次交任务", zhTW = "%1：首次交任務" } },
	{ "^Into the (.+)$", "into" },
	{ "^Into (.+)$", {
		es = "Hacia %1", de = "Auf nach %1", fr = "En route vers %1",
		pt = "Rumo a %1", ru = "В путь: %1", ko = "%1(으)로",
		zhCN = "前往%1", zhTW = "前往%1" } },
	{ "^Back to the (.+)$", "back" },
	{ "^Back to (.+)$", {
		es = "De vuelta: %1", de = "Zurück: %1", fr = "Retour : %1",
		pt = "De volta: %1", ru = "Обратно: %1", ko = "돌아가기: %1",
		zhCN = "返回：%1", zhTW = "返回：%1" } },
	{ "^Back at the (.+)$", "at" },
	{ "^Back at (.+)$", "at" },
	{ "^Back in (.+)$", {
		es = "De vuelta en %1", de = "Zurück in %1", fr = "De retour : %1",
		pt = "De volta em %1", ru = "Снова здесь: %1", ko = "다시 %1",
		zhCN = "回到%1", zhTW = "回到%1" } },
	{ "^Fly to the (.+)$", "fly" },
	{ "^Fly to (.+)$", {
		es = "Vuela a %1", de = "Flug nach %1", fr = "Vol vers %1",
		pt = "Voe para %1", ru = "Полёт: %1", ko = "비행: %1",
		zhCN = "飞往%1", zhTW = "飛往%1" } },
	{ "^Boat to the (.+)$", "boat" },
	{ "^Boat to (.+)$", {
		es = "Barco a %1", de = "Schiff nach %1", fr = "Bateau pour %1",
		pt = "Barco para %1", ru = "Корабль: %1", ko = "배편: %1",
		zhCN = "乘船前往%1", zhTW = "搭船前往%1" } },
	{ "^To the (.+)$", "to" },
	{ "^To (.+)$", {
		es = "Rumbo a %1", de = "Nach %1", fr = "Vers %1",
		pt = "Rumo a %1", ru = "Путь: %1", ko = "이동: %1",
		zhCN = "前往%1", zhTW = "前往%1" } },
	{ "^Around the (.+)$", "around" },
	{ "^Around (.+)$", {
		es = "Por %1", de = "Rund um %1", fr = "Autour de %1",
		pt = "Arredores: %1", ru = "Окрестности: %1", ko = "%1 주변",
		zhCN = "%1周边", zhTW = "%1周邊" } },
	{ "^On the way$", {
		es = "En el camino", de = "Unterwegs", fr = "En chemin",
		pt = "No caminho", ru = "По пути", ko = "가는 길에", zhCN = "沿途", zhTW = "沿途" } },
	{ "^The way back$", {
		es = "El camino de vuelta", de = "Der Rückweg", fr = "Le chemin du retour",
		pt = "O caminho de volta", ru = "Обратный путь", ko = "돌아가는 길", zhCN = "回程", zhTW = "回程" } },
	{ "^Before you start$", {
		es = "Antes de empezar", de = "Bevor du anfängst", fr = "Avant de commencer",
		pt = "Antes de começar", ru = "Перед началом", ko = "시작하기 전에", zhCN = "开始之前", zhTW = "開始之前" } },
}

-- Las formas con «the» usan la traducción de la que no lo lleva.
local POR_NOMBRE = { into = "^Into (.+)$", back = "^Back to (.+)$", at = "^Back in (.+)$", fly = "^Fly to (.+)$",
	boat = "^Boat to (.+)$", to = "^To (.+)$", around = "^Around (.+)$" }
local porPatron = {}
for _, f in ipairs(FORMAS) do porPatron[f[1]] = f end
for _, f in ipairs(FORMAS) do
	if type(f[2]) == "string" then f[2] = porPatron[POR_NOMBRE[f[2]]][2] end
end
ns.FORMAS_TITULO = FORMAS

local IDIOMA = { esMX = "es", esES = "es", deDE = "de", frFR = "fr", ptBR = "pt", ruRU = "ru", koKR = "ko", zhCN = "zhCN", zhTW = "zhTW" }

-- El título de un paso que su guía no traduce, por su forma; nil si no tiene una de estas.
function ns.TituloDeGuia(en, idioma)
	local clave = IDIOMA[idioma or ""]
	if not clave or type(en) ~= "string" or en == "" or #en > 90 or en:find("\n", 1, true) then return nil end
	for _, f in ipairs(FORMAS) do
		local x = match(en, f[1])
		if x then
			local t = f[2][clave]
			if not t then return nil end
			if f[1]:find("(.+)", 1, true) then return (gsub(t, "%%1", (gsub(x, "%%", "%%%%")))) end
			return t
		end
	end
	return nil
end
