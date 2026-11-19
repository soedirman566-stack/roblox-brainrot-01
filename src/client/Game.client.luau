-- BRAINROT TYCOON — client HUD.
-- One job: show the player their game — Coin, income per second, speed,
-- rebirths, the day/night clock, the shop (speed tiers, Robux speed
-- passes, pen and treadmill upgrades, eggs), the brainrot catalog,
-- the treadmill meter, tsunami warnings, server notifications and a
-- "you are carrying" flag. All state lives on the server; this script
-- only displays it and fires requests. Prices come from the shared
-- GameConfig so the panel can never drift from the server's numbers.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local stats = player:WaitForChild("leaderstats")
local coinValue = stats:WaitForChild("Coin")
local rebirthsValue = stats:WaitForChild("Rebirths")
local remotes = ReplicatedStorage:WaitForChild("BrainrotRemotes")
local rebirthRequest = remotes:WaitForChild("RebirthRequest")
local tsunamiAlert = remotes:WaitForChild("TsunamiAlert")
local notifyRemote = remotes:WaitForChild("Notify")
local shopRequest = remotes:WaitForChild("ShopRequest")
local treadmillProgress = remotes:WaitForChild("TreadmillProgress")

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
	{ "Squalo Dorato", "Epic", 48000, 1050 }, { "Pando Roboto", "Epic", 65000, 1400 },
	{ "King Kokonut", "Legendary", 75000, 1350 }, { "La Mucca Banana", "Legendary", 180000, 3000 },
	{ "Elefante Cristallo", "Legendary", 260000, 4600 }, { "Pavone Reale", "Legendary", 380000, 6800 },
	{ "Tiburon Fantasma", "Mythic", 450000, 7500 }, { "Godini Brainrotti", "Mythic", 1100000, 19000 },
	{ "Gatto Galattico", "Mythic", 1600000, 26000 }, { "Drago Vulcano", "Mythic", 2400000, 40000 },
	{ "Naga Langit Suci", "Dewa Langit", 12000000, 220000 }, { "Feniks Bintang", "Dewa Langit", 20000000, 380000 },
	{ "Paus Bulan", "Dewa Langit", 32000000, 600000 },
}
local RARITY_COLORS = {
	Common = Color3.fromRGB(178, 190, 181),
	Rare = Color3.fromRGB(84, 150, 255),
	Epic = Color3.fromRGB(178, 102, 255),
	Legendary = Color3.fromRGB(255, 196, 46),
	Mythic = Color3.fromRGB(255, 84, 150),
	["Dewa Langit"] = Color3.fromRGB(255, 242, 194),
}

local function formatCoin(amount: number): string
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

local function panelFrame(name, size, position)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = frame
	return frame
end

-- Top bar: Coin, income, speed, rebirths.
local topBar = panelFrame("TopBar", UDim2.fromOffset(640, 52), UDim2.new(0.5, -320, 0, 10))
local coinLabel = makeLabel(topBar, "Coin", UDim2.fromOffset(215, 52), UDim2.fromOffset(16, 0), "Coin: 0", Color3.fromRGB(140, 255, 150), 24)
local incomeLabel = makeLabel(topBar, "Income", UDim2.fromOffset(165, 52), UDim2.fromOffset(238, 0), "+0/s", Color3.fromRGB(255, 226, 130), 20)
local speedLabel = makeLabel(topBar, "Speed", UDim2.fromOffset(105, 52), UDim2.fromOffset(408, 0), "⚡ 16", Color3.fromRGB(150, 220, 255), 20)
local rebirthLabel = makeLabel(topBar, "Rebirths", UDim2.fromOffset(110, 52), UDim2.fromOffset(520, 0), "⭐ 0", Color3.fromRGB(210, 190, 255), 20)

local function refreshTopBar()
	coinLabel.Text = "Coin: " .. formatCoin(coinValue.Value)
	rebirthLabel.Text = "⭐ " .. tostring(rebirthsValue.Value)
	speedLabel.Text = "⚡ " .. tostring(player:GetAttribute("EffectiveSpeed") or 16)
end
coinValue.Changed:Connect(refreshTopBar)
rebirthsValue.Changed:Connect(refreshTopBar)
player:GetAttributeChangedSignal("EffectiveSpeed"):Connect(refreshTopBar)
player:GetAttributeChangedSignal("IncomePerSec"):Connect(function()
	incomeLabel.Text = "+" .. formatCoin(player:GetAttribute("IncomePerSec") or 0) .. "/s"
end)
refreshTopBar()

