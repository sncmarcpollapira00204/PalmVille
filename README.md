# PalmVille — Rojo-managed source

This source bundle imports the project-owned scripts from the supplied `COPY OF PALM.rbxlx` while leaving the hand-built world, terrain, models, and other manually managed instances in Studio.

## What Rojo manages

- `src/server` → `ServerScriptService`
- `src/client` → `StarterPlayer/StarterPlayerScripts`
- `src/gui/PalmVilleAdminGui` → `StarterGui/PalmVilleAdminGui` (`ScreenGui`)

Each mapped service/container uses `$ignoreUnknownInstances: true`, so Studio instances not represented in these source folders are intentionally left alone. Do not change these flags without reviewing the place hierarchy first.

## Conflict cleanup

The uploaded place already has the following legacy scripts set to `Disabled = true`. Matching `.meta.json` files are included so Rojo keeps them disabled:

- `ServerScriptService/PalmVilleAdminServer` — legacy admin event handler; its announcement branch broadcasts raw, unfiltered text. The current V2 admin server applies Roblox text filtering and owns the admin role resolver.
- `ServerScriptService/RoleTitleSystem` — duplicates the V2 BillboardGui title and labels the master developer as `ALIPIN`; V2 displays `DEV` and listens for role/visibility updates.
- `StarterGui/PalmVilleAdminGui/AdminClient` — second client-side panel/launcher in the same ScreenGui. `PalmVilleAdminClient` is the current admin interface.
- `ServerScriptService/PalmVilleCode` — old empty Rojo placeholder; real service scripts now map directly under `ServerScriptService`. The clean place copy disables this no-op placeholder.

The two dated `PalmVilleAdminClient` backups are under `archive/admin-client-backups/` and are not part of the Rojo project tree.

## Runtime dependencies to keep in Studio

- `ServerStorage/PalmVilleAdminItems/RICE_SEED` is required by `PalmVilleItemRegistry`. It is a model/tool asset, so it is intentionally not replaced by source-only Rojo mapping.
- `PalmVilleAdminServerV2` creates `PalmVilleGetAdminRole` and `PalmVilleAdminRoleChanged`; analytics, players directory, and role titles use those services. Keep V2 enabled.
- `PalmVillePlayersServer` optionally reads a `BindableFunction` named `PalmVilleAdminPlayerData` for money, earned-today, level, XP, and playtime. That adapter is not present in the uploaded place, so those progress values will remain unavailable until connected to the real player-data system. Do not fill them with placeholder values.
- Analytics and cross-server player directory features rely on Roblox DataStore/MemoryStore/MessagingService APIs. Studio tests may need API access enabled, and cross-server travel must be tested in a published experience.

## Safe sync process

1. Back up the current place.
2. Extract this ZIP into the root of your existing local `PalmVille` Git repository. Replace `default.project.json` and `README.md` when prompted; keep your existing `.git` folder.
3. Review `git status`, then commit and push the imported source files to your chosen branch.
4. Run `rojo serve default.project.json` and connect the Studio Rojo plugin to `localhost:34872`.
5. Check Explorer: the three legacy scripts above and `PalmVilleCode` should show `Disabled = true`; the V2 scripts should remain enabled.
6. Test with a private server before publishing.

This setup does not change the game's max-player setting or any place geometry. The uploaded place file does not contain a `MaxPlayers` value, so verify the six-player cap in the experience/place settings.
