-- BRAINROT TYCOON — client HUD.
-- One job: show the player their game — cash, income per second, rebirths,
-- the rebirth button, the brainrot catalog, tsunami warnings, server
-- notifications and a "you are carrying" flag. All state lives on the
-- server; this script only displays it and fires the rebirth remote.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local stats = player:WaitForChild("leaderstats")
local cashValue = stats:WaitForChild("Cash")
local rebirthsValue = stats:WaitForChild("Rebirths")
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local rebirthRequest = remotes:WaitForChild("RebirthRequest")
local tsunamiAlert = remotes:WaitForChild("TsunamiAlert")
local notifyRemote = remotes:WaitForChild("Notify")

local REBIRTH_BASE_COST = 25000
local REBIRTH_COST_GROWTH = 4

-- Display copy of the catalog (the server owns the real numbers; this is
-- only so the panel can list names, rarities, prices and incomes).
local CATALOG = {
	{ "Noobini", "Common", 25, 1 }, { "Pizzanini", "Common", 60, 2 },
	{ "Burp Froggo", "Common", 120, 4 }, { "Sir Quackalot", "Common", 250, 8 },
	{ "DJ Bananini", "Rare", 600, 16 }, { "Turbo Toastini", "Rare", 1300, 30 },
	{ "Capitano Cappuccino", "Rare", 3000, 65 }, { "Glorbo Melonini", "Epic", 7000, 140 },
	{ "Zibra Zebroni", "Epic", 15000, 290 }, { "Robo Rizzini", "Epic", 32000, 600 },
	{ "King Kokonut", "Legendary", 75000, 1350 }, { "La Mucca Banana", "Legendary", 180000, 3000 },
	{ "Tiburon Fantasma", "Mythic", 450000, 7500 }, { "Godini Brainrotti", "Mythic", 1100000, 19000 },
}
local RARITY_COLORS = {
	Common = Color3.fromRGB(178, 190, 181),
	Rare = Color3.fromRGB(84, 150, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 46),
	Mythic = Color3.fromRGB(255, 84, 150),
}

local function formatCash(amount: number): string
	local text = tostring(math.floor(amount))
	local out = ""
	while #text > 3 do
		out = "," .. string.sub(text, -3) .. out
		text = string.sub(text, 1, -4)
	end
	return text .. out
end

local gui = Instance.new("ScreenGui")
gui.Name = "BrainrotGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local function makeLabel(parent, name, size, position, text, color, textSize)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.Size = size
	label.Position = position
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.TextColor3 = color
	label.TextSize = textSize
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Parent = parent
	return label
end

-- Top bar: cash, income, rebirths.
local topBar = Instance.new("Frame")
topBar.Name = "TopBar"
topBar.AnchorPoint = Vector2.new(0.5, 0)
topBar.Position = UDim2.new(0.5, 0, 0, 10)
topBar.Size = UDim2.fromOffset(560, 52)
topBar.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
topBar.BackgroundTransparency = 0.25
topBar.BorderSizePixel = 0
topBar.Parent = gui
local topCorner = Instance.new("UICorner")
topCorner.CornerRadius = UDim.new(0, 12)
topCorner.Parent = topBar

local cashLabel = makeLabel(topBar, "Cash", UDim2.fromOffset(210, 52), UDim2.fromOffset(18, 0), "$0", Color3.fromRGB(140, 255, 150), 26)
local incomeLabel = makeLabel(topBar, "Income", UDim2.fromOffset(170, 52), UDim2.fromOffset(235, 0), "+0/s", Color3.fromRGB(255, 226, 130), 22)
local rebirthLabel = makeLabel(topBar, "Rebirths", UDim2.fromOffset(140, 52), UDim2.fromOffset(415, 0), "⭐ 0", Color3.fromRGB(210, 190, 255), 22)

local function refreshTopBar()
	cashLabel.Text = "$" .. formatCash(cashValue.Value)
	rebirthLabel.Text = "⭐ " .. tostring(rebirthsValue.Value)
end
cashValue.Changed:Connect(refreshTopBar)
rebirthsValue.Changed:Connect(refreshTopBar)
player:GetAttributeChangedSignal("IncomePerSec"):Connect(function()
	incomeLabel.Text = "+" .. formatCash(player:GetAttribute("IncomePerSec") or 0) .. "/s"
end)
refreshTopBar()

-- Tsunami warning banner.
local banner = Instance.new("TextLabel")
banner.Name = "TsunamiBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 74)
banner.Size = UDim2.fromOffset(620, 58)
banner.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
banner.BackgroundTransparency = 0.15
banner.BorderSizePixel = 0
banner.Font = Enum.Font.GothamBold
banner.TextColor3 = Color3.fromRGB(255, 255, 255)
banner.TextSize = 26
banner.Visible = false
banner.Parent = gui
local bannerCorner = Instance.new("UICorner")
bannerCorner.CornerRadius = UDim.new(0, 12)
bannerCorner.Parent = banner

