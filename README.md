# WarlockGod

Addon de mejoras para brujos en WoW Forever, de la familia de HunterGod y MageGod, con la misma ventana de opciones en el color del brujo (#8788EE). Comandos: `/warlockgod` y `/brujo`. En inglés y en español. Proyecto de CurseForge 1832594, repositorio github.com/alaz-gtn/WarlockGod. Hace esto:

- **Fila de avisos** encima del personaje, como la de HunterGod: iconos del mismo tamaño con borde negro de un píxel, centrados y que se mueven juntos. Un clic hace lo suyo, solo fuera de combate (en combate el juego no deja a los addons tocar esos botones). En orden:
  - **Demonio**: si no tienes ninguno fuera, el clic invoca el último que invocaste (o el que elijas). No sale montado ni muerto, ni con el bufo de Sacrificio demoníaco, salvo que tengas Pacto demoníaco (talento de Forever que conserva el bufo al invocar otro). Sale también en combate, sin botón.
  - **Enlace de alma**: si lo sabes, tienes demonio y no lo llevas puesto. Solo fuera de combate.
  - **Piel o Armadura demoníaca**: gris si falta, en color con el tiempo en sus últimos minutos.
  - **Piedra del arma**: en Forever la piedra de fuego y la de hechizo imbuyen el arma. Si el arma de la mano derecha no lleva encantamiento temporal: con la piedra en la bolsa, el clic la pone (`/use item` + `/use 16`); sin ella, la crea. Elige la última que usaste, o la que digas; si no, la de hechizo.
  - **Piedra de salud**: si sabes hacerla y no llevas ninguna.
  - **Piedra de alma**: si no llevas, hacerla; si llevas una lista (sin reutilización), usarla en tu objetivo amistoso o en ti (`/use [@target,help,nodead][@player]`).
  - Las piedras solo se proponen si tienes un fragmento de alma para hacerlas.
- **Contador de fragmentos de alma** (objeto 6265): rojo por debajo de 3, naranja por encima de 20; las dos líneas se cambian. Siempre, o solo cuando hay algo que decir.
  - **Rastreo de recolección**: con Herboristería o Minería y sin Buscar hierbas ni Buscar minerales puesto, fuera de mazmorras y de vuelos; el clic pone el último que llevaste. Es `Gathering.lua`, el archivo común de la familia (copiado de MageGod).
- **Procs**, cada uno con su dibujo pequeño (por defecto al 40 %, 60 % al saltar y 20 % mientras dura, como HunterGod), sus segundos, su interruptor y su color, y solo si tu build tiene el talento. Los dibuja el juego en un `AuraContainer` por proc, como el viento de HunterGod y los rayos de MageGod. Texturas de `tools/make_procs.py`.
  - Trance de las Sombras (bufo 17941; Aflicción, talento Ocaso 18094): llamas de sombra a los dos lados.
  - Cosecha de almas (bufo 1242853; Aflicción, talento 437032): almas azuladas que suben detrás.
  - Diezmar (bufo 440873; Demonología, talento 440870): anillo de fuego vil a los pies.
  - Sombra y llama (Destrucción, talento 426316): "Shadow" (1293816) tras Conflagrar, brasa morada sobre el hombro izquierdo; "Flame" (426311) tras Quemadura de las Sombras, brasa naranja sobre el derecho. Cada mitad pide además su hechizo. Solo por ID: hay otros hechizos llamados "Shadow" y "Flame".
  - No se pueden animar (caen en el objetivo, no en ti): Descarga de las Sombras mejorada, Marca demoníaca, Secuelas y Piroclasmo. Backdraft (427714) está entre los hechizos de Forever, pero su talento no está en el árbol: no va.
- **Barra de escudos** (`Shields.lua`, la de MageGod): Custodia de las Sombras, el Sacrificio del abisario (lo lanza el demonio: se escucha `UNIT_SPELLCAST_SUCCEEDED` de "pet") y la tabla común de la familia con los de las demás clases (los del mago, el Palabra de poder: escudo de un sacerdote y las seis pociones de protección, solo por ID), cada uno con su color.
- **Barra de golpe de la varita** (`Wand.lua`, la del Disparo automático de `HunterGod/Swing.lua` sola): `PLAYER_SWING` de tipo Ranged (2) con la duración del juego, descartando secretos; si no llega, `START_AUTOREPEAT_SPELL`/`STOP_AUTOREPEAT_SPELL` con la velocidad de `UnitRangedDamage`. Plana, empieza al 45 % de brillo y se enciende al final, destello al disparar, segundos e icono de la varita. Se ve mientras disparas y 2 s después, en gris fuera de alcance (`C_SwingTimer` o el alcance de Disparar). Pestaña Varita y `/brujo varita`.
- **Equipo y bolsas** (`Repair.lua`, común de la familia, copiado de MageGod): en la lista junto al chat, debajo de los reactivos, cuando la pieza más gastada baja del 25 % o te quedan 2 huecos o menos (los dos se cambian); un vendedor que repara dice en el chat cómo está tu equipo. Solo fuera de combate.
- **Bufos de grupo** (`GroupBuffs.lua`, común): conectado a la fila de avisos (tres huecos, icono con cuántos faltan y clic en el primero al alcance), pero el brujo no tiene bufos de grupo en la lista de la familia: aquí no sale nunca.
- **Cooldowns que vuelven** (`Pulse.lua`, el de Traslación de MageGod ampliado a una lista con cola): Espiral de la muerte, Aullido de terror, Dominación vil, Amplificar maldición, Inferno, Ritual de condenación y la media hora de la Piedra de alma (cooldown del objeto) encendidos; Fuego de alma, Bane de fatalidad y Custodia de las Sombras apagados por defecto (salen demasiado). Solo los que sabes; `isActive` es público en combate y el global no cuenta.
- **Tus efectos en el objetivo** (`Debuffs.lua`): un `AuraContainer` en "target" con un grupo (`AddAuraGroup`, filtro `HARMFUL|PLAYER`, máximo 8) que el juego coloca en fila y pinta (`SetIcon`, `SetDurationCooldown`), a la derecha de la barra de vida de su placa, o donde lo pongas. Grupos con su interruptor: Corrupción, Inmolar, tu Bane, tu maldición, Succionar vida, control (Miedo, Desterrar, Aullido, Espiral) y, con su talento, Vulnerabilidad a las Sombras (17794) y Marca demoníaca (1293696). Solo los rangos de lo que sabes.
- **¡INTERRUMPE!** (`Interrupt.lua`): el brujo solo tiene el Bloqueo de hechizo del manáfago (19244, 19647; hechizo de mascota, `IsSpellKnown(id, true)` o la barra de mascota). Sale a la izquierda de la placa cuando el objetivo lanza o canaliza algo interrumpible y el bloqueo está listo. Un lanzamiento secreto cuenta como interrumpible; el alcance es el del manáfago y no se comprueba.
- El brujo no tiene posturas ni formas: no lleva aviso de postura equivocada.
- **¡CURA A TU DEMONIO!** con el % de vida, con la curva secreta de HunterGod (`UnitHealthPercent` + `C_CurveUtil`).
- **Distancia al objetivo** (de MageGod): rojo a melee, amarillo al alcance de Drenar vida (o de Miedo antes de aprenderla, 20 yd), verde a tiro de Descarga de las Sombras, Inmolar o Corrupción, y lila en sus últimas 5 yardas.
- **Aviso de agro**: con tu demonio fuera o en grupo.
- **Bien alimentado y reactivos**: la lista pequeña junto al chat. Arriba el aviso de comida de MageGod (con la lista de tu comida de exp) y debajo los reactivos que te faltan, de `Reagents.lua`, el archivo común copiado de MageGod: Piedra infernal (Inferno), Figurilla demoníaca (Ritual de condenación) y los fragmentos de alma solo si el contador está apagado, para no avisar dos veces. Solo fuera de combate; con Reagent Economy (legado), no los de vendedor; un vendedor que tiene uno que te falta lo dice en el chat.
- **Precio de reiniciar talentos**: `Respec.lua`, el de la familia (la clase sale del nombre del addon y el color de `ns.ACCENT`).

## Carpetas

- `WarlockGod/`: el addon tal como se instala en `_forever_\Interface\AddOns`. En este PC esa carpeta es una unión (junction) a esta, así que los cambios llegan al juego sin copiar nada: con `/reload` basta, salvo los archivos nuevos, que piden reiniciar el juego.
- `tools/`: `test_addon.py` (pruebas con lupa), `make_procs.py` (las texturas de los procs; necesita pillow), `build_zip.py` (el zip) y `publish.py` (la subida a CurseForge).
- `curseforge/`: el logo, la descripción de la página y las notas de cada versión. El logo y el icono los dibuja `..\ClassGods\make_logos.py`.
- `release/`: los zips, que no van al repositorio.

## Probar

`python -I tools/test_addon.py WarlockGod enUS` y lo mismo con `esES`.

## Sacar una versión nueva

1. Cambia `## Version:` en `WarlockGod/WarlockGod.toc` y añade su entrada en `curseforge/changelog.md`.
2. Pasa las pruebas en los dos idiomas.
3. Haz commit, crea la etiqueta `v<versión>` y súbela (`git push origin main v<versión>`). GitHub Actions (`.github/workflows/release.yml`) prueba el addon y lo sube a CurseForge con su nota de cambios (`tools/publish.py`, con la clave de CurseForge en el secreto `CF_API_KEY` del repositorio y el proyecto, 1832594, en `## X-Curse-Project-ID` del TOC). Para ver el zip sin subirlo: `python -I tools/build_zip.py` o `python -I tools/publish.py --dry-run`.

La descripción de la página de CurseForge (`curseforge/description.md`) no la sube `publish.py`: se pega a mano.

Archivos comunes de la familia, copiados tal cual de MageGod (se cambian allí y se vuelven a copiar): `Gathering.lua`, `Reagents.lua`, `GroupBuffs.lua` y `Repair.lua`. `Respec.lua` es el mismo que el de PriestGod.
