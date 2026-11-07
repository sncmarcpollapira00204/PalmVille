# PalmVille source audit and cleanup record

## Current managed source

The current Rojo-managed source tree contains:
- 5 client scripts
- 1 Admin GUI LocalScript and its metadata
- 9 server scripts/modules, including the Admin, player data, economy, inventory, item registry, chicken, role title, graphics preference, and underwater chest systems

The exact live mapping is defined in `default.project.json`. Files under `src/server`, `src/client`, and `src/gui/PalmVilleAdminGui` are mapped into Roblox Studio.

## Dependency review

The following dependencies were checked and retained:
- Admin server → item registry and inventory service.
- Inventory service → economy and item registry.
- Player data → economy and inventory service.
- Role titles → Admin role resolver.
- Chicken animator → chicken controller's CollectionService tag and model attributes.
- Graphics settings UI → graphics settings persistence.
- Underwater chest feedback → underwater chest service.
- Cash HUD → replicated leaderstats Money value.

Some server/client scripts are entry points and communicate through Roblox services, attributes, CollectionService tags, and RemoteEvents instead of `require`. They are not considered unused merely because no other source file requires them.

## Cleanup completed

- Removed five archived Admin client backup files from the active branch.
- Removed two archived pre-merge Players/Analytics server backup files. Their consolidated implementation remains in `PalmVilleAdminServerV2.server.lua`.
- Removed experimental Rooster branches from the chicken controller and animator because neither imported Rooster asset was successfully validated in Studio.
- Kept the original working chicken controller and client bone animator.
- Refreshed project and server documentation to describe the current managed source and dependencies.

Deleted files remain recoverable from Git history if a rollback is ever needed.

## Not deleted

- Active systems and their required modules.
- `audit/script-inventory.csv`: this is a historical inventory of the uploaded Studio place from 2026-11-04, not a current list of Rojo-managed files.
- Manually managed Workspace/map assets and third-party scripts. The Rojo project intentionally preserves unmanaged Studio instances through `$ignoreUnknownInstances: true`.

## Studio validation still required

The source cleanup is committed, but it has not been validated in a live Roblox Studio Play Test. After pulling and syncing, test Admin, player data, seed inventory, chicken movement/animation, graphics settings, and underwater chests before publishing.
