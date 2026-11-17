"""Publica las novedades de Alfa en el canal de Discord de La Jauría con el bot
Jesus GPT (el mismo de ToxicHost).

Uso:
  python -I tools/anunciar.py activo [--vista]       Alfa ya está activo (la 1.0.0)
  python -I tools/anunciar.py version 1.1.0 [--vista] Salió una versión: su sección del CHANGELOG

--vista imprime la tarjeta sin publicarla; --editar ID corrige un aviso ya publicado;
--borrar ID publica el nuevo y borra el anterior.

Lee tools/anunciar_local.json (no se sube a git):
  {"bot": "C:/.../toxichost/dist_package/data/discord.json", "canal": "<id del canal>",
   "ayuda": "<id del canal donde reportar fallas>"}
El token del bot se queda en el archivo de ToxicHost; aquí solo se lee para publicar.
Nunca menciona a nadie (sin @everyone).
"""
import json
import pathlib
import re
import sys
import time
import urllib.request

RAIZ = pathlib.Path(__file__).resolve().parent.parent
LOCAL = RAIZ / "tools" / "anunciar_local.json"
REPO = "https://github.com/toxic3000/alfa-forever"
INSTALADOR = f"{REPO}/releases/latest/download/Instalar-Alfa.exe"
DONAR = "https://www.paypal.com/donate/?hosted_button_id=7J5BYWH9DVT9C"
LOGO = "https://raw.githubusercontent.com/toxic3000/alfa-forever/main/curseforge/avatar.png"
VERDE = 0x8BE04E
API = "https://discord.com/api/v10"


def _api(token, metodo, ruta, datos=None):
    req = urllib.request.Request(API + ruta, method=metodo,
                                 data=json.dumps(datos).encode("utf-8") if datos is not None else None,
                                 headers={"Authorization": "Bot " + token, "Content-Type": "application/json",
                                          "User-Agent": f"DiscordBot ({REPO}, 1.0)"})
    with urllib.request.urlopen(req, timeout=20) as r:
        return json.load(r)


def _cambios(version: str) -> list:
    texto = (RAIZ / "CHANGELOG.md").read_text(encoding="utf-8")
    m = re.search(rf"^## {re.escape(version)}\b.*?\n(.*?)(?=^## |\Z)", texto, re.S | re.M)
    if not m:
        raise SystemExit(f"No hay sección {version} en CHANGELOG.md")
    es = re.split(r"^\*\*English\*\*", m.group(1), flags=re.M)[0]
    return [l.rstrip() for l in es.splitlines() if l.lstrip().startswith("- ")]


def _instalar():
    return {"name": "📥 Instálalo o actualízalo",
            "value": f"Descarga **[Instalar-Alfa.exe]({INSTALADOR})** y ábrelo: encuentra tu WoW y lo pone solo.\n"
                     "Si Windows avisa: *Más información* → *Ejecutar de todas formas*.", "inline": False}


def _falla(ayuda):
    """Dónde reportar: el canal "ayuda" de anunciar_local.json (mencionar un canal no notifica a nadie)."""
    donde = f"<#{ayuda}>" if ayuda else "el Discord de La Jauría"
    return {"name": "🐛 ¿Algo falla?", "value": f"Escríbenos en {donde} o usa `/alfa reportar` en el juego. ¡Gracias!", "inline": True}


