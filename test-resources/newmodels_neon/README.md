# newmodels_neon

Minimal library resource for Neon's **server-authoritative custom model registry**.

Server scripts allocate stable logical model IDs with `engineRequestModel`. Clients resolve
those IDs to local GTA runtime slots with `engineGetModelRuntimeID`, then apply DFF/TXD/COL
replacements from this resource (or from another resource via `registerModels`).

## Folder layout

Place models under `models/<type>/<parent>/<name>/`:

```text
models/
  object/
    1337/
      demo_crate/
        model.dff
        model.col
        settings.txt
      boxes.txd
```

Supported types: `vehicle`, `object`, `ped`.

Each model folder must contain a DFF. TXD and COL are optional. Shared textures can live in
the parent folder and be referenced from `settings.txt`:

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
        settings = { lodDistance = 300 },
    },
})
```

## Client usage

Asset loading is automatic. To inspect mappings:

```lua
local runtime = exports.newmodels_neon:getModelRuntimeId(logicalId)
```

Never persist or synchronize runtime IDs. Only logical server IDs are stable.

## Test commands

- `/newmodelspawn` — spawns the bundled `demo_crate` object next to the player
- `/newmodelinfo` — lists registered logical models (server)
- `/newmodelclient` — prints logical/runtime mappings and load state (client)

## Related resources

- `server-model-registry-test` — low-level engine registry validation
- [Custom models (Neon wiki)](https://mtasa-neon-wiki.vercel.app/neon/models-and-streaming)
