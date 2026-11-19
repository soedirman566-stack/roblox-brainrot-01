-- Signs: hangs text on the world's sign boards. The Rojo project file can
-- only place plain parts (its JSON cannot express Gui sizes), so the boards
-- are named in the project and this module finds them and gives each a
-- SurfaceGui label on both faces. One job: sign text — static boards at
-- boot (welcome tower, shop, shrine, the six rarity arches over the belt,
-- the treadmill, the egg hatchery and the lucky block stand), and live
-- boards after that: every base board shows its owner's name and pen
-- level, and the leaderboard board near spawn lists the top earners.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local Signs = {}

local TEXTS: { [string]: { Text: string, Color: Color3 } } = {
	TsunamiSign = { Text = "TSUNAMI ZONE", Color = Color3.fromRGB(180, 230, 255) },
	LeaderboardSign = { Text = "TOP EARNERS", Color = Color3.fromRGB(255, 226, 130) },
}

-- The conveyor arches carry the rarity ladder in order, west to east.
local ARCH_TEXTS: { [string]: string } = {
	ArchSignCommon = "COMMON",
	ArchSignRare = "RARE",
	ArchSignEpic = "EPIC",
	ArchSignLegendary = "LEGENDARY",
	ArchSignMythic = "MYTHIC",
	ArchSignDewa = "DEWA LANGIT",
}

local boardLabels: { [BasePart]: { TextLabel } } = {}

local function labelBoard(board: BasePart, text: string, color: Color3)
	local labels = {}
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignText"
		gui.Face = face
		gui.CanvasSize = Vector2.new(800, 200)
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = text
		label.TextColor3 = color
		label.Parent = gui
		gui.Parent = board
		table.insert(labels, label)
	end
	boardLabels[board] = labels
	return labels
end

local function setBoardText(board: BasePart, text: string)
	local labels = boardLabels[board]
	if labels then
		for _, label in ipairs(labels) do
			label.Text = text
		end
	end
end

function Signs.Init()
	for name, spec in pairs(TEXTS) do
		local board = Workspace:FindFirstChild(name)
		if board and board:IsA("BasePart") then
			labelBoard(board, spec.Text, spec.Color)
		end
	end

	local shop = Workspace:FindFirstChild("Shop")
	local shopBoard = shop and shop:FindFirstChild("SignBoard")
	if shopBoard then
		labelBoard(shopBoard, "BRAINROT SHOP", Color3.fromRGB(255, 226, 130))
	end

	local shrine = Workspace:FindFirstChild("Shrine")
	local shrineBoard = shrine and shrine:FindFirstChild("SignBoard")
	if shrineBoard then
		labelBoard(shrineBoard, "REBIRTH SHRINE", Color3.fromRGB(255, 240, 200))
	end

	local lane = Workspace:FindFirstChild("Lane")
	if lane then
		-- The boards hang inside the Arch1..Arch6 folders along the lane.
		for _, archFolder in ipairs(lane:GetChildren()) do
			for partName, text in pairs(ARCH_TEXTS) do
				local board = archFolder:FindFirstChild(partName)
				if board then
					local rarity = string.gsub(partName, "ArchSign", "")
					if rarity == "Dewa" then
						rarity = "Dewa Langit"
					end
					labelBoard(board, text, BrainrotDefs.RarityColors[rarity] or Color3.new(1, 1, 1))
				end
			end
		end
	end

	local treadmill = Workspace:FindFirstChild("Treadmill")
	local treadmillBoard = treadmill and treadmill:FindFirstChild("TreadmillSign")
	if treadmillBoard then
		labelBoard(treadmillBoard, "TREADMILL", Color3.fromRGB(140, 255, 190))
	end

	local eggs = Workspace:FindFirstChild("EggStation")
	local eggBoard = eggs and eggs:FindFirstChild("EggStationSign")
	if eggBoard then
		labelBoard(eggBoard, "EGG HATCHERY", Color3.fromRGB(255, 200, 230))
	end

	local lucky = Workspace:FindFirstChild("LuckyBlockStand")
	local luckyBoard = lucky and lucky:FindFirstChild("LuckySign")
	if luckyBoard then
		labelBoard(luckyBoard, "LUCKY BLOCKS", Color3.fromRGB(255, 226, 130))
	end

	local bases = Workspace:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			local board = base:FindFirstChild("SignBoard")
			if board then
				local number = string.match(base.Name, "%d+")
				labelBoard(board, "BASE " .. (number or "?"), Color3.fromRGB(255, 255, 255))
			end
			local penBoard = base:FindFirstChild("PenBoard")
			if penBoard then
				labelBoard(penBoard, "PEN Lv.1", Color3.fromRGB(255, 226, 130))
			end
		end
	end
end

-- A base board comes alive: owner's name on the big board, pen level
-- (and next-level price) on the little pen board beside the upgrade post.
function Signs.RefreshBaseBoard(base: Folder)
	local number = string.match(base.Name, "%d+") or "?"
	local ownerId = base:GetAttribute("OwnerUserId")
	local board = base:FindFirstChild("SignBoard")
	if board then
		if ownerId then
			local owner = Players:GetPlayerByUserId(ownerId)
			setBoardText(board, (owner and owner.DisplayName or "BASE " .. number) .. "'S BASE")
		else
			setBoardText(board, "BASE " .. number)
		end
	end
	local penBoard = base:FindFirstChild("PenBoard")
	if penBoard then
		local level = base:GetAttribute("PenLevel") or 1
		setBoardText(penBoard, "PEN Lv." .. level)
	end
end

-- The leaderboard board near spawn: title line plus the top earners.
function Signs.SetLeaderboard(lines: { string })
	local board = Workspace:FindFirstChild("LeaderboardSign")
	if board then
		setBoardText(board, table.concat(lines, "\n"))
	end
end

return Signs
