local _, ns = ...

-- English first; the Spanish client overwrites what it has
local L = {
	PREFIX = "|cff8788eeWarlockGod:|r ",
	SUBTITLE = "Quality of life for warlocks",
	YARDS = "yd",
	METERS = "m",
	NOT_IN_COMBAT = "not in combat: try again when the fight is over.",
	UNLOCKED = "displays unlocked: drag them where you want them. /warlockgod lock when you're done.",
	LOCKED = "displays locked.",
	OTHER_CLASS = "only for a warlock: on this character it stays hidden.",

	-- Reminders
	REMINDERS_NAME = "Reminders",
	CLICK_CAST = "Click: cast it",
	CLICK_CREATE = "Click: create it (a soul shard)",
	CLICK_IMBUE = "Click: put it on your weapon",
	CLICK_SOULSTONE = "Click: on your friendly target, or on you",
	CLICK_SUMMON = "Click: summon it",
	SOULSTONE_READY = "ready",
	SHARDS_NAME = "Soul shards",
	SHARDS_TIP = "You carry %d. Red under %d, orange over %d (in the options).",
	BUFFS_REPORT = "armor: %s; healthstone: %s; soulstone: %s; weapon stone: %s; soul shards: %d.",
	BUFFS_SEEN = "buffs on you: %s",
	BUFFS_HIDDEN = "the game hides your buffs in combat: try again out of it.",
	BUFF_LEFT = "%s, %s left",
	BUFF_ON = "%s, no end",
	BUFF_NONE = "none",
	BUFF_UNKNOWN = "not seen yet",
	BUFF_NOT_KNOWN = "not learned",
	STONE_NONE = "none in your bags",
	STONE_HAVE = "%s (you have %d)",
	WEAPON_ON = "on your weapon",
	WEAPON_OFF = "not on your weapon",

	-- Food
	FOOD_NAME = "Food, reagents and repairs",
	FOOD_MISSING = "No XP from food",
	CLICK_FOOD = "Click: your XP food",
	CLICK_EAT = "Click: eat it",
	NO_XP_FOOD = "No XP food in your bags",
	WELL_FED = "Well Fed",
	FOOD_STOCK = "XP food in your bags: %s",

	-- The demon
	DEMON_MISSING = "You have no demon out.",
	DEMON_HEALTH = "HEAL YOUR DEMON! %d%%",
	DEMON_HEALTH_NAME = "Demon's health",

	-- Range
	RANGE = {
		melee = "Melee",
		drain = "Drain range",
		ranged = "In range",
		far = "Max range",
		out = "Out of range",
	},
	RANGE_NO_TARGET = "no target.",
	RANGE_REPORT = "%s at %d-%d yd; %s reaches %d yd and says %s.",
	RANGE_STEPS = "range checks: ",
	RANGE_LOADING = "(some range items not loaded yet)",
	RANGE_YES = "yes",
	RANGE_NO = "no",
	UNITS_SET = "range in %s.",
	THREAT = "AGGRO %d%%",
	THREAT_PULLED = "YOU HAVE AGGRO!",
	THREAT_NAME = "Aggro",

	-- Procs
	PROCS_NAME = "Procs",
	PROCS_WATCHING = "%s: watching spells %s.",
	PROCS_NOT_READY = "%s isn't set up yet: the addon builds it out of combat.",
	PROCS_REFUSED = "the game didn't take the animations for %s, so it won't show.",
	PROCS_NO_TALENT = "%s: off, your build doesn't have %s.",

	-- Options
	TAB_BUFFS = "Reminders",
	TAB_DEMON = "Demon",
	TAB_RANGE = "Range",
	TAB_THREAT = "Aggro",
	TAB_PROCS = "Procs",
	TAB_WAND = "Wand",
	TAB_COOLDOWNS = "Cooldowns",
	PULSE_NAME = "Cooldown back",
	SEC_PULSE = "Your big cooldowns, back",
	OPT_PULSE = "Their icon big in the middle each time one is ready again",
	PULSE_SOULSTONE = "Soulstone (the stone's half hour)",
	OPT_PULSE_SIZE = "Size",
	OPT_PULSE_ALPHA = "Strength (%)",
	OPT_PULSE_COLOR = "Colour of the shine behind it",
	OPT_PULSE_TEST = "See how it looks",
	PULSE_HINT = "It pops up and fades in under a second. Only for the spells you know. In combat Forever hides how long a cooldown has left, but not whether it's running, so it shows in fights too; the global cooldown doesn't count. Two back at once come one after the other. Drag it with Move displays.",
	TAB_TARGET = "Target",
	DOTS_NAME = "Your effects on the target",
	SEC_DOTS = "Your effects on your target",
	OPT_DOTS = "Small icons with their seconds, beside its nameplate",
	DOT_BANES = "Your Bane (Agony, Doom or Havoc)",
	DOT_CURSES = "Your Curse (the Elements, Weakness, Recklessness, Tongues or Exhaustion)",
	DOT_CONTROL = "Fear, Banish, Howl of Terror and Death Coil",
	OPT_DOTS_SIZE = "Icon size",
	DOTS_HINT = "Only yours, and only of the spells you know (Shadow Vulnerability and Demonic Brand with their talents). The game draws them and counts their time, in combat too. With no nameplate, they go where you put them with Move displays.",
	SEC_INTERRUPT = "Interrupt",
	INTERRUPT_NAME = "Interrupt",
	OPT_INTERRUPT = "The icon of your Felhunter's %s beside your target while it casts something you can stop and it's ready",
	INTERRUPT_HINT = "A warlock's only interrupt is the Felhunter's Spell Lock: it only shows with one out that knows it. In a fight Forever may hide whether a cast can be stopped: then the game itself shows or hides the icon. Its reach is the Felhunter's, which the addon can't measure.",
	WAND_NAME = "Wand swing timer",
	SEC_WAND = "Your wand's swing timer",
	OPT_WAND = "A bar for your wand's shots (Shoot)",
	OPT_WAND_TIME = "Seconds to the next shot",
	OPT_WAND_ICON = "The wand's icon on the left",
	OPT_WAND_COLOR = "Its colour",
	OPT_WAND_TEST = "See it shoot",
	WAND_HINT = "It starts dim, lights up as the shot comes and flashes when it goes. It shows while you shoot and a moment after, grey when your target is out of reach. Forever tells the game each shot, in combat too. Drag it with Move displays.",
	SEC_BUFFS = "Your armor",
	OPT_BUFFS_ON = "Remind me of what I'm missing",
	OPT_ARMOR = "%s, then %s",
	OPT_WARN_TIME = "Warn before it ends (minutes)",
	OPT_IN_COMBAT = "Armor and stones also in combat",
	OPT_CLICK = "Click a reminder to cast it (out of combat)",
	SEC_STONES = "Stones",
	OPT_HEALTHSTONE = "Healthstone: remind me to make one when I carry none",
	OPT_SOULSTONE = "Soulstone: remind me to make one when I carry none",
	OPT_SOULSTONE_USE = "And to use it when it's ready (on my friendly target, or on me)",
	OPT_WEAPON = "Firestone or Spellstone on my weapon",
	OPT_WEAPON_CHOICE = "Which one",
	WEAPON_AUTO = "The last one you used",
	STONES_HINT = "In Forever the Firestone and the Spellstone imbue your weapon. A click makes the stone, or puts it on the weapon in your main hand. Making one takes a soul shard: with none, it doesn't remind you.",
	SEC_SHARDS = "Soul shards",
	OPT_SHARDS = "Count my soul shards",
	OPT_SHARDS_ALWAYS = "Always, not only when I'm short or carry too many",
	OPT_SHARDS_LOW = "Red under",
	OPT_SHARDS_MAX = "Orange over",
	BARRIER_NAME = "Shield",
	SEC_BARRIER = "Shields",
	OPT_BARRIER = "A bar with what's left of your shield: %s or %s",
	OPT_BARRIER_POTIONS = "Protection potions too, in their school's colour",
	OPT_BARRIER_WIDTH = "Width",
	OPT_BARRIER_HEIGHT = "Height",
	OPT_BARRIER_TEXT = "Show how much it still absorbs",
	OPT_BARRIER_TIME = "Show the seconds it has left",
	OPT_BARRIER_ICON = "The shield's icon beside it",
	OPT_BARRIER_COLOR = "%s: colour",
	BARRIER_HINT = "Shadow Ward only stops Shadow damage. Any other shield on you shows too, in its colour (a priest's Power Word: Shield, a mage's ward...): out of combat, as the game shows your buffs. The game only gives the total of every shield on you: with two at once the bar shows both, in the colour of the last one. Move it over the game's own bars with the Move displays button.",
	SEC_GATHER = "Gathering tracking",
	OPT_GATHER = "Herbalism or Mining: remind me to turn on %s or %s out in the world",
	SEC_FOOD = "Food",
	SEC_REPAIR = "Gear and bags",
	OPT_REPAIR = "Remind me beside the chat when my gear wears out or my bags fill up",
	OPT_REPAIR_LOW = "Gear under (%)",
	OPT_REPAIR_BAGS = "Free bag slots, or fewer",
	SEC_GROUP_BUFFS = "Group buffs",
	OPT_GROUP_BUFFS = "Remind me of my buffs someone in my group lacks",
	GROUP_BUFFS_HINT = "The family's reminder: a mage's, a priest's or a druid's buffs. A warlock has none to give, so here it never shows.",
	SEC_REAGENTS = "Reagents",
	OPT_REAGENTS = "Remind me when the reagents my spells use run low, beside the chat",
	REAGENTS_HINT = "Infernal Stone for Inferno, Demonic Figurine for Ritual of Doom, and Soul Shards when the shard count is off. Only for the spells you know, and out of combat. With the legacy talent Reagent Economy, not the ones vendors sell. A vendor that sells one you're low on says so in the chat.",
	OPT_FOOD_ON = "A small reminder when I'm not Well Fed (+5% XP from kills)",
	SEC_DEMON = "Your demon",
	OPT_DEMON_MISSING = "Remind me when I have no demon out",
	OPT_DEMON_CHOICE = "Which one a click summons",
	DEMON_AUTO = "The last one you summoned",
	OPT_SOUL_LINK = "%s: remind me when it isn't on",
	DEMON_HINT = "Not while mounted or dead, nor while Demonic Sacrifice's buff is on you (unless you have Demonic Pact). It also shows in combat; the click only works out of it.",
	SEC_DEMON_HEALTH = "Your demon's health",
	OPT_DEMON_HEALTH = "HEAL YOUR DEMON! when its health drops",
	OPT_DEMON_HEALTH_PCT = "Under (% of its health)",
	DEMON_HEALTH_HINT = "Forever hides your demon's health from addons in combat; the game itself shows the warning and its number. Move it with the Move displays button.",
	-- Talent reset price, under the class trainer's window
	SEC_RESPEC = "Class trainer",
	OPT_RESPEC = "When the talent reset price drops, under your trainer's window",
	RESPEC_HINT = "Blizzard doesn't publish it: players report a step up with each reset (1, 5, 10, then 5 g more up to 50 g) and a step down for each week since the last one. The price the trainer asks is the real one.",
	RESPEC_TITLE = "Talent reset",
	RESPEC_CLASS = "Class talents",
	RESPEC_LEGACY = "Legacy talents",
	RESPEC_LAST = "Last one %s ago, for %s",
	RESPEC_NOW = "Now: %s",
	RESPEC_NOW_ABOUT = "Now: about %s",
	RESPEC_DROPS = "Drops to %s %s (in %s)",
	RESPEC_LOWEST = "It's at its lowest",
	RESPEC_ASKED = "The trainer asked %s, %s ago",
	RESPEC_UNKNOWN = "%s doesn't know when you last reset yet: it writes it down the next time you pay for one.",
	RESPEC_TODAY = "today at %s",
	RESPEC_TOMORROW = "tomorrow at %s",
	RESPEC_ON = "on %s at %s",
	RESPEC_WEEKDAYS = { "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday" },
	RESPEC_MINUTES = "%d min",
	RESPEC_HOURS = "%d h",
	RESPEC_DAYS = "%d days",
	OPT_PROC = {
		trance = "%s (Affliction, Nightfall: your next Shadow Bolt is instant): shadow flames on both sides of you",
		harvest = "%s (Affliction: mana while you cast, after a kill with Drain Soul): souls rising behind you",
		decimation = "%s (Demonology: Soul Fire faster and free): a ring of fel fire at your feet",
		shadow = "%s (Destruction, after Conflagrate: more Shadow damage): an ember over your left shoulder",
		flame = "%s (Destruction, after Shadowburn: more Fire damage): an ember over your right shoulder",
	},
	OPT_PROC_COLOR = "%s: colour",
	PROCS_HINT = "Each one shows only if your build has its talent (Shadow and Flame also needs Conflagrate or Shadowburn). A burst as it procs, then calmer while it lasts, with its seconds. The game itself shows them, so they work in combat too; changes made in a fight wait until it's over.",
	SEC_PROCS_ALL = "All of them",
	OPT_PROCS_SIZE = "Size (%)",
	OPT_PROCS_X = "Left or right",
	OPT_PROCS_Y = "Down or up",
	OPT_PROCS_GAP = "Space between the flames' sides",
	OPT_PROCS_ALPHA = "Strength of the burst as it procs (%)",
	OPT_PROCS_CALM = "Strength afterwards, while it lasts (%)",
	OPT_PROCS_TIMER = "The seconds they have left",
	OPT_PROCS_TIMER_SIZE = "Size of the number",
	OPT_PROCS_TEST = "See how they look",
	TRY = "Try it",
	PROCS_MOVE_HINT = "They go around your character: drag them all with the Move displays button.",
	SEC_DISTANCE = "Distance",
	OPT_RANGE_ON = "Show the range to your target",
	OPT_ONLY_COMBAT = "Only in combat",
	OPT_SHOW_STATE = "Show the state under the number",
	OPT_FAR = "Glow in the last 5 yards of your reach",
	OPT_RANGE_SPELL = "Spell that measures it",
	RANGE_SPELL_AUTO = "The last one you cast",
	SEC_LOOK = "Look",
	OPT_DISPLAY = "Show",
	DISPLAY = { number = "One number (32 yd)", bracket = "Between two checks (30-35 yd)" },
	OPT_UNITS = "Units",
	UNITS = { yards = "Yards", meters = "Metres" },
	OPT_FONT = "Font",
	FONTS = { fredoka = "Fredoka", changa = "Changa", game = "The game's" },
	OPT_STYLE = "Style",
	STYLE = { text = "Number", icon = "Colour square", both = "Both" },
	OPT_POSITION = "Where",
	POSITION = { plate = "On the target's nameplate", free = "Where I put it" },
	OPT_PLATE_SIDE = "Side of the nameplate",
	PLATE_SIDE = { top = "Above", bottom = "Below", left = "Left", right = "Right" },
	OPT_PLATE_GAP = "Distance from the nameplate",
	OPT_SIZE = "Size",
	PREVIEW_HINT = "Click a state to change its colour",
	SEC_THREAT = "Aggro",
	OPT_THREAT = "Warn me before I pull aggro off my demon or the tank",
	OPT_THREAT_PCT = "From (% of their threat)",
	THREAT_HINT = "Solo without a demon you always have the aggro, so then it doesn't show.",
	UNLOCK = "Move displays",
	LOCK = "Lock displays",
	OPT_MINIMAP_BUTTON = "Minimap button",

	-- Minimap button
	TIP_LEFT = "Left click: options",
	TIP_RIGHT_UNLOCK = "Right click: move the displays",
	TIP_RIGHT_LOCK = "Right click: lock the displays",
	TIP_DRAG = "Drag: move this button",
	TIP_SHARDS = "Soul shards: %d",
	TIP_STONE = "%s: %d",

	HELP = {
		"|cff8788eeWarlockGod|r commands:",
		"  /warlockgod  - options (or click the minimap button; /brujo too)",
		"  /warlockgod unlock | lock  - move the displays",
		"  /warlockgod meters | yards  - the range in metres or yards",
		"  /warlockgod range  - what each range check says about your target",
		"  /warlockgod buffs  - what the addon sees of your armor, stones and shards",
		"  /warlockgod procs  - try the procs and see which ones your build has",
		"  /warlockgod wand  - try your wand's swing timer",
		"  /warlockgod cooldowns  - try the pulse of a cooldown back",
		"  /warlockgod respec  - when the talent reset price drops",
		"  /warlockgod button  - show or hide the minimap button",
		"  The reminders also tell herbalists and miners to turn on their tracking out in the world (option in Reminders)",
	},
}

