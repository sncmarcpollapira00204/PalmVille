# PalmVille server scripts

The Admin backend is consolidated into one server Script:

- `PalmVilleAdminServerV2.server.lua` — authoritative Admin roles and permissions, remote access/actions, moderation, announcements, logs, tools, cross-server Players directory, and overview analytics.
- `PalmVilleItemRegistry.lua` — ModuleScript required by the Admin server for registered item templates.
- `PalmVilleRoleTitlesV2.server.lua` — role title billboards driven by the Admin role resolver.
- `FarmVilleGraphicsSettingsPersistence.server.lua` — separate non-Admin graphics preferences service.
- `src/client/UnderwaterChestFeedback.client.lua` — displays chest reward, jackpot, empty-roll, and wallet-configuration notifications.
- `UnderwaterChestService.server.lua` — detects each outer `Chest` model or part inside `Workspace.Underwater Chest`, adds an E/tap ProximityPrompt, validates distance on the server, and grants weighted Money rewards once per player per chest per server session.

The former `PalmVillePlayersServer` and `PalmVilleAnalyticsServer` implementations are embedded in the Admin server and archived under `archive/merged-server-backups/`. Their existing DataStore names and RemoteFunction endpoints are retained. Their old standalone Scripts must not be restored.

The old duplicate `AdminClient` placeholder is removed. The active Admin interface is `PalmVilleAdminClient.client.lua` under `src/gui/PalmVilleAdminGui`.