-- Day/night widget: phase icon, day counter, phase progress bar.
local clockFrame = panelFrame("Clock", UDim2.fromOffset(210, 44), UDim2.new(0.5, -105, 0, 70))
local clockLabel = makeLabel(clockFrame, "Phase", UDim2.fromOffset(190, 24), UDim2.fromOffset(10, 2), "☀️ Day 1", Color3.fromRGB(255, 255, 255), 17)
local clockBarBack = Instance.new("Frame")
clockBarBack.Name = "BarBack"
clockBarBack.Position = UDim2.fromOffset(10, 30)
clockBarBack.Size = UDim2.fromOffset(190, 8)
clockBarBack.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
clockBarBack.BorderSizePixel = 0
clockBarBack.Parent = clockFrame
local clockBarFill = Instance.new("Frame")
clockBarFill.Name = "BarFill"
clockBarFill.Size = UDim2.fromScale(0, 1)
clockBarFill.BackgroundColor3 = Color3.fromRGB(255, 205, 80)
clockBarFill.BorderSizePixel = 0
clockBarFill.Parent = clockBarBack

local function refreshClock()
	local phase = Workspace:GetAttribute("PhaseName") or "Day"
	local day = Workspace:GetAttribute("DayNumber") or 1
	local progress = Workspace:GetAttribute("PhaseProgress") or 0
	clockLabel.Text = (if phase == "Night" then "🌙 Night " else "☀️ Day ") .. tostring(day)
	clockBarFill.Size = UDim2.fromScale(math.clamp(progress, 0, 1), 1)
	clockBarFill.BackgroundColor3 = if phase == "Night" then Color3.fromRGB(130, 160, 255) else Color3.fromRGB(255, 205, 80)
end
Workspace:GetAttributeChangedSignal("PhaseName"):Connect(refreshClock)
Workspace:GetAttributeChangedSignal("DayNumber"):Connect(refreshClock)
Workspace:GetAttributeChangedSignal("PhaseProgress"):Connect(refreshClock)
refreshClock()

-- Tsunami warning banner.
local banner = Instance.new("TextLabel")
banner.Name = "TsunamiBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 126)
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
local carryLabel = makeLabel(gui, "Carrying", UDim2.fromOffset(560, 40), UDim2.new(0.5, -280, 0, 196),
	"🏃 Carrying a brainrot — get it back to YOUR base!", Color3.fromRGB(255, 170, 90), 22)
carryLabel.TextXAlignment = Enum.TextXAlignment.Center
carryLabel.Visible = false
player:GetAttributeChangedSignal("Carrying"):Connect(function()
	carryLabel.Visible = player:GetAttribute("Carrying") == true
end)

