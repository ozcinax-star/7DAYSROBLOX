--!strict
-- Avatar arms solve from the rig's joint offsets and the shared equipment grip markers.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local HeldItems = require(ReplicatedStorage:WaitForChild("Shared").HeldItems)
local BowState = require(script.Parent.Parent.Modules.BowState)
local HC = Config.WeaponHandling
type Joint = Motor6D | AnimationConstraint
type Arm = { shoulder: Joint, elbow: Joint, wrist: Joint }
type Rig = { character: Model, root: BasePart, right: Arm, left: Arm, pose: CFrame? }
local rigs: { [Player]: Rig } = {}
local written: { [Joint]: { base: CFrame, value: CFrame } } = {}
local EquipmentPoseController = {}

local function armOf(character: Model, side: string): Arm?
	local found: { Joint } = {}
	for _, name in { "Shoulder", "Elbow", "Wrist" } do
		local joint = character:FindFirstChild(side .. name, true)
		if joint == nil or not (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then return nil end
		table.insert(found, joint)
	end
	return { shoulder = found[1], elbow = found[2], wrist = found[3] }
end

local function restore(arm: Arm)
	for _, joint in { arm.shoulder, arm.elbow, arm.wrist } do
		local last = written[joint]
		if last and joint.Transform == last.value then joint.Transform = last.base end
		written[joint] = nil
	end
end

local function write(joint: Joint, parentCF: CFrame, childCF: CFrame)
	local last = written[joint]
	local base = if last and joint.Transform == last.value then last.base else joint.Transform
	local value = joint.C0:Inverse() * parentCF:ToObjectSpace(childCF) * joint.C1
	joint.Transform = value
	written[joint] = { base = base, value = value }
end

local function bone(from: Vector3, to: Vector3, localFrom: Vector3, localTo: Vector3, normal: Vector3): CFrame
	return CFrame.lookAt(from, to, normal) * CFrame.lookAt(localFrom, localTo, Vector3.zAxis):Inverse()
end

local function solve(arm: Arm, target: CFrame, pole: Vector3): CFrame?
	local shoulder, elbow, wrist = arm.shoulder, arm.elbow, arm.wrist
	local torso, hand = shoulder.Part0, wrist.Part1
	if torso == nil or hand == nil then return nil end
	local start = (torso.CFrame * shoulder.C0).Position
	local goal = (target * wrist.C1).Position
	local a = (elbow.C0.Position - shoulder.C1.Position).Magnitude
	local b = (wrist.C0.Position - elbow.C1.Position).Magnitude
	local delta = goal - start
	if a < 0.01 or b < 0.01 or delta.Magnitude < 0.01 then return nil end
	local distance = math.clamp(delta.Magnitude, math.abs(a - b) + 0.001, a + b - 0.001)
	local along = delta.Unit
	local bend = pole - start; bend -= along * bend:Dot(along)
	if bend.Magnitude < 0.001 then return nil end
	bend = bend.Unit
	local x = (a * a - b * b + distance * distance) / (2 * distance)
	local middle = start + along * x + bend * math.sqrt(math.max(0, a * a - x * x))
	goal = start + along * distance
	local normal = along:Cross(bend).Unit
	local upperCF = bone(start, middle, shoulder.C1.Position, elbow.C0.Position, normal)
	local lowerCF = bone(middle, goal, elbow.C1.Position, wrist.C0.Position, normal)
	local handCF = CFrame.new(goal - target:VectorToWorldSpace(wrist.C1.Position)) * target.Rotation
	write(shoulder, torso.CFrame, upperCF)
	write(elbow, upperCF, lowerCF)
	write(wrist, lowerCF, handCF)
	return handCF
end

local function attach(player: Player, character: Model)
	local hum = character:WaitForChild("Humanoid", 10)
	local root = character:WaitForChild("HumanoidRootPart", 10)
	character:WaitForChild("RightHand", 10)
	local right, left = armOf(character, "Right"), armOf(character, "Left")
	if hum and root and root:IsA("BasePart") and right and left and player.Character == character then
		local old = rigs[player]; if old then restore(old.right); restore(old.left) end
		rigs[player] = { character = character, root = root, right = right, left = left }
	end
end

local function step(dt: number)
	for player, rig in rigs do
		if rig.character.Parent == nil then restore(rig.right); restore(rig.left); rigs[player] = nil; continue end
		local held = rig.character:FindFirstChild("HeldItem")
		local id = held and held:GetAttribute("ItemId")
		local weapon = if typeof(id) == "string" then Config.Ranged.Weapons[id] else nil
		local tool = if typeof(id) == "string" then Config.Tools[id] else nil
		local untilSwing = rig.character:GetAttribute("MeleePoseUntil")
		local hum = rig.character:FindFirstChildOfClass("Humanoid")
		local active = (weapon ~= nil or tool ~= nil) and hum ~= nil and hum.Health > 0
			and not (typeof(untilSwing) == "number" and untilSwing > workspace:GetServerTimeNow())
		if not active then restore(rig.right); restore(rig.left); rig.pose = nil; continue end
		local camera = workspace.CurrentCamera
		local pitch = player:GetAttribute("WeaponPitch")
		local direction = if player == Players.LocalPlayer and camera then rig.root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
			else (CFrame.Angles(if typeof(pitch) == "number" then pitch else 0, 0, 0)).LookVector
		local at = Vector3.new(0.62, if weapon then 0.55 else 0.15, if weapon then -0.85 else -0.55)
		local reloadEnds = player:GetAttribute("WeaponReloadEnds")
		local reload = if weapon and typeof(reloadEnds) == "number" and reloadEnds > workspace:GetServerTimeNow()
			then math.sin(math.pi * math.clamp(1 - (reloadEnds - workspace:GetServerTimeNow()) / (weapon.ReloadSeconds or 1), 0, 1)) else 0
		local desired = CFrame.lookAt(at, at + direction)
			* CFrame.Angles(math.rad(-reload * 12), math.rad(-reload * 20), math.rad(-reload * 25))
		rig.pose = if rig.pose then rig.pose:Lerp(desired, 1 - math.exp(-dt / HC.PoseSmoothSeconds)) else desired
		local rightCF = solve(rig.right, rig.root.CFrame * (rig.pose :: CFrame),
			(rig.root.CFrame * CFrame.new(HC.ElbowWidth, -0.2, 0.35)).Position)
		if id == "PrimitiveBow" and held and held:IsA("Model") then
			HeldItems.poseBow(held, BowState.sample(player))
		end
		local primary = held and held:IsA("Model") and held.PrimaryPart
		local support = primary and primary:FindFirstChild("SupportGrip")
		local hand = rig.right.wrist.Part1
		if rightCF and hand and support and support:IsA("Attachment") and id ~= "WoodenClub" then
			local relative = hand.CFrame:ToObjectSpace(support.WorldCFrame)
			solve(rig.left, rightCF * relative * CFrame.new(0, -reload * 0.5, 0) * CFrame.Angles(0, 0, math.rad(-70)),
				(rig.root.CFrame * CFrame.new(-HC.ElbowWidth, -0.2, 0.35)).Position)
		else restore(rig.left) end
	end
end

function EquipmentPoseController.release(character: Model)
	for _, rig in rigs do
		if rig.character == character then restore(rig.right); restore(rig.left); rig.pose = nil; return end
	end
end

function EquipmentPoseController.init() end
function EquipmentPoseController.start()
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character) task.spawn(attach, player, character) end)
		if player.Character then task.spawn(attach, player, player.Character) end
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		local rig = rigs[player]; if rig then restore(rig.right); restore(rig.left) end
		rigs[player] = nil
	end)
	for _, player in Players:GetPlayers() do watch(player) end
	RunService.PreSimulation:Connect(step)
end
return EquipmentPoseController
