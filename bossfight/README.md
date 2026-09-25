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

- **You fight in spiral power.** Every player wears the cutscene's green spiral aura (veins, glowing eyes, glow, whirling rings). There are no weapons: all damage to him comes from **parrying**.
- **Dodge** by getting out of the red. **Parry** with the QTE prompts that appear when a hit is about to land on you:
  - **Single:** one key, as the ring closes on it.
  - **Chord:** several keys at once (the bigger attacks), all inside the window.
  - **Ultimate:** Big Bang's five-step sequence with tight timing (±0.09 s, perfect ±0.045 s). Land it and a cutscene counter plays: GIGA DRILL BREAK.
  - Keys: **CLICK**, **SPACE**, **Q**, **E**, **F** (gamepad R2 / A / X / Y / B; on touch, tap the prompt discs).
- A successful parry plays a move on your character that everyone sees (a palm deflect, a spinning backhand on a perfect, or a cross-arm guard that bursts open on a chord), then fires a counter-bolt into him. Getting hit knocks you reeling.
- **Camera:** it frames you with him and follows him around. Right-drag or the right stick looks around, and **C** toggles it. Big attacks cut in to a cinematic shot.
- **He talks:** his lines appear at the bottom of the screen in the cutscene's font and animation.
- **Impact frames** hit on the big moments.

## Attacks

1. **Galaxy Barrage.** Purple galaxies tear open and fire planets and stars at you. Finale: **The Last World** (a chord QTE).
2. **Fist Slam.** Red zones fill, then violet fists crash down. Finale: **Hammer of Despair** (a chord).
3. **Stomp Quake.** He stomps the rim. Jump the shockwaves: SPACE on the beat parries them.
4. **Constellation Lances.** Constellations form overhead, then come down as blades of light.
5. **Annihilation Beam.** A palm-charged beam sweeps the arena. It's too tall to jump: parry it with the chord.
6. **Spiral Collapse.** A black hole drags you in, then collapses. Escape the red, or parry it with the chord.
7. **Galaxy Corruption** (set piece, at 58% health: the end of phase 1). Every galaxy turns violet and bombards the arena. It ends with every galaxy converging on each player (a chord).
8. **Big Bang** (his ultimate, at 72% and 30% health). It covers the whole arena, so the five-step QTE is the only way through.

## Tuning

Everything is in `ServerStorage.BossFightServer.Config`:
- `MaxHealth` is for one player; each extra player adds `HealthPerExtraPlayer` of it (70%).
- `SetPieces` sets when Galaxy Corruption and Big Bang happen.
- `Phases` sets the attacks and their weights. Phase 2 still reuses these attacks at a harder setting, as a placeholder.

Each attack module (`ServerStorage.BossFightServer.Attacks`) sets its own counter damage (`Counter` / `CounterPerfect`) and QTE (`Qte`).

## If something doesn't work

Open **View → Output**. Messages starting with `[BossFight]` show how far the fight got (`server ready`, `N player(s): … health`, `fight started`, `attack: …`, `client: the fight is on`). Send me anything red or orange.

## Rebuilding the install files

After editing `src/`, run `python3 tools/build_rbxmx.py`.
