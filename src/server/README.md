# PalmVille server systems

## Active server scripts and modules

- `PalmVilleAdminServerV2.server.lua` — authoritative Admin roles, permissions, moderation, announcements, logs, tools, player directory, and overview analytics.
- `PalmVilleEconomy.lua` — server-side profile and currency API. Gameplay systems must use this module rather than creating another wallet.
- `PalmVillePlayerData.server.lua` — persistent player profiles, session locking, autosave, and Admin player-data adapter.
- `PalmVilleInventoryService.lua` — persistent seed-pack inventory and equipped Tool restoration.
- `PalmVilleItemRegistry.lua` — registered admin items and the 15 PalmVille seed-pack Tool templates.
- `PalmVilleChickenController.server.lua` — server-authoritative wandering for supported imported chicken models.
- `PalmVilleRoleTitlesV2.server.lua` — role title billboards driven by the Admin role resolver.
- `FarmVilleGraphicsSettingsPersistence.server.lua` — graphics preference persistence.
- `UnderwaterChestService.server.lua` — server-validated chest interactions and rewards.

## Active client scripts

- `PalmVilleChickenAnimator.client.lua` — client-side bone animation for supported chicken models.
- `PalmVilleCashHUD.client.lua` — replicated Money display.
- `FarmVilleGraphicsSettings.client.lua` — graphics settings UI.
- `UnderwaterCameraAtmosphere.client.lua` — underwater camera atmosphere.
- `UnderwaterChestFeedback.client.lua` — chest reward feedback.
- `PalmVilleAdminClient.client.lua` — Admin V2 interface under `StarterGui/PalmVilleAdminGui`.

## Required dependencies

- Admin server requires `PalmVilleItemRegistry` and `PalmVilleInventoryService`.
- Inventory service requires `PalmVilleEconomy` and `PalmVilleItemRegistry`.
- Player data requires `PalmVilleEconomy` and `PalmVilleInventoryService`.
- Role titles use the Admin role resolver from the Admin server.
- Chicken animator listens for the tag and attributes created by the chicken controller.
- Graphics settings client pairs with the server persistence script.
- Underwater chest feedback pairs with the server chest service.

These entry-point scripts may not contain a `require` call because they communicate through Roblox services, attributes, CollectionService tags, or RemoteEvents. Do not remove them without testing their paired system.

## Player data and currency

The profile is stored in `PalmVille_PlayerData_v1`; Studio uses `PalmVille_PlayerData_Test_v1`. Server scripts should require `ServerScriptService.PalmVilleEconomy` and use `AddMoney`, `SpendMoney`, or `AddXP`. Do not accept client-submitted balance changes or create a second Money value.

New profiles start with ₱500. Change `STARTING_MONEY` in `PalmVillePlayerData.server.lua` to adjust it. Enable Studio API access only when testing DataStores in a published experience.

## Seed pack inventory

The item registry creates the seed-pack Tool templates in ServerStorage. The inventory service stores counts in the existing player profile under `inventory.seedPacks`, then restores Tools to the Backpack after data load and respawn. Seed item grants are routed through the Admin server and validated against the registry.

## Chicken model requirements

The controller recognizes `PalmVilleChicken - Owned`, `PalmVilleChicken`, and `fullpollo`. Each complete model must contain a skinned MeshPart named `pollo` and the required original `CHICKEN_-` bone names. Duplicate the complete model, not the mesh or individual bones. The controller handles wandering and smooth turning; the client animator handles legs, knees, wings, neck/peck, and tail.

The experimental static/rigged Rooster integration was removed because the imported Rooster asset did not successfully load and was not ready for use. It can be added later after a model passes Studio import and rig validation.

## Studio sync safety

Save a place backup before syncing. Run `git pull --ff-only origin feature/admin-menu-redesign`, start `rojo serve default.project.json`, connect Studio to `localhost:34872`, and review the diff before accepting. Stop Play before syncing. Test Admin, player data, seed inventory, chicken movement/animation, graphics settings, and underwater chests before publishing.
