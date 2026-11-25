# La página web de Alfa

HTML y CSS propios, sin JavaScript, sin rastreadores, sin anuncios y sin nada de otros sitios (la letra Inter va en `fuentes/`, con su licencia OFL).

- `index.html` en español de México y `en/index.html` en inglés (el botón de arriba cambia de idioma).
- `estilo.css`: el estilo nocturno de Alfa.
- `img/`: el banner, el lobo y 12 capturas de `curseforge/galeria/`, reducidas a 960 px en JPG para que pese poco. Para cambiar una, redúcela a 960 px de ancho (JPG, calidad 82) y guárdala con el mismo nombre.
- Los manuales PDF y la descarga se enlazan con su dirección completa de GitHub, así que funcionan aunque solo se publique esta carpeta.

## Publicarla con GitHub Pages

GitHub Pages solo sirve desde la raíz del repositorio o desde `/docs`, no desde `/docs/web`. Dos maneras:

1. **Rama propia (la más limpia):** copia el contenido de `docs/web/` a la raíz de una rama `gh-pages` (con el `.nojekyll`) y en *Settings > Pages* elige «Deploy from a branch», rama `gh-pages`, carpeta `/ (root)`.
2. **Con una acción:** en *Settings > Pages* elige «GitHub Actions» y usa la acción oficial de páginas estáticas con `path: docs/web`.

La dirección queda en `https://toxic3000.github.io/alfa-forever/`. Después, enlázala desde la descripción de CurseForge y el Discord.