def tarjeta(tipo: str, version: str, ayuda=None) -> dict:
    if tipo == "activo":
        embed = {
            "title": f"🐺 ¡Alfa {version} ya está activo!",
            "url": f"{REPO}/releases/tag/v{version}",
            "description": "El addon de la manada para WoW Forever ya se puede instalar: guías, ruta, mapa, "
                           "bolsas, talentos, enciclopedia, mazmorras y La Jauría, todo en uno.\n"
                           "Hecho por **toxic3000**.",
            "fields": [_instalar(),
                       {"name": "🎮 En el juego", "value": "Escribe `/alfa`", "inline": True},
                       {"name": "🔄 Para actualizar", "value": "Abre otra vez el instalador", "inline": True},
                       _falla(ayuda),
                       {"name": "📦 Dónde está",
                        "value": f"Ya está publicado en **[GitHub]({REPO}/releases/latest)**. En **CurseForge** "
                                 "está pendiente de validación: en cuanto lo aprueben, también sale ahí.",
                        "inline": False}],
        }
    else:
        resumen = RAIZ / "docs" / "anuncios" / f"{version}.md"  # el resumen hecho a mano, si lo hay
        if resumen.exists():
            cuerpo = resumen.read_text(encoding="utf-8").strip()
        else:
            cuerpo = ""
            for l in _cambios(version):
                if len(cuerpo) + len(l) + 1 > 1500:
                    cuerpo += "\n…y más en las notas completas."
                    break
                cuerpo += ("\n" if cuerpo else "") + l
        embed = {
            "title": f"🔄 Salió Alfa {version}",
            "url": f"{REPO}/releases/tag/v{version}",
            "description": cuerpo,
            "fields": [_instalar(), _falla(ayuda),
                       {"name": "💛 Apoya a Alfa",
                        "value": "Alfa es gratis y lo seguirá siendo. Donar es opcional: es una forma de "
                                 "agradecer el trabajo de toxic3000 y no desbloquea nada.", "inline": False}],
        }
    embed.update(color=VERDE, thumbnail={"url": LOGO},
                 timestamp=time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()))
    return embed


def botones(version: str) -> list:
    """Botones de enlace (no necesitan que el bot escuche clics). Donar va solo aquí, en Discord,
    nunca dentro del juego (regla 5 de Blizzard, docs/REGLAS-BLIZZARD.md)."""
    def enlace(texto, url, emoji):
        return {"type": 2, "style": 5, "label": texto, "url": url, "emoji": {"name": emoji}}
    return [{"type": 1, "components": [
        enlace("Instalar Alfa", INSTALADOR, "📥"),
        enlace("Notas completas", f"{REPO}/releases/tag/v{version}", "📜"),
        enlace("Donar con PayPal", DONAR, "💛"),
    ]}]


def main(argv) -> int:
    if not argv or argv[0] not in ("activo", "version"):
        print(__doc__)
        return 1
    tipo = argv[0]
    cfg_alfa = json.loads((RAIZ / "tools" / "alfa.json").read_text(encoding="utf-8"))
    version = argv[1] if tipo == "version" and len(argv) > 1 and not argv[1].startswith("--") else cfg_alfa["version"]
    local = json.loads(LOCAL.read_text(encoding="utf-8"))
    embed = tarjeta(tipo, version, local.get("ayuda"))
    bot = json.loads(pathlib.Path(local["bot"]).read_text(encoding="utf-8"))
    token, canal = bot["token"], str(local["canal"])
    if bot.get("guild_id"):  # el pie con el nombre y el icono del servidor, como las tarjetas de ToxicHost
        g = _api(token, "GET", f"/guilds/{bot['guild_id']}")
        pie = {"text": f"{g['name']} · Alfa {version}"}
        if g.get("icon"):
            pie["icon_url"] = f"https://cdn.discordapp.com/icons/{g['id']}/{g['icon']}.png"
        embed["footer"] = pie
    if "--vista" in argv:
        sys.stdout.reconfigure(encoding="utf-8")
        print(json.dumps(embed, ensure_ascii=False, indent=2))
        return 0
    cuerpo = {"embeds": [embed], "allowed_mentions": {"parse": []}, "components": botones(version)}
    if "--editar" in argv:  # corrige un aviso ya publicado en vez de mandar otro
        mid = argv[argv.index("--editar") + 1]
        msg = _api(token, "PATCH", f"/channels/{canal}/messages/{mid}", cuerpo)
        print(f"Editado en el canal {canal}: mensaje {msg['id']}")
    else:
        msg = _api(token, "POST", f"/channels/{canal}/messages", cuerpo)
        print(f"Publicado en el canal {canal}: mensaje {msg['id']}")
        if "--borrar" in argv:  # reemplaza un aviso anterior: se borra después de publicar el nuevo
            viejo = argv[argv.index("--borrar") + 1]
            req = urllib.request.Request(f"{API}/channels/{canal}/messages/{viejo}", method="DELETE",
                                         headers={"Authorization": "Bot " + token, "User-Agent": f"DiscordBot ({REPO}, 1.0)"})
            urllib.request.urlopen(req, timeout=20).close()
            print(f"Borrado el aviso anterior {viejo}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
