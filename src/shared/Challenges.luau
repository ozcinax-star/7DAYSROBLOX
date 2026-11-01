--!strict
-- Challenges: pure rules for the 7DTD challenge chain in Config.Challenges, shared by the server
-- (ChallengeService, which counts) and the Lune tests.

local Config = require("./Config")

-- What the client is sent about the tracked challenge.
export type ObjectiveView = {
	kind: Config.ChallengeKind,
	item: string?,
	held: string?,
	have: number,
	need: number,
}
export type View = {
	id: string,
	group: string,
	-- Position in its group, and the group's size.
	index: number,
	total: number,
	objectives: { ObjectiveView },
	-- The challenge just finished before this one, if any.
	completed: string?,
}

local Challenges = {}

-- Whether an event counts toward `objective`: the same kind, the same item when the objective names
-- one, and the held tool when it names one.
function Challenges.matches(
	objective: Config.ChallengeObjective,
	kind: Config.ChallengeKind,
	item: string?,
	held: string?
): boolean
	if objective.Kind ~= kind then
		return false
	end
	if objective.Item ~= nil and objective.Item ~= item then
		return false
	end
	return objective.Held == nil or objective.Held == held
end

-- Everything a player has done this session that a challenge can count (all kinds but Gather),
-- keyed by kind, item and held tool. A challenge that comes up later starts from it, so work done
-- early (a stone axe crafted while still gathering) still counts when its turn comes.
export type Tally = { [string]: { kind: Config.ChallengeKind, item: string?, held: string?, count: number } }

function Challenges.addToTally(tally: Tally, kind: Config.ChallengeKind, item: string?, held: string?, count: number)
	local key = `{kind}|{item or ""}|{held or ""}`
	local entry = tally[key]
	if entry then
		entry.count += count
	else
		tally[key] = { kind = kind, item = item, held = held, count = count }
	end
end

-- Starting progress of `def` from `tally`: each non-Gather objective counts the matching events,
-- capped at its count. Gather objectives are left to the inventory.
function Challenges.seed(def: Config.ChallengeDef, tally: Tally): { number }
	local progress: { number } = {}
	for index, objective in def.Objectives do
		if objective.Kind ~= "Gather" then
			local have = 0
			for _, entry in tally do
				if Challenges.matches(objective, entry.kind, entry.item, entry.held) then
					have += entry.count
				end
			end
			if have > 0 then
				progress[index] = math.min(objective.Count, have)
			end
		end
	end
	return progress
end

-- True when every objective of `def` has reached its count in `progress` (by objective index).
function Challenges.isComplete(def: Config.ChallengeDef, progress: { number }): boolean
	for index, objective in def.Objectives do
		if (progress[index] or 0) < objective.Count then
			return false
		end
	end
	return true
end

-- Position of challenge `index` (of Config.Challenges) within its group, and the group's size.
function Challenges.position(index: number): (number, number)
	local group = Config.Challenges[index].Group
	local position, total = 0, 0
	for other, def in Config.Challenges do
		if def.Group == group then
			total += 1
			if other <= index then
				position += 1
			end
		end
	end
	return position, total
end

return Challenges
