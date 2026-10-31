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
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Bootstrap script + `Controllers/*` + `Modules/*` (`ZombieRig`: jointed zombie body and its procedural shamble). `GraphicsController`: Low / Medium / High / Auto presets (`Config.Graphics`, `Shared/Graphics`) for zombie LOD and corpse time, shadows, bloom, sun rays and lamp reach; fog and the night tint are never touched |
| `src/character` | `StarterPlayer.StarterCharacterScripts` | `Health` (empty: replaces Roblox's default health regeneration) |
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
| `DayNightService` | World clock (`Shared/DayClock`): an 11-minute day and night, the day counter and the horde night (default every 7th; lobby choice of 5–10 later), published to clients as a start-time attribute; phase-change listeners |
| `ThreatService` | Noise + Trace meters, sound points and the 5 threat tiers (`Shared/Threat`); the ambient zombie population around the players (more at night and at higher tiers) and the horde night waves (20 per player) |
| `ZombieService` | Humanoid-free zombies: flow-field movement on a ground and an upper-floor layer joined by stairs, house visits, indoor sleepers, server LOD, snapshot replication, `damage` / `onDied` |
| `BuildService` | Player blocks on the 4-stud grid (`Shared/BuildGrid`): frames, wood blocks and ladders placed from the hand with server checks, stone-axe upgrade and repair, damage, collapse of unsupported blocks, zombie structure cells priced by block health (zombies break the weakest wall), 2000-block cap, Trace |
| `ToolService` | Melee swings with the held tool or the fist: validated aim, 7DTD swing rate, server-side target pick (`Shared/Melee`: zombie cylinder + head sphere, line of sight), damage, wear, swing broadcast; world hits go to `onWorldHit` listeners; held items with a use handler (`onUse`: blocks, food) are used instead, a fist `use` may drink (`onFistUse`), every swing passes the stamina gate |
| `InventoryService` | Server-owned inventories (10-slot toolbelt + 45-slot backpack, 7DTD sizes), validated move / select remotes, the active item shown in the right hand (`Modules/HeldItems`), a pickup-feed event for every item given |
| `CraftingService` | 7DTD backpack crafting: a four-job queue per player on the server clock (`Shared/Crafting` craft times and costs), ingredients taken at queue time and refunded on cancel with their sources, output waiting in the queue when there is no room, stone-tool repair through the same queue |
| `SurvivalService` | Server-owned stamina, food and water (`Shared/Vitals`, 7DTD numbers): drains per in-game day, hunger and thirst stages that block stamina, starvation, the stamina cost of swings and jumps, the sprint intent (WalkSpeed 16 / 24), food, drinks and medicine from the hand, drinking lake water, the death bag (half of the raw resources); Player attributes for the HUD |
| `LootService` | Loot bags on the ground: zombie drops (`Shared/Loot`), a held search prompt that takes what fits, overflow drops from other services, lifetime and a world cap (death bags kept); searchable town furniture (174 containers, rolled on first search, refilled after 7 in-game days, wall check from the head) |
| `HarvestService` | Gathering on `ToolService.onWorldHit`: trees, bushes, grass, boulders and loose rocks listed by `MapService.getHarvestables()`; 7DTD yields (`Shared/Harvest`), shared damage, tree felling with navigation reopening, loose-rock pick-up prompts |
| `RangedService` | Bows: the held bow's use handler takes one arrow, wears the bow and flies the arrow on the server under gravity (`Shared/Ballistics`, 7DTD damage, speed and range); each flight step is tested against the zombie hit volumes (`Shared/Melee`, head shots double) and the world; clients draw the arc (`ArrowController`) |
| `StorageService` | Storage crates: a crate block (`BuildService.onPlaced`) gets 36 shared slots and an Open prompt; openers stay viewers while in reach and alive and get every change (`StorageUpdate`); `StorageAction` takes, stores (`Inventory.transfer`), takes all or closes, each checked for rate, open crate, reach and slot range; a broken crate spills into a loot bag. The client panel (`StorageController`) takes the crafting panel's place |
| `PowerService` | Generators and electric lamps (`Shared/Power`, 7DTD generator bank without wires): gas poured in with use, on / off with the interact key; a running generator lights the lamps within 48 studs up to its 50 W, burns gas for the watts in use, makes generator noise under one merged sound point and adds Trace with its lit lamps |
| `FarmService` | Crops on farm plots (`Shared/Farming`, 7DTD 3.2): a seed in the hand is planted with use on a free plot, grows through three stages on the server clock (1.05 in-game days each), and a held Harvest prompt pays 2 produce, a 50 % bonus and the seed back; a broken plot takes its crop (`BuildService.onRemoved`) |
| `DigService` | Digging the terrain on `ToolService.onWorldHit`: one 4-stud voxel off the top of the column hit, 7DTD health and yield per material (`Config.Dig`: clay, crushed sand, small stones), at most two voxels below a side neighbour, Dirt (16 clay) fills dug columns back up to their old height, no digging on roads, by buildings, by water, under trees, props or blocks, or into the last voxel; the meshed surface goes back into the height grid and MapService reads heights around holes with a ray |

### World modules (`src/server/World`)

| Module | Responsibility |
| --- | --- |
| `BuildingTemplates` | ASCII floor plans on the 4-stud grid (legend in the file header), per floor |
| `FloorPlan` | Pure plan reader: rooms (flood fill + kind from furniture), furniture facing, stairs |
| `BuildingKit` | Turns a plan into a furnished model: plinth, facade + painted interior linings, casings, open doors, floors and ceilings per room, stairs with railings, gable or flat roof, signs |
| `Furniture` | One model per furniture symbol; bodies collide, small dressing is decor |
| `TerrainBuilder` | Writes terrain from the height field (surface, dirt, rock 12 studs down); bare ground under building footprints; rewrites one column for digging |
| `PropKit`, `Palette`, `PartFactory` | Props, colour/material styles, part creation (`decor` = no collision) |

Building rules: walls stand on cell centre lines, every doorway and floor cell stays walkable for the
zombie navigation grid (trims are decor), and the Lune tests check that every floor cell, piece of
furniture and stair in every template can be walked to. `BuildingKit.build` also returns the stairs and
upper-floor cells in world space; templates have at most two floors.

Not in the prototype (reserved): `LootService`, `CraftingService`, `PerkService`, `SaveService`,
`MonetizationService`. Every inventory stack carries its source (`Types.ItemSource`) as the plan
requires; stacks of the same item from different sources never merge (`Shared/Inventory`).
