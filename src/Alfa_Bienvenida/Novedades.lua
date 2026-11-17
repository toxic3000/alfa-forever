-- Alfa - Bienvenida: lo nuevo de Alfa 1.0 (toxic3000 / La Jauría). GPL-3.0.
--
-- Las novedades que muestra la portada de la bienvenida. Deben decir lo mismo
-- que la sección 1.0.0 de CHANGELOG.md (docs/VERSIONES.md): una línea por
-- novedad, en el mismo orden. Al publicar otra versión, se cambia VERSION y
-- esta lista (y, si debe salir otra vez a todos, M.VERSION en Bienvenida.lua).

local ADDON, M = ...

M.VERSION_ALFA = "1.0.0"

-- { icono (ic-* de Alfa), título, una línea }
M.NOVEDADES = {
	{ "ic-hoy", "Hoy te guía", "Una acción recomendada en grande y tu camino en un par de clics." },
	{ "ic-ruta", "Tu ruta, paso a paso", "Rastreador propio y misiones que se liberan o se recogen en un clic." },
	{ "ic-enciclopedia", "Enciclopedia", "Todo objeto, PNJ, misión, zona y raro, con dónde conseguirlo y «Guíame»." },
	{ "ic-talentos", "Talentos y combate", "Qué talento poner y por qué, ayuda de rotación y el daño del grupo." },
	{ "ic-mazmorra", "Mazmorras claras", "Por nivel: jefes, botín, misiones, la entrada y consejos." },
	{ "ic-manada", "La Jauría", "Solo tu grupo y quienes usan Alfa y aceptaron compartir." },
	{ "ic-bolsas", "Bolsas y banco", "General, por categorías o por bolsa, y depósito rápido al banco." },
	{ "ic-mapa", "Mapa y marcadores", "Marcadores propios para compartir y seguir con la flecha." },
	{ "ic-apariencia", "Tres estilos y el lobo", "Alfa, Clásico WoW o Cristal, la flecha del lobo y el aullido." },
}
