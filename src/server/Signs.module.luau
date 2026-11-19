-- Signs: hangs text on the world's sign boards. The Rojo project file can
-- only place plain parts (its JSON cannot express Gui sizes), so the boards
-- are named in the project and this module finds them and gives each a
-- SurfaceGui label on both faces. One job: sign text.

local Workspace = game:GetService("Workspace")

local Signs = {}

local TEXTS: { [string]: { Text: string, Color: Color3 } } = {
	WelcomeSign = { Text = "BRAINROT TYCOON", Color = Color3.fromRGB(255, 255, 160) },
	TsunamiSign = { Text = "TSUNAMI ZONE", Color = Color3.fromRGB(180, 230, 255) },
}

local function labelBoard(board: BasePart, text: string, color: Color3)
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

	local bases = Workspace:FindFirstChild("Bases")
	if bases then
		for _, base in ipairs(bases:GetChildren()) do
			local board = base:FindFirstChild("SignBoard")
			if board then
				local number = string.match(base.Name, "%d+")
				labelBoard(board, "BASE " .. (number or "?"), Color3.fromRGB(255, 255, 255))
			end
		end
	end
end

return Signs
