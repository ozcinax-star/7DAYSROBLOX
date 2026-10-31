--!strict
-- Shared types used by server services and client controllers.

export type Service = {
	init: (self: any) -> (),
	start: (self: any) -> (),
}

export type DayPhase = "Day" | "Night"

export type ZombieState = "Idle" | "Wander" | "SeekSound" | "Search" | "Chase" | "AttackPlayer" | "AttackStructure"

export type NoiseKind = "Gunshot" | "Sprint" | "DoorBreak" | "Generator" | "Harvest" | "TreeFall"

-- A positional sound that zombies can hear. Plain numbers so pure modules stay Roblox-free.
export type SoundPoint = {
	id: number,
	x: number,
	y: number,
	z: number,
	radius: number,
	strength: number,
	createdAt: number,
}

export type BuildPieceKind = "WoodWall"

-- Reserved for later sessions (loot, crafting, perks, save, monetization). Kept here so the
-- services that come next have a typed contract to implement against.
export type ItemSource = "Craft" | "Loot" | "Purchase" | "Pass"

return nil
