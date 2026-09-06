# newmodels_neon

Minimal library resource for Neon's **server-authoritative custom model registry**.

Server scripts allocate stable logical model IDs with `engineRequestModel`. Clients resolve
those IDs to local GTA runtime slots with `engineGetModelRuntimeID`, then apply DFF/TXD/COL
replacements from this resource (or from another resource via `registerModels`).

## Resource layout

```text
lib/shared.lua                 # shared helpers and settings parsing
lib/scan_models.lua            # scans models/ on the server
server/model_registry.lua      # production: allocation, exports, catalog sync
client/load_model_assets.lua   # production: runtime asset loading
test/demo_spawn_server.lua     # optional: /newmodelspawn
test/demo_inspect_server.lua   # optional: /newmodelinfo
test/demo_inspect_client.lua   # optional: /newmodelclient
models/                        # your DFF/TXD/COL tree (bundled demos are optional)
```

Production servers only need the `lib/`, `server/`, and `client/` scripts plus your own
`models/` assets. Remove the three `test/` scripts from `meta.xml` when you do not need the
bundled demo commands. See `meta.xml` comments for details.

The server pushes the client catalog through `onPlayerResourceStart` (per player, after their
client has loaded this resource). It does not use element data or root-wide client events.

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

Bundled example assets come from
[mta-add-models/newmodels_red](https://github.com/Fernando-A-Rocha/mta-add-models/tree/main/newmodels_red/models)
and
[models_alt/s_mod_list.lua](https://github.com/Fernando-A-Rocha/mta-add-models/blob/main/newmodels_red/models_alt/s_mod_list.lua)
(Elegant/nandocrypt entry excluded).

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

After `newmodels_neon` starts, use the returned logical IDs directly in normal element APIs:

```lua
local model = exports.newmodels_neon:getModelId("demo_crate")
local vehicle = createVehicle(model, x, y, z)
```

Or resolve by qualified name:

```lua
local model = engineGetModelIDFromName("newmodels_neon:demo_crate")
```

Register models from another resource:

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

Asset loading is automatic. To inspect mappings:

```lua
local runtime = exports.newmodels_neon:getModelRuntimeId(logicalId)
```

Never persist or synchronize runtime IDs. Only logical server IDs are stable.

## Test commands (optional scripts)

These require the `test/` scripts listed in `meta.xml`:

- `/newmodelspawn [name|all]` — spawns bundled demo models (default: all)
  - object: `demo_crate`, `small_box`, `engine_hoist`, `wrecked_car_1`, `wrecked_car_2`
  - ped: `demo_gangster`, `mafioso_1`, `mafioso_2`, `mafioso_3`
  - vehicle: `demo_faggio`, `demo_hydra`, `schafter`, `landstalker_02`, `landstalker_86`, `landstalker_98`, `sanchez_test`
  - warps you into `schafter` (or `demo_faggio`) when spawned as part of `all`
- `/newmodelinfo` — lists registered logical models (server)
- `/newmodelclient` — prints logical/runtime mappings and load state (client)

## Related resources

- `server-model-registry-test` — low-level engine registry validation
- [Custom models (Neon wiki)](https://mtasa-neon-wiki.vercel.app/neon/models-and-streaming)
