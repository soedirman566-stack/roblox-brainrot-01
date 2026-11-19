-- BrainrotFactory: builds the 3D model of one brainrot from its definition.
-- One job: turn a BrainrotDefs row into a Model — a chunky body, a head, two
-- eyes and a floating name tag — that the conveyor, the bases and thieves
-- can all carry around the same way.

local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local BrainrotFactory = {}

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

-- Builds the model with its feet at the given CFrame's origin, facing -Z of
-- that frame. The model is anchored: movers reposition it with PivotTo.
function BrainrotFactory.Build(def, origin: CFrame): Model
	local scale = def.Scale or 1
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
	local head = makePart(
		"Head",
		Vector3.new(headSize, headSize, headSize),
		def.Color:Lerp(Color3.new(1, 1, 1), 0.18),
		Vector3.new(0, bodyHeight + headSize / 2, 0),
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
	gem.Parent = model

	-- Floating name tag: name in the rarity colour, income underneath.
	local tag = Instance.new("BillboardGui")
	tag.Name = "NameTag"
	tag.Size = UDim2.fromOffset(220, 62)
	tag.StudsOffset = Vector3.new(0, bodyHeight + headSize + 1.1, 0)
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
	infoLabel.Text = def.Rarity .. " · $" .. BrainrotDefs.FormatCash(def.Income) .. "/s"
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
