-- Alfa - Combate: habilidades de reacción por clase (toxic3000 / La Jauría). GPL-3.0.
--
-- Una habilidad de reacción se vuelve usable por algo que pasó (el enemigo
-- esquivó, tú bloqueaste, al enemigo le queda poca vida...). Alfa la vigila
-- con datos de tu personaje: C_Spell.IsSpellUsable, su recarga y el brillo
-- oficial del hechizo. ids: todos sus rangos, de menor a mayor (vale el que
-- conozcas). texto: el aviso; porque: la línea de debajo.

local ADDON, M = ...
local L = M.L

M.REACCIONES = {
	WARRIOR = {
		{ clave = "abrumar", ids = { 7384, 7887, 11584, 11585 }, texto = L["¡Abrumar!"],
			porque = L["Tu objetivo esquivó: Abrumar no se puede esquivar y pega fuerte. Necesita actitud de batalla."] },
		{ clave = "revancha", ids = { 6572, 6574, 7379, 11600, 11601, 25288 }, texto = L["¡Revancha!"],
			porque = L["Bloqueaste, esquivaste o paraste: Revancha es barata y genera mucha amenaza. Necesita actitud defensiva."] },
		{ clave = "ejecutar", ids = { 5308, 20658, 20660, 20661, 20662 }, texto = L["¡Ejecutar!"],
			porque = L["Al objetivo le queda poca vida: Ejecutar lo remata usando tu ira."] },
		{ clave = "victorioso", ids = { 402927 }, texto = L["¡Ataque de la victoria!"],
			porque = L["Acabas de vencer a un enemigo: este ataque es gratis y te cura."] },
	},
	ROGUE = {
		{ clave = "contraataque", ids = { 14251 }, texto = L["¡Contraataque!"],
			porque = L["Paraste un golpe: tu contraataque está listo y desarma al enemigo."] },
	},
	HUNTER = {
		{ clave = "mangosta", ids = { 1495, 14269, 14270, 14271 }, texto = L["¡Mordedura de mangosta!"],
			porque = L["El enemigo esquivó: este golpe cuerpo a cuerpo está listo."] },
		{ clave = "contraataque", ids = { 19306, 20909, 20910 }, texto = L["¡Contraataque!"],
			porque = L["Paraste un golpe: tu contraataque inmoviliza al enemigo."] },
	},
	PALADIN = {
		{ clave = "colera", ids = { 24275, 24274, 24239 }, texto = L["¡Martillo de cólera!"],
			porque = L["Al objetivo le queda poca vida: el martillo lo remata a distancia."] },
	},
}

-- Las de tu clase (definiciones), o una lista vacía.
function M.ReaccionesDeClase()
	return M.REACCIONES[M.Clase() or ""] or {}
end
