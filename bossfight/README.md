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
- **Dodging:** when the red **!** flashes, something is about to land where you stand. MOVE, JUMP or ROLL, and it tells you which.
- **Roll:** **CTRL** (gamepad B, or the ROLL button on mobile). A quick roll you can't be hit during.
- **Hurting him:** after every 2 attacks (and after each set piece) he's **dazed** for 14 seconds. He collapses over the rim with his head down on the arena, marked by a green target. Run to it and **CLICK** (R2, or the PUNCH button on mobile) to throw spiral punches. A bar shows how long he's down, and then he comes round with a roar and a shockwave you have to jump.
- **One QTE, the black hole (Spiral Collapse):** if you're caught in it, circles pop up around the screen one after another, just like the cutscene's dodge. Press each key as its ring closes on it. Land all five and you tear free and hurt him.
- **Getting hit:** knockback, blood, a shockwave, a stumble (or a full knockdown for the big ones) and a camera jolt.
- **Camera:** it follows you and him. Right-drag looks around, and **C** toggles it. The big wind-ups cut in to a cinematic shot and get a title and a lock-on warning.

## Attacks

1. **Galaxy Barrage.** Galaxies tear open and fire planets and stars. Finale: **The Last World**.
2. **Fist Slam.** Red zones fill, then violet fists crash down. Finale: **Hammer of Despair**.
3. **Stomp Quake.** Shockwave walls roll across the arena, with a red line racing ahead of each one: jump them.
4. **Constellation Lances.** Constellations form overhead and come down as blades of light.
5. **Annihilation Beam.** A sweeping beam that's too tall to jump: roll through it.
6. **Spiral Collapse.** A black hole pulls you in, then collapses (QTE).
7. **Galaxy Corruption** (at 58% health, the end of phase 1). Every galaxy bombards the arena.
8. **Big Bang** (his ultimate, at 72% and 30%). A universe falls on the middle of the arena: get to the green outer ring (or roll at the perfect moment).

## Tuning

Everything is in `ServerStorage.BossFightServer.Config`:
- `MaxHealth` is for one player; each extra player adds `HealthPerExtraPlayer` of it (70%).
- `AttacksBeforeDaze`, `DazeTime`, `PunchDamage`, `PunchRange`, `PunchCooldown`, `RollCooldown`, `RollIFrames` and `IntroTime` control the daze, punches, roll and the intro.
- `SetPieces` sets when Galaxy Corruption and Big Bang happen.
- `Phases` sets the attacks and their weights. Phase 2 still reuses these attacks at a harder setting, as a placeholder.

An attack gets a QTE only if its module sets `Qte` on a hit (see `F.qte.sequence`). `Big = true` gives a hit the lock-on warning.

## If something doesn't work

Open **View → Output**. Messages starting with `[BossFight]` show how far the fight got (`server ready`, `N player(s): … health`, `fight started`, `attack: …`, `client: the fight is on`). Send me anything red or orange.

## Rebuilding the install files

After editing `src/`, run `python3 tools/build_rbxmx.py`.
