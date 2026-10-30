# Zombie Survival (Roblox)

Co-op zombie survival where the world gets more dangerous the more you grow. Design decisions live in
[docs/PLAN.md](docs/PLAN.md); if code and the plan disagree, the plan wins. Project history, current
state and the next tasks are in [docs/HANDOFF.md](docs/HANDOFF.md) and [docs/NEXT_STEPS.md](docs/NEXT_STEPS.md).

## Toolchain

Tools are pinned in `rokit.toml`.

```sh
rokit install                 # rojo, stylua, selene, lune
rojo plugin install           # Rojo plugin for Studio
rojo serve                    # then click "Connect" in the Rojo plugin in Studio
```

Checks:

```sh
stylua --check src tests      # formatting
selene src                    # lint (Roblox std)
lune run tests/run            # pure-logic unit tests outside Studio
rojo build -o build.rbxl      # full place build
```

## Layout

| Path | Roblox location | Contents |
| --- | --- | --- |
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (all balance numbers), `Localization` (all UI text), `Types`, `NavGrid`, `ZombieProtocol` (snapshot encoding), `ZombieLook` (zombie appearance from its id), `World/` (map layout, height field) |
| `src/server` | `ServerScriptService.Server` | Bootstrap script + `Services/*` + `World/*` (terrain, building kit, floor plans, props) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Bootstrap script + `Controllers/*` + `Modules/*` (`ZombieRig`: jointed zombie body and its procedural shamble) |
| `tests` | not synced | Lune unit tests for pure modules |
| `tools/studio` | not synced | Dev-only Studio MCP sync + test harness and the floor-plan checker (see `docs/HANDOFF.md`) |

### Rules

- `--!strict` in every file.
- No magic numbers: balance values come from `Shared/Config`.
- No hardcoded UI strings: text comes from `Shared/Localization`.
- Server authoritative: damage, threat and building are computed on the server. Every RemoteEvent is
  validated for type, range and rate.
- Pure logic (e.g. threat math) does not touch Roblox APIs, so Lune can test it.

### Services

| Service | Responsibility |
| --- | --- |
| `MapService` | Builds the 2048×2048 map (Forest + Small Town) at startup; terrain height (`heightAt`) and walking height including building floors (`groundAt`) |
| `DayNightService` | Day/night clock, day counter, horde night (default 7, lobby picks 5–10) |
| `ThreatService` | Noise + Trace meters, sound points, 5 threat tiers |
| `ZombieService` | Humanoid-free zombies: flow-field movement on a ground and an upper-floor layer joined by stairs, house visits, indoor sleepers, server LOD, snapshot replication, `damage` / `onDied` |
| `BuildService` | 4-stud grid, wooden wall, part HP, 2000 part cap |
| `InventoryService` | Server-owned inventories (10-slot toolbelt + 45-slot backpack, 7DTD sizes), validated move / select remotes, the active item shown in the right hand (`Modules/HeldItems`) |

### World modules (`src/server/World`)

| Module | Responsibility |
| --- | --- |
| `BuildingTemplates` | ASCII floor plans on the 4-stud grid (legend in the file header), per floor |
| `FloorPlan` | Pure plan reader: rooms (flood fill + kind from furniture), furniture facing, stairs |
| `BuildingKit` | Turns a plan into a furnished model: plinth, facade + painted interior linings, casings, open doors, floors and ceilings per room, stairs with railings, gable or flat roof, signs |
| `Furniture` | One model per furniture symbol; bodies collide, small dressing is decor |
| `TerrainBuilder` | Writes terrain from the height field; bare ground under building footprints |
| `PropKit`, `Palette`, `PartFactory` | Props, colour/material styles, part creation (`decor` = no collision) |

Building rules: walls stand on cell centre lines, every doorway and floor cell stays walkable for the
zombie navigation grid (trims are decor), and the Lune tests check that every floor cell, piece of
furniture and stair in every template can be walked to. `BuildingKit.build` also returns the stairs and
upper-floor cells in world space; templates have at most two floors.

Not in the prototype (reserved): `LootService`, `CraftingService`, `PerkService`, `SaveService`,
`MonetizationService`. Every inventory stack carries its source (`Types.ItemSource`) as the plan
requires; stacks of the same item from different sources never merge (`Shared/Inventory`).
