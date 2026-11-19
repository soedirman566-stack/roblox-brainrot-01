-- Economy: each player's money state — cash, rebirths, lifetime earnings.
-- One job: hold the numbers and the rules that change them (spending,
-- earning, the rebirth ladder). It knows nothing about models or pads;
-- PlotManager counts a player's brainrots and init.server does the tick.

local Economy = {}

Economy.StartCash = 100
Economy.RebirthBaseCost = 25000
Economy.RebirthCostGrowth = 4
Economy.RebirthIncomeBonus = 0.5 -- each rebirth adds +50% income

local data: { [Player]: { Cash: number, Rebirths: number, TotalEarned: number } } = {}

local function syncLeaderstats(player: Player)
	local entry = data[player]
	if not entry then
		return
	end
	local stats = player:FindFirstChild("leaderstats")
	if stats then
		stats.Cash.Value = math.floor(entry.Cash)
		stats.Rebirths.Value = entry.Rebirths
	end
end

function Economy.SetupPlayer(player: Player)
	data[player] = { Cash = Economy.StartCash, Rebirths = 0, TotalEarned = 0 }

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local cash = Instance.new("IntValue")
	cash.Name = "Cash"
	cash.Value = Economy.StartCash
	cash.Parent = stats
	local rebirths = Instance.new("IntValue")
	rebirths.Name = "Rebirths"
	rebirths.Value = 0
	rebirths.Parent = stats
	stats.Parent = player

	player:SetAttribute("IncomePerSec", 0)
	player:SetAttribute("Carrying", false)
end

function Economy.CleanupPlayer(player: Player)
	data[player] = nil
end

function Economy.Get(player: Player)
	return data[player]
end

function Economy.AddCash(player: Player, amount: number)
	local entry = data[player]
	if not entry then
		return
	end
	entry.Cash += amount
	if amount > 0 then
		entry.TotalEarned += amount
	end
	syncLeaderstats(player)
end

-- Spends only if the player can afford it; returns whether the sale happened.
function Economy.TrySpend(player: Player, amount: number): boolean
	local entry = data[player]
	if not entry or entry.Cash < amount then
		return false
	end
	entry.Cash -= amount
	syncLeaderstats(player)
	return true
end

-- Income multiplier from rebirths: 1x, 1.5x, 2x, ...
function Economy.Multiplier(player: Player): number
	local entry = data[player]
	if not entry then
		return 1
	end
	return 1 + Economy.RebirthIncomeBonus * entry.Rebirths
end

function Economy.RebirthCost(player: Player): number
	local entry = data[player]
	local rebirths = entry and entry.Rebirths or 0
	return Economy.RebirthBaseCost * (Economy.RebirthCostGrowth ^ rebirths)
end

-- Performs a rebirth if affordable: rebirths +1, cash back to the start.
-- Clearing the player's brainrots is PlotManager's job; init.server calls
-- both. Returns success and the cost that applied.
function Economy.DoRebirth(player: Player): (boolean, number)
	local entry = data[player]
	if not entry then
		return false, 0
	end
	local cost = Economy.RebirthCost(player)
	if entry.Cash < cost then
		return false, cost
	end
	entry.Rebirths += 1
	entry.Cash = Economy.StartCash
	syncLeaderstats(player)
	return true, cost
end

return Economy
