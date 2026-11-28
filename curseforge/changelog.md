# 1.3.2

- **No more false "back" pulses after shooting your wand**: each shot shows your spells cooling down for a moment, and since the game hides cooldown times in a fight, that looked like their own cooldown. Now the time you spend shooting, and a moment after, doesn't count.

# 1.3.1

- **No more false "back" pulses** in combat (Death Coil, Howl of Terror...): casting instant spells one after another kept the global cooldown running non-stop, and since the game hides cooldown times in a fight, that looked like those spells cooling down. Now the global cooldown is checked on its own and its time doesn't count.
- **Nor after a silence, a stun or a school lockout**: while one lasts, the game shows every spell cooling down, and when it ended the addon took them as back. Now that time doesn't count either.
- **Fixed a Lua error** ("Auras cannot be accessed when secret while tainted") when a group member was in combat: the group buff rows now leave them out until the fight is over.

# 1.3.0

- **Missing buffs row** in dungeons and raids: a small row with the buffs your group can give you and you don't have (Arcane Intellect with a mage in the group, Fortitude with a priest, Mark of the Wild with a druid, a blessing per paladin). Click one to ask for it in the group chat ("Missing Arcane Intellect"); the paladin's lets you pick the blessing to ask for, and remembers it. Your own class's buffs are left out, and nothing in combat. Drag it with Move displays; an option turns it off, another shows it outside dungeons too.

# 1.2.0

- **Reagent vendors on the world map**: the vendors who sell the reagents of the spells you know (Infernal Stones, Demonic Figurines), only your faction's, each pin with the reagent's icon. Hover one for what it has of yours and how many you carry; click it for a waypoint (TomTom's if you have it). None with Reagent Economy. An option in the reagents section turns it off. Data from QuestieDB. If you update with the game open, restart it: the addon brings a new Libs folder.

# 1.1.0

- **Repair at a merchant** (an option, off by default): talking to a merchant who repairs fixes everything you wear and carry with your money, and says in the chat what it cost; without enough money it says so. Only this class's addon does it, so with every ...God addon on you pay once.
- **Buy your reagents at a merchant** (an option, off by default): a merchant who sells one you spend tops you up to a handful (10 runes, 20 powders, candles or feathers, 5 seeds...), only for the spells you know and not with Reagent Economy; it buys only what your money pays for and says in the chat what it bought and spent. Works with the low reagent reminder off too.
- **Cooldown pulses**: casting several spells in a row (your buffs from the reminders, say) no longer makes spells that weren't cooling down pulse as if they had come back: a global cooldown's time no longer counts.

# 1.0.3

- The Spell Lock warning no longer shows for casts that can't be interrupted. In a fight Forever hides that from addons, so the game itself now shows or hides the icon. It's also smaller: just Spell Lock's icon with a soft glow.

# 1.0.2

- With another class, WarlockGod now shows nothing at all: no reminders, bars, samples or chat lines on top of your other ...God addons. Only its minimap button and its options stay; Move displays says there's nothing to move.

# 1.0.1

- Fixed Lua errors on login: some texts were written before they had a font.

# 1.0.0

- First release, in English and Spanish:
  - **Procs**, small, each with its own drawing and its seconds, and only for the build that has its talent: shadow flames on Shadow Trance, souls rising on Soul Harvest, a ring of fel fire on Decimation, and an ember over each shoulder for the two halves of Shadow and Flame.
  - **Clickable reminders** above your character: your demon (a click summons it), Soul Link, Demon Skin or Demon Armor, Forever's Firestone or Spellstone on your weapon, your healthstone and soulstone (make them, and use the soulstone when it's ready), and Find Herbs or Find Minerals out in the world.
  - **Your effects on your target** beside its nameplate: Corruption, Immolate, your Bane and Curse, Siphon Life, your Fear, Banish, Howl or Death Coil, Shadow Vulnerability and Demonic Brand.
  - **Your big cooldowns back**, big in the middle, and **INTERRUPT!** when your Felhunter's Spell Lock is ready.
  - A **shield bar** (Shadow Ward, your Voidwalker's Sacrifice, protection potions and any other shield on you), a **wand swing timer** and a **soul shard count**.
  - HEAL YOUR DEMON! when its health drops, the **range** to your target and an **aggro warning** with your demon or in a group.
  - Beside the chat: Well Fed with your XP food, the reagents you're running low on, worn gear and full bags.
  - The talent reset price at your trainer.