if GetLocale() == "esES" or GetLocale() == "esMX" then
	L.SUBTITLE = "Mejoras para brujos"
	L.NOT_IN_COMBAT = "no en combate: vuelve a probar cuando acabe la pelea."
	L.UNLOCKED = "avisos desbloqueados: arrástralos donde quieras. /brujo bloquear cuando acabes."
	L.LOCKED = "avisos bloqueados."
	L.OTHER_CLASS = "solo para un brujo: en este personaje no se muestra."

	L.REMINDERS_NAME = "Avisos"
	L.CLICK_CAST = "Clic: lanzarlo"
	L.CLICK_CREATE = "Clic: crearla (un fragmento de alma)"
	L.CLICK_IMBUE = "Clic: ponerla en el arma"
	L.CLICK_SOULSTONE = "Clic: en tu objetivo amistoso, o en ti"
	L.CLICK_SUMMON = "Clic: invocarlo"
	L.SOULSTONE_READY = "lista"
	L.SHARDS_NAME = "Fragmentos de alma"
	L.SHARDS_TIP = "Llevas %d. En rojo por debajo de %d y en naranja por encima de %d (en las opciones)."
	L.BUFFS_REPORT = "armadura: %s; piedra de salud: %s; piedra de alma: %s; piedra del arma: %s; fragmentos de alma: %d."
	L.BUFFS_SEEN = "bufos que llevas: %s"
	L.BUFFS_HIDDEN = "el juego esconde tus bufos en combate: vuelve a probar fuera de él."
	L.BUFF_LEFT = "%s, le quedan %s"
	L.BUFF_ON = "%s, sin final"
	L.BUFF_NONE = "sin poner"
	L.BUFF_UNKNOWN = "aún sin ver"
	L.BUFF_NOT_KNOWN = "sin aprender"
	L.STONE_NONE = "no llevas"
	L.STONE_HAVE = "%s (llevas %d)"
	L.WEAPON_ON = "puesta en el arma"
	L.WEAPON_OFF = "sin poner en el arma"

	L.FOOD_NAME = "Comida, reactivos y reparaciones"
	L.FOOD_MISSING = "Sin exp de comida"
	L.CLICK_FOOD = "Clic: tu comida de exp"
	L.CLICK_EAT = "Clic: comerla"
	L.NO_XP_FOOD = "No llevas comida de exp"
	L.WELL_FED = "Bien alimentado"
	L.FOOD_STOCK = "comida de exp en tus bolsas: %s"

	L.DEMON_MISSING = "No tienes ningún demonio fuera."
	L.DEMON_HEALTH = "¡CURA A TU DEMONIO! %d%%"
	L.DEMON_HEALTH_NAME = "Vida del demonio"

	L.RANGE = {
		melee = "Cuerpo a cuerpo",
		drain = "Alcance de drenar",
		ranged = "A distancia",
		far = "Al límite",
		out = "Fuera de alcance",
	}
	L.RANGE_NO_TARGET = "no tienes objetivo."
	L.RANGE_REPORT = "%s a %d-%d yd; %s llega a %d yd y dice %s."
	L.RANGE_STEPS = "comprobaciones: "
	L.RANGE_LOADING = "(faltan por cargar algunos objetos de distancia)"
	L.RANGE_YES = "sí"
	L.RANGE_NO = "no"
	L.UNITS_SET = "distancia en %s."
	L.THREAT = "AGRO %d%%"
	L.THREAT_PULLED = "¡TIENES EL AGRO!"
	L.THREAT_NAME = "Agro"

	L.PROCS_NAME = "Procs"
	L.PROCS_WATCHING = "%s: vigilando los hechizos %s."
	L.PROCS_NOT_READY = "%s aún no está montado: el addon lo monta fuera de combate."
	L.PROCS_REFUSED = "el juego no aceptó las animaciones de %s, así que no saldrá."
	L.PROCS_NO_TALENT = "%s: apagado, tu build no tiene %s."

	L.TAB_BUFFS = "Recordatorios"
	L.TAB_DEMON = "Demonio"
	L.TAB_RANGE = "Distancia"
	L.TAB_THREAT = "Agro"
	L.TAB_PROCS = "Procs"
	L.TAB_WAND = "Varita"
	L.TAB_COOLDOWNS = "Cooldowns"
	L.PULSE_NAME = "Cooldown listo"
	L.SEC_PULSE = "Tus cooldowns gordos, de vuelta"
	L.OPT_PULSE = "Su icono en grande en el centro cada vez que uno está listo otra vez"
	L.PULSE_SOULSTONE = "Piedra de alma (su media hora)"
	L.OPT_PULSE_SIZE = "Tamaño"
	L.OPT_PULSE_ALPHA = "Intensidad (%)"
	L.OPT_PULSE_COLOR = "Color del destello de detrás"
	L.OPT_PULSE_TEST = "Ver cómo queda"
	L.PULSE_HINT = "Aparece de golpe y se desvanece en menos de un segundo. Solo de los hechizos que sabes. En combate Forever esconde cuánto le falta a un cooldown, pero no si está corriendo, así que también sale en las peleas; el cooldown global no cuenta. Si vuelven dos a la vez, salen uno detrás de otro. Arrástralo con Mover avisos."
	L.TAB_TARGET = "Objetivo"
	L.DOTS_NAME = "Tus efectos en el objetivo"
	L.SEC_DOTS = "Tus efectos en tu objetivo"
	L.OPT_DOTS = "Iconos pequeños con sus segundos, junto a su placa"
	L.DOT_BANES = "Tu Bane (de agonía, de fatalidad o de estragos)"
	L.DOT_CURSES = "Tu maldición (de los elementos, de debilidad, de temeridad, de lenguas o de agotamiento)"
	L.DOT_CONTROL = "Miedo, Desterrar, Aullido de terror y Espiral de la muerte"
	L.OPT_DOTS_SIZE = "Tamaño de los iconos"
	L.DOTS_HINT = "Solo los tuyos, y solo de los hechizos que sabes (Vulnerabilidad a las Sombras y Marca demoníaca con sus talentos). Los pinta el juego y cuenta su tiempo, también en combate. Sin placa, van donde los pongas con Mover avisos."
	L.SEC_INTERRUPT = "Interrupción"
	L.INTERRUPT_NAME = "Interrupción"
	L.OPT_INTERRUPT = "El icono del %s de tu manáfago junto a tu objetivo mientras lanza algo que se puede cortar y está listo"
	L.INTERRUPT_HINT = "La única interrupción del brujo es el Bloqueo de hechizo del manáfago: solo sale con uno fuera que lo sepa. En combate Forever puede esconder si un hechizo se puede cortar: entonces el propio juego enseña u oculta el icono. Su alcance es el del manáfago, y el addon no puede medirlo."
	L.WAND_NAME = "Barra de la varita"
	L.SEC_WAND = "Barra de golpe de la varita"
	L.OPT_WAND = "Una barra para los disparos de tu varita (Disparar)"
	L.OPT_WAND_TIME = "Segundos hasta el siguiente disparo"
	L.OPT_WAND_ICON = "El icono de la varita a la izquierda"
	L.OPT_WAND_COLOR = "Su color"
	L.OPT_WAND_TEST = "Verla disparar"
	L.WAND_HINT = "Empieza apagada, se enciende según llega el disparo y destella al salir. Se ve mientras disparas y un momento después, y en gris si tu objetivo está fuera de alcance. Forever le dice al juego cada disparo, también en combate. Arrástrala con Mover avisos."
	L.SEC_BUFFS = "Tu armadura"
	L.OPT_BUFFS_ON = "Recordarme lo que me falta"
	L.OPT_ARMOR = "%s y luego %s"
	L.OPT_WARN_TIME = "Avisar antes de que se acabe (minutos)"
	L.OPT_IN_COMBAT = "La armadura y las piedras también en combate"
	L.OPT_CLICK = "Hacer clic en un aviso para lanzarlo (fuera de combate)"
	L.SEC_STONES = "Piedras"
	L.OPT_HEALTHSTONE = "Piedra de salud: recordarme hacerla cuando no llevo"
	L.OPT_SOULSTONE = "Piedra de alma: recordarme hacerla cuando no llevo"
	L.OPT_SOULSTONE_USE = "Y usarla cuando esté lista (en mi objetivo amistoso, o en mí)"
	L.OPT_WEAPON = "Piedra de fuego o de hechizo en el arma"
	L.OPT_WEAPON_CHOICE = "Cuál"
	L.WEAPON_AUTO = "La última que usaste"
	L.STONES_HINT = "En Forever la piedra de fuego y la de hechizo imbuyen el arma. Un clic hace la piedra o la pone en el arma de tu mano derecha. Hacer una gasta un fragmento de alma: sin ninguno, no te lo recuerda."
	L.SEC_SHARDS = "Fragmentos de alma"
	L.OPT_SHARDS = "Contar mis fragmentos de alma"
	L.OPT_SHARDS_ALWAYS = "Siempre, no solo cuando me faltan o llevo demasiados"
	L.OPT_SHARDS_LOW = "En rojo por debajo de"
	L.OPT_SHARDS_MAX = "En naranja por encima de"
	L.BARRIER_NAME = "Escudo"
	L.SEC_BARRIER = "Escudos"
	L.OPT_BARRIER = "Una barra con lo que le queda a tu escudo: %s o %s"
	L.OPT_BARRIER_POTIONS = "También las pociones de protección, del color de su escuela"
	L.OPT_BARRIER_WIDTH = "Ancho"
	L.OPT_BARRIER_HEIGHT = "Alto"
	L.OPT_BARRIER_TEXT = "Mostrar cuánto absorbe todavía"
	L.OPT_BARRIER_TIME = "Mostrar los segundos que le quedan"
	L.OPT_BARRIER_ICON = "El icono del escudo al lado"
	L.OPT_BARRIER_COLOR = "%s: color"
	L.BARRIER_HINT = "Custodia de las Sombras solo para el daño de sombra. Cualquier otro escudo que te pongan también sale, con su color (el Palabra de poder: escudo de un sacerdote, una custodia de mago...): fuera de combate, cuando el juego enseña tus bufos. El juego solo da el total de todos los escudos que llevas: con dos a la vez la barra muestra los dos, del color del último. Ponla encima de las barras del juego con el botón Mover avisos."
	L.SEC_GATHER = "Rastreo de recolección"
	L.OPT_GATHER = "Herboristería o Minería: recordarme poner %s o %s fuera de mazmorras"
	L.SEC_FOOD = "Comida"
	L.SEC_REPAIR = "Equipo y bolsas"
	L.OPT_REPAIR = "Avisarme junto al chat cuando se me gaste el equipo o se me llenen las bolsas"
	L.OPT_REPAIR_LOW = "Equipo por debajo de (%)"
	L.OPT_REPAIR_BAGS = "Huecos libres en las bolsas, o menos"
	L.SEC_GROUP_BUFFS = "Bufos de grupo"
	L.OPT_GROUP_BUFFS = "Avisarme de mis bufos que le faltan a alguien del grupo"
	L.GROUP_BUFFS_HINT = "El aviso común de la familia: los bufos del mago, del sacerdote o del druida. El brujo no tiene ninguno que dar, así que aquí no sale nunca."
	L.SEC_REAGENTS = "Reactivos"
	L.OPT_REAGENTS = "Avisarme junto al chat cuando me queden pocos reactivos de mis hechizos"
	L.REAGENTS_HINT = "Piedra infernal para Inferno, Figurilla demoníaca para Ritual de condenación, y los fragmentos de alma si el contador está apagado. Solo de los hechizos que sabes, y fuera de combate. Con el talento de legado Reagent Economy, no los que venden los vendedores. Un vendedor que tiene uno que te falta lo dice en el chat."
	L.OPT_FOOD_ON = "Un aviso pequeño cuando no llevo Bien alimentado (+5% de exp por muerte)"
	L.SEC_DEMON = "Tu demonio"
	L.OPT_DEMON_MISSING = "Avisarme cuando no tengo ningún demonio fuera"
	L.OPT_DEMON_CHOICE = "Cuál invoca el clic"
	L.DEMON_AUTO = "El último que invocaste"
	L.OPT_SOUL_LINK = "%s: avisarme cuando no esté puesto"
	L.DEMON_HINT = "No sale montado ni muerto, ni con el bufo de Sacrificio demoníaco (salvo que tengas Pacto demoníaco). También sale en combate; el clic solo funciona fuera de él."
	L.SEC_DEMON_HEALTH = "Vida de tu demonio"
	L.OPT_DEMON_HEALTH = "¡CURA A TU DEMONIO! cuando le baje la vida"
	L.OPT_DEMON_HEALTH_PCT = "Por debajo de (% de su vida)"
	L.DEMON_HEALTH_HINT = "En combate Forever esconde a los addons la vida de tu demonio; el propio juego pinta el aviso y su número. Muévelo con el botón Mover avisos."
	L.SEC_RESPEC = "Instructor de clase"
	L.OPT_RESPEC = "Cuándo baja el precio de reiniciar talentos, bajo la ventana del instructor"
	L.RESPEC_HINT = "Blizzard no lo publica: los jugadores cuentan que sube un escalón con cada reinicio (1, 5, 10 y luego 5 g más hasta 50 g) y baja uno por cada semana desde el último. El precio que pide el instructor es el real."
	L.RESPEC_TITLE = "Reinicio de talentos"
	L.RESPEC_CLASS = "Talentos de clase"
	L.RESPEC_LEGACY = "Talentos de legado"
	L.RESPEC_LAST = "El último, hace %s, por %s"
	L.RESPEC_NOW = "Ahora: %s"
	L.RESPEC_NOW_ABOUT = "Ahora: unos %s"
	L.RESPEC_DROPS = "Baja a %s %s (en %s)"
	L.RESPEC_LOWEST = "Ya está en lo más bajo"
	L.RESPEC_ASKED = "El instructor te pidió %s hace %s"
	L.RESPEC_UNKNOWN = "%s aún no sabe cuándo reiniciaste por última vez: lo apunta la próxima vez que pagues uno."
	L.RESPEC_TODAY = "hoy a las %s"
	L.RESPEC_TOMORROW = "mañana a las %s"
	L.RESPEC_ON = "el %s a las %s"
	L.RESPEC_WEEKDAYS = { "domingo", "lunes", "martes", "miércoles", "jueves", "viernes", "sábado" }
	L.RESPEC_MINUTES = "%d min"
	L.RESPEC_HOURS = "%d h"
	L.RESPEC_DAYS = "%d días"
	L.OPT_PROC = {
		trance = "%s (Aflicción, Ocaso: tu próxima Descarga de las Sombras es instantánea): llamas de sombra a los lados",
		harvest = "%s (Aflicción: maná mientras lanzas, tras matar con Drenar alma): almas que suben detrás de ti",
		decimation = "%s (Demonología: Fuego de alma más rápido y gratis): un anillo de fuego vil a tus pies",
		shadow = "%s (Destrucción, tras Conflagrar: más daño de sombra): una brasa sobre tu hombro izquierdo",
		flame = "%s (Destrucción, tras Quemadura de las Sombras: más daño de fuego): una brasa sobre tu hombro derecho",
	}
	L.OPT_PROC_COLOR = "%s: color"
	L.PROCS_HINT = "Cada uno solo sale si tu build tiene su talento (Sombra y llama necesita además Conflagrar o Quemadura de las Sombras). Un estallido al salir y después más tranquilo mientras dura, con sus segundos. Los muestra el propio juego, así que también salen en combate; lo que cambies en una pelea se aplica al acabar."
	L.SEC_PROCS_ALL = "Todos"
	L.OPT_PROCS_SIZE = "Tamaño (%)"
	L.OPT_PROCS_X = "Izquierda o derecha"
	L.OPT_PROCS_Y = "Abajo o arriba"
	L.OPT_PROCS_GAP = "Separación entre los lados de las llamas"
	L.OPT_PROCS_ALPHA = "Intensidad del estallido al salir (%)"
	L.OPT_PROCS_CALM = "Intensidad después, mientras dura (%)"
	L.OPT_PROCS_TIMER = "Los segundos que les quedan"
	L.OPT_PROCS_TIMER_SIZE = "Tamaño del número"
	L.OPT_PROCS_TEST = "Ver cómo quedan"
	L.TRY = "Probar"
	L.PROCS_MOVE_HINT = "Van alrededor de tu personaje: arrástralos todos con el botón Mover avisos."
	L.SEC_DISTANCE = "Distancia"
	L.OPT_RANGE_ON = "Mostrar la distancia a tu objetivo"
	L.OPT_ONLY_COMBAT = "Solo en combate"
	L.OPT_SHOW_STATE = "Mostrar el estado debajo del número"
	L.OPT_FAR = "Brillar en las últimas 5 yardas de tu alcance"
	L.OPT_RANGE_SPELL = "Hechizo que la mide"
	L.RANGE_SPELL_AUTO = "El último que lanzaste"
	L.SEC_LOOK = "Aspecto"
	L.OPT_DISPLAY = "Mostrar"
	L.DISPLAY = { number = "Un número (32 yd)", bracket = "Entre dos comprobaciones (30-35 yd)" }
	L.OPT_UNITS = "Unidades"
	L.UNITS = { yards = "Yardas", meters = "Metros" }
	L.OPT_FONT = "Letra"
	L.FONTS = { fredoka = "Fredoka", changa = "Changa", game = "La del juego" }
	L.OPT_STYLE = "Estilo"
	L.STYLE = { text = "Número", icon = "Cuadrado de color", both = "Los dos" }
	L.OPT_POSITION = "Dónde"
	L.POSITION = { plate = "En la placa del objetivo", free = "Donde yo la ponga" }
	L.OPT_PLATE_SIDE = "Lado de la placa"
	L.PLATE_SIDE = { top = "Encima", bottom = "Debajo", left = "Izquierda", right = "Derecha" }
	L.OPT_PLATE_GAP = "Separación de la placa"
	L.OPT_SIZE = "Tamaño"
	L.PREVIEW_HINT = "Haz clic en un estado para cambiar su color"
	L.SEC_THREAT = "Agro"
	L.OPT_THREAT = "Avisarme antes de quitarle el agro a mi demonio o al tanque"
	L.OPT_THREAT_PCT = "Desde (% de su amenaza)"
	L.THREAT_HINT = "Solo y sin demonio siempre tienes tú el agro, así que entonces no sale."
	L.UNLOCK = "Mover avisos"
	L.LOCK = "Bloquear avisos"
	L.OPT_MINIMAP_BUTTON = "Botón del minimapa"

	L.TIP_LEFT = "Clic izquierdo: opciones"
	L.TIP_RIGHT_UNLOCK = "Clic derecho: mover los avisos"
	L.TIP_RIGHT_LOCK = "Clic derecho: bloquear los avisos"
	L.TIP_DRAG = "Arrastrar: mover este botón"
	L.TIP_SHARDS = "Fragmentos de alma: %d"

	L.HELP = {
		"Comandos de |cff8788eeWarlockGod|r:",
		"  /brujo  - opciones (o clic en el botón del minimapa; también /warlockgod)",
		"  /brujo desbloquear | bloquear  - mover los avisos",
		"  /brujo metros | yardas  - la distancia en metros o en yardas",
		"  /brujo rango  - qué dice cada comprobación de distancia de tu objetivo",
		"  /brujo bufos  - lo que el addon ve de tu armadura, piedras y fragmentos",
		"  /brujo procs  - probar los procs y ver cuáles tiene tu build",
		"  /brujo varita  - probar la barra de golpe de la varita",
		"  /brujo pulso  - probar el aviso de un cooldown que vuelve",
		"  /brujo talentos  - cuándo baja el precio de reiniciar talentos",
		"  /brujo boton  - mostrar u ocultar el botón del minimapa",
		"  Los avisos también recuerdan a herboristas y mineros poner su rastreo fuera de mazmorras (opción en Recordatorios)",
	}
end

ns.L = L
