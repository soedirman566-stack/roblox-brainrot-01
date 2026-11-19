-- BRAINROT TYCOON — server bootstrap.
-- Creates the remotes, wires the systems together, greets players with a
-- base and a character on it, runs the income tick and answers rebirths.
-- The systems themselves live in the modules beside this script.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotDefs = require(script:WaitForChild("BrainrotDefs"))
local Economy = require(script:WaitForChild("Economy"))
local PlotManager = require(script:WaitForChild("PlotManager"))
local Steal = require(script:WaitForChild("Steal"))
local Conveyor = require(script:WaitForChild("Conveyor"))
local Tsunami = require(script:WaitForChild("Tsunami"))
local Signs = require(script:WaitForChild("Signs"))

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
remotes.Parent = ReplicatedStorage

local function notify(player: Player, text: string)
	notifyRemote:FireClient(player, text)
end

Signs.Init()
PlotManager.Init({
	OnPlaced = function(record)
		Steal.AttachPrompt(record)
	end,
})
Steal.Init({ Plots = PlotManager, Economy = Economy, Notify = notify })
Conveyor.Init({ Plots = PlotManager, Economy = Economy, Notify = notify })
Tsunami.Init({ Plots = PlotManager, Steal = Steal, Conveyor = Conveyor, AlertRemote = tsunamiAlert })

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
end

local function onPlayerAdded(player: Player)
	Economy.SetupPlayer(player)
	PlotManager.AssignBase(player)
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
		notify(player, "Rebirth needs $" .. BrainrotDefs.FormatCash(cost) .. " — keep earning!")
	end
end)

-- The income tick: every second, every placed brainrot pays its owner,
-- scaled by the owner's rebirth multiplier.
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			if Economy.Get(player) then
				local income = PlotManager.TotalIncome(player) * Economy.Multiplier(player)
				if income > 0 then
					Economy.AddCash(player, income)
				end
				player:SetAttribute("IncomePerSec", income)
			end
		end
	end
end)

Conveyor.Start()
Tsunami.Start()

print("Brainrot Tycoon server is running")
