# Source audit — 2026-11-04

## Inventory

The submitted XML place contains 65 Script, LocalScript, and ModuleScript instances. Thirteen current/legacy PalmVille scripts are mapped into the managed source tree; two dated admin GUI backups are archived; third-party/free-model and map-attached scripts remain outside the managed source tree. See `script-inventory.csv` for exact hierarchy and source sizes.

## Legacy duplicates and existing safety state

1. `StarterGui/PalmVilleAdminGui/AdminClient` and `PalmVilleAdminClient` are both present under the same ScreenGui and each constructs an `AdminLauncher` and admin panel. In the uploaded place, `AdminClient.Disabled` is already `true`; keep `PalmVilleAdminClient` as the active interface.
2. `ServerScriptService/RoleTitleSystem` and `PalmVilleRoleTitlesV2` both create `FarmVilleRoleTitle` BillboardGuis. The legacy static table assigns UserId `11199335797` the title `ALIPIN`, while V2 recognizes that ID as `MASTER DEVELOPER` and renders `DEV`. In the uploaded place, `RoleTitleSystem.Disabled` is already `true`; keep V2 enabled.
3. `ServerScriptService/PalmVilleAdminServer` and `PalmVilleAdminServerV2` both listen to `ReplicatedStorage/PalmVilleAdminRemote`. The legacy script has its own owner-only access path and raw announcement broadcast; V2 handles the current `Action` request envelope, server-side role permissions, and filtered announcements. In the uploaded place, `PalmVilleAdminServer.Disabled` is already `true`; keep V2 enabled.
4. `ServerScriptService/PalmVilleCode` contains only a 135-byte placeholder and the existing project mapped `src/server/init.server.lua` into that single Script instance. That mapping does not put `PalmVilleItemRegistry` at the `ServerScriptService` root where V2 requires it. The new project maps real server files directly under `ServerScriptService`; the place copy disables the no-op placeholder.

## Kept dependencies

- `PalmVilleAdminServerV2` provides `PalmVilleGetAdminRole` and `PalmVilleAdminRoleChanged` used by V2 role titles, Analytics, and Players.
- `PalmVilleItemRegistry` requires `ServerStorage/PalmVilleAdminItems/RICE_SEED`, which exists in the supplied place. The model/tool remains in Studio and is not recreated by this code import.
- `FarmVilleGraphicsSettings` pairs with `FarmVilleGraphicsSettingsPersistence`.

## Gaps and not changed

- `PalmVillePlayersServer` has an optional `PalmVilleAdminPlayerData` BindableFunction integration for money, earnedToday, level, XP, and playtime. That BindableFunction is not present in the uploaded place, so player progress metrics remain unavailable until connected to the actual economy/progression system.
- The uploaded XML does not include a `Players.MaxPlayers` value. The six-player cap must be verified in the experience/place settings; this import does not set it.
- No terrain, Workspace models, spawn location, tool assets, or player data were changed.
