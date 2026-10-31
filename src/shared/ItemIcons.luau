--!strict
-- ItemIcons: a picture glyph (an emoji) for every item, drawn over the item's colour square in the
-- backpack, the toolbelt, crates, the crafting panel and the pickup feed until real icons exist.
-- Emoji need no uploaded images and read on every device; the colour square stays as a tint behind.
-- Roblox draws emoji up to Unicode 12; newer ones (log, rock, ladder, blueberries) show as boxes.

local ItemIcons = {}

ItemIcons.Glyphs = {
	Wood = "🌲",
	SmallStone = "🌑",
	PlantFiber = "🌿",
	Lumber = "📏",
	ScrapIron = "🔩",
	Clay = "🟤",
	CrushedSand = "⏳",
	Dirt = "🟫",
	Cloth = "🧵",
	CanChili = "🥫",
	CanDogFood = "🥫",
	Bone = "🦴",
	MetalPipe = "🔧",
	Glue = "🧴",
	Ammo9mm = "🔸",
	PipePistol = "🔫",
	PipeRifle = "🔭",
	PipeShotgun = "💥",
	PipeMachineGun = "🔗",
	Ammo762mm = "🔶",
	AmmoShotgunShell = "🔴",
	BakedPotato = "🍠",
	CornOnTheCob = "🌽",
	BottledWater = "💧",
	MurkyWater = "🧪",
	FirstAidBandage = "🩹",
	WoodFrame = "🔳",
	WoodLadder = "🧗",
	WoodDoor = "🚪",
	WoodBars = "🚧",
	StoneAxe = "🪓",
	StoneShovel = "🥄",
	StonePickaxe = "⛏",
	WoodenClub = "🏏",
	StoneSpear = "🔱",
	PrimitiveBow = "🏹",
	StoneArrow = "🎯",
	Corn = "🌽",
	Potato = "🥔",
	Blueberries = "🍇",
	CornSeed = "🌱",
	PotatoSeed = "🌱",
	BlueberrySeed = "🌱",
	FarmPlot = "🌾",
	GasCan = "⛽",
	MechanicalParts = "⚙",
	ElectricalParts = "🔌",
	Generator = "⚡",
	StorageCrate = "📦",
	Campfire = "🔥",
	CookingPot = "🍲",
	CookingGrill = "♨",
	ElectricLamp = "💡",
} :: { [string]: string }

-- Shows item `id`'s glyph on the colour square `icon`, adding the glyph label the first time.
function ItemIcons.apply(icon: GuiObject, id: string)
	local glyph = icon:FindFirstChild("Glyph")
	if glyph == nil then
		local label = Instance.new("TextLabel")
		label.Name = "Glyph"
		label.BackgroundTransparency = 1
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
		label.Size = UDim2.fromScale(1.15, 1.15)
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.ZIndex = icon.ZIndex + 1
		label.Parent = icon
		glyph = label
	end
	(glyph :: TextLabel).Text = ItemIcons.Glyphs[id] or ""
end

return ItemIcons
