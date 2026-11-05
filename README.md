# PalmVille — Rojo-managed source

This repository manages project-owned scripts while leaving the hand-built world, Terrain, models, meshes, unions, and other manually managed Studio instances intact.

## What Rojo manages

- `src/server` → `ServerScriptService`
- `src/client` → `StarterPlayer/StarterPlayerScripts`
- `src/gui/PalmVilleAdminGui` → `StarterGui/PalmVilleAdminGui` (`ScreenGui`)

Each mapped container uses `$ignoreUnknownInstances: true`. Unmanaged Studio objects are intentionally preserved; do not change these flags without reviewing the full place hierarchy.

## Admin architecture

The Admin system now has one main client LocalScript and one main server Script:

- `src/gui/PalmVilleAdminGui/PalmVilleAdminClient.client.lua` — the complete Admin V2 interface: Overview, Players, Announcements, Moderation, Staff & Roles, Tools, and Logs.
- `src/server/PalmVilleAdminServerV2.server.lua` — the authoritative server backend: role verification, permissions, admin actions, moderation, announcements, logs, cross-server Players directory, and overview analytics.
- `src/server/PalmVilleItemRegistry.lua` — ModuleScript required by the Admin server for registered item templates.
- `src/server/PalmVilleRoleTitlesV2.server.lua` — role title billboards using the Admin role resolver.

The former standalone `PalmVillePlayersServer` and `PalmVilleAnalyticsServer` implementations are embedded in `PalmVilleAdminServerV2`. Their data-store names and RemoteFunction endpoints are retained. Their old standalone Script files are removed from the active source tree and from the clean full-place test artifact.

The former 120 KB Admin client is archived under `archive/admin-client-backups/`. The former Players and Analytics server files are archived under `archive/merged-server-backups/`. Archive files are not mapped into Roblox Studio.

## Other active server systems

- `FarmVilleGraphicsSettingsPersistence.server.lua` — graphics preferences; separate from Admin.
- `PalmVilleRoleTitlesV2.server.lua` — role title display.
- `PalmVilleItemRegistry.lua` — required item templates for Give Item.

Keep `ServerStorage/PalmVilleAdminItems/RICE_SEED`; the item registry requires this Tool template. The optional `PalmVilleAdminPlayerData` BindableFunction can provide money, earned-today, level, XP, and playtime to the cross-server player directory. It is not present in the current place, so those values remain unavailable rather than fabricated.

## Legacy scripts

The old `ServerScriptService/PalmVilleAdminServer`, `RoleTitleSystem`, and `PalmVilleCode` entries are retired disabled placeholders. They are not part of the active Rojo source. Keep them disabled if they remain in a Studio copy; the validated full-place builder removes them only when their `Disabled = true` state is confirmed.

The duplicate `StarterGui/PalmVilleAdminGui/AdminClient` placeholder is removed from the managed source tree. Rojo should remove that mapped child on sync. The active client is `PalmVilleAdminClient`.

## Safe sync process

1. Save a backup of the current place before syncing.
2. In the local PalmVille repository, run `git pull --ff-only origin feature/admin-menu-redesign`.
3. Keep `rojo serve default.project.json` running and connect Studio to `localhost:34872`.
4. Review the Rojo changes. Expect the Admin client/server source updates and deletion of the mapped standalone Players/Analytics scripts and duplicate `AdminClient`. Do not accept unrelated map or Workspace changes.
5. Stop Play before accepting changes, then Play-test access, Overview, Players, Announcements, Moderation, Staff & Roles, Tools, and Logs.
6. Do not publish until the Studio test is successful.

The workflow does not change the place geometry or six-player cap. Verify the six-player limit in the Roblox experience/place settings.
