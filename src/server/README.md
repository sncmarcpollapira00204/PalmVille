# PalmVille server scripts

The Admin backend is consolidated into one server Script:

- `PalmVilleAdminServerV2.server.lua` — authoritative Admin roles and permissions, remote access/actions, moderation, announcements, logs, tools, cross-server Players directory, and overview analytics.
- `PalmVilleEconomy.lua` — server-only ModuleScript API for player profiles and Money: `RegisterProfile`, `IsLoaded`, `GetProfile`, `GetMoney`, `AddMoney`, `SpendMoney`, `SetMoney`, `AddXP`, and `UnregisterProfile`. Other server scripts should use this module instead of creating or changing their own wallet.
- `PalmVillePlayerData.server.lua` — loads and saves one persistent player profile per UserId using `PalmVille_PlayerData_v1`; Studio uses the separate `PalmVille_PlayerData_Test_v1` store. Includes session locking, 60-second autosave, save/release on leave and shutdown, `leaderstats.Money`, `leaderstats.Level`, and the Admin player-data adapter. New profiles start with ₱500; change `STARTING_MONEY` in this script to adjust it.
- `PalmVilleItemRegistry.lua` — ModuleScript required by the Admin server for registered item templates.
- `PalmVilleRoleTitlesV2.server.lua` — role title billboards driven by the Admin role resolver.
- `FarmVilleGraphicsSettingsPersistence.server.lua` — separate non-Admin graphics preferences service.
- `UnderwaterChestService.server.lua` — detects each outer `Chest` model or part inside `Workspace.Underwater Chest`, adds an E/tap ProximityPrompt, validates distance and one-claim-per-player-per-chest rules on the server, and credits rewards through `PalmVilleEconomy.AddMoney`.
- `src/client/UnderwaterChestFeedback.client.lua` — displays chest reward, jackpot, empty-roll, and wallet-loading notifications.

The former `PalmVillePlayersServer` and `PalmVilleAnalyticsServer` implementations are embedded in the Admin server and archived under `archive/merged-server-backups/`. Their existing DataStore names and RemoteFunction endpoints are retained. Their old standalone Scripts must not be restored.

The old duplicate `AdminClient` placeholder is removed. The active Admin interface is `PalmVilleAdminClient.client.lua` under `src/gui/PalmVilleAdminGui`.

## Player data and currency

The player profile is stored under the stable key `Player_<UserId>` in one DataStore record. The initial schema contains Money, Level, XP, seeds, inventory, farm plots, and statistics so later farming systems can extend the same profile instead of creating competing databases.

Server scripts should require `ServerScriptService.PalmVilleEconomy` and call `AddMoney(player, amount, reason)` or `SpendMoney(player, amount, reason)`. Do not accept client-submitted balance changes. The module returns failure while the player profile is not loaded.

Studio uses `PalmVille_PlayerData_Test_v1`; published servers use `PalmVille_PlayerData_v1`. The Admin role, permission, log, and moderation stores also receive a `_StudioTest` suffix in Studio. The analytics and announcement systems already use separate Studio test stores; graphics-settings persistence is disabled in Studio. This prevents Studio testing from writing to the live profile or Admin stores.

Enable **Game Settings → Security → Enable Studio Access to API Services** after publishing the experience. A load failure is fail-closed: the player is not given a fresh unsaved profile that could overwrite existing progress.

### Economy API example

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local Economy = require(ServerScriptService:WaitForChild("PalmVilleEconomy"))

-- Reward a player from trusted server-side gameplay logic.
local ok, newBalance = Economy.AddMoney(player, 100, "Harvest")

-- Charge for a seed or shop item; check success before delivering the item.
local purchased, balanceOrReason = Economy.SpendMoney(player, 75, "SeedShop")
if not purchased then
	warn(balanceOrReason)
	return
end
```

Do not create a second Money value or let a LocalScript submit a balance. The replicated `leaderstats.Money` is for display; the server Economy module is the authority.
The lower-left cash display is a standalone LocalScript at `src/client/PalmVilleCashHUD.client.lua`. It reads the replicated `leaderstats.Money` value after `PalmVilleDataLoaded` becomes true, formats it as Philippine pesos, and moves higher on touch devices to avoid the default mobile joystick. Its coin ImageLabel and amount text have transparent backgrounds. Set `COIN_IMAGE_ID` to the uploaded Roblox image asset ID for the supplied transparent coin PNG.
