-- LuckyBlocks: the lucky block stand by the shop. Two question-mark
-- blocks are on display — a plain Lucky Block and a Golden Lucky
-- Block — and buying one sets YOUR block down on an opening pad at
-- the stand. Hit OPEN and it shakes, swells and bursts into a random
-- brainrot rolled from that block's table: Common-Legendary for the
-- plain block, Rare-Mythic for the golden. Dewa Langit is in neither
-- table (conveyor and Telur Ilahi only). Pen full? The creature
-- converts to Coin at half price, like every other grant system.
-- One job: lucky blocks — selling, the suspense, the grant. Fully
-- server-authoritative; the client only ever sees the toasts.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("GameConfig"))
local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))
local Factory = require(script.Parent:WaitForChild("BrainrotFactory"))

local LuckyBlocks = {}

local economy = nil
local plots = nil
local notify: ((Player, string) -> ())? = nil

local rng = Random.new()
local openingPads: { BasePart } = {}
local padTakenBy: { [BasePart]: Player } = {}
-- A player's bought-but-unopened block: its model, its table row, the
-- pad it stands on and whether the suspense is already running.
local pending: { [Player]: { Model: Model, Def: any, Pad: BasePart, Opening: boolean } } = {}

local function tell(player: Player, text: string)
	if notify then
		notify(player, text)
	end
end

function LuckyBlocks.Init(deps)
	economy = deps.Economy
	plots = deps.Plots
	notify = deps.Notify

	local stand = Workspace:WaitForChild("LuckyBlockStand")
	for i = 1, 3 do
		local pad = stand:FindFirstChild("OpeningPad" .. i)
		if pad then
			table.insert(openingPads, pad)
		end
	end

	-- The two display blocks on their pedestals carry the buy prompts,
	-- exactly like the hatchery's eggs carry theirs.
	for index, blockDef in ipairs(GameConfig.LuckyBlockDefs) do
		local pedestal = stand:FindFirstChild("Pedestal" .. index)
		if pedestal then
			local display = Factory.BuildLuckyBlock(
				blockDef.Golden,
				CFrame.new(pedestal.Position + Vector3.new(0, pedestal.Size.Y / 2, 0))
			)
			display.Name = "DisplayBlock" .. index
			display.Parent = stand
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "BuyLuckyBlockPrompt"
			prompt.ActionText = "Buy · " .. BrainrotDefs.FormatCash(blockDef.Price) .. " Coin"
			prompt.ObjectText = blockDef.Name .. if blockDef.Golden then " · Rare–Mythic!" else " · Common–Legendary"
			prompt.HoldDuration = 0.5
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Parent = display:FindFirstChild("Body")
			prompt.Triggered:Connect(function(player)
				LuckyBlocks.BuyBlock(player, index)
			end)
		end
	end
end

local function freePad(): BasePart?
	for _, pad in ipairs(openingPads) do
		if not padTakenBy[pad] then
			return pad
		end
	end
	return nil
end

function LuckyBlocks.BuyBlock(player: Player, index: number)
	local blockDef = GameConfig.LuckyBlockDefs[index]
	if not blockDef then
		return
	end
	if pending[player] then
		tell(player, "🍀 Open the lucky block you already bought first!")
		return
	end
	local pad = freePad()
	if not pad then
		tell(player, "🍀 The lucky stand is packed — one moment!")
		return
	end
	if not economy.TrySpend(player, blockDef.Price) then
		tell(player, blockDef.Name .. " needs " .. BrainrotDefs.FormatCash(blockDef.Price) .. " Coin!")
		return
	end

	padTakenBy[pad] = player
	local model = Factory.BuildLuckyBlock(
		blockDef.Golden,
		CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2, 0))
	)
	model.Parent = Workspace:FindFirstChild("LuckyBlockStand")

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenLuckyBlockPrompt"
	prompt.ActionText = "OPEN!"
	prompt.ObjectText = blockDef.Name
	prompt.HoldDuration = 0.4
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = model:FindFirstChild("Body")
	prompt.Triggered:Connect(function(triggering)
		if triggering == player then
			LuckyBlocks.OpenBlock(player)
		end
	end)

	pending[player] = { Model = model, Def = blockDef, Pad = pad, Opening = false }
	tell(player, "🍀 Your " .. blockDef.Name .. " is on the stand — hit OPEN!")
end

-- The suspense beat, then the burst: the block shakes harder and
-- swells for a couple of seconds before it pops into the prize.
local function suspense(player: Player, entry)
	local model = entry.Model
	local baseCFrame = model:GetPivot()
	local duration = 2.4
	local steps = 16
	for step = 1, steps do
		if not model.Parent then
			return
		end
		local frac = step / steps
		local jitter = 0.06 + 0.3 * frac
		local offset = Vector3.new(
			rng:NextNumber(-jitter, jitter),
			0.05 * frac,
			rng:NextNumber(-jitter, jitter)
		)
		local tilt = math.rad(rng:NextNumber(-7, 7) * frac)
		model:PivotTo(baseCFrame * CFrame.new(offset) * CFrame.Angles(0, 0, tilt))
		model:ScaleTo(1 + 0.55 * frac)
		task.wait(duration / steps)
	end
end

function LuckyBlocks.OpenBlock(player: Player)
	local entry = pending[player]
	if not entry or entry.Opening then
		return
	end
	entry.Opening = true
	local prompt = entry.Model:FindFirstChild("OpenLuckyBlockPrompt", true)
	if prompt then
		prompt.Enabled = false
	end
	tell(player, "🍀 It's shaking… something's coming!")

	task.spawn(function()
		suspense(player, entry)
		-- However the beat ended, the block is spent now.
		if pending[player] == entry then
			pending[player] = nil
		end
		if padTakenBy[entry.Pad] == player then
			padTakenBy[entry.Pad] = nil
		end
		entry.Model:Destroy()

		local def = BrainrotDefs.RollWeighted(rng, entry.Def.Factors)
		local pad = plots.FreePad(player)
		if pad then
			local model = Factory.Build(def, CFrame.new(pad.Position + Vector3.new(0, 2, 0)))
			plots.PlaceOnPad(player, def, model, pad)
			tell(player, "🍀✨ " .. entry.Def.Name .. " burst into " .. def.Name .. " (" .. def.Rarity .. ")!")
		else
			local coin = math.floor(def.Price / 2)
			economy.AddCoin(player, coin)
			tell(player, "🍀✨ " .. def.Name .. " burst out, but your pen is full — converted to " .. BrainrotDefs.FormatCash(coin) .. " Coin!")
		end
	end)
end

-- Player leaving (or a reset): their unopened block leaves with them.
function LuckyBlocks.ClearBlock(player: Player)
	local entry = pending[player]
	if not entry then
		return
	end
	pending[player] = nil
	if padTakenBy[entry.Pad] == player then
		padTakenBy[entry.Pad] = nil
	end
	entry.Model:Destroy()
end

return LuckyBlocks