-- Notification toast.
local toast = makeLabel(gui, "Toast", UDim2.fromOffset(680, 44), UDim2.new(0.5, -340, 1, -120),
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

-- Treadmill meter: fills while you run on the belt.
local meterFrame = panelFrame("TreadmillMeter", UDim2.fromOffset(340, 46), UDim2.new(0.5, -170, 1, -186))
meterFrame.Visible = false
local meterLabel = makeLabel(meterFrame, "Label", UDim2.fromOffset(320, 22), UDim2.fromOffset(10, 1), "🏃 TREADMILL — keep running!", Color3.fromRGB(255, 255, 255), 15)
local meterBack = Instance.new("Frame")
meterBack.Name = "BarBack"
meterBack.Position = UDim2.fromOffset(10, 27)
meterBack.Size = UDim2.fromOffset(320, 10)
meterBack.BackgroundColor3 = Color3.fromRGB(10, 10, 16)
meterBack.BorderSizePixel = 0
meterBack.Parent = meterFrame
local meterFill = Instance.new("Frame")
meterFill.Name = "BarFill"
meterFill.Size = UDim2.fromScale(0, 1)
meterFill.BackgroundColor3 = Color3.fromRGB(120, 255, 160)
meterFill.BorderSizePixel = 0
meterFill.Parent = meterBack

local meterToken = 0
treadmillProgress.OnClientEvent:Connect(function(fraction)
	meterToken += 1
	local token = meterToken
	if fraction > 0 then
		meterFrame.Visible = true
		meterFill.Size = UDim2.fromScale(math.clamp(fraction, 0, 1), 1)
	else
		meterFill.Size = UDim2.fromScale(0, 1)
		task.wait(0.6)
		if meterToken == token then
			meterFrame.Visible = false
		end
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
	rebirthButton.Text = "⭐ REBIRTH ⭐\n" .. formatCoin(cost) .. " Coin · +50% income"
end
rebirthsValue.Changed:Connect(refreshRebirthButton)
refreshRebirthButton()
rebirthButton.Activated:Connect(function()
	rebirthRequest:FireServer()
end)

-- ============================================================
-- Panels: catalog and shop share one slot on the left edge.
-- ============================================================
local function toggleButton(name, y, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.Position = UDim2.fromOffset(16, y)
	button.Size = UDim2.fromOffset(150, 46)
	button.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	button.BackgroundTransparency = 0.25
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = text
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.TextSize = 20
	button.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = button
	return button
end

local function scrollPanel(name)
	local panel = Instance.new("ScrollingFrame")
	panel.Name = name
	panel.Position = UDim2.fromOffset(16, 228)
	panel.Size = UDim2.fromOffset(348, 400)
	panel.BackgroundColor3 = Color3.fromRGB(24, 24, 32)
	panel.BackgroundTransparency = 0.2
	panel.BorderSizePixel = 0
	panel.ScrollBarThickness = 6
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel
	return panel
end

local catalogButton = toggleButton("CatalogButton", 120, "📖 Catalog")
local shopButton = toggleButton("ShopButton", 174, "🛒 Shop")
local catalogPanel = scrollPanel("CatalogPanel")
local shopPanel = scrollPanel("ShopPanel")

catalogButton.Activated:Connect(function()
	catalogPanel.Visible = not catalogPanel.Visible
	if catalogPanel.Visible then
		shopPanel.Visible = false
	end
end)
shopButton.Activated:Connect(function()
	shopPanel.Visible = not shopPanel.Visible
	if shopPanel.Visible then
		catalogPanel.Visible = false
	end
end)

for order, row in ipairs(CATALOG) do
	local name, rarity, price, income = row[1], row[2], row[3], row[4]
	local label = Instance.new("TextLabel")
	label.LayoutOrder = order
	label.Size = UDim2.new(1, -12, 0, 30)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = name .. "  ·  " .. formatCoin(price) .. "  ·  " .. formatCoin(income) .. "/s"
	label.TextColor3 = RARITY_COLORS[rarity]
	label.Parent = catalogPanel
end
catalogPanel.CanvasSize = UDim2.fromOffset(0, #CATALOG * 34 + 8)

-- Shop panel rows. Buttons fire ShopRequest; the server re-checks
-- everything. Labels refresh from player attributes.
local shopOrder = 0
local function shopLabel(text, color, size)
	shopOrder += 1
	local label = Instance.new("TextLabel")
	label.LayoutOrder = shopOrder
	label.Size = UDim2.new(1, -12, 0, size or 26)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.Parent = shopPanel
	return label
end

local function shopBuyButton(text, color)
	shopOrder += 1
	local button = Instance.new("TextButton")
	button.LayoutOrder = shopOrder
	button.Size = UDim2.new(1, -12, 0, 36)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = 15
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.Text = text
	button.Parent = shopPanel
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = button
	return button
end

shopLabel("⚡ SPEED", Color3.fromRGB(150, 220, 255), 30)
local speedInfo = shopLabel("", Color3.fromRGB(230, 230, 230))
local speedBuy = shopBuyButton("", Color3.fromRGB(40, 110, 190))
speedBuy.Activated:Connect(function()
	shopRequest:FireServer("BuySpeedTier")
end)
local pass2Button = shopBuyButton("", Color3.fromRGB(150, 110, 30))
pass2Button.Activated:Connect(function()
	MarketplaceService:PromptGamePassPurchase(player, GameConfig.PassIds.SpeedX2)
end)
local pass5Button = shopBuyButton("", Color3.fromRGB(170, 80, 160))
pass5Button.Activated:Connect(function()
	MarketplaceService:PromptGamePassPurchase(player, GameConfig.PassIds.SpeedX5)
end)

shopLabel("🏠 PEN (KANDANG)", Color3.fromRGB(255, 205, 120), 30)
local penInfo = shopLabel("", Color3.fromRGB(230, 230, 230))
local penBuy = shopBuyButton("", Color3.fromRGB(160, 110, 40))
penBuy.Activated:Connect(function()
	shopRequest:FireServer("BuyPen")
end)

shopLabel("🏃 TREADMILL", Color3.fromRGB(140, 255, 190), 30)
local treadmillInfo = shopLabel("", Color3.fromRGB(230, 230, 230))
local treadmillBuy = shopBuyButton("", Color3.fromRGB(40, 140, 90))
treadmillBuy.Activated:Connect(function()
	shopRequest:FireServer("BuyTreadmill")
end)

shopLabel("🥚 EGGS — hatch at your base", Color3.fromRGB(255, 200, 230), 30)
local eggInfo = shopLabel("", Color3.fromRGB(230, 230, 230))
local eggButtons = {}
for index, eggDef in ipairs(GameConfig.EggDefs) do
	local button = shopBuyButton("", Color3.fromRGB(120, 70, 130))
	button.Text = "🥚 " .. eggDef.Name .. " · " .. formatCoin(eggDef.Price) .. " Coin · " .. eggDef.HatchSeconds .. "s"
	button.Activated:Connect(function()
		shopRequest:FireServer("BuyEgg", index)
	end)
	table.insert(eggButtons, button)
end

shopLabel("🍀 LUCKY BLOCKS — open at the stand", Color3.fromRGB(255, 226, 130), 30)
for index, blockDef in ipairs(GameConfig.LuckyBlockDefs) do
	local button = shopBuyButton("", if blockDef.Golden then Color3.fromRGB(190, 130, 20) else Color3.fromRGB(170, 140, 30))
	button.Text = "🍀 " .. blockDef.Name .. " · " .. formatCoin(blockDef.Price) .. " Coin"
	button.Activated:Connect(function()
		shopRequest:FireServer("BuyLuckyBlock", index)
	end)
end
shopPanel.CanvasSize = UDim2.fromOffset(0, shopOrder * 40 + 220)

local function refreshShop()
	local tier = player:GetAttribute("SpeedTier") or 0
	local effective = player:GetAttribute("EffectiveSpeed") or 16
	speedInfo.Text = "Tier " .. tier .. " · WalkSpeed " .. effective
	local nextSpec = GameConfig.SpeedTiers[tier + 2]
	if nextSpec then
		speedBuy.Text = "Buy Tier " .. (tier + 1) .. " (" .. nextSpec.Speed .. ") · " .. formatCoin(nextSpec.Price) .. " Coin"
	else
		speedBuy.Text = "SPEED MAXED"
	end
	pass2Button.Text = if player:GetAttribute("PassX2") then "⚡ Speed x2 — OWNED ✓" else "⚡ Speed x2 Pass · 1 R$"
	pass5Button.Text = if player:GetAttribute("PassX5") then "⚡ Speed x5 — OWNED ✓" else "⚡ Speed x5 Pass · 5 R$"

	local penLevel = player:GetAttribute("PenLevel") or 1
	local capacity = player:GetAttribute("PenCapacity") or 6
	penInfo.Text = "Pen Lv." .. penLevel .. " · " .. capacity .. " pads · +" .. math.floor(GameConfig.PenIncomeBonusPerLevel * (penLevel - 1) * 100) .. "% income"
	local penCost = GameConfig.PenUpgradeCost(penLevel)
	penBuy.Text = if penCost > 0 then "Upgrade Pen · " .. formatCoin(penCost) .. " Coin" else "PEN MAXED"

	local tmLevel = player:GetAttribute("TreadmillLevel") or 1
	treadmillInfo.Text = "Treadmill Lv." .. tmLevel .. " · run at the station by spawn"
	local tmCost = GameConfig.TreadmillUpgradeCost(tmLevel)
	treadmillBuy.Text = if tmCost > 0 then "Upgrade Treadmill · " .. formatCoin(tmCost) .. " Coin" else "TREADMILL MAXED"

	local eggTier = player:GetAttribute("EggTier") or ""
	if eggTier == "" then
		eggInfo.Text = "Incubator empty — buy an egg!"
	else
		local readyAt = player:GetAttribute("EggReadyAt") or 0
		local left = readyAt - os.time()
		eggInfo.Text = if left > 0
			then "🥚 Telur (" .. eggTier .. ") hatching… " .. left .. "s"
			else "🥚 Telur (" .. eggTier .. ") READY — open it at your nest!"
	end
end
for _, attribute in ipairs({ "SpeedTier", "EffectiveSpeed", "PassX2", "PassX5", "PenLevel", "PenCapacity", "TreadmillLevel", "EggTier", "EggReadyAt" }) do
	player:GetAttributeChangedSignal(attribute):Connect(refreshShop)
end
refreshShop()
-- The egg countdown ticks once a second while an egg is incubating.
task.spawn(function()
	while true do
		task.wait(1)
		if (player:GetAttribute("EggTier") or "") ~= "" then
			refreshShop()
		end
	end
end)

-- Help line.
local help = makeLabel(gui, "Help", UDim2.fromOffset(760, 30), UDim2.new(0, 16, 1, -44),
	"Buy from the belt · Crack lucky blocks · Run the treadmill · Hatch eggs · Upgrade your pen · Every dawn the belt restocks!",
	Color3.fromRGB(230, 230, 230), 15)
help.TextStrokeTransparency = 0.6
