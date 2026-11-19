-- Pen: the kandang upgrade system. Every base has an upgrade post with
-- a prompt only its owner can use: pay Coin, gain a pen level (1-20).
-- Levels unlock more of the base's 24 pads, add +2% income each
-- (Economy.Multiplier reads the level), and step the pen's look up at
-- milestones (PlotManager.RefreshPen does the painting). One job: pen
-- purchases and keeping the post's prompt honest about the next price.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local Pen = {}

local economy = nil
local plots = nil
local signs = nil
local notify: ((Player, string) -> ())? = nil

local promptByBase: { [Folder]: ProximityPrompt } = {}

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

local function refreshPrompt(base: Folder)
	local prompt = promptByBase[base]
	if not prompt then
		return
	end
	local level = base:GetAttribute("PenLevel") or 1
	if level >= GameConfig.PenMaxLevel then
		prompt.ActionText = "PEN MAXED"
	else
		prompt.ActionText = "Upgrade · " .. BrainrotDefs.FormatCash(GameConfig.PenUpgradeCost(level)) .. " Coin"
	end
	prompt.ObjectText = "Pen Lv." .. level .. " · " .. GameConfig.PenCapacity(level) .. " pads"
end

function Pen.Init(deps)
	economy = deps.Economy
	plots = deps.Plots
	signs = deps.Signs
	notify = deps.Notify

	for _, base in ipairs(plots.GetBases()) do
		base:SetAttribute("PenLevel", 1)
		local post = base:FindFirstChild("PenPost")
		if post then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "PenUpgradePrompt"
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = post
			promptByBase[base] = prompt
			refreshPrompt(base)
			prompt.Triggered:Connect(function(player)
				Pen.OnPrompt(base, player)
			end)
		end
	end
end

-- Called when a player takes over a base: the board and the prompt
-- switch to their pen level.
function Pen.OnBaseAssigned(player: Player)
	local base = plots.GetBase(player)
	if not base then
		return
	end
	local entry = economy.Get(player)
	base:SetAttribute("PenLevel", entry and entry.PenLevel or 1)
	refreshPrompt(base)
	signs.RefreshBaseBoard(base)
end

function Pen.OnPrompt(base: Folder, player: Player)
	local ownerId = base:GetAttribute("OwnerUserId")
	if not ownerId or Players:GetPlayerByUserId(ownerId) ~= player then
		tell(player, "This is not your pen!")
		return
	end
	Pen.BuyUpgrade(player)
end

-- Sells the next pen level to the base's owner.
function Pen.BuyUpgrade(player: Player)
	local entry = economy.Get(player)
	local base = plots.GetBase(player)
	if not entry or not base then
		return
	end
	local level = entry.PenLevel
	if level >= GameConfig.PenMaxLevel then
		tell(player, "Your pen is already MAX level!")
		return
	end
	local cost = GameConfig.PenUpgradeCost(level)
	if not economy.TrySpend(player, cost) then
		tell(player, "Pen Lv." .. (level + 1) .. " needs " .. BrainrotDefs.FormatCash(cost) .. " Coin!")
		return
	end
	economy.SetPenLevel(player, level + 1)
	base:SetAttribute("PenLevel", level + 1)
	plots.RefreshPen(player)
	refreshPrompt(base)
	signs.RefreshBaseBoard(base)
	tell(player, "Pen upgraded to Lv." .. (level + 1) .. " — " .. GameConfig.PenCapacity(level + 1) .. " pads, +2% income!")
end

return Pen
