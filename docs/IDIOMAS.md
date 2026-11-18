# Idiomas de Alfa

Alfa se escribe en español y viene en 9 idiomas: español, inglés, alemán (deDE), francés (frFR), portugués de Brasil (ptBR), ruso (ruRU), coreano (koKR), chino simplificado (zhCN) y chino tradicional (zhTW). El motor (lo que viene de Polestar) trae sus propias traducciones; los módulos de Alfa usan las de esta carpeta.

## Cómo funciona

- Cada módulo escribe sus textos en español y trae su inglés en `Textos.lua` (`M.EN`). Los consejos de Mazmorras traen el par `{ español, inglés }`.
- `tools/textos.py fuente` reúne todo en `textos/fuente.json`.
- Las traducciones están en `textos/<locale>/*.json`, como `{ "texto en español": "traducción" }`.
- `tools/textos.py estado` dice cuánto falta en cada idioma y qué está mal.
- `tools/textos.py generar` escribe `src/Alfa_Nucleo/Idiomas/<locale>.lua`. Cada archivo solo se carga en un cliente de ese idioma.

Una traducción se descarta si no conserva exactamente los huecos `%s`/`%d` **en el mismo orden** (el `string.format` de Lua no permite reordenarlos), los colores `|c…|r`, las texturas `|T…|t`, los enlaces `|H…|h` y los saltos de línea.

## Claves con contexto

Cada idioma es **una sola tabla** para todos los módulos: si dos módulos usan el mismo texto en español con sentidos distintos, en los otros idiomas los dos salen con la misma traducción y uno queda mal. Para separarlos, la clave lleva su contexto al final, entre corchetes: `L["Alto [calidad]"]`. `N.Textos` (Alfa_Nucleo) quita ese `[...]` final al mostrarla en español y cuando falta la traducción, así que en español se sigue leyendo «Alto». En `Textos.lua` el inglés va con la misma clave (`["Alto [calidad]"] = "High"`).

Separadas hoy (traducciones en `textos/<locale>/zz_Separadas.json`, que se lee al final y gana sobre los demás archivos):

| Clave con contexto | Dónde | La otra, sin contexto |
|---|---|---|
| `Alto [calidad]` | preajuste de Paisaje y gráficos | `Alto`: la altura de los marcos de Curación |
| `Estadísticas [pesca]` | pestaña y tarjeta de Pesca | `Estadísticas`: los atributos de un objeto (Enciclopedia) |
| `Guardar [conservar]` | consejo y filtro de Comercio | `Guardar`: botón de guardar (marcadores, planes, rutas) |
| `Mejora [reporte]` | tipo de reporte de `/alfa reportar` | `Mejora`: la especialización del chamán |
| `Misiones [bolsas]` | categoría de Bolsas (objetos de misión) | `Misiones`: misiones en todo lo demás |
| `No [apagado]` | «Recordatorio del instructor» de Hoy | `No`: la respuesta del resumen de la bienvenida |
| `Principal [mano]`, `Secundaria [mano]` | arma principal y secundaria (Hoy, tu clase) | `Principal`, `Secundaria`: profesiones (Talentos > Equipo) |
| `Listo [estado]` | insignia «preparado» de Comodidades y Pesca | `Listo`: terminar un asistente, botón «Listo» |

Para encontrar más: las claves en español que tienen un inglés distinto en dos `Textos.lua` (casi siempre es solo otra redacción, pero así salieron estas). `Protección [paladín]` y `Restauración [chamán]` usan lo mismo desde antes (con su propio `gsub`, que sigue sirviendo).

## Corregir una traducción

1. Busca el texto en `textos/<locale>/` y cambia solo la traducción, nunca la clave en español.
2. Corre `tools/textos.py estado` y luego `tools/textos.py generar`.
3. Abre un Issue o un pull request en https://github.com/toxic3000/alfa-forever, o avísanos en el Discord de La Jauría.

## Para que revise alguien nativo

Las traducciones las hizo una IA con los términos del cliente de cada idioma y del motor. Estas son las dudas que dejaron los traductores:

