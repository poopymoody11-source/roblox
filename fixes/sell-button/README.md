# Sell Everything button getting stuck (main place)

**Causes**
1. One click fired the button twice: on the press (the frame and its label) and on the release (the ImageButton's `Activated`). The 0.12s debounce only caught fast clicks, so a slow click armed *and* confirmed, and a double click could sell and then re-arm, leaving "CLICK AGAIN TO CONFIRM" stuck on the button.
2. The old "disarm after 2.5s" timer from an earlier click could fire during a newer one.
3. On the server, if anything errored mid-sale, the `selling[player]` lock never cleared, so Sell Everything silently did nothing until you rejoined.

**Fixes**
- `SellCient`: a click counts once, on the press (`Activated` only for gamepads). The button has clear states (SELL EVERYTHING → CLICK AGAIN TO CONFIRM → SELLING...) and always returns to normal: on the server's answer, after a timeout, or when the menu closes. The one/quarter/half/all buttons also no longer sell twice on a slow click.
- `SellServerScript`: the sale runs in a `pcall`, the lock always clears (and expires after 5s anyway), and the client always gets an answer.

**Install**
- Delete `StarterGui > Screen > master > Sell > SellCient`, then right-click `Sell` → Insert → Import Roblox Model → `build/Sell.rbxmx`.
- Delete `ServerScriptService > GameScripts > SellServerScript`, then right-click `GameScripts` → Import → `build/GameScripts.rbxmx`.
