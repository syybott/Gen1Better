# 🎨 Artist & Creator Launch Pad

Welcome! Gen1Better turns Gen 1 widescreen into an open canvas for pixel artists, storytellers, and modders. You do not need to be a low-level engine programmer to put your art or narrative into the game.

Choose what you want to build below:

---

## 🧭 What do you want to do?

### 1. Make a Custom Battle Backdrop Pack
> *"I have 320×180 pixel-art backgrounds and want them to appear behind Pokémon during battle."*
- **No engine coding required**: Use the **3 Safe Doors** (*Here is my image*, *Here is when it appears*, *Here is how shadows look*).
- Complete beginner quickstart, folder layout, copy-paste `main.lua` templates, and encounter recipes.
- 👉 **[Go to the Artist Backdrop Pack Quickstart](Artist-Backdrop-Packs.md)**

---

### 2. Make a Cinematic Story Cutscene (BetterScenes)
> *"I want to create narrative scenes outside of combat with character sprites, comic dialogue bubbles, emotes, camera shakes, and weather."*
- Position actors with grounded feet coordinates, mirror sprites, and add animated speech/thought bubbles that track mouth anchors.
- Multi-step declarative timeline runner (`playSequence`) with player input barriers and smooth transitions into combat.
- 👉 **[Go to the BetterScenes Cutscene Guide](BetterScenes.md)**

---

### 3. Style & Customize Floor Shadows (BetterShadows)
> *"I want to adjust ground shadows for my custom scenes (space, caves, water) or custom Pokémon / Fakemon."*
- Unified Actor Shadow Engine (`schemaVersion = 1`, `profileVersion = 1`) with soft feathered multi-ring contact ovals.
- Configure scene tinting, water reflections, zero-G space suppression, or register custom species footprint baselines.
- 👉 **[Battle Scene Shadow Settings](Battle-Backdrops.md#shadow-system-and-scene-interaction)**
- 👉 **[Story Actor Shadows & Floor Contact](BetterScenes.md#actor-shadows--floor-contact)**

---

### 4. Trigger Custom Battles & Arena Transitions
> *"I want to script a custom boss encounter, spawn a special trainer with unique art, or shift the arena mid-battle."*
- Hook into encounter selection (`bettermenus.battle_backdrop`) or smoothly crossfade arena art and ledge elevations mid-fight.
- 👉 **[Custom Spawn & Encounter Hooks](Battle-Backdrops.md#custom-spawn-hook)**
- 👉 **[Mid-Battle Scene Changes & Elevation Lerping](Battle-Backdrops.md#dynamic-scene-changes--transitions)**

---

### 5. Detailed API & Developer Contract
> *"I want complete technical documentation for Lua exports, provider ownership, render composition passes, and UI scaling."*
- Comprehensive reference for `betterBattle`, `betterScenes`, hooks, and screen markers.
- 👉 **[Provider & Mod Compatibility Reference](Compatibility.md)**

---

## 📐 The Golden Rule: Strictly 320×180 Pixels

All backdrops and cutscenes operate on an exact **320×180 Restomod Hard Wall**. 
In 16:9 widescreen, 180 is an exact mathematical divisor of all standard display heights:
- **720p**: $180 \times 4 = 720$ ($4\times$ exact integer scale)
- **1080p**: $180 \times 6 = 1080$ ($6\times$ exact integer scale)
- **1440p**: $180 \times 8 = 1440$ ($8\times$ exact integer scale)
- **4K**: $180 \times 12 = 2160$ ($12\times$ exact integer scale)

Because artwork uses nearest-neighbor integer scaling, every pixel of your art maps to a clean, razor-sharp block of screen pixels with zero blur, distortion, or shimmering.

### Automated Validator
Before packaging your artwork, run the Python validator included in the mod repository:
```bash
python tools/verify_backdrop.py assets/my_art_320.png
```
It confirms exact dimensions, 16:9 aspect ratio, integer-scaling sharpness at 1080p/4K, and warns if any accidental transparent pixels exist.