- **Todos los idiomas:** nombres de habilidades clásicas de guerrero (Embate, Golpes de barrido, Muro de escudo, Último recurso, Deseo de muerte, Ataque victorioso…) y de otras clases (Forma de lechúcico lunar, Mordedura de mangosta, Transfusión de vida); los nombres de funciones nuevas de Blizzard (clic para lanzar, línea de tiempo de jefes, ayuda de combate); y los nombres de estilos y builds de Alfa.
- **Claves que comparten dos clases:** "Protección" (guerrero / paladín) y "Restauración" (druida / chamán) tienen nombres distintos en coreano y otros idiomas. Hay que separarlas en el español.
- **Fechas:** "el %d/%d a las %s" va con el orden día/mes del español; en coreano y chino se lee al revés.
- **frFR:** "Stormwind" o "Hurlevent", y Polestar usa otros nombres para algunos talentos ("Coup mortel", "Lacération").
- **zhCN:** "Asesinato" como 刺杀 o 奇袭; "Forever" sin traducir (Polestar usa 无限).
- **zhTW:** 主要/次要 frente a 主手/副手 en el temporizador de golpe.
- **ruRU:** los plurales van como "Заданий: %d". La búsqueda de Bolsas con mayúscula inicial no encuentra nada en cirílico (pendiente en `docs/PLAN.md`).
- **deDE:** "Ruhebonus", "Fokusmodus", "Vorkommen" y "Klickzauber".
- **ptBR:** varios hechizos quedaron en inglés (Slam, Shield Wall, Last Stand…) a la espera del nombre oficial.

### Dudas de la 1.1.0

