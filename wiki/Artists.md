# 🎨 Artist & Creator Launch Pad

Welcome! Gen1Better turns Gen 1 widescreen into an open canvas for pixel artists, storytellers, and modders. You do not need to be a low-level engine programmer to put your art or narrative into the game.

Choose what you want to build below:

---

## 🧭 What do you want to do?

### 1. Make a Custom Battle Backdrop Pack
> *"I have 320×180 pixel-art backgrounds and want them to appear behind Pokémon during battle."*
- **No engine coding required**: Use the **3 Safe Doors** (*Here is my image*, *Here is when it appears*, *Here is how shadows look*).
- Complete beginner quickstart, folder layout, copy-paste `main.lua` templates, and encounter recipes.
- 👉 **[Go to the Artist Backdrop Pack Quickstart](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs)**

---

### 2. Make a Cinematic Story Cutscene (BetterScenes)
> *"I want to create narrative scenes outside of combat with character sprites, comic dialogue bubbles, emotes, camera shakes, and weather."*
- Position actors with grounded feet coordinates, mirror sprites, and add speech/thought bubbles placed at mouth anchors; reposition them after actor movement when needed.
- Multi-step declarative timeline runner (`playSequence`) with player input barriers and smooth transitions into combat.
- 👉 **[Go to the BetterScenes Cutscene Guide](https://github.com/syybott/Gen1Better/wiki/BetterScenes)**

---

### 3. Style & Customize Floor Shadows (BetterShadows)
> *"I want to adjust ground shadows for my custom scenes (space, caves, water) or custom Pokémon / Fakemon."*
- Unified Actor Shadow Engine (`schemaVersion = 2`, `profileVersion = 1`) with soft feathered multi-ring contact ovals.
- Configure scene shadow tint and gain, suppress shadows for space, or register custom species footprint baselines.
- 👉 **[Battle Scene Shadow Settings](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#shadow-system-and-scene-interaction)**
- 👉 **[Story Actor Shadows & Floor Contact](https://github.com/syybott/Gen1Better/wiki/BetterScenes#actor-shadows-and-floor-contact)**

---

### 4. Trigger Custom Battles & Arena Transitions
> *"I want to script a custom boss encounter, spawn a special trainer with unique art, or shift the arena mid-battle."*
- Hook into encounter selection (`bettermenus.battle_backdrop`) or smoothly crossfade arena art and ledge elevations mid-fight.
- 👉 **[Custom Spawn & Encounter Hooks](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#custom-spawn-hook)**
- 👉 **[Mid-Battle Scene Changes & Elevation Lerping](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#dynamic-scene-changes--transitions)**

---

### 5. Detailed API & Developer Contract
> *"I want complete technical documentation for Lua exports, provider ownership, render composition passes, and UI scaling."*
- Comprehensive reference for `betterBattle`, `betterScenes`, hooks, and screen markers.
- 👉 **[Provider & Mod Compatibility Reference](https://github.com/syybott/Gen1Better/wiki/Compatibility)**

---

## 📐 The Golden Rule: Strictly 320×180 Pixels

All backdrops and cutscenes operate on an exact **320×180 Restomod Hard Wall**. 
In 16:9 widescreen, 180 is an exact mathematical divisor of all standard display heights:
- **720p**: $180 \times 4 = 720$ ($4\times$ exact integer scale)
- **1080p**: $180 \times 6 = 1080$ ($6\times$ exact integer scale)
- **1440p**: $180 \times 8 = 1440$ ($8\times$ exact integer scale)
- **4K**: $180 \times 12 = 2160$ ($12\times$ exact integer scale)

At those full 16:9 viewport sizes, nearest-neighbor sampling gives uniform pixel blocks. Other window sizes can use fractional scales; author at 320×180 and check the intended display sizes.

### Automated Validator
Before packaging your artwork, run the Python validator included in the mod repository:
```bash
python tools/verify_backdrop.py assets/my_art_320.png
```
It checks the opaque 320×180 PNG contract and reports pixel-art heuristics. Any transparency fails. Native-only inspection does not verify in-game 1080p/4K output; optional counterpart comparisons provide additional image measurements. See the [validator details](https://github.com/syybott/Gen1Better/wiki/Battle-Backdrops#validation-script).