local bannerToken = 0
tsunamiAlert.OnClientEvent:Connect(function(seconds)
	bannerToken += 1
	local token = bannerToken
	if seconds > 0 then
		banner.Visible = true
		for left = seconds, 1, -1 do
			if bannerToken ~= token then
				return
			end
			banner.Text = "🌊 TSUNAMI IN " .. left .. "s — GET TO A BASE! 🌊"
			task.wait(1)
		end
	else
		banner.Visible = true
		banner.Text = "🌊 TSUNAMI! 🌊"
		task.wait(3)
		if bannerToken == token then
			banner.Visible = false
		end
	end
end)

-- Carrying flag.
local carryLabel = makeLabel(gui, "Carrying", UDim2.fromOffset(560, 40), UDim2.new(0.5, -280, 0, 140),
	"🏃 Carrying a brainrot — get it back to YOUR base!", Color3.fromRGB(255, 170, 90), 22)
carryLabel.TextXAlignment = Enum.TextXAlignment.Center
carryLabel.Visible = false
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	carryLabel.Visible = player:GetAttribute("Carrying") == true
end)

-- Notification toast.
local toast = makeLabel(gui, "Toast", UDim2.fromOffset(640, 44), UDim2.new(0.5, -320, 1, -120),
	"", Color3.fromRGB(255, 255, 255), 24)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.TextStrokeTransparency = 0.5
local toastToken = 0
notifyRemote.OnClientEvent:Connect(function(text)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	task.wait(3.5)
	if toastToken == token then
		toast.Text = ""
	end
end)

-- Rebirth button.
local rebirthButton = Instance.new("TextButton")
rebirthButton.Name = "RebirthButton"
rebirthButton.AnchorPoint = Vector2.new(1, 1)
rebirthButton.Position = UDim2.new(1, -16, 1, -16)
rebirthButton.Size = UDim2.fromOffset(230, 74)
rebirthButton.BackgroundColor3 = Color3.fromRGB(104, 68, 190)
rebirthButton.BorderSizePixel = 0
rebirthButton.Font = Enum.Font.GothamBold
rebirthButton.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthButton.TextSize = 18
rebirthButton.Parent = gui
local rebirthCorner = Instance.new("UICorner")
rebirthCorner.CornerRadius = UDim.new(0, 12)
rebirthCorner.Parent = rebirthButton

local function refreshRebirthButton()
	local cost = REBIRTH_BASE_COST * (REBIRTH_COST_GROWTH ^ rebirthsValue.Value)
	rebirthButton.Text = "⭐ REBIRTH ⭐\n$" .. formatCash(cost) .. " · +50% income"
end
rebirthsValue.Changed:Connect(refreshRebirthButton)
refreshRebirthButton()
rebirthButton.Activated:Connect(function()
	rebirthRequest:FireServer()
end)

-- Catalog panel.
local catalogButton = Instance.new("TextButton")
catalogButton.Name = "CatalogButton"
catalogButton.Position = UDim2.fromOffset(16, 120)
catalogButton.Size = UDim2.fromOffset(150, 46)
catalogButton.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
catalogButton.BackgroundTransparency = 0.25
catalogButton.BorderSizePixel = 0
catalogButton.Font = Enum.Font.GothamBold
catalogButton.Text = "📖 Catalog"
catalogButton.TextColor3 = Color3.fromRGB(255, 255, 255)
catalogButton.TextSize = 20
catalogButton.Parent = gui
local catalogCorner = Instance.new("UICorner")
catalogCorner.CornerRadius = UDim.new(0, 10)
catalogCorner.Parent = catalogButton

local panel = Instance.new("ScrollingFrame")
panel.Name = "CatalogPanel"
panel.Position = UDim2.fromOffset(16, 176)
panel.Size = UDim2.fromOffset(330, 380)
panel.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
panel.BackgroundTransparency = 0.2
panel.BorderSizePixel = 0
panel.ScrollBarThickness = 6
panel.Visible = false
panel.Parent = gui
local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 10)
panelCorner.Parent = panel
local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 4)
layout.Parent = panel

for _, row in ipairs(CATALOG) do
	local name, rarity, price, income = row[1], row[2], row[3], row[4]
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -12, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name .. "  ·  $" .. formatCash(price) .. "  ·  $" .. formatCash(income) .. "/s"
	label.TextColor3 = RARITY_COLORS[rarity]
	label.Parent = panel
end
panel.CanvasSize = UDim2.fromOffset(0, #CATALOG * 34 + 8)

catalogButton.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)

-- Help line.
local help = makeLabel(gui, "Help", UDim2.fromOffset(700, 30), UDim2.new(0, 16, 1, -44),
	"Buy from the belt · Catch wild ones free · Steal rivals' brainrots · Step on your black pad to LOCK your base · Bases are tsunami-safe!",
	Color3.fromRGB(230, 230, 230), 15)
help.TextStrokeTransparency = 0.6
