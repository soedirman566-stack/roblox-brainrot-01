-- BrainrotFactory: builds the 3D model of one brainrot from its definition.
-- One job: turn a BrainrotDefs row into a Model — a chunky body, a head, two
-- eyes and a floating name tag — that the conveyor, the bases and thieves
-- can all carry around the same way. A def's Look table adds the animal
-- accessories: ears, horns, wings, a dorsal fin, tails (long, fan or
-- fluke), a trunk, an antenna, a crown and a halo. Rare creatures glow.

local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local BrainrotFactory = {}

local GOLD = Color3.fromRGB(255, 205, 55)
local HALO_COLOR = Color3.fromRGB(255, 240, 170)

local function makePart(name: string, size: Vector3, color: Color3, offset: Vector3, base: CFrame): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CFrame = base * CFrame.new(offset)
	return part
end

-- Like makePart, but also rotated (degrees) — wings, horns and tail fans
-- are all just boxes leaned at an angle.
local function makeTilted(name: string, size: Vector3, color: Color3, offset: Vector3, base: CFrame, rx: number, ry: number, rz: number): Part
	local part = makePart(name, size, color, offset, base)
	part.CFrame = base * CFrame.new(offset) * CFrame.Angles(math.rad(rx), math.rad(ry), math.rad(rz))
	return part
end

local function glowify(part: Part)
	part.Material = Enum.Material.Neon
end

