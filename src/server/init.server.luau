-- BRAINROT TYCOON — server bootstrap.
-- Creates the remotes, wires the systems together, greets players with a
-- base and a character on it, runs the income tick and answers rebirths
-- and shop requests. The systems themselves live in the modules beside
-- this script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(script:WaitForChild("BrainrotDefs"))
local Economy = require(script:WaitForChild("Economy"))
local PlotManager = require(script:WaitForChild("PlotManager"))
local Steal = require(script:WaitForChild("Steal"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local Tsunami = require(script:WaitForChild("Tsunami"))
local Signs = require(script:WaitForChild("Signs"))
local SpeedPass = require(script:WaitForChild("SpeedPass"))
local Pen = require(script:WaitForChild("Pen"))
local Treadmill = require(script:WaitForChild("Treadmill"))
local Eggs = require(script:WaitForChild("Eggs"))
local LuckyBlocks = require(script:WaitForChild("LuckyBlocks"))
local DayNight = require(script:WaitForChild("DayNight"))

-- Remotes the client HUD talks on.
local remotes = Instance.new("Folder")
remotes.Name = "BrainrotRemotes"
local rebirthRequest = Instance.new("RemoteEvent")
rebirthRequest.Name = "RebirthRequest"
rebirthRequest.Parent = remotes
local tsunamiAlert = Instance.new("RemoteEvent")
tsunamiAlert.Name = "TsunamiAlert"
tsunamiAlert.Parent = remotes
local notifyRemote = Instance.new("RemoteEvent")
notifyRemote.Name = "Notify"
notifyRemote.Parent = remotes
local shopRequest = Instance.new("RemoteEvent")
shopRequest.Name = "ShopRequest"
shopRequest.Parent = remotes
local treadmillProgress = Instance.new("RemoteEvent")
treadmillProgress.Name = "TreadmillProgress"
treadmillProgress.Parent = remotes
remotes.Parent = ReplicatedStorage

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

local function broadcast(text: string)
	notifyRemote:FireAllClients(text)
end

Signs.Init()
PlotManager.Init({
	OnPlaced = function(record)
		Steal.AttachPrompt(record)
	end,
})
Steal.Init({
	Plots = PlotManager,
	Economy = Economy,
	Notify = notify,
	GetCarrySpeed = function(player)
		return SpeedPass.CarrySpeed(player)
	end,
	RestoreSpeed = function(player)
		SpeedPass.ApplySpeed(player)
	end,
})
SpeedPass.Init({ Economy = Economy, Notify = notify })
Pen.Init({ Economy = Economy, Plots = PlotManager, Signs = Signs, Notify = notify })
Conveyor.Init({ Plots = PlotManager, Economy = Economy, Notify = notify })
Tsunami.Init({ Plots = PlotManager, Steal = Steal, Conveyor = Conveyor, AlertRemote = tsunamiAlert })
Treadmill.Init({
	Economy = Economy,
	Plots = PlotManager,
	Notify = notify,
	ProgressRemote = treadmillProgress,
	EffectiveSpeed = function(player)
		return SpeedPass.EffectiveSpeed(player)
	end,
})
Eggs.Init({ Economy = Economy, Plots = PlotManager, Notify = notify })
LuckyBlocks.Init({ Economy = Economy, Plots = PlotManager, Notify = notify })
DayNight.Init({ Conveyor = Conveyor, Broadcast = broadcast })

local function onCharacterAdded(player: Player, character: Model)
	local base = PlotManager.GetBase(player)
	if not base then
		return
	end
	local homePad = base:FindFirstChild("HomePad")
	local root = character:WaitForChild("HumanoidRootPart", 10)
	if homePad and root then
		character:PivotTo(CFrame.new(homePad.Position + Vector3.new(0, 4, 0)))
	end
	SpeedPass.ApplySpeed(player)
end

local function onPlayerAdded(player: Player)
	Economy.SetupPlayer(player)
	PlotManager.AssignBase(player)
	Pen.OnBaseAssigned(player)
	Eggs.RefreshNest(player)
	task.spawn(function()
		SpeedPass.CheckPasses(player)
	end)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	notify(player, "Welcome to Brainrot Tycoon! Buy brainrots from the belt.")
end

local function onPlayerRemoving(player: Player)
	Steal.DropCarried(player)
	Eggs.ClearNest(player)
	LuckyBlocks.ClearBlock(player)
	PlotManager.ReleaseBase(player)
	Economy.CleanupPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

rebirthRequest.OnServerEvent:Connect(function(player)
	local ok, cost = Economy.DoRebirth(player)
	if ok then
		Steal.DropCarried(player)
		PlotManager.ClearPlayer(player)
		notify(player, "REBIRTH! Your income is permanently boosted.")
	else
		notify(player, "Rebirth needs " .. BrainrotDefs.FormatCash(cost) .. " Coin — keep earning!")
	end
end)

-- The shop panel's requests, routed to the system that owns each sale.
-- Every handler re-checks price and state on the server; the client's
-- numbers are display only.
shopRequest.OnServerEvent:Connect(function(player, action, arg)
	if action == "BuySpeedTier" then
		SpeedPass.BuyNextTier(player)
	elseif action == "BuyPen" then
		Pen.BuyUpgrade(player)
	elseif action == "BuyTreadmill" then
		Treadmill.BuyUpgrade(player)
	elseif action == "BuyEgg" and type(arg) == "number" then
		Eggs.BuyEgg(player, arg)
	elseif action == "BuyLuckyBlock" and type(arg) == "number" then
		LuckyBlocks.BuyBlock(player, arg)
	end
end)

-- The income tick: every second, every placed brainrot pays its owner,
-- scaled by the owner's rebirth x pen multiplier.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if Economy.Get(player) then
				local income = PlotManager.TotalIncome(player) * Economy.Multiplier(player)
				if income > 0 then
					Economy.AddCoin(player, income)
				end
				player:SetAttribute("IncomePerSec", income)
			end
		end
	end
end)

-- The leaderboard board near spawn: top earners, refreshed on a timer.
task.spawn(function()
	while true do
		task.wait(10)
		local ranked = {}
		for _, player in ipairs(Players:GetPlayers()) do
			local entry = Economy.Get(player)
			if entry then
				table.insert(ranked, { Name = player.DisplayName, Earned = entry.TotalEarned })
			end
		end
		table.sort(ranked, function(a, b)
			return a.Earned > b.Earned
		end)
		local lines = { "🏆 TOP EARNERS" }
		for i = 1, math.min(3, #ranked) do
			table.insert(lines, i .. ". " .. ranked[i].Name .. " — " .. BrainrotDefs.FormatCash(ranked[i].Earned) .. " Coin")
		end
		if #ranked == 0 then
			table.insert(lines, "No earners yet —")
			table.insert(lines, "be the first!")
		end
		Signs.SetLeaderboard(lines)
	end
end)

Conveyor.Start()
Tsunami.Start()
Treadmill.Start()
Eggs.Start()
DayNight.Start()

print("Brainrot Tycoon server is running")
