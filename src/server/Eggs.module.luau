-- Eggs: the hatchery. Six eggs are sold at the egg station by the shop
-- (Telur Umum up to Telur Ilahi), each mirroring a rarity tier. Buying
-- one puts it in the incubator nest at your own base; when its timer
-- runs out you open it and a random brainrot from that egg's tier band
-- hatches onto a free pad — or converts to Coin at half price if your
-- pen is full. Telur Ilahi is the only egg whose band reaches Dewa
-- Langit. One job: eggs — selling, incubating, hatching. The egg's
-- state (tier + ready timestamp) lives in Economy's player data, so a
-- mid-incubation egg is rebuilt at the nest whenever a base is assigned.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

local Eggs = {}

local economy = nil
local plots = nil
local notify: ((Player, string) -> ())? = nil

local rng = Random.new()
local nestVisual: { [Player]: Model } = {}
local nestPrompt: { [Player]: ProximityPrompt } = {}
local readyTold: { [Player]: boolean } = {}

local eggDefByTier: { [string]: any } = {}
for _, eggDef in ipairs(GameConfig.EggDefs) do
	eggDefByTier[eggDef.Tier] = eggDef
end

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

function Eggs.Init(deps)
	economy = deps.Economy
	plots = deps.Plots
	notify = deps.Notify

	local station = Workspace:WaitForChild("EggStation")
	for index, eggDef in ipairs(GameConfig.EggDefs) do
		local prop = station:FindFirstChild("Egg" .. index)
		if prop then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BuyEggPrompt"
			prompt.ActionText = "Buy · " .. BrainrotDefs.FormatCash(eggDef.Price) .. " Coin"
			prompt.ObjectText = eggDef.Name .. " · hatches in " .. eggDef.HatchSeconds .. "s"
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = prop
			prompt.Triggered:Connect(function(player)
				Eggs.BuyEgg(player, index)
			end)
		end
	end
end

function Eggs.BuyEgg(player: Player, index: number)
	local eggDef = GameConfig.EggDefs[index]
	if not eggDef then
		return
	end
	if economy.GetEgg(player) then
		tell(player, "Your incubator is busy — hatch that egg first!")
		return
	end
	if not plots.GetBase(player) then
		tell(player, "You need a base before you can incubate an egg!")
		return
	end
	if not economy.TrySpend(player, eggDef.Price) then
		tell(player, eggDef.Name .. " needs " .. BrainrotDefs.FormatCash(eggDef.Price) .. " Coin!")
		return
	end
	economy.SetEgg(player, { Tier = eggDef.Tier, ReadyAt = os.time() + eggDef.HatchSeconds })
	readyTold[player] = nil
	Eggs.RefreshNest(player)
	tell(player, "🥚 " .. eggDef.Name .. " is incubating at your base — ready in " .. eggDef.HatchSeconds .. "s!")
end

-- (Re)builds the egg visual in the player's base nest from their data.
function Eggs.RefreshNest(player: Player)
	Eggs.ClearNest(player)
	local egg = economy.GetEgg(player)
	local base = plots.GetBase(player)
	if not egg or not base then
		return
	end
	local nest = base:FindFirstChild("Nest")
	if not nest then
		return
	end
	local eggDef = eggDefByTier[egg.Tier]
	local model = Instance.new("Model")
	model.Name = "IncubatingEgg"
	local ball = Instance.new("Part")
	ball.Name = "EggBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3.8, 3)
	ball.Color = BrainrotDefs.RarityColors[egg.Tier] or Color3.new(1, 1, 1)
	if egg.Tier ~= "Common" and egg.Tier ~= "Rare" then
		ball.Material = Enum.Material.Neon
	end
	ball.Anchored = true
	ball.CanCollide = false
	ball.Position = nest.Position + Vector3.new(0, 2.2, 0)
	ball.Parent = model
	model.Parent = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HatchPrompt"
	prompt.ActionText = if os.time() >= egg.ReadyAt then "OPEN!" else "Hatching…"
	prompt.ObjectText = eggDef and eggDef.Name or "Egg"
	prompt.HoldDuration = 0.8
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = ball
	prompt.Triggered:Connect(function(triggering)
		if triggering == player then
			Eggs.TryHatch(player)
		end
	end)

	nestVisual[player] = model
	nestPrompt[player] = prompt
end

function Eggs.ClearNest(player: Player)
	if nestVisual[player] then
		nestVisual[player]:Destroy()
		nestVisual[player] = nil
	end
	nestPrompt[player] = nil
end

function Eggs.TryHatch(player: Player)
	local egg = economy.GetEgg(player)
	if not egg then
		return
	end
	if os.time() < egg.ReadyAt then
		tell(player, "Not ready yet — " .. (egg.ReadyAt - os.time()) .. "s to go!")
		return
	end
	local eggDef = eggDefByTier[egg.Tier]
	economy.SetEgg(player, nil)
	readyTold[player] = nil
	Eggs.ClearNest(player)
	if not eggDef then
		return
	end
	local def = BrainrotDefs.RollWeighted(rng, eggDef.Factors)
	local pad = plots.FreePad(player)
	if pad then
		local model = Factory.Build(def, CFrame.new(pad.Position + Vector3.new(0, 2, 0)))
		plots.PlaceOnPad(player, def, model, pad)
		tell(player, "🥚✨ Your " .. eggDef.Name .. " hatched into " .. def.Name .. " (" .. def.Rarity .. ")!")
	else
		local coin = math.floor(def.Price / 2)
		economy.AddCoin(player, coin)
		tell(player, "🥚✨ " .. def.Name .. " hatched, but your pen is full — converted to " .. BrainrotDefs.FormatCash(coin) .. " Coin!")
	end
end

-- Watches for eggs reaching their hatch time: one toast, and the nest
-- prompt flips to OPEN!.
function Eggs.Start()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				local egg = economy.GetEgg(player)
				if egg and os.time() >= egg.ReadyAt and not readyTold[player] then
					readyTold[player] = true
					local prompt = nestPrompt[player]
					if prompt then
						prompt.ActionText = "OPEN!"
					end
					local eggDef = eggDefByTier[egg.Tier]
					tell(player, "🥚 Your " .. (eggDef and eggDef.Name or "egg") .. " is ready to hatch!")
				end
			end
		end
	end)
end

return Eggs