- **Todos los idiomas:** el sistema del Legado de Forever no tiene nombres oficiales confirmados (Legado, registro del Legado, árbol "Recursos", sus premios del oso espectral y el rifle de réplica de Forjaz); "Barrow Deeps" quedó en inglés en varios idiomas; "Campo de Honor" se tradujo a mano. Los argumentos de `/alfa cerca` (vuelo, posada…) se quedan en español con la traducción entre paréntesis.
- **deDE:** "Konzentration" (Premeditación), "Finishing Move" (remate), "Reiten (Lehrling/Geselle)", "Abklingzeit-Animation" (barrido de recarga).
- **frFR:** "maître de monte" y "monte d'apprenti/de compagnon", "Maîtrise du blocage" (Bloqueo con escudo), "Souhait mortel" (Deseo de muerte).
- **ptBR:** "Cume Hyjal", "Golpe Fantasmagórico", "Adrenalina" (Subidón de adrenalina), "Clarividência" (Claridad), rangos de equitación Aprendiz/Artesão, "Emissário do Caos" (abisario).
- **ruRU:** Alfa en masculino ("аддон") y Lya en femenino; "мини-карта" con guion; "очки серии"; "Хардкор"; "Повелитель зверей" / "Сила зверя".
- **koKR:** términos de equitación (타기 / 수습 타기 / 숙련 타기, 탈것 조련사); instructor de clase 상급자 frente a instructor de profesión 전문가 (en los archivos anteriores está mezclado); 정기의 숙련 (Maestría elemental); Lya habla en 해요체 y la interfaz en 합니다체.
- **zhCN / zhTW:** hechizos donde Polestar no coincide con el cliente de Taiwán (寒冰護體 o 冰封屏障, 燃燒 o 大火焰, 秘法 o 奧術, 雄鷹守護 o 鷹之守護); 火焰風暴 de Polestar en zhTW parece un error (Piroexplosión es 炎爆術); "Modo extremo" quedó 硬核模式 / 專家模式; diario de monturas 坐骑收藏 / 坐騎收藏.
- **deDE / frFR / ptBR (1.1.4, lore de Lya):** sin confirmar en alemán Todesend, Lorenhall, Flickwerk, Robogenieur Thermadraht, Mekkadrill, Splitterholzposten, Marschalls Zuflucht, Steinard, Laubschattental, Konzentration; en francés Recousu, Glas-Mortuaire, Trépas-d'Orgrim, Refuge de l'Ornière, Halte du Thorium, Mekkanivelle, Cherchevent, « des bonbons ou un sort »; en portugués quedaron en inglés Hammerfall, Fandral Staghelm, Stonard, Nethergarde, Ironband, y faltan confirmar Pontos, Sino da Morte, Vale Sombrio, Urzal dos Navalhanes/dos Mortos, Jardinova, Subminas, Termaplugue, Grão-faz-tudo, Velassangue, Ventura & Cia., "serpes". El "mon" de los Lanza Negra: Mann / man / mon.
- **ruRU / koKR (1.1.4, lore de Lya):** sin confirmar en ruso «Ториевая Застава», «друиды Пера», «Похоронный Звон», «раскопки Айронбенда», «Громораан», «Нижняя Шахта», «Любовная лихорадка», «Изера Сновидица», «Хоггер»; en coreano 토륨 거점, 피난처 주둔지, 갈퀴발톱의 드루이드, 죽음의 종소리, 앰버밀, 바람추적자 썬더란, 밤표범, 텔사마 순대, 룬 마법막대, 영원의 노즈도르무; el «zug zug» de los peones («Зуг-зуг», «작작») depende del doblaje; especialidades de peletería y herrería descriptivas.
- **zhCN / zhTW (1.1.4, lore de Lya):** Atiesh no coincide entre los dos clientes en Names.lua (埃提耶什，守护者的传说之杖 / 阿泰絲，守護者之杖); sin confirmar: Costuras 斯迪克斯, Elune'ara, Kel'Theril, Punta de Torio, Quel'Danil, Ruinas de Eldarath, El Valle Calcinado, Refugio del Mariscal, Caldera de la Garganta de Fuego, Prestor, Taretha, Maiev, Eitrigg, Sayge, Mankrik, Linken, Leeroy, Minahonda, Kezan, Quel'Serrar; en zhTW Malygos 織法者, Velen, eredar, Kirin Tor, Felhunter, frascos 精煉藥劑 y «維克多·奈法利斯領主».
- **Todos (lote b):** los logros y maestrías de pesca son nombres propios de Alfa (Cien al cesto, Paciencia de lobo, Conocido…Leyenda); el nombre oficial del concurso de pesca de Tuercespina y del pescado sabroso no está confirmado en ningún idioma.
- **deDE / frFR / ptBR (lote b):** los temas de Lya van en dativo en alemán; en francés y portugués la frase cambió (« Au programme : %s et %s… », "Entre %s e %s…") para no chocar con el artículo. Sin confirmar: Robogenieur Thermadraht, Steinard, Venture Co., Ewige Warte; Pierrêche, Rempart-du-Néant, Mekgénieur Thermojoncteur, Fort-de-Durn, KapitalRisque; en ptBR quedaron en inglés Fandral Staghelm, Genn Greymane, Stonard y Nethergarde, y faltan por confirmar Ventura & Cia., Cinzarra, Termaplugue, Guilnéas y "Torneio de pesca da Selva do Espinhaço".
- **ruRU / koKR (lote b):** los temas de las historias de Lya ("los lobos", "las arpías"…) van declinados para «про» (solo entran en frases de "de qué va"); "%s te encargó…" en presente para no elegir el género del PNJ; sin confirmar: 타우릿산, 자에데나르, 마즈소릴, 세라다인, 황천의 요새 (Nethergarde), 투자개발회사 (Ventura y Cía.), «Крепость Стражей Пустоты», «Кабестан», «Круговзор», el concurso «Рыболовная феерия Тернистой долины» y el pescado sabroso (пятнистая вкуснорыбка / 얼룩무늬 별미고기); maestrías de pesca propias (Знакомство…Легенда / 익숙함…전설) distintas de los rangos del juego; "placas de nombre" = индикаторы здоровья / 이름표, "preajuste" = набор / 프리셋.
- **zhCN / zhTW (lote b: pesca, paisaje, historias de Lya):** el pescado del concurso de Tuercespina quedó genérico (美味鱼 / 美味魚); los nombres de logros y maestrías de pesca son traducciones libres (满篓一百条, 熟练, 传奇); sin confirmar con el cliente de Taiwán: 梣谷 (Vallefresno), 索爾 / 杜洛塔, 諾姆瑞根, 奧格瑪, 奧格林, 雅立史卓莎, 希瓦娜斯, 瑪法里恩, 古神, 奪魂者哈卡; Festival Lunar como 春节 / 春節; Strom como 斯托姆.
- **Para el español:** "Cerrar lo que tu guía salta" es ambiguo (cierra el diálogo, no abandona misiones); el buscador de la Enciclopedia pide "Nombre del objeto (en español o inglés)" — revisar si acepta el idioma del cliente.
