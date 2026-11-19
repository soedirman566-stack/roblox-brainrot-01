-- PlotManager: the six base plots — who owns which, which pads are taken,
-- and the record of every brainrot standing on a pad.
-- One job: placement bookkeeping. A "record" is one placed brainrot:
-- { Player = owner, Def = its definition, Model = its model, Pad = its pad,
--   CarriedBy = thief or nil }. Steal and the income tick read these records.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local PlotManager = {}

local bases: { Folder } = {}
local baseOwner: { [Folder]: Player } = {}
local playerBase: { [Player]: Folder } = {}
local lockUntil: { [Folder]: number } = {}
local recordsByPlayer: { [Player]: { any } } = {}
local recordByPad: { [BasePart]: any } = {}
local recordByModel: { [Model]: any } = {}

local onPlaced: ((any) -> ())? = nil

local PAD_NAMES = { "Pad1", "Pad2", "Pad3", "Pad4", "Pad5", "Pad6" }

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
			return base
		end
	end
	return nil
end

function PlotManager.GetBase(player: Player): Folder?
	return playerBase[player]
end

function PlotManager.ReleaseBase(player: Player)
	PlotManager.ClearPlayer(player)
	local base = playerBase[player]
	if base then
		baseOwner[base] = nil
		base:SetAttribute("OwnerUserId", nil)
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

function PlotManager.FreePad(player: Player): BasePart?
	local base = playerBase[player]
	if not base then
		return nil
	end
	for _, name in ipairs(PAD_NAMES) do
		local pad = base:FindFirstChild(name)
		if pad and recordByPad[pad] == nil then
			return pad
		end
	end
	return nil
end

-- Stands a model on a pad, facing the lane, and records it as placed.
function PlotManager.PlaceOnPad(player: Player, def, model: Model, pad: BasePart)
	local top = pad.Position + Vector3.new(0, pad.Size.Y / 2, 0)
	-- North plots face south (+Z), south plots face north (-Z): both face
	-- the lane at Z = 0.
	local facing = if pad.Position.Z < 0 then top + Vector3.new(0, 0, 10) else top - Vector3.new(0, 0, 10)
	model:PivotTo(CFrame.lookAt(top, facing))
	model.Parent = Workspace

	local record = {
		Player = player,
		Def = def,
		Model = model,
		Pad = pad,
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
