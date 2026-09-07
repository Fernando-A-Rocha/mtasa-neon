# newmodels_neon

Minimal library resource for Neon's **server-authoritative custom model registry**.

Server scripts allocate stable logical model IDs with `engineRequestModel`. Clients resolve
those IDs to local GTA runtime slots with `engineGetModelRuntimeID`, then apply DFF/TXD/COL
replacements from this resource (or from another resource via `registerModels`).

## Resource layout

```text
server/newmodels.lua           # production: scan, allocation, exports, catalog sync
client/load_model_assets.lua   # production: runtime asset loading
test/demo_commands_server.lua  # optional: /newmodelspawn and /newmodelinfo
test/demo_inspect_client.lua   # optional: /newmodelclient
models/                        # your DFF/TXD/COL tree (bundled demos are optional)
```

Production servers only need the `server/` and `client/` scripts plus your own `models/`
assets. There is no shared Lua script: folder scan and settings parsing stay server-only so
clients do not download unused helpers. Remove the two `test/` scripts from `meta.xml` when
you do not need the bundled demo commands. See `meta.xml` comments for details.

The server pushes the client catalog through `onPlayerResourceStart` (per player, after their
client has loaded this resource). Later `registerModels` updates are broadcast to connected
players; no persistent synced-player set is kept.

## Folder layout

Place models under `models/<type>/<parent>/<name>/`:

```text
models/
  object/
    1337/              # demo_crate, small_box, engine_hoist (+ boxes.txd)
    3593/              # wrecked_car_2
    3594/              # wrecked_car_1
    wrecked_car.txd    # shared texture for wrecked cars
  ped/
    1/                 # mafioso_1, mafioso_2, mafioso_3 (models_alt)
    7/                 # demo_gangster (models/)
  vehicle/
    400/               # landstalker_86, landstalker_98
    462/               # demo_faggio
    468/               # sanchez_test (DFF only)
    489/               # landstalker_02
    507/               # schafter
    520/               # demo_hydra
```

Supported types: `vehicle`, `object`, `ped`.

Each model folder must provide **at least one** of DFF, TXD, or COL. Any combination is valid
(for example DFF-only, TXD-only, or all three). Shared textures can live in a parent folder and
be referenced from `settings.txt`:

```text
txd=../boxes.txd
lodDistance=300
enableDFFAlphaTransparency
disableTXDTextureFiltering
```

`meta.xml` uses `<file src="models/**/*" />` so every asset under `models/` is downloaded
automatically.

## Server usage

After `newmodels_neon` starts, resolve a vanilla vehicle ID or a registered custom model
name to the ID `createVehicle` expects (vanilla GTA ID, or Neon's stable logical ID).

Canonical registry names are always `resource:name`. `engineGetModelIDFromName` accepts an
unqualified short name, but only by scoping it to the **calling** resource (so `"schafter"`
from inside `newmodels_neon` becomes `newmodels_neon:schafter`). Callers in another resource
must pass the qualified name, or retry with the `newmodels_neon:` prefix as below.

```lua
-- idOrName: vanilla ID (411), custom short name ("schafter"), or qualified name
-- ("newmodels_neon:schafter")
local function resolveVehicleModel(idOrName)
    local asNumber = tonumber(idOrName)
    if asNumber then
        -- Already a numeric ID: vanilla vehicle range, or a logical ID you already hold.
        return asNumber
    end

    local name = tostring(idOrName)
    local logicalId = engineGetModelIDFromName(name)
    -- Unqualified names are scoped to the calling resource; retry against this library
    -- when the caller lives elsewhere and did not pass "newmodels_neon:...".
    if not logicalId and not name:find(":", 1, true) then
        logicalId = engineGetModelIDFromName("newmodels_neon:" .. name)
    end
    return logicalId -- nil if the name is not registered
end

local model = resolveVehicleModel("schafter") -- or 411, or "newmodels_neon:schafter"
if not model then
    return -- unknown model; do not call createVehicle
end
local vehicle = createVehicle(model, x, y, z)

-- Related natives: engineGetModelName, engineGetModelType, engineGetModelParent, engineGetModels
```

Register models from another resource (asset paths + catalog sync):

```lua
exports.newmodels_neon:registerModels({
    {
        type = "vehicle",
        parent = 411,
        name = "mission_infernus",
        dff = "assets/infernus.dff",
        txd = "assets/infernus.txd",
    },
    {
        type = "vehicle",
        parent = 468,
        name = "sanchez_mesh_only",
        dff = "assets/sanchez.dff",
    },
})
```

## Client usage

Asset loading is automatic. Resolve runtime slots with the engine native:

```lua
local runtime = engineGetModelRuntimeID(logicalId)
```

Resource-specific helpers: `isModelLoaded`, `getLoadedModels`, `getClientCatalog`.

Never persist or synchronize runtime IDs. Only logical server IDs are stable.

## Test commands (optional scripts)

These require the `test/` scripts listed in `meta.xml`:

- `/newmodelspawn <name|id>` — spawns one model next to the player
  - custom logical models by registered name (e.g. `schafter`, `demo_crate`)
  - vanilla MTA model IDs (e.g. `411`)
  - vanilla vehicle names via `getVehicleModelFromName` (e.g. `Infernus`)
- `/newmodelinfo` — lists registered logical models (server; same file as spawn)
- `/newmodelclient` — prints logical/runtime mappings and load state (client)

## Related resources

- `server-model-registry-test` — low-level engine registry validation
- [Custom models (Neon wiki)](https://mtasa-neon-wiki.vercel.app/neon/models-and-streaming)

## Credits

- Created by [Fernando-A-Rocha](https://github.com/Fernando-A-Rocha) — original
  [mta-add-models / newmodels_red](https://github.com/Fernando-A-Rocha/mta-add-models)
  approach and bundled demo assets (from
  [newmodels_red/models](https://github.com/Fernando-A-Rocha/mta-add-models/tree/main/newmodels_red/models)
  and
  [models_alt/s_mod_list.lua](https://github.com/Fernando-A-Rocha/mta-add-models/blob/main/newmodels_red/models_alt/s_mod_list.lua);
  Elegant/nandocrypt entry excluded).
- Thanks to [Dryxio](https://github.com/Dryxio) for [mtasa-neon](https://github.com/Dryxio/mtasa-neon).
