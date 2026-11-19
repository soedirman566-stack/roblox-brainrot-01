-- PlotManager: the six base plots — who owns which, which pads are taken,
-- and the record of every brainrot standing on a pad.
-- One job: placement bookkeeping. A "record" is one placed brainrot:
-- { Player = owner, Def = its definition, Model = its model, Pad = its pad,
--   Ring = its rarity ring, CarriedBy = thief or nil }. Steal and the
-- income tick read these records.
--
-- A base has 24 physical pads, but only the owner's pen level unlocks
-- them: pen level 1 opens 6, level 20 opens all 24 (GameConfig). Locked
-- pads are dimmed; unlocked pads light up, and the pen's floor and trim
-- get fancier at milestone levels 5/10/15/20.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local BrainrotDefs = require(script.Parent:WaitForChild("BrainrotDefs"))

local PlotManager = {}

local bases: { Folder } = {}
local baseOwner: { [Folder]: Player } = {}
local playerBase: { [Player]: Folder } = {}
local lockUntil: { [Folder]: number } = {}
local recordsByPlayer: { [Player]: { any } } = {}
local recordByPad: { [BasePart]: any } = {}
local recordByModel: { [Model]: any } = {}

local onPlaced: ((any) -> ())? = nil
local trimBaseColor: { [Folder]: Color3 } = {}

local PAD_NAMES: { string } = {}
for i = 1, 24 do
	table.insert(PAD_NAMES, "Pad" .. i)
end

local PAD_OPEN_COLOR = Color3.fromRGB(238, 232, 218)
local PAD_GOLD_COLOR = Color3.fromRGB(245, 225, 160)
local PAD_LOCKED_COLOR = Color3.fromRGB(90, 90, 100)
local TRIM_SILVER = Color3.fromRGB(190, 195, 205)
local TRIM_GOLD = Color3.fromRGB(255, 205, 55)

function PlotManager.Init(deps)
	onPlaced = deps and deps.OnPlaced or nil
	local basesFolder = Workspace:WaitForChild("Bases")
	local found = basesFolder:GetChildren()
	table.sort(found, function(a, b)
		return a.Name < b.Name
	end)
	for _, base in ipairs(found) do
		if base:IsA("Folder") then
			table.insert(bases, base)
			local trim = base:FindFirstChild("TrimN")
			if trim then
				trimBaseColor[base] = trim.Color
			end
			-- Stepping on the lock pad locks this base (owner only, checked
			-- against baseOwner at touch time).
			local lockPad = base:FindFirstChild("LockPad")
			if lockPad then
				lockPad.Touched:Connect(function(hit)
					local character = hit.Parent
					local player = character and Players:GetPlayerFromCharacter(character)
					if player and baseOwner[base] == player then
						PlotManager.LockBase(player)
					end
				end)
			end
		end
	end
end

function PlotManager.AssignBase(player: Player): Folder?
	for _, base in ipairs(bases) do
		if baseOwner[base] == nil then
			baseOwner[base] = player
			playerBase[player] = base
			base:SetAttribute("OwnerUserId", player.UserId)
			PlotManager.RefreshPen(player)
			return base
		end
	end
	return nil
end

function PlotManager.GetBase(player: Player): Folder?
	return playerBase[player]
end

function PlotManager.GetBases(): { Folder }
	return bases
end

function PlotManager.ReleaseBase(player: Player)
	PlotManager.ClearPlayer(player)
	local base = playerBase[player]
	if base then
		baseOwner[base] = nil
		base:SetAttribute("OwnerUserId", nil)
		PlotManager.ResetBaseLook(base)
	end
	playerBase[player] = nil
	lockUntil[base] = nil
end

function PlotManager.LockBase(player: Player)
	local base = playerBase[player]
	if base then
		lockUntil[base] = os.clock() + 60
	end
end

function PlotManager.IsLocked(player: Player): boolean
	local base = playerBase[player]
	if not base then
		return false
	end
	local until_ = lockUntil[base]
	return until_ ~= nil and os.clock() < until_
end

-- How many pads this player's pen level unlocks (Economy mirrors it
-- into an attribute; 6 is the level-1 default).
local function capacityOf(player: Player): number
	return player:GetAttribute("PenCapacity") or 6
end

-- Paints the pen for its owner's current level: locked pads dim,
-- unlocked pads bright (gold-tinted from level 15), floor material
-- and wall trim stepping up at levels 5, 10, 15 and 20.
function PlotManager.RefreshPen(player: Player)
	local base = playerBase[player]
	if not base then
		return
	end
	local level = player:GetAttribute("PenLevel") or 1
	local capacity = capacityOf(player)
	for i, name in ipairs(PAD_NAMES) do
		local pad = base:FindFirstChild(name)
		if pad then
			if i <= capacity then
				pad.Color = if level >= 15 then PAD_GOLD_COLOR else PAD_OPEN_COLOR
				pad.Transparency = 0
			else
				pad.Color = PAD_LOCKED_COLOR
				pad.Transparency = 0.35
			end
		end
	end
	local floor = base:FindFirstChild("Floor")
	if floor then
		floor.Material = if level >= 15
			then Enum.Material.Marble
			elseif level >= 10 then Enum.Material.Granite
			elseif level >= 5 then Enum.Material.WoodPlanks
			else Enum.Material.Plastic
	end
	for _, trimName in ipairs({ "TrimN", "TrimS", "TrimE", "TrimW" }) do
		local trim = base:FindFirstChild(trimName)
		if trim then
			if level >= 15 then
				trim.Color = TRIM_GOLD
			elseif level >= 10 then
				trim.Color = TRIM_SILVER
			elseif trimBaseColor[base] then
				trim.Color = trimBaseColor[base]
			end
			trim.Material = if level >= 20 then Enum.Material.Neon else Enum.Material.Plastic
		end
	end