-- Builds the model with its feet at the given CFrame's origin, facing -Z of
-- that frame. The model is anchored: movers reposition it with PivotTo.
-- Everything scales with def.Scale, so a Dewa Langit (Scale 3+) is built
-- exactly like a Noobini — just colossal, tag floating far overhead.
function BrainrotFactory.Build(def, origin: CFrame): Model
	local scale = def.Scale or 1
	local look = def.Look or {}
	local model = Instance.new("Model")
	model.Name = def.Name
	model:SetAttribute("BrainrotName", def.Name)
	model:SetAttribute("Rarity", def.Rarity)
	model:SetAttribute("Income", def.Income)

	local bodyHeight = 3.2 * scale
	local body = makePart(
		"Body",
		Vector3.new(3 * scale, bodyHeight, 2.2 * scale),
		def.Color,
		Vector3.new(0, bodyHeight / 2, 0),
		origin
	)
	body.CanQuery = true -- prompts and clicks target the body
	model.PrimaryPart = body
	body.Parent = model

	local headSize = 2.1 * scale
	local headY = bodyHeight + headSize / 2
	local head = makePart(
		"Head",
		Vector3.new(headSize, headSize, headSize),
		def.Color:Lerp(Color3.new(1, 1, 1), 0.18),
		Vector3.new(0, headY, 0),
		origin
	)
	head.Parent = model

	-- Two eyes on the face (the face looks along -Z of the origin frame).
	local eyeColor = Color3.fromRGB(20, 20, 25)
	local eyeY = bodyHeight + headSize * 0.58
	local eyeZ = -headSize / 2 - 0.06
	makePart("EyeL", Vector3.new(0.34 * scale, 0.5 * scale, 0.12), eyeColor, Vector3.new(-0.5 * scale, eyeY, eyeZ), origin).Parent = model
	makePart("EyeR", Vector3.new(0.34 * scale, 0.5 * scale, 0.12), eyeColor, Vector3.new(0.5 * scale, eyeY, eyeZ), origin).Parent = model

	-- A rarity gem on the chest, so rarity reads at a distance.
	local gem = makePart(
		"Gem",
		Vector3.new(0.9 * scale, 0.9 * scale, 0.14),
		BrainrotDefs.RarityColors[def.Rarity],
		Vector3.new(0, bodyHeight * 0.55, -1.1 * scale - 0.06),
		origin
	)
	gem.Shape = Enum.PartType.Ball
	glowify(gem)
	gem.Parent = model

	local dark = def.Color:Lerp(Color3.new(0, 0, 0), 0.22)
	local light = def.Color:Lerp(Color3.new(1, 1, 1), 0.3)

	-- Ears: round balls for pandas, elephants and cows; pointed cones
	-- (leaned boxes) for cats.
	if look.Ears == "Round" then
		local earSize = 0.95 * scale
		local earL = makePart("EarL", Vector3.new(earSize, earSize, 0.4 * scale), dark, Vector3.new(-headSize * 0.52, headY + headSize * 0.38, 0), origin)
		earL.Shape = Enum.PartType.Ball
		earL.Parent = model
		local earR = makePart("EarR", Vector3.new(earSize, earSize, 0.4 * scale), dark, Vector3.new(headSize * 0.52, headY + headSize * 0.38, 0), origin)
		earR.Shape = Enum.PartType.Ball
		earR.Parent = model
	elseif look.Ears == "Point" then
		makeTilted("EarL", Vector3.new(0.55 * scale, 1.1 * scale, 0.3 * scale), dark, Vector3.new(-headSize * 0.38, headY + headSize * 0.62, 0), origin, 0, 0, 14).Parent = model
		makeTilted("EarR", Vector3.new(0.55 * scale, 1.1 * scale, 0.3 * scale), dark, Vector3.new(headSize * 0.38, headY + headSize * 0.62, 0), origin, 0, 0, -14).Parent = model
	end

	-- Horns: two gold spikes leaned outward on top of the head.
	if look.Horns then
		makeTilted("HornL", Vector3.new(0.4 * scale, 1.3 * scale, 0.4 * scale), GOLD, Vector3.new(-headSize * 0.34, headY + headSize * 0.66, 0), origin, 0, 0, 24).Parent = model
		makeTilted("HornR", Vector3.new(0.4 * scale, 1.3 * scale, 0.4 * scale), GOLD, Vector3.new(headSize * 0.34, headY + headSize * 0.66, 0), origin, 0, 0, -24).Parent = model
	end

	-- A trunk hanging down the face (the crystal elephant).
	if look.Trunk then
		makePart("Trunk", Vector3.new(0.62 * scale, 1.7 * scale, 0.62 * scale), light, Vector3.new(0, headY - headSize * 0.42, -headSize / 2 - 0.28 * scale), origin).Parent = model
	end

	-- A robot antenna with a glowing tip ball.
	if look.Antenna then
		makePart("AntennaStem", Vector3.new(0.16 * scale, 1.1 * scale, 0.16 * scale), dark, Vector3.new(0, headY + headSize / 2 + 0.5 * scale, 0), origin).Parent = model
		local tip = makePart("AntennaTip", Vector3.new(0.55 * scale, 0.55 * scale, 0.55 * scale), BrainrotDefs.RarityColors[def.Rarity], Vector3.new(0, headY + headSize / 2 + 1.1 * scale, 0), origin)
		tip.Shape = Enum.PartType.Ball
		glowify(tip)
		tip.Parent = model
	end

	-- Wings on the back (+Z side): flat boxes swept up and out. "Huge"
	-- wings are the Dewa Langit treatment — broader than the body.
	if look.Wings then
		local wingScale = if look.Wings == "Huge" then 1.9 elseif look.Wings == "Big" then 1.35 else 0.95
		local wingSize = Vector3.new(2.6 * scale * wingScale, 1.7 * scale * wingScale, 0.22 * scale)
		local wingY = bodyHeight * 0.78
		local wingX = (1.5 + 1.1 * wingScale) * scale
		local wingL = makeTilted("WingL", wingSize, light, Vector3.new(-wingX, wingY, 0.9 * scale), origin, -18, 0, 28)
		wingL.Parent = model
		local wingR = makeTilted("WingR", wingSize, light, Vector3.new(wingX, wingY, 0.9 * scale), origin, -18, 0, -28)
		wingR.Parent = model
		if look.Glow then
			glowify(wingL)
			glowify(wingR)
		end
	end

	-- A dorsal fin (sharks, the moon whale) standing on the body's top.
	if look.Fin then
		makeTilted("Fin", Vector3.new(0.24 * scale, 1.5 * scale, 1.6 * scale), dark, Vector3.new(0, bodyHeight + 0.55 * scale, 0.2 * scale), origin, -16, 0, 0).Parent = model
	end

	-- Tails at the back: "Long" is two stacked segments, "Fan" is the
	-- peacock/phoenix spread of five leaned plumes, "Fluke" is the flat
	-- horizontal paddle a whale or shark swims with.
	if look.Tail == "Long" then
		makeTilted("TailA", Vector3.new(0.55 * scale, 1.8 * scale, 0.55 * scale), dark, Vector3.new(0, bodyHeight * 0.42, 1.35 * scale), origin, 42, 0, 0).Parent = model
		makeTilted("TailB", Vector3.new(0.45 * scale, 1.5 * scale, 0.45 * scale), light, Vector3.new(0, bodyHeight * 0.72, 2.05 * scale), origin, 68, 0, 0).Parent = model
	elseif look.Tail == "Fan" then
		for i = -2, 2 do
			local plume = makeTilted(
				"TailFan" .. (i + 3),
				Vector3.new(0.62 * scale, 2.6 * scale, 0.18 * scale),
				if i == 0 then light else dark,
				Vector3.new(i * 0.62 * scale, bodyHeight * 0.62, 1.45 * scale),
				origin, -32, i * 13, i * -10
			)
			if look.Glow then
				glowify(plume)
			end
			plume.Parent = model
		end
	elseif look.Tail == "Fluke" then
		makePart("TailFluke", Vector3.new(2.4 * scale, 0.24 * scale, 1.1 * scale), dark, Vector3.new(0, bodyHeight * 0.3, 1.6 * scale), origin).Parent = model
	end

	-- A golden crown: a band plus four spikes, worn by kings and gods.
	if look.Crown then
		local crownY = headY + headSize / 2
		makePart("CrownBand", Vector3.new(headSize * 0.92, 0.42 * scale, headSize * 0.92), GOLD, Vector3.new(0, crownY + 0.2 * scale, 0), origin).Parent = model
		for i, dx in ipairs({ -0.32, 0.32 }) do
			for _, dz in ipairs({ -0.32, 0.32 }) do
				makePart("CrownSpike" .. i .. (dz > 0 and "F" or "B"), Vector3.new(0.3 * scale, 0.75 * scale, 0.3 * scale), GOLD, Vector3.new(dx * headSize, crownY + 0.75 * scale, dz * headSize), origin).Parent = model
			end
		end
	end

	-- A halo: a flat glowing ring floating above everything else. A
	-- cylinder reads as a ring from every angle a player actually sees.
	if look.Halo then
		local halo = makePart(
			"Halo",
			Vector3.new(2.3 * scale, 0.22 * scale, 2.3 * scale),
			HALO_COLOR,
			Vector3.new(0, headY + headSize / 2 + 1.15 * scale, 0),
			origin
		)
		halo.Shape = Enum.PartType.Cylinder
		glowify(halo)
		halo.Parent = model
	end

	-- The divine treatment: the whole body glows softly.
	if look.Glow then
		body.Material = Enum.Material.Neon
	end

	-- Floating name tag: name in the rarity colour, income underneath.
	-- The offset is computed from the full built height, so even a
	-- colossal Dewa Langit's tag sits above its halo, not inside it.
	local tagHeight = bodyHeight + headSize + (if look.Halo then 1.7 * scale else 1.1)
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(220, 62)
	tag.StudsOffset = Vector3.new(0, tagHeight, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 90

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Name = "NameLabel"
	nameLabel.Size = UDim2.fromScale(1, 0.58)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextScaled = true
	nameLabel.Text = def.Name
	nameLabel.TextColor3 = BrainrotDefs.RarityColors[def.Rarity]
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Parent = tag

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Name = "InfoLabel"
	infoLabel.Position = UDim2.fromScale(0, 0.58)
	infoLabel.Size = UDim2.fromScale(1, 0.42)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.Gotham
	infoLabel.TextScaled = true
	infoLabel.Text = def.Rarity .. " · " .. BrainrotDefs.FormatCash(def.Income) .. " Coin/s"
	infoLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Parent = tag

	tag.Adornee = body
	tag.Parent = model

	return model
end

-- Total height of a built brainrot, so pads and carriers can lift it right.
function BrainrotFactory.Height(def): number
	local scale = def.Scale or 1
	return 3.2 * scale + 2.1 * scale
end

return BrainrotFactory
