# Anti-Spiral boss fight rework

The source is in `src/` (one folder per Roblox service). The files you install are in `build/`.

## Install / update in Studio

1. **Back up the place** (File → Save to File As…).
2. **Delete anything from an earlier install** (whatever you have of these):
   - `ServerScriptService` → `BossFight` (and the old `BossService`, `BatService`, `SpiralEnergyService`)
   - `ServerStorage` → `BossFightServer`
   - `ReplicatedStorage` → `AntiSpiralFight`
   - `StarterPlayer` → `StarterPlayerScripts` → `BossFightClient`, `BossHealthBar` (and the old `BatClient`, `SpiralClient`)
   - `StarterPack` → `VerityBat` / `SpiralBat`
3. **Import the new ones.** Right-click each of these, choose **Insert → Import Roblox Model**, and pick the matching file from `build/`:

   | Right-click             | Import                        |
   |-------------------------|-------------------------------|
   | `ServerScriptService`   | `ServerScriptService.rbxmx`   |
   | `ServerStorage`         | `ServerStorage.rbxmx`         |
   | `ReplicatedStorage`     | `ReplicatedStorage.rbxmx`     |
   | `StarterPlayerScripts`  | `StarterPlayerScripts.rbxmx`  |

## Test quickly

Add a Boolean attribute **`BF_TestFight`** = true on **Workspace**, then press **Play**. The cutscene jumps to its last chapter and the fight starts about 15 seconds after you spawn. Remove the attribute before publishing.

## How the fight plays

- **Before his first attack,** how-to-play cards show after the cutscene. The server holds his first attack until they finish.
- **Boss music:** a theme per phase, a swell for his set pieces, and a quiet one when he falls. Change the tracks in `ReplicatedStorage.AntiSpiralFight.Client.Music` (TRACKS).
- **You fight in spiral power:** the cutscene's green aura is on every player.
- **Dodging:** when the red **!** flashes, something is about to land where you stand. MOVE, JUMP or ROLL, and it tells you which. Red zones have a dark base, a red fill that grows to the edge as the hit comes, and a flashing red fence round the rim.
- **What a roll can dodge:** only beams and lance blades. Fists, planets and blasts must be outrun, and shockwaves must be jumped (rolling into them still hurts).
- **Roll:** **CTRL** (gamepad B, or the ROLL button on mobile). A fast dash-roll (a full tucked flip) that eases out, with a green streak and afterimages. You flash green while you can't be hit. The whoosh is preloaded and plays the instant you press.
- **Hurting him:** after every 2 attacks (and after each set piece) he's **dazed** for 14 seconds (a little less for each extra player). He collapses over the rim with his head down on the arena, marked by a green target. Run to it and **CLICK** (R2, or the PUNCH button on mobile) to throw spiral punches. A bar shows how long he's down, and then he comes round with a roar and a shockwave you have to jump.
- **One QTE, the black hole (Spiral Collapse):** if you're caught in it, circles pop up around the screen one after another, just like the cutscene's dodge. Press each key as its ring closes on it. Land all five and you tear free and hurt him.
- **Getting hit:** knockback, blood, a shockwave, a stumble (or a full knockdown for the big ones) and a camera jolt.
- **Camera:** your normal camera most of the time. Now and then (when he walks, changes phase or winds up something big) it pulls back to follow him for a few seconds, and **C** toggles that follow mode yourself. The big wind-ups cut in to a cinematic shot and get a title. For Big Bang it cuts to an overhead view so you can see the green safe ring.

## Attacks

1. **Galaxy Barrage.** Galaxies tear open and fire planets and stars. Finale: **The Last World**.
2. **Fist Slam.** Red zones fill, then violet fists crash down. Finale: **Hammer of Despair**.
3. **Stomp Quake.** Solid violet shockwave walls (white crest, dark base) roll across the arena, with a red line racing ahead of each one: jump them.
4. **Constellation Lances.** Constellations form overhead and come down as blades of light.
5. **Annihilation Beam.** A sweeping beam that's too tall to jump: roll through it.
6. **Spiral Collapse.** A black hole pulls you in, then collapses (QTE).
7. **Galaxy Corruption** (at 58% health, the end of phase 1). Every galaxy bombards the arena.
8. **Big Bang** (his ultimate, at 72% and 30%). A universe falls on the middle of the arena: get to the green outer ring (or roll at the perfect moment).

## Tuning

Everything is in `ServerStorage.BossFightServer.Config`:
- `MaxHealth` (2500) is for one player; each extra player adds `HealthPerExtraPlayer` of it (85%). Barrage, Lances and Corruption also fire more with more players, and each extra player shortens the daze by `DazeShortenPerPlayer` seconds.
- `AttacksBeforeDaze`, `DazeTime`, `PunchDamage`, `PunchRange`, `PunchCooldown`, `RollCooldown`, `RollIFrames` and `IntroTime` control the daze, punches, roll and the intro.
- `SetPieces` sets when Galaxy Corruption and Big Bang happen.
- `Phases` sets the attacks and their weights. Phase 2 still reuses these attacks at a harder setting, as a placeholder.

An attack gets a QTE only if its module sets `Qte` on a hit (see `F.qte.sequence`). Only Spiral Collapse does.

## If something doesn't work

Open **View → Output**. Messages starting with `[BossFight]` show how far the fight got (`server ready`, `N player(s): … health`, `fight started`, `attack: …`, `client: the fight is on`). Send me anything red or orange.

## Rebuilding the install files

After editing `src/`, run `python3 tools/build_rbxmx.py`.