end

-- Back to the un-owned look when a player leaves.
function PlotManager.ResetBaseLook(base: Folder)
	for _, name in ipairs(PAD_NAMES) do
		local pad = base:FindFirstChild(name)
		if pad then
			pad.Color = PAD_OPEN_COLOR
			pad.Transparency = 0
		end
	end
	local floor = base:FindFirstChild("Floor")
	if floor then
		floor.Material = Enum.Material.Plastic
	end
	for _, trimName in ipairs({ "TrimN", "TrimS", "TrimE", "TrimW" }) do
		local trim = base:FindFirstChild(trimName)
		if trim then
			trim.Material = Enum.Material.Plastic
			if trimBaseColor[base] then
				trim.Color = trimBaseColor[base]
			end
		end
	end
end

function PlotManager.FreePad(player: Player): BasePart?
	local base = playerBase[player]
	if not base then
		return nil
	end
	local capacity = capacityOf(player)
	for i, name in ipairs(PAD_NAMES) do
		if i > capacity then
			break
		end
		local pad = base:FindFirstChild(name)
		if pad and recordByPad[pad] == nil then
			return pad
		end
	end
	return nil
end

-- Stands a model on a pad, facing the lane, and records it as placed.
-- A glowing rarity ring is laid under the creature, sized to its body —
-- for a colossal Dewa Langit the ring (and the creature) deliberately
-- overhang the pad: the size is the prestige. Feet stay planted on the
-- pad top either way, and pads sit far enough from the walls and the
-- roofline trim that even the biggest body never clips them.
function PlotManager.PlaceOnPad(player: Player, def, model: Model, pad: BasePart)
	local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	-- North plots face south (+Z), south plots face north (-Z): both face
	-- the lane at Z = 0.
	local facing = if pad.Position.Z < 0 then top + Vector3.new(0, 0, 10) else top - Vector3.new(0, 0, 10)
	model:PivotTo(CFrame.lookAt(top, facing))
	model.Parent = Workspace

	local scale = def.Scale or 1
	local ring = Instance.new("Part")
	ring.Name = "RarityRing"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.25, 3.6 * scale, 3.6 * scale)
	ring.Color = BrainrotDefs.RarityColors[def.Rarity]
	ring.Material = Enum.Material.Neon
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	-- Cylinder axis is X: rotate so the disc lies flat on the pad.
	ring.CFrame = CFrame.new(top + Vector3.new(0, 0.14, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = Workspace

	local record = {
		Player = player,
		Def = def,
		Model = model,
		Pad = pad,
		Ring = ring,
		CarriedBy = nil,
	}
	recordsByPlayer[player] = recordsByPlayer[player] or {}
	table.insert(recordsByPlayer[player], record)
	recordByPad[pad] = record
	recordByModel[model] = record
	if onPlaced then
		onPlaced(record)
	end
	return record
end

-- Removes a record from the books; optionally destroys its model.
function PlotManager.DetachRecord(record, destroyModel: boolean)
	local owner = record.Player
	local list = recordsByPlayer[owner]
	if list then
		local index = table.find(list, record)
		if index then
			table.remove(list, index)
		end
	end
	if record.Pad and recordByPad[record.Pad] == record then
		recordByPad[record.Pad] = nil
	end
	recordByModel[record.Model] = nil
	if record.Ring then
		record.Ring:Destroy()
		record.Ring = nil
	end
	if destroyModel and record.Model then
		record.Model:Destroy()
	end
end

function PlotManager.ClearPlayer(player: Player)
	local list = recordsByPlayer[player]
	if not list then
		return
	end
	local copy = table.clone(list)
	for _, record in ipairs(copy) do
		PlotManager.DetachRecord(record, true)
	end
	recordsByPlayer[player] = {}
end

function PlotManager.GetRecords(player: Player): { any }
	return recordsByPlayer[player] or {}
end

function PlotManager.GetRecordByModel(model: Model)
	return recordByModel[model]
end

function PlotManager.TotalIncome(player: Player): number
	local total = 0
	for _, record in ipairs(PlotManager.GetRecords(player)) do
		total += record.Def.Income
	end
	return total
end

-- Is this world position inside the player's own plot (floor bounds)?
function PlotManager.IsOnOwnBase(player: Player, position: Vector3): boolean
	local base = playerBase[player]
	if not base then
		return false
	end
	local floor = base:FindFirstChild("Floor")
	if not floor then
		return false
	end
	return math.abs(position.X - floor.Position.X) <= floor.Size.X / 2
		and math.abs(position.Z - floor.Position.Z) <= floor.Size.Z / 2
end

-- Safety from the tsunami: standing on ANY plot's floor counts.
function PlotManager.IsOnAnyBase(position: Vector3): boolean
	for _, base in ipairs(bases) do
		local floor = base:FindFirstChild("Floor")
		if floor then
			if math.abs(position.X - floor.Position.X) <= floor.Size.X / 2
				and math.abs(position.Z - floor.Position.Z) <= floor.Size.Z / 2 then
				return true
			end
		end
	end
	return false
end

return PlotManager
