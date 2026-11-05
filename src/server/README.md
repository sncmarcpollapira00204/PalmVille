# PalmVille server scripts

Server-side scripts and ModuleScripts in this folder map directly into Roblox `ServerScriptService` through `default.project.json`.

Active server systems:
- `PalmVilleAdminServerV2.server.lua` — admin backend and role resolver.
- `PalmVilleRoleTitlesV2.server.lua` — role-title billboards driven by the V2 role resolver.
- `PalmVilleAnalyticsServer.server.lua` — admin overview analytics.
- `PalmVillePlayersServer.server.lua` — admin player directory and player actions.
- `FarmVilleGraphicsSettingsPersistence.server.lua` — persistent graphics preferences.
- `PalmVilleItemRegistry.lua` — ModuleScript required by the admin backend.

Retired duplicate/placeholder scripts are intentionally removed from this source tree. Preserve unrelated Studio-only services and scripts unless separately audited.
