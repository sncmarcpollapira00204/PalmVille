# PalmVille — Rojo-managed source

This repository manages project-owned scripts while leaving the hand-built world, Terrain, models, meshes, unions, and other manually managed Studio instances intact.

## Rojo mapping

- `src/server` → `ServerScriptService`
- `src/client` → `StarterPlayer/StarterPlayerScripts`
- `src/gui/PalmVilleAdminGui` → `StarterGui/PalmVilleAdminGui`

Mapped containers use `$ignoreUnknownInstances: true` so manually managed Studio objects are preserved.

## Active systems

### Server
- `PalmVilleAdminServerV2.server.lua` — authoritative Admin roles, permissions, moderation, announcements, logs, tools, player directory, and analytics.
- `PalmVilleEconomy.lua` — server-side player profile and currency API.
- `PalmVillePlayerData.server.lua` — persistent player data, session locking, autosave, and Admin player-data adapter.
- `PalmVilleInventoryService.lua` — persistent seed-pack inventory and Tool restoration.
- `PalmVilleItemRegistry.lua` — registered item templates, including the PalmVille seed packs.
- `PalmVilleChickenController.server.lua` — server-authoritative wandering for supported chicken models.
- `PalmVilleRoleTitlesV2.server.lua` — role title billboards.
- `FarmVilleGraphicsSettingsPersistence.server.lua` — graphics preferences.
- `UnderwaterChestService.server.lua` — secure underwater chest interactions and rewards.

### Client
- `PalmVilleAdminClient.client.lua` — Admin V2 interface.
- `PalmVilleChickenAnimator.client.lua` — client-side chicken bone animation.
- `PalmVilleCashHUD.client.lua` — replicated Money display.
- `FarmVilleGraphicsSettings.client.lua` — graphics settings UI.
- `UnderwaterCameraAtmosphere.client.lua` — underwater camera atmosphere.
- `UnderwaterChestFeedback.client.lua` — chest reward feedback.

## Important dependencies

- Admin server requires `PalmVilleItemRegistry` and `PalmVilleInventoryService`.
- Inventory service requires `PalmVilleEconomy` and `PalmVilleItemRegistry`.
- Player data requires `PalmVilleEconomy` and `PalmVilleInventoryService`.
- Role titles use the Admin role resolver.
- Chicken animator listens for the tag and attributes created by the chicken controller.
- Graphics settings client pairs with the server persistence script.
- Underwater chest feedback pairs with the server chest service.

Do not delete a mapped script based only on its lack of a visible `require`: some scripts are entry points and communicate through Roblox services, attributes, tags, or RemoteEvents.

## Chicken model requirements

The active chicken controller recognizes `PalmVilleChicken - Owned`, `PalmVilleChicken`, and `fullpollo`. The model must contain a skinned MeshPart named `pollo` with the original `CHICKEN_-` bone names. Duplicate the complete model, not the mesh or individual bones.

## Data and safety

The live player store is `PalmVille_PlayerData_v1`; Studio uses `PalmVille_PlayerData_Test_v1`. Keep the six-player cap configured in the Roblox experience settings. This source cleanup does not alter place geometry, player data, or experience settings.

## Safe sync

1. Save a backup of the current place.
2. Pull `feature/admin-menu-redesign`.
3. Run `rojo serve default.project.json` and connect Studio to `localhost:34872`.
4. Review Rojo changes before accepting them.
5. Stop Play before syncing.
6. Test Admin, player data, seed inventory, chicken movement/animation, graphics settings, and underwater chests before publishing.
