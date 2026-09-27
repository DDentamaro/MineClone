<!-- Inventario statico del prototipo v0_64 (redatto in inglese durante M0, sessione del 27/09/2026). Righe = righe di reference/isoterra_proto_v0_64_humanoids.html. Nessuna esecuzione in browser. -->

# IsoTerra v0.64 "humanoids": inventory for the Godot port

Source: `cec68f9b-isoterra_proto_v0_64_humanoids.html`: 8,333 lines, 2,128,428 bytes.
SHA-256: `2f2f771f3a83af9b016de9e024cc38a3ce8282bb97d289809a4edc9474a5c76a`.
`<title>`: "IsoTerra · v0.64 · acqua a livelli, correnti e cascate volumetriche". `root.ISO.version` is `"0.64"` (line 8325).

This report is based on static reading only. Status labels:
- **ACTIVE**: reached from `boot()`, the frame loop, or an input handler.
- **DORMANT**: defined but never called, or forced off.
- **LEGACY**: still runs, but it belongs to an older system and has no real effect.

**Key finding.** Despite the "humanoids" name, this file already contains the mob-combat stack: `ENEMY_TYPES` (slime, skeleton, goblin), `BasicEnemy`, `spawnBasicEnemies`, `PLAYER` vitals with death and respawn, lock-on, strafe, damage numbers and HP bars. Up to about line 7430 its line numbers match the plan (which was written for v0_66) almost exactly. From the combat section onward, v0_64 is about 70–80 lines shorter.

---

## 1. Script block map

| Lines | Block | Contents | Size |
|---|---|---|---|
| 1–76 | `<head>` CSS + DOM | Styles. Line 14: `.hud,.help{display:none!important}`. DOM: `#view` canvas, `#fx`, `#joy`, `.hud` (62), `.tools` (63–68), `.bottom` (70), `#composer` (71–75) | 9.2 KB |
| 77–83 | `<script>` | `window.ISO_REPORT` error box; handlers for `error`, `unhandledrejection` and `webglcontextlost` | 1.4 KB |
| 84–86 | `<script>` | Writes errors into `#status` | 0.1 KB |
| 87–4209 | `<script>` | `/* vendor/three-r185.js */`: minified Three.js r185. Lines 89, 93, 3759, 4048, 4172, 4196 and 4145 are very long | 532 KB |
| 4210–4244 | `<script>` | `src/pipeline.js`: `RMD_THREE` (createRenderer, rawPass, assertNearest) and `RMD_PIX_ISO` (RT_H 270/360/450, TILE_W, PX_PER_UNIT, CAM_DIST 120, rtSize, orthoBounds, setRes; localStorage `isoterra.rtH`) | 2.8 KB |
| 4245 | `<script id="hair-data" type="application/json">` | Quantized hair meshes `ciuffo` and `lungo` (base64). Read by `CharacterSkinned` (6632) | 29 KB |
| 4246–4481 | `<script id="chargen">` | `CHARGEN v2`: rbox primitives, `OPTIONS` (4311), `BASE` (4326), `PRESETS` eroe1/eroe2 (4328), `build`, `randomDna`, `CG.rig={restBones,bakeAO,toRig,SLOT,S}` (4478) | 34 KB |
| 4482 | `<script id="isochar-predone" type="application/json">` | `ISOCHAR1` baked vertex-animation asset "Predone" (raider). vcount 7214; clips idle (20 frames at 6 fps), walk (11 at 12), attack (11 at 12, hit .45), death (12 at 12); gzip + base64 | **1.09 MB** |
| 4483–5110 | `<script id="iso-core">` | `src/core.js` → `ISO_CORE` (pure JS, no Three). Its text is reused as the Worker source (7045) | 57 KB |
| 5111–5666 | `<script>` | `src/shaders.js` → `window.ISO_SHADERS` (5213). GLSL3 RawShaderMaterial sources | 41 KB |
| 5667–8331 | `<script>` | 5668: `const GRASS_LEAF_DATA` (base64 PNG, **never referenced**). 5669–8330: `src/app.js`, the IIFE with `boot()` | 331 KB |

Note: line 7117 contains the text `<script id="isochar-predone">`, but it sits inside a JS comment and is not a tag.

### ISO_CORE internal map (4483–5110)
- 4489–4495: `B`, `NAMES`, `OPAQUE`/`SOLID`/`EMIT`, `CH=16`
- 4498–4508: mulberry32, hash3, noise2/3, fbm2
- 4511–4520: `class World`
- 4526–4600: `BIOME`, `BIOMES`, spline, subSeed, `GEN_PASSES`
- 4601–4608: `generate`, `spawnPoint`
- 4613–4633: `computeLight`
- 4638–4709: `meshChunk` (greedy mesher, AO, torch boxes), `pack`
- 4712–4720: `moveAABB` (unused by the app)
- 4722–4735: `raycast` (DDA)
- 4741–4866: density, surface nets (`meshChunkSmooth`, `grassOnMesh`), `buildHeightGrid`, `fieldHeight`/`fieldSupport`/`slopeClass`
- 4871–4892: local updates, `canPlaceBlock`, `applyEdit`
- 4894–4957: tree templates, `treeSpots`, `grassBlades`
- 4959–4963: `isCovered`, `occluded`
- 4965–5103: fluid system
- 5105: `ISO_CORE` export

