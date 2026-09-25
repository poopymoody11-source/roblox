# Anti-Spiral boss fight rework (Phase 1)

The source is in `src/` (one folder per Roblox service). The files you install are in `build/`.

## Install in Studio

1. **Back up the place first** (File → Save to File As…).
2. **Delete the old scripts this replaces:**
   - `ServerScriptService` → `BossService`, `BatService`, `SpiralEnergyService`
   - `StarterPlayer` → `StarterPlayerScripts` → `BatClient`, `BossHealthBar`
   - `StarterPack` → `VerityBat`
3. **Insert the new ones.** In the Explorer, right-click each of these and choose **Insert from File…**, then pick the matching file from `build/`:

   | Right-click             | Insert                        |
   |-------------------------|-------------------------------|
   | `ServerScriptService`   | `ServerScriptService.rbxmx`   |
   | `ServerStorage`         | `ServerStorage.rbxmx`         |
   | `ReplicatedStorage`     | `ReplicatedStorage.rbxmx`     |
   | `StarterPlayerScripts`  | `StarterPlayerScripts.rbxmx`  |

The old `ServerStorage` boss modules (`BossController`, `BossConfig`, `BossUtil`, `BossAttacks`, `SpiralEnergy`, `SpiralPickups`) no longer run. They're harmless, and you can delete them once you're happy with the new fight.

## Test quickly

Select **Workspace** and add an attribute: **`BF_TestFight`**, a Boolean set to true. Then press **Play**. The cutscene jumps to its last chapter and the fight starts about 15 seconds after you spawn. Remove the attribute before you publish. It only works in Studio anyway.

## What's in it

- **He walks the arena.** Between attacks the Anti-Spiral walks round the rim on a road of violet galaxy. The walk uses the cutscene's leg code: every footfall plants, forms a galaxy pad, and stomps.
- **Lock-on camera.** The camera frames you and him together and follows him round. Right-drag (or the right stick) to look around. **C** toggles it.
- **The Spiral Bat** is a new drill-headed bat:
  - **Click:** 3-hit swing. Swing just as a hit lands to **parry** it. The green closing-ring prompt shows the timing. A parry does 45 damage to him, a perfect parry 80.
  - **Q:** Spiral Dash, a burst of speed with brief invulnerability.
  - **E:** Drill Break, a thrown drill that hits his core for 60 damage.
- **Attacks** (all parryable):
  1. **Galaxy Barrage.** Purple galaxies (a recolour of the cutscene's green ones) open in the sky and fire planets, moons and stars. Each one gets the cutscene's red lock-on warning.
  2. **Fist Slam.** Red zones fill up, then violet fists crash down.
  3. **Stomp Quake.** He raises a foot and stomps the rim. Shockwave rings roll across the arena: jump them or parry.
  4. **Constellation Lances.** Stars join into constellations. Their lines burn red on the floor, then come down as blades of light.
- The **Spiral Energy** gauge and system are gone.

Tuning (health, damage, cooldowns, walk speed, which attacks each phase uses) is all in `ServerStorage.BossFightServer.Config`. Phase 2 currently reuses these attacks, harder, as a placeholder.

## Rebuilding the install files

After editing `src/`, run `python3 tools/build_rbxmx.py`.
