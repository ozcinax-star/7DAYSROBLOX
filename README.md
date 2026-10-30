# Zombie Survival (Roblox)

Co-op zombie survival where the world gets more dangerous the more you grow. Design decisions live in
[docs/PLAN.md](docs/PLAN.md); if code and the plan disagree, the plan wins.

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
| `src/shared` | `ReplicatedStorage.Shared` | `Config` (all balance numbers), `Localization` (all UI text), `Types`, `NavGrid`, `World/` (map layout, height field) |
| `src/server` | `ServerScriptService.Server` | Bootstrap script + `Services/*` + `World/*` (terrain, building kit, floor plans, props) |
| `src/client` | `StarterPlayer.StarterPlayerScripts.Client` | Bootstrap script + `Controllers/*` |
| `tests` | not synced | Lune unit tests for pure modules |

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
| `MapService` | Builds the 2048×2048 map (Forest + Small Town) at startup; ground height lookup |
| `DayNightService` | Day/night clock, day counter, horde night (default 7, lobby picks 5–10) |
| `ThreatService` | Noise + Trace meters, sound points, 5 threat tiers |
| `ZombieService` | Humanoid-free zombies, flow-field movement, server LOD, snapshot replication |
| `BuildService` | 4-stud grid, wooden wall, part HP, 2000 part cap |

Not in the prototype (reserved): `LootService`, `CraftingService`, `PerkService`, `SaveService`,
`MonetizationService`. Item ownership will carry its source (`Types.ItemSource`) as the plan requires.