### ISO_SHADERS keys (5213–5664)
blitVS 5214, blitFS 5218, chunkVS 5278, chunkFS 5284, grassVS 5342, grassFS 5371, treeVS 5392, treeFS 5407, smoothVS 5422, smoothFS 5431, shadowFS 5478, trailVS 5484, trailFS 5487, silFS 5490, shadowVS 5494, shadowDepthFS 5500, particleVS 5508, particleFS 5518, bakedVS 5525, bakedFS 5530, entityVS 5540, entityFS 5546, crackVS 5553, crackFS 5557, waterVS 5576, waterFS 5581, skyFS 5640.

Shared GLSL:
- `RUSTIC_GLSL` 5117
- `LIGHT_GLSL` 5145: point lights (up to 6), Bayer dither, cloud shadow, 2×2 PCF shadow map, `rusticLightM` banded light, `shadeTint`, `quantize`
- `XRAY_GLSL` 5200: checkerboard ghost hole

### app.js internal map (5669–8330)
- 5675: `WORLD={X:192,Y:48,Z:192}`
- 5676–5700: sky and lighting state (DAY/DUSK/NIGHT, `skyState`, `SHADOW`, `PTL` point lights)
- 5704: `makeAtlas`
- 5718–5762: `makeWorker`, with a main-thread fake-Worker fallback at 5751
- 5763–6372: `CharacterRig` (v0.23 lathe rig, GAIT, DNA, fist swing)
- 6373–6558: `CharacterRigV2`. **DORMANT**: only built if `USE_PLACEHOLDER_V10` is false
- 6559–6624: `CharacterPlaceholderV10`
- 6629–6677: `CharacterSkinned` (CHARGEN hero). **ACTIVE**
- 6682–6715: `Dummy`. **DORMANT**: never instantiated, only exported
- 6718–6922: `View`
- 6929–7040: `CTRL`, `CLIMB` (unused), `reliefAhead` (unused), `class Game`
- 7043–8327: `boot()`
- 8329: `DOMContentLoaded` → `boot`

---

## 2. Bootstrap trace (call sites followed)

1. Scripts in order: the error reporter (77–83), Three, pipeline (reads `isoterra.rtH`), then CHARGEN (sets `window.CHARGEN`), ISO_CORE (`window.ISO_CORE`) and ISO_SHADERS.
2. Line 8329: `boot()` runs on DOMContentLoaded.
3. `boot()` at 7043:
   - `new View(canvas)` (6718). This creates the renderer, materials and atlas, and `this.character = USE_PLACEHOLDER_V10 ? new CharacterSkinned() : …` (6742). `USE_PLACEHOLDER_V10=true` (6559), so **CharacterSkinned** is active. It falls back to `CharacterPlaceholderV10` if CHARGEN throws. CharacterSkinned reads `hair-data` and localStorage `isoterra.hero.dna` (6645).
   - `new Game()` (6939) allocates a `World(192,48,192)` plus `density`. Initial state: `mode='dig'`, `block=DIRT`, `reach=6.5`, `time=.35`, `dayLen=240`.
   - `makeWorker($('iso-core').textContent)` (7045) builds a Blob Worker from the ISO_CORE source plus the glue code.
   - Locals: `seed=1931`, `mode='blocks'` (7046).
4. Top-level statements inside `boot()` run before the first frame:
   - Input listeners (7058–7059, 7836–7852, 7857–7870).
   - `ISOCHAR.ready = isocharDecode(JSON.parse(#isochar-predone))` (7434). The 1.09 MB raider asset **is decoded at every load**, but `spawnHumanoids()` is never called, so the asset is DORMANT.
   - `syncUI(); trailInit(); setWeapon('sword'); WIELD.state='drawn'` (7871). **The player starts with the sword drawn, not with fists.**
   - `loadDNA()` → `CH().applyDNA()` from `isoterra.char` (7878). This is LEGACY: placeholder setters only store the DNA and have no visual effect (6617–6622).
   - Composer, hero-editor and magic UI wiring; `magicSyncUI()` (8322).
   - `root.MAGIC` and `root.ISO` exports (8323, 8325).
   - `init(seed)` and `requestAnimationFrame(frame)` (8326).
5. `init(1931)` (7047) posts `{type:'init', X:192, Y:48, Z:192, seed:1931, mode:'blocks'}`.
6. Worker `init` handler (5731):
   - `mode='blocks'`: hard-coded, and it ignores `m.mode`.
   - `C.generate(world, seed, {caves:false})`, then `computeLight`, `computeDensity`, `buildHeightGrid`.
   - Posts `ready` with blocks, sun, blk, surface, density, hgrid, fluid, water arrays, biome, climate and `spawn: C.spawnPoint(world)`.
   - Then `meshAll()`, which uses **`meshChunk` (greedy blocks)** plus `grassBlades(...,.27)` only for `cy===0` chunk columns, in batches of 18 chunks.
   - The worker's `mode` message handler (5734) and every `mode==='smooth'` branch (5725, 5736, 5745) are **DORMANT**: nothing posts `{type:'mode'}`, and `#t-mesh` is `hidden` with no onclick.
7. Main thread on `ready` (7049–7052):
   - Copies the arrays and calls `C.initFluid(W, m.fluid)`, `view.setWater(W)` and `view.setClimate`.
   - Places the player at the spawn point: `game.p = {spawn.x, game.ground(), spawn.z}` (spawn is x 96.5, z 96.5).
   - `view.setTrees(W, seed)`, `resetPlayerVitals()`, **`spawnDummies()`**.
   - **`spawnDummies()` (7441) is `{spawnBasicEnemies();}`**. The comment on `const SPAWN_ENTITIES=false` (7440) claims there are no mannequins or enemies, but that constant is **never read**. **Up to 9 enemies ARE spawned** (slime, skeleton, goblin at radii 8, 21 and 34).
