# Final Boss portal showing before it's unlocked (main place)

**Cause:** each base's portal prompt (`Upgrades > Purchases > bossfight > teleport > teleport`) carries the `NPCprompt` tag. `ReplicatedStorage.DialogModule` switches every `NPCprompt` back on when you spawn, die or finish talking to an NPC, so the locked portal's prompt came on. `FinalPortalFX` builds the vortex, runes and FINAL BOSS sign whenever that prompt is on, so they showed too. The server never trusted it (`FinalBossLobbyService` checks `BossfightUnlocked`), so it was only visual, but it looked unlocked.

**Fix:** two new scripts. Nothing existing is edited.
- `PortalLockFix` (ServerScriptService) takes the portal prompts out of the `NPCprompt` tag and sets the `bossfight` model's `Unlocked` attribute from the server's prompt state.
- `PortalLockGuard` (StarterPlayerScripts) keeps a locked portal's prompt off on each client, whatever turns it on.

**Install:** right-click `ServerScriptService` → Insert → Import Roblox Model → `build/ServerScriptService.rbxmx`. Right-click `StarterPlayer > StarterPlayerScripts` → Import → `build/StarterPlayerScripts.rbxmx`.
