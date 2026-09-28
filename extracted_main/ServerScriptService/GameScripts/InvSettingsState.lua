--==================================================
-- INV SETTINGS STATE (shared, single source of truth)
--
-- sessionData[userId] = { Favorites = {[item]=true}, AutoSell = {[item]=true}, Loaded = bool }
--
-- FavoriteDataServer loads/saves/toggles this table.
-- AutoSellService READS it to decide what to sell.
-- Previously each kept its own copy and they drifted apart,
-- which is why items the UI showed as NOT autosell still sold.
--==================================================

return {}