8. Frame loop `frame()` (7941–7976), in order:
   1. Hitstop time scaling.
   2. `stepFluid` every 0.25 s, with updates posted to the worker (`fluid`).
   3. Throttled `view.setWater(W, false)` (every ≥100 ms when dirty).
   4. Q/E/Z/X camera keys, `readInput`, `playerVitalsStep`, `game.step`.
   5. Entity push-out.
   6. `lockUpdate`, then `magicCombat` if magic is on, otherwise `combatUpdate`.
   7. `updateFacing`, strafe weight, `updateAnimation`, `magicPose`, `updateAquaticPose`, `contactUpdate`, `debugBoxes`, `trailStep`, `waterEffects`, `magicStep`, `entities.update`, `fx.update`.
   8. Occlusion `coverage()` → x-ray.
   9. `skyState`, TPS context, `frameCamera`, `magicRender`, `view.render`.

   `dtA` (hitstop-adjusted) drives the controller, attacks, rig and entities.

UI at load:
- **Hidden by CSS** (line 14): `.hud` (#fps, #info, #inv, #mana, #vitality, #status) and `.help` (the key help text **and the time-of-day slider**, whose label has class `help`). **HP, mana and kill counts are never visible.**
- **Visible:** `.tools` rows (top right) and `.bottom` row, plus the `#fx` overlay (damage numbers, enemy HP bars).
- **`hidden` attribute:** `#joy` (shown while touching), `#t-auto` (shown in TPS), `#t-mesh` (never shown), `#spell` (shown in magic mode), `#heavy` (shown when a weapon is equipped, so visible at boot), `#composer`.
- `#hint` does not exist in the DOM. `setWeapon` checks for it and skips it (7753).

### ACTIVE / DORMANT / LEGACY summary

| Status | Item |
|---|---|
| ACTIVE | ISO_CORE generation (without caves), light, greedy meshing, fluids, trees, grassBlades |
| ACTIVE | CharacterSkinned hero, sword and other weapons, fist combo, BasicEnemy x3 types, PLAYER vitals, lock-on and strafe, magic, reactions, water, TPS and iso camera, hero editor (`c-open`) |
| DORMANT | Caves (`caves:false`) and therefore lava in the world |
| DORMANT | Smooth mode (surface nets, `meshChunkSmooth`, `grassOnMesh`, `smoothMat`, the worker `mode` message) |
| DORMANT | `fieldHeightSmoothUnused`/`fieldNormalSmoothUnused` (4788, 4796). `fieldNormal` always returns up (4795), so slope classes are always 0 |
| DORMANT | `moveAABB`, `reliefAhead`, `CLIMB`, `View.rotate` |
| DORMANT | `Dummy`, `Humanoid` + `spawnHumanoids` + `ISOCHAR.onPlayerHit` (asset decoded, never spawned) |
| DORMANT | `meleeHit` (7794, commented as unused), `CharacterRigV2`, `GRASS_LEAF_DATA`, `.lockm` CSS, `SPAWN_ENTITIES` |
| DORMANT | Block digging and tree chopping (`resolveTarget`/`breakTarget`/crack overlay): the only tool is `TOOLS.fist` with `hitsBlocks:false` |
| LEGACY | Old composer (`#c-open2`, key C, `#composer` panel, H/O keys, `isoterra.char`). It pauses the game and zooms, but its setters are no-ops on the active hero |
| LEGACY | CharacterRig lathe-rig code still underpins the arms, legs, fist swing and hitboxes of the active hero |
| COMPUTED BUT UNUSED BY THE ACTIVE PATH | `computeDensity` and `buildHeightGrid`: they are run and transferred. Only `groundHeight` in `treeSpots` (tree Y) reads the density; `fieldHeight` reads blocks directly |

---

## 3. Plan section-3 rows re-mapped to v0_64

| System | v0_64 lines | Status | Verified facts |
|---|---|---|---|
| Mondo e blocchi | 4489–4495 (B/NAMES/flags); World 4511–4520 | active | 16 IDs including AIR (0–15). Finite 192×48×192 world. `CH=16` chunks, giving 12×3×12 = 432 chunks. See §4 and §5 |
| Generazione | passes 4522–4600; `generate` 4601–4607; `spawnPoint` 4608 | active | 11 named passes, each with its own seed `mulberry32(subSeed(seed,name))`: Campi, Quote, Laghi, Fiumi, Terrazze, Argini, Biomi, Strati, Grotte, Minerali, Rifinitura. Then `shapeRiverBanks`, `initFluid`, and ≤160 `stepFluid(…,200000)` ticks. SEA = round(48·.55) = 26. Six biomes (4527–4533). Massif ~62 blocks from centre. Lakes ≤9 (first one ~23 from spawn). 2 rivers with waterfalls. Terraces cap neighbour Δh ≤ 2. Ores: copper, iron (<40% Y), gold (<20% Y) |
| Grotte | pass 4593–4596; forced off at worker 5731 `{caves:false}` | **dormant** | Two noise3 tunnel systems. Cells with y<4 (or y<3 in the second system) become LAVA. With caves off, no lava exists, which also makes the lava-quench reaction unreachable in practice |
| Meshing e luce | light 4613–4633; mesher 4638–4709; worker 5718–5762; `View.setChunk` 6811 | active | Sun: 15 straight down, −1 sideways. Block light: flood fill, torch 14, lava 12. Greedy mesher with per-vertex AO (2 bits), a "cut" flag, and torches as 5-quad boxes. `aData=[tile, face|cut<<3|ao<<4, sun, blk]`. Every edit runs a **full `computeLight`** in the worker, then remeshes chunks within ±2 cells and sends back a light patch of R=18 columns (5736–5739, 5741–5748) |
| Terreno smussato | 4739–4882; smoothVS/FS 5422–5476 | **dormant** (density and hgrid are still computed) | Surface nets at ISO 13.5, weighted 3×3×3 blur. `mode` is hard-coded to 'blocks' in both worker (5731) and main thread (7046) |
| Vegetazione | 4893–4957; `View.setTrees` 6830–6854; treeVS/FS; grass 6819–6829 | active | Three tree archetypes, 2 variants each (6 templates), grouped by 32×32 area; `treeGrid` in 8×8 cells. Trees are cylinder colliders for the player, enemies and projectiles. `killTree` exists but is only reachable from `breakTarget`, which is dormant, so trees cannot be chopped. Grass: `grassBlades` billboards (density .27) on chunk columns with cy=0 |
| Acqua | core 4965–5103; `View.setWater` 6799–6808; `Game.stepWater` 6943–6982; FX 8013–8057; `#water-trip` 8045; waterFS 5581 | active | `FLUID={SOURCE:16, FALLING:32, MAX:8, TICK:.25, SEARCH:4, FALL_LIP_HEIGHT:.5}`. Per-voxel `fluid` byte: level&15 (1–8), source=24, falling=40. Spread favours the nearest drop within 4 cells. Two or more adjacent sources over a solid floor create a new source. Surface corners are shared by rendering and `sampleWater`. Current from `waterGuide` (rivers) or the level gradient; ×.72 horizontally, −2.5 when falling. Per-16×16-column mesh tiles; only dirty tiles are rebuilt |
| Estetica | shaders 5112–5665; View 6718–6922; toggles 7855–7865 | active | Pixel render target (RT_H 360 by default, 270/360/450 via `t-res`); blit with outline, edges, god-rays, dither, "dipinto" (`uPaint` banded light), fog. 2048² shadow map with 34-unit extent, texel-snapped. Cloud shadows, sky with sun, moon and stars. Two-pass x-ray (`rtB` with scissor) with a checkerboard hole, plus silhouettes. Day length 240 s |
| Camera | `View` 6718–6922 (TPS 6863–6888, iso 6889–6903) | active | Iso: orthographic, yaw starts at π/4, pitch 38° (clamped 22–62°), zoom .55–2.4, pixel-snapped. TPS: perspective 52° FOV, distance 6.5 adjusted by speed, ceiling and lock; zoom .28–3.4; pitch −.22 to 1.42; wall pullback via voxel march plus tree test. Auto-follow and auto-framing of the lock target (`tpsAuto`). Lock-on shifts the look target (7967) |
| Movimento | `CTRL` 6929; `Game.step` 6987–7039 | active | speed 5.5, stepUp 1.05, stepDown .08, jumpH 2.1, g 28, radius .26, airCtl .45, landRec .28. Auto "ramp" up steps ≤1.05 within 1.15 ahead (×.72 speed on ramp). Stepped descent ≤1.08. Walls block. Landing slowdown after drops >1.2. Tree push-out. `fieldHeight` = top of the solid column below yRef+1.08. **Slope classes are inert** (`fieldNormal` returns up) |
| Nuoto | 6941–6982 | active | Enter: depth>.9, immersion>.76, v.y<2. Stay: depth>.65, immersion>.18. Swim speed 2.65 plus current. Buoyancy targets level−.72 with a bob. Jump exits when immersion ≤1.05. Wading slows to max(.52, 1−depth·.42) when deeper than .12. Swimming disables combat, magic and lock (7951–7954), and enemies go back home (7356) |
| Avatar | CHARGEN 4246–4481; CharacterRig 5803–6372; Placeholder 6559–6624; **CharacterSkinned 6629–6677**; hero editor 7898–7915 (`#c-open` 7917); legacy composer 7875–7924 | active (editor) / legacy (composer) | Hero recipe ~500 bytes: `BASE` + `OPTIONS` (14 groups), presets eroe1 and eroe2, random. Saved to `isoterra.hero.dna` as `{i, dna}`. `#c-hero` cycles Eroe 1 / Eroe 2 / A caso. `#c-dna` pastes a JSON recipe. The editor panel is **7900**, not 7980 as in the plan |
| Corpo a corpo | TOOLS 7107; fist COMBO 7756; fist path 7806–7834; hitboxes 6087; weapons 7490–7572; `bladeAttack` 7610; `bladeContact` 7637; `bladeStep` 7671; wield 7684–7730; trail 7731–7749; `setWeapon`/`cycleWeapon` 7750–7755 | active | Five weapons: fist, sword, spear, hammer, great(sword). Hitstop, lunge, sweep contact, one hit per target per attack, knockback. Details in §7 |
| Combo spada | `SWORD_COMBO` **7543–7550**; tree logic 7616–7620 | active | L, LL, LLL, LLLL, H, LH, LLH (plan cites 7625–7632, which is off by ~80 lines) |
| Nemici | ENEMY_TYPES 7183–7187; `BasicEnemy` 7232–7408; `spawnBasicEnemies` 7409–7420; `visitEnemy` 7421–7431 (`#enemy-trip` 8324); `enemySpot` 7212; LOS 7208 | **active** | Slime, skeleton, goblin with distinct builds (slime: voxel jelly with translucent shell and lunge; skeleton and goblin re-skinned with CHARGEN parts via `matchHeroStyle` 7240). States: idle, chase, attack, stagger, return, dead. LOS raycast every .22 s within 12 units. Leash 13; give up at d>11. Respawn after 25 s, only if the player is >9 from home. Full heal on returning home |
| Vita giocatore | PLAYER 7188; `enemyPlayerHit` 7190–7197; `playerVitalsStep` 7198–7207 | **active** (HUD hidden) | 100 HP. Invulnerable .65 s after a hit. Death timer 2.6 s, then respawn at `PLAYER.home` (the spawn point) with 3 s invulnerability. Regen 5 HP/s after 7 s without a hit, if no enemy is attacking or chasing within 7. `#vitality` text is updated but hidden by CSS |
| Lock-on e feedback | lock 7776–7783; keys 7860; `#lock` 7861; strafe 7061–7089 and 7957; fx 7442–7469 (damage numbers 7445, HP bars 7447/7469, sparks/cut 7462–7464, lockTri 6750, ground lock marker 7459); trail 7731 | **active** | Range 7.5, drop at 9.5. Candidates are scored by distance − 1.5·frontness. Damage numbers are HTML `.dmg` elements, with `.crit` shown as "★". HP bar label shows ◆ name hp/max and status tags |
| Magia | 7977–8322 (spells 8002–8008; grains 8011, 8059–8120; projectiles 8122–8169; cast 8256–8292; audio 8304–8313; UI 8315–8321) | active | Four elements; mana; gather, release, recover. Details in §8. The plan cites 8059–8403, but this file ends at 8333 |
| Reazioni | 8171–8255 (world 8171–8239; statuses 8240–8255) | active (lava quench effectively dormant) | Details in §8 |
| Scavo | TOOLS 7107; BLOCK_INFO 7108; breakTime/resolveTarget/breakTarget 7757–7775; crack 6747/7832 | **dormant** | `combatUpdate` only resolves a block or tree target `if(combat.tool.hitsBlocks)` (7808), and the only tool is `fist` with `hitsBlocks:false`. The only active world removal comes from spells: the earth crater (8193) and fire burning grass or wood (8229) |
| Costruzione | `act` 7098–7102; `#mode` 7858; `#blk` 7859; keys F/T/1–3 7860; `canPlaceBlock` 4885 | active (mouse); touch only in place mode | Placeable blocks: DIRT, STONE, SAND, WOOD, TORCH (`#blk` cycles them; keys 1/2/3 = DIRT/STONE/WOOD; T = TORCH). Reach `game.reach + 1` = 7.5 from the eye. Placement is refused if it overlaps the player AABB or the target cell is not AIR (or WATER with a solid cell below). No cost |
| Inventario | `inv`/`give` 7109; `syncInv` 7110 | partial | A name→count map. `give` is only reached through `crater()` (earth spell on dirt, grass or sand), since `breakTarget` is dormant. Placing blocks does not consume. The display in `#inv` is hidden |
| Persistenza | see §9 | partial | Only settings, the avatar and camera prefs are saved. No world, inventory or progress save |
| UI mobile | pointer handlers 7835–7852; buttons 7857–7870, 7917, 8321, 8324, 8045 | active | Left 40% width × lower 65% height = floating joystick (touch only). Other touches: camera drag, 2-finger pinch zoom. **A touch tap in dig mode does nothing** (7849): attacks come from `#hit` and `#heavy`, and placing from a tap in place mode. Many debug and graphics buttons are visible in `.tools` |

---

## 4. Block IDs (ISO_CORE, 4489–4494)

`OPAQUE`, `SOLID` and `EMIT` are `Uint8Array(32)`. `OPAQUE=SOLID=1` for IDs 1–9 and 11–14; then `SOLID[LAVA]=0`, `EMIT[TORCH]=14`, `EMIT[LAVA]=12`.

| ID | Key | NAMES (it) | OPAQUE | SOLID | EMIT | BLOCK_INFO hard/tool (7108) |
|---|---|---|---|---|---|---|
| 0 | AIR | aria | 0 | 0 | 0 | – |
| 1 | GRASS | erba | 1 | 1 | 0 | .6 shovel |
| 2 | DIRT | terra | 1 | 1 | 0 | .5 shovel |
| 3 | STONE | pietra | 1 | 1 | 0 | 1.5 pick |
| 4 | SAND | sabbia | 1 | 1 | 0 | .5 shovel |
| 5 | COPPER | rame | 1 | 1 | 0 | 3 pick |
| 6 | IRON | ferro | 1 | 1 | 0 | 3 pick |
| 7 | GOLD | oro | 1 | 1 | 0 | 3 pick |
| 8 | BEDROCK | roccia madre | 1 | 1 | 0 | −1 (unbreakable) |
| 9 | LAVA | lava | 1 | **0** | **12** | −1 |
| 10 | TORCH | torcia | 0 | 0 | **14** | 0 shovel |
| 11 | WOOD | legno | 1 | 1 | 0 | 2 axe |
| 12 | LEAVES | foglie | 1 | 1 | 0 | .2 axe |
| 13 | SANDSTONE | arenaria | 1 | 1 | 0 | .8 pick |
| 14 | DARKSTONE | pietra scura | 1 | 1 | 0 | 2.5 pick |
| 15 | WATER | acqua | 0 | 0 | 0 | – |

`breakTime = hard × (tool can harvest ? 1.5 : 5) / speed` (7757). `treeTime = (4 + 3·scale) × (axe ? 1 : 2.5) / speed` (7758). Both are dormant. WATER is not in the atlas (5704–5716, tiles 0–14) and is meshed by `meshFluid`. The raycast hits OPAQUE blocks or TORCH (4729).

---

## 5. World memory layout

- **Size.** Default `WORLD={X:192, Y:48, Z:192}` (5675), which is 1,769,472 cells. Chunks are 16³ (`CH`): 12×3×12.
- **Index.** `idx(x,y,z) = (y*Z + z)*X + x` (4513). x varies fastest, then z, then y; Y-major slabs.
- **Per-voxel `Uint8Array(X*Y*Z)`:**
  - `blocks`, `sun` (0–15) and `blk` (0–15), in the constructor (4512).
  - `fluid` (`initFluid`, 5040): bits 0–3 level 1..8, bit 4 SOURCE, bit 5 FALLING.
  - `density` (`computeDensity`, 4750; also preallocated by `Game`, 6939).
- **Per-column (N=X·Z):**
  - `surface` U8 (constructor)
  - `biome` U8, `climate` U8×4 (temperature, humidity, peak flag, 255)
  - `waterLevel` U8 (top water y+1; 0 = dry)
  - `waterFlow` F32×2, `riverMask` U8, `waterfallMask`/`waterfallBase`/`waterfallTop` U8, `waterGuide` I8×2 (all created in `generate`, 4602)
  - `waterBodies` U32 (`labelWater`, 5004)
- **Height grid.** `hgrid={C, R, step:.5, h:Float32Array(C*R)}` with C=R=385 (`buildHeightGrid`, 4773). Only used by the dormant smooth path.
- **Other fields:**
  - `fluidQueue` (Set of voxel indices), `fluidDirty` (Set of "cx,cz" keys for 16×16 tiles), `fluidClock`, `fluidRenewSources=true`
  - `genLog`, `biomeShare`, `massif{x,z}`, `waterInfo{lakes, rivers[{len,falls}], cells}`, `bankBlocks`
- **`generate(world, seed, opts)`** (4601). `opts.caves === false` skips the Grotte pass, and no other option is read. It clears the blocks, allocates the per-column arrays, runs the passes, then `shapeRiverBanks`, `initFluid` and up to 160 `stepFluid(W,200000)` ticks. It returns `world`.
- **`spawnPoint(world)`** (4608). Returns `{x:(X>>1)+.5, y, z:(Z>>1)+.5}`, where y = surface+1, raised until two cells are free. The main thread then sets `y = fieldSupport(...)` (7050).
- **Worker bootstrap call.** `C.generate(world, seed, {caves:false})` with `mode='blocks'` (5731). The seed is 1931 by default (7046); `#regen` picks `random·1e6` (7870).
- **Other signatures:**
  - `meshChunk(world,cx,cy,cz,slice)`, where slice is always `world.Y-1`
  - `applyEdit(world,x,y,z,id)` returns the list of chunks to remesh
  - `raycast(world,ox,oy,oz,dx,dy,dz,maxT,slice)` returns `{x,y,z,nx,ny,nz,t,id}`
  - `sampleWater(W,x,y,z)` returns `{wet, level, depth, floor, immersion, flowX/Y/Z, body, falling}`

---

## 6. Controls (actual handlers)

**Keyboard.**
- Movement keys (7058, 7071, 7091):
  - WASD / arrow keys: move, camera-relative.
  - Space: jump (and jump out of water).
  - P: pause.
  - Shift only affects the strafe walk/run cap with the joystick; on keyboard, movement is always full speed (7083).
- Actions (keyup 7059, keydown 7860):
  - J: light attack (tap queued; holding sets `combat.btn`, which repeats fist punches or keeps the magic gather). K: heavy (weapons only).
  - V: next weapon (Shift+V: previous). This also turns magic off.
  - M: toggle magic. 1–4 with magic on: fire, water, earth, air.
  - Blocks with magic off: 1 = DIRT, 2 = STONE, 3 = WOOD (selects the block without switching mode). T: torch + place mode. F: toggle dig/place.
  - Tab / L: lock on or off. With a target, Tab or Shift+L cycles to the next target.
  - B: hitbox debug.
  - C: old composer (LEGACY); Esc closes it. H: cycle eyes, O: cycle arms (both LEGACY, no visible effect).
- Camera keys (7946): Q/E rotate continuously at 1.6 rad/s; Z/X zoom in/out.

**Mouse (canvas).**
- Drag >8 px: `view.spin` (yaw −dx·.006; pitch dy·.004, or TPS pitch). Wheel: zoom.
- Left click (<450 ms, ≤8 px): in dig mode, `act` → `combat.tapQueue=1` (light attack or tap); in place mode, place a block.
- Right click inverts the place/dig choice.
- Holding still for >140 ms sets `combat.hold`. This feeds magic gathering and the (dormant) block breaking, but **not** sword attacks.
- In place mode, hovering shows the cursor cube.

**Touch.**
- Touch start in the left 40% width and lower 65% height: floating joystick (radius 40 px, dead zone .04, minimum .13).
- Elsewhere: one finger drags the camera; two fingers pinch-zoom.
- A tap places a block only in place mode. In dig mode a tap does nothing.

**On-screen buttons.**
- Top rows (visible):
  - Graphics: `t-outline`, `t-res` (270/360/450), `t-paint`, `t-edges`, `t-dither`, `t-rays`, `t-grass`, `t-shadow`, `t-cloud`.
  - Camera and debug: `t-cam` (ISO ↔ third person), `t-auto` (TPS auto, double-click resets), `rot-l`/`rot-r` (hold to rotate), `z-out`/`z-in` (×1.25), `t-hb`, `regen`, `water-trip` (teleport to the nearest lake shore to the centre), `enemy-trip` (teleport next to the nearest enemy, lock it, equip the sword).
  - Avatar: `c-open` (hero editor), `c-hero` (cycle hero), `c-dna` (paste recipe).
- Bottom row: `rot-l2`/`rot-r2`, `mode` (dig/place), `blk` (cycle placeable block), `c-open2` (legacy composer), `lock`, `wpn` (cycle weapon), `magic`, `spell` (next spell, visible in magic mode).
- Action buttons: `heavy` (pointerdown → heavyQ), `hit` (pointerdown → btn + tap), `jump`.
- `#time` slider (it is inside the hidden `.help` label).

---

## 7. Weapons and combos

**Fist** (`TOOLS.fist`, 7107): dmg 4, knock 3.6, reach 1.30, arc 62° (these two are only used by the dormant `meleeHit`), `hitsBlocks:false`.
- Combo (7756): jab .34 s (dmg ×1, knock ×1), cross .32 s (×1.1, ×1.1), hook .50 s (×1.9, ×2.2, heavy).
- `COMBO_RESET=.55`, `CHAIN_AT=.70` (the heavy move cannot be chained out of), `BUFFER_T=.35`.
- Hitbox: a hand sphere active during u∈[.26,.62], or [.34,.70] for heavy (6087). Damage = 4·mul·(.85–1.15); crit 12% (×1.7 damage, ×1.6 knock). Hitstop .04, .06 on crit, .075 heavy.
- Lunge 3.6 (heavy 4.6) toward the lock target or forward, when the nearest target is .75–2.0 away (7825).

**Blade weapons** (`WEAPONS`, 7551–7571). Order: fist → sword → spear → hammer → great (7572).

| Weapon | dmg | hands | reachU | light chain | heavy | contact profile [root, tip, radius] | draw/sheathe |
|---|---|---|---|---|---|---|---|
| sword (Spada) | 9 | 1 | 1.05 | tree (below) | tree | [.14, 1.20, .065] | .36 / .42 |
| spear (Lancia) | 11 | 2 | 1.7 | spearA | spearHeavy | [1.15, 1.81, .075] | .48 / .52 |
| hammer (Martello) | 15 | 2 | .95 | hammerA | hammerHeavy | [.42, .90, .24] | .55 / .58 |
| great (Spadone) | 14 | 2 | 1.4 | greatA → greatB | greatHeavy | [.14, 1.62, .085] | .52 / .56 |

**Sword combo tree** (`SWORD_COMBO`, 7543–7550). Keys are the actual press sequence (L = light, H = heavy). An unknown branch restarts from the single input (7619).

| Path | Clip | damage × | knock | hitstop | finisher |
|---|---|---|---|---|---|
| L | swordA "Taglio" | 1.00 | .10 | .028 | |
| LL | swordB "Rovescio" | 1.12 | .14 | .030 | |
| LLL | swordC "Fendente" | 1.28 | .24 | .038 | |
| LLLL | swordD "Falce di ritorno" | 1.45 | .32 | .045 | yes |
| H | swordHeavy "Spaccaguardia" | 1.90 | .50 | .055 | yes (heavy) |
| LH | swordLH "Incrocio pesante" | 1.68 | .40 | .052 | yes (heavy) |
| LLH | swordLLH "Spaccaterra" | 2.10 | .62 | .068 | yes (heavy) |

**Clip timing** (`FORGED_CLIPS`, 7494–7508), in seconds, before scaling:

| Clip | wind | active | recover | link | travel | side | weight mass |
|---|---|---|---|---|---|---|---|
| swordA | .17 | .13 | .21 | .065 | .30 | .02 | 1.0 |
| swordB | .13 | .12 | .22 | .055 | .27 | −.13 | 1.0 |
| swordC | .20 | .14 | .30 | .14 | .39 | .08 | 1.0 |
| swordD | .15 | .13 | .28 | .11 | .34 | −.12 | 1.05 |
| swordHeavy | .43 | .17 | .40 | .24 | .31 | 0 | 1.3 |
| swordLH | .29 | .16 | .34 | .18 | .44 | .15 | 1.35 |
| swordLLH | .34 | .18 | .42 | .22 | .54 | 0 | 1.55 |
| spearA | .30 | .17 | .33 | .14 | .48 | – | 1.1 |
| spearHeavy | .57 | .22 | .45 | .22 | .65 | – | 1.4 |
| hammerA | .43 | .23 | .41 | .20 | .31 | – | 1.8 |
| hammerHeavy | .78 | .28 | .62 | .30 | .40 | – | 2.4 |
| greatA | .28 | .17 | .34 | .14 | .36 | – | 1.7 |
| greatB | .34 | .19 | .42 | .20 | .42 | – | 1.8 |
| greatHeavy | .62 | .22 | .55 | .30 | .38 | – | 2.3 |

`FORGED_WEIGHT` (7509–7512) also holds rise, drop, lunge, over, lean and hop for each clip.

**Runtime rules** (7610–7682):
- Scaling: `wind×(heavy ? .94 : .86)`, `recover×.86`.
- Damage: `W.damage × def.damage` for the sword. For other weapons: ×1.9 heavy, otherwise ×(1 + chain·.18). Then ×(.9–1.1), crit 10% ×1.5.
- Knock: `2.4 + kb·11` with `kb = knock·(.7+.3·mass) + (mass−1)·.12`. Hitstop: `min(.095, hitstop·√mass)`.
- Input buffer: at most 2 queued inputs. The next attack starts at `wind + active + min(recover, link·.8)`. `comboT` .48 s after the end keeps the chain alive.
- Contact: 11 blade samples swept at 120 Hz, one hit per target.
- Aim: clamped to ±.9 rad of facing (±.52 when chaining), with soft-aim at 3.8 rad/s during the first 78% of wind.
- Footwork uses `travel × reachScale` (reachScale .78–1.38 when locked), collision-checked by `combatMove` (7656).
- An attack before the weapon is drawn is stored as `WIELD.intent` and fires once the draw ends. Attacks require being on the ground.

---

## 8. Spells and reactions

**Spells** (`SPELLS`, 8002–8006; order fire, water, earth, air; `MG=18` dart gravity):

| Spell | cost | castDur | recover | speed | grav | drag | life | r | dmg | knock | area | status |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| fire "Dardo di fuoco" 🔥 | 14 | .36 | .22 | 16 | .16 | .12 | 1.4 | .13 | 24 | 3.2 | 1.1 | burn |
| water "Dardo d'acqua" 💧 | 12 | .40 | .24 | 14 | 1.0 | .04 | 1.7 | .14 | 20 | 4.4 | 1.5 | wet |
| earth "Masso" 🪨 | 18 | .55 | .30 | 11 | 1.0 | 0 | 2.2 | .22 | 34 | 6.0 | 1.2 | slow |
| air "Spina d'aria" 🌪 | 9 | .22 | .16 | 38 | 0 | 0 | .40 | .12 (wide .45) | 14 | 8.0 | .9 | pushed |

**Mana and casting** (8008, 8259–8276):
- Mana 100/100. Regen 9/s, ×.3 while not idle.
- Cost is paid at gather start (needs `onGround`). Commit happens at 35% of `castDur`. Releasing before commit after .2 s cancels with a 60% refund; before .2 s it becomes a tap auto-fire.
- The dart fires at 100% gather: on release, on auto-fire, or after `castDur + 1.6` s of holding.
- Aim goes to the lock target at 55% of its height; without lock, 7 units along the facing (never the pointer). Ballistic compensation is applied.
- Spell hits: ×(.9–1.1), crit 10% ×1.5.
- Area splash: `dmg × .35 × reaction multiplier` on other entities within `area + radius`.
- The earth dart bounces once off non-soft blocks at speed >5 (×.45).
- Air does not stop on entities; it pierces.

**Entity statuses** (`STDEF`, 8240):
- burn: 4.0 s, tick .45 s, 3.5 dps × stacks, max 3 stacks, a new stack needs a .9 s gap
- wet: 6.0 s
- slow: 2.5 s (enemy speed ×.55, 7375)
- pushed: .85 s (tag only, no mechanical effect)

**`statusReact`** (8245–8248):
- fire on a wet target: removes wet, steam, multiplier **0** (no damage and no status).
- water on a burning target: removes burn, "SHOCK TERMICO", multiplier **1.25**.
- air on a wet target: knock **×1.8** (projHitEntity 8166).
- Otherwise ×1.

**World reactions** (8171–8239):
- Flammability `FLAM`: GRASS .55, WOOD .30, LEAVES .85.
- `BURN_LIFE`: GRASS 3.2, WOOD 7.5, LEAVES 2.5, × U(.8, 1.2). `BURN_TO`: GRASS → DIRT, WOOD → AIR, LEAVES → AIR.
- Fire cells: max 110, tick .25 s. Spread chance = `FLAM × .13 × decay × (1 + windBias·2.5) × (WOOD ? 1.3 : 1)`, with `decay = .78^gen` for grass and `.88^gen` otherwise. Max children: 2 (grass) or 3. Wood also spreads vertically at .14·decay. Burnt-out edits are flushed via `setBlocks` every .4 s or at 14 edits. Entities standing in fire get burn.
- Fire impact: `ignite` on the struck flammable block, plus `igniteAround(r 1.2)` with probability .9 at the centre and .5 around it.
- Water impact: `wetAround(r 1.6)` marks cells wet for 45 s. Wet cells cannot ignite; the timer decays at (1 + daylight·1.5)/s. It extinguishes fire in dy −1..2 ("SPENTO"). `lavaQuench` turns LAVA into DARKSTONE in the 3×3×3 around the hit (dormant in practice because there is no lava without caves).
- Earth impact on SOFT blocks (DIRT, GRASS, SAND) at speed >4: `crater` removes 1 block (never under the player) and gives the item.
- Air: `blowFire` blows out grass fires with 55% chance and otherwise spreads embers downwind at 35%. It also sets grass wind (`uSpellWind`) and shakes trees within 1.8.

Synthesized audio: `VOICE` (8305) plus gather and release noise; no audio samples.

---

## 9. localStorage keys

| Key | Read / write | Content |
|---|---|---|
| `isoterra.rtH` | 4237 / 4241 | Render-target height: 270, 360 or 450 |
| `isoterra.hero.dna` | 6645 / 6653 | `{i: heroIndex, dna: heroDna}`: the active CHARGEN hero |
| `isoterra.tps` | 7857 / 6858 | `'1'`/`'0'`: third-person camera |
| `isoterra.tpsAuto` | 6722 / 7857 | `'1'`/`'0'` |
| `isoterra.tpsPitch` | 6722 / 6777 | Number |
| `isoterra.tpsZoom` | 6722 / 6779 | Number |
| `isoterra.edges` | 7857 / 7857 | `'1'`/`'0'` |
| `isoterra.char` | 7876 / 7877 | Legacy CharacterRig DNA (old composer) |

No sessionStorage or IndexedDB. No world, inventory, position or progress persistence. `DIPINTO`, outline, dither, rays, shadows, clouds and grass are not persisted.
