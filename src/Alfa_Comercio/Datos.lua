-- Alfa - Comercio: datos fijos del juego (Toxic / La Jauría). GPL-3.0.
--
-- Tablas clásicas de desencantar, escritas a mano a partir de los hechos del
-- juego clásico (nivel de objeto -> materiales). Son ESTIMADAS: Forever puede
-- tener otros cortes o probabilidades. Se verifican en el juego (LEEME.md).

local _, M = ...

-- Hechizo Desencantar y línea de habilidad de Encantamiento (la del motor:
-- Compat.SKILL_LINES.enchanting = 333).
M.HECHIZO_DESENCANTAR = 13262
M.LINEA_ENCANTAMIENTO = 333

-- Materiales (itemID).
local POLVO_EXTRANO, POLVO_ALMAS, POLVO_VISION, POLVO_SUENO, POLVO_ILUSION = 10940, 11083, 11137, 11176, 16204
local ESENCIA = {
	magiaMenor = 10938, magiaMayor = 10939, astralMenor = 10998, astralMayor = 11082,
	misticaMenor = 11134, misticaMayor = 11135, abisalMenor = 11174, abisalMayor = 11175,
	eternaMenor = 16202, eternaMayor = 16203,
}
local FRAG = {
	brilloPeq = 10978, brilloGrande = 11084, resplandorPeq = 11138, resplandorGrande = 11139,
	radiantePeq = 11177, radianteGrande = 11178, brillantePeq = 14343, brillanteGrande = 14344,
}
local NEXO = 20725

-- Poco común (verde). Cada fila: { nivel máximo, polvo {id, mín, máx},
-- esencia {id, mín, máx}, fragmento {id, probabilidad} | false }.
-- Armadura: 75 % polvo, 20 % esencia, 5 % fragmento (80/20 sin fragmento,
-- 75/15/10 en 21-25). Armas: polvo y esencia al revés.
M.DE_VERDE = {
	{ 15, { POLVO_EXTRANO, 1, 2 }, { ESENCIA.magiaMenor, 1, 2 }, false },
	{ 20, { POLVO_EXTRANO, 2, 3 }, { ESENCIA.magiaMayor, 1, 2 }, { FRAG.brilloPeq, 0.05 } },
	{ 25, { POLVO_EXTRANO, 4, 6 }, { ESENCIA.astralMenor, 1, 2 }, { FRAG.brilloPeq, 0.10 } },
	{ 30, { POLVO_ALMAS, 1, 2 }, { ESENCIA.astralMayor, 1, 2 }, { FRAG.brilloGrande, 0.05 } },
	{ 35, { POLVO_ALMAS, 2, 5 }, { ESENCIA.misticaMenor, 1, 2 }, { FRAG.resplandorPeq, 0.05 } },
	{ 40, { POLVO_VISION, 1, 2 }, { ESENCIA.misticaMayor, 1, 2 }, { FRAG.resplandorGrande, 0.05 } },
	{ 45, { POLVO_VISION, 2, 5 }, { ESENCIA.abisalMenor, 1, 2 }, { FRAG.radiantePeq, 0.05 } },
	{ 50, { POLVO_SUENO, 1, 2 }, { ESENCIA.abisalMayor, 1, 2 }, { FRAG.radianteGrande, 0.05 } },
	{ 55, { POLVO_SUENO, 2, 5 }, { ESENCIA.eternaMenor, 1, 2 }, { FRAG.brillantePeq, 0.05 } },
	{ 60, { POLVO_ILUSION, 1, 2 }, { ESENCIA.eternaMayor, 1, 2 }, { FRAG.brillanteGrande, 0.05 } },
	{ 65, { POLVO_ILUSION, 2, 5 }, { ESENCIA.eternaMayor, 2, 3 }, { FRAG.brillanteGrande, 0.05 } },
}

-- Raro (azul): un fragmento seguro; en lo más alto, 0,5 % de Cristal de nexo.
-- Cada fila: { nivel máximo, { {id, probabilidad, mín, máx}, ... } }.
M.DE_AZUL = {
	{ 25, { { FRAG.brilloPeq, 1, 1, 1 } } },
	{ 30, { { FRAG.brilloGrande, 1, 1, 1 } } },
	{ 35, { { FRAG.resplandorPeq, 1, 1, 1 } } },
	{ 40, { { FRAG.resplandorGrande, 1, 1, 1 } } },
	{ 45, { { FRAG.radiantePeq, 1, 1, 1 } } },
	{ 50, { { FRAG.radianteGrande, 1, 1, 1 } } },
	{ 55, { { FRAG.brillantePeq, 1, 1, 1 } } },
	{ 65, { { FRAG.brillanteGrande, 0.995, 1, 1 }, { NEXO, 0.005, 1, 1 } } },
}

-- Épico (morado).
M.DE_MORADO = {
	{ 45, { { FRAG.radiantePeq, 1, 2, 4 } } },
	{ 50, { { FRAG.radianteGrande, 1, 2, 4 } } },
	{ 55, { { FRAG.brillantePeq, 1, 2, 4 } } },
	{ 60, { { NEXO, 1, 1, 1 } } },
	{ 80, { { NEXO, 1, 1, 2 } } },
}

-- Habilidad de Encantamiento que pide desencantar, por nivel de objeto
-- (la misma tabla para verde, azul y morado; estimada).
M.DE_HABILIDAD = {
	{ 20, 1 }, { 25, 25 }, { 30, 50 }, { 35, 75 }, { 40, 100 },
	{ 45, 125 }, { 50, 150 }, { 55, 175 }, { 60, 200 }, { 999, 225 },
}

-- Clases de objeto que se desencantan (Enum.ItemClass): Arma 2, Armadura 4.
-- Subclase de armadura 5 (cosmético) no se desencanta.
M.DE_CLASES = { [2] = true, [4] = true }
M.DE_SUBCLASE_NO = { [4] = { [5] = true } }

-- Clase de objeto de misión (Enum.ItemClass.Questitem).
M.CLASE_MISION = 12

-- Fila de una tabla por nivel de objeto (la primera cuyo máximo lo cubre, o
-- la última).
function M.FilaPorNivel(tabla, nivel)
	for i = 1, #tabla do
		if nivel <= tabla[i][1] then return tabla[i] end
	end
	return tabla[#tabla]
end
