-- Economy: each player's money and progression state — Coin, rebirths,
-- lifetime earnings, speed tier, pen level, treadmill level, Robux pass
-- ownership and the egg currently in their incubator.
-- One job: hold the numbers and the rules that change them (spending,
-- earning, the rebirth ladder, upgrade bookkeeping). It knows nothing
-- about models or pads; the systems that use these numbers live in
-- their own modules and read them through here. Player-facing numbers
-- are mirrored into leaderstats and player attributes so the client
-- HUD can display them without extra remotes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))

local Economy = {}

Economy.StartCoin = 100
Economy.RebirthBaseCost = 25000
Economy.RebirthCostGrowth = 4
Economy.RebirthIncomeBonus = 0.5 -- each rebirth adds +50% income

type PlayerData = {
	Coin: number,
	Rebirths: number,
	TotalEarned: number,
	SpeedTier: number,
	PenLevel: number,
	TreadmillLevel: number,
	PassX2: boolean,
	PassX5: boolean,
	Egg: { Tier: string, ReadyAt: number }?,
}

local data: { [Player]: PlayerData } = {}

local function syncLeaderstats(player: Player)
	local entry = data[player]
	if not entry then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Coin.Value = math.floor(entry.Coin)
		stats.Rebirths.Value = entry.Rebirths
	end
end

-- Mirror the progression numbers into attributes the HUD reads.
local function syncAttributes(player: Player)
	local entry = data[player]
	if not entry then
		return
	end
	player:SetAttribute("SpeedTier", entry.SpeedTier)
	player:SetAttribute("PenLevel", entry.PenLevel)
	player:SetAttribute("PenCapacity", GameConfig.PenCapacity(entry.PenLevel))
	player:SetAttribute("TreadmillLevel", entry.TreadmillLevel)
	player:SetAttribute("PassX2", entry.PassX2)
	player:SetAttribute("PassX5", entry.PassX5)
	if entry.Egg then
		player:SetAttribute("EggTier", entry.Egg.Tier)
		player:SetAttribute("EggReadyAt", entry.Egg.ReadyAt)
	else
		player:SetAttribute("EggTier", "")
		player:SetAttribute("EggReadyAt", 0)
	end
end

function Economy.SetupPlayer(player: Player)
	data[player] = {
		Coin = Economy.StartCoin,
		Rebirths = 0,
		TotalEarned = 0,
		SpeedTier = 0,
		PenLevel = 1,
		TreadmillLevel = 1,
		PassX2 = false,
		PassX5 = false,
		Egg = nil,
	}

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local coin = Instance.new("IntValue")
	coin.Name = "Coin"
	coin.Value = Economy.StartCoin
	coin.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = stats
	stats.Parent = player

	player:SetAttribute("IncomePerSec", 0)
	player:SetAttribute("Carrying", false)
	syncAttributes(player)
end

function Economy.CleanupPlayer(player: Player)
	data[player] = nil
end

function Economy.Get(player: Player)
	return data[player]
end

function Economy.AddCoin(player: Player, amount: number)
	local entry = data[player]
	if not entry then
		return
	end
	entry.Coin += amount
	if amount > 0 then
		entry.TotalEarned += amount
	end
	syncLeaderstats(player)
end

-- Spends only if the player can afford it; returns whether the sale happened.
function Economy.TrySpend(player: Player, amount: number): boolean
	local entry = data[player]
	if not entry or entry.Coin < amount then
		return false
	end
	entry.Coin -= amount
	syncLeaderstats(player)
	return true
end

-- Income multiplier: rebirths (+50% each) times the pen bonus
-- (+2% per pen level above the first).
function Economy.Multiplier(player: Player): number
	local entry = data[player]
	if not entry then
		return 1
	end
	local rebirthMult = 1 + Economy.RebirthIncomeBonus * entry.Rebirths
	local penMult = 1 + GameConfig.PenIncomeBonusPerLevel * (entry.PenLevel - 1)
	return rebirthMult * penMult
end

function Economy.RebirthCost(player: Player): number
	local entry = data[player]
	local rebirths = entry and entry.Rebirths or 0
	return Economy.RebirthBaseCost * (Economy.RebirthCostGrowth ^ rebirths)
end

-- Performs a rebirth if affordable: rebirths +1, Coin back to the start.
-- Clearing the player's brainrots is PlotManager's job; init.server calls
-- both. Returns success and the cost that applied.
function Economy.DoRebirth(player: Player): (boolean, number)
	local entry = data[player]
	if not entry then
		return false, 0
	end
	local cost = Economy.RebirthCost(player)
	if entry.Coin < cost then
		return false, cost
	end
	entry.Rebirths += 1
	entry.Coin = Economy.StartCoin
	syncLeaderstats(player)
	return true, cost
end

-- ============================================================
-- Progression setters (speed tier, pen, treadmill, passes, egg).
-- Each keeps the HUD attributes in step with the data.
-- ============================================================

function Economy.SetSpeedTier(player: Player, tier: number)
	local entry = data[player]
	if entry then
		entry.SpeedTier = tier
		syncAttributes(player)
	end
end

function Economy.SetPenLevel(player: Player, level: number)
	local entry = data[player]
	if entry then
		entry.PenLevel = level
		syncAttributes(player)
	end
end

function Economy.SetTreadmillLevel(player: Player, level: number)
	local entry = data[player]
	if entry then
		entry.TreadmillLevel = level
		syncAttributes(player)
	end
end

function Economy.SetPass(player: Player, which: string, owned: boolean)
	local entry = data[player]
	if entry then
		if which == "SpeedX2" then
			entry.PassX2 = owned
		elseif which == "SpeedX5" then
			entry.PassX5 = owned
		end
		syncAttributes(player)
	end
end

-- The egg in the player's incubator: { Tier = egg tier name,
-- ReadyAt = os.time() when it can be opened }, or nil.
function Economy.GetEgg(player: Player)
	local entry = data[player]
	return entry and entry.Egg or nil
end

function Economy.SetEgg(player: Player, egg)
	local entry = data[player]
	if entry then
		entry.Egg = egg
		syncAttributes(player)
	end
end

return Economy
