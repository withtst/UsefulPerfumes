UsefulPerfumes = UsefulPerfumes or {}

UsefulPerfumes.ModId = "UsefulPerfumes"
UsefulPerfumes.AromaHours = 4
UsefulPerfumes.FluidPerUse = 0.001
UsefulPerfumes.Epsilon = 0.000001
UsefulPerfumes.FluidTolerance = 0.0001
UsefulPerfumes.MergeMaxBottles = 32

UsefulPerfumes.Profiles = {
    Perfume = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.75,
        moodRiseReduction = 0.40,
    },
    Cologne = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.75,
        moodRiseReduction = 0.40,
        enduranceReduction = 0.15,
    },
    UP_FirstLoveBlueberry = {
        unhappiness = 80, stress = 0.80, smellFactor = 0.75,
        moodRiseReduction = 1.0,
        sleepComfortRate = 0.05,
    },
    UP_CheapKnockoff = {
        unhappiness = 10, stress = 0.10, smellFactor = 0.75,
        moodRiseReduction = 0.40,
    },
    UP_ElegantMiss = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.75,
        moodRiseReduction = 1.0,
        sleepComfortRate = 0.02,
        detectionReduction = 0.15,
    },
    UP_HerbalBlend = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.75,
        moodRiseReduction = 0.40,
        fatigueReduction = 0.15,
    },
    UP_ColdCotton = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.40,
        moodRiseReduction = 0.40,
    },
    UP_SlumberFloral = {
        unhappiness = 40, stress = 0.40, smellFactor = 0.75,
        moodRiseReduction = 1.0,
        sleepComfortRate = 0.02,
        sleepAnywhere = true,
        sleepTimeScale = 0.7,
    },
}

-- IsoPlayer.updateStats_Sleeping(): fatigue loses (0.7/5) per hour above 0.3, (0.3/7) below,
-- scaled by the bed quality and the Insomniac/NightOwl traits.
UsefulPerfumes.SleepFatigueBreakpoint = 0.3
UsefulPerfumes.SleepFatigueFastRate = 0.7 / 5
UsefulPerfumes.SleepFatigueSlowRate = 0.3 / 7
UsefulPerfumes.SleepBedMods = {
    averageBedPillow = 1.05, goodBed = 1.1, goodBedPillow = 1.15,
    badBed = 0.9, badBedPillow = 0.95, floor = 0.6, floorPillow = 0.75,
}
UsefulPerfumes.SleepInsomniacMod = 0.5
UsefulPerfumes.SleepNightOwlMod = 1.4
-- OnSleepingTick fires every frame; bank time so float clock noise cannot stall the drain.
UsefulPerfumes.SleepSettleHours = 0.05



UsefulPerfumes.PerfumeFluidByType = {
    UP_FirstLoveBlueberry = "UP_FirstLoveBlueberryPerfume",
    UP_CheapKnockoff = "UP_CheapKnockoffPerfume",
    UP_ElegantMiss = "UP_ElegantMissPerfume",
    UP_HerbalBlend = "UP_HerbalBlendPerfume",
    UP_ColdCotton = "UP_ColdCottonPerfume",
    UP_SlumberFloral = "UP_SlumberFloralPerfume",
}

-- The fluid each bottle is allowed to contain. The six new items declare this in their
-- container whitelist; the two vanilla bottles have no script of their own, so their intake
-- is locked at runtime instead.
UsefulPerfumes.RequiredFluidByType = {
    Perfume = "Perfume",
    Cologne = "Cologne",
}
for itemType, fluidName in pairs(UsefulPerfumes.PerfumeFluidByType) do
    UsefulPerfumes.RequiredFluidByType[itemType] = fluidName
end

UsefulPerfumes.clientState = UsefulPerfumes.clientState or {}
UsefulPerfumes.lastStats = setmetatable({}, { __mode = "k" })
UsefulPerfumes.zombieBlindUntil = setmetatable({}, { __mode = "k" })
UsefulPerfumes.zombieSeen = setmetatable({}, { __mode = "k" })
UsefulPerfumes.lastDetectScan = setmetatable({}, { __mode = "k" })
UsefulPerfumes.SleepForce = UsefulPerfumes.SleepForce or {}

function UsefulPerfumes.getProfile(itemType)
    if not itemType then return nil end
    return UsefulPerfumes.Profiles[itemType]
end

function UsefulPerfumes.getTooltipKey(itemType)
    if not itemType then return nil end
    if itemType:sub(1, 3) == "UP_" then
        return "Tooltip_" .. itemType
    end
    return "Tooltip_UP_" .. itemType
end

function UsefulPerfumes.migratePerfumeFluid(item)
    if not item then return false end
    local targetName = UsefulPerfumes.PerfumeFluidByType[item:getType()]
    if not targetName then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    -- Only old bottles keep the vanilla container name; unique-container items are already named.
    if fc:getContainerName() ~= "BottlePerfume" then return false end
    local amount = fc:getAmount()
    if amount <= UsefulPerfumes.Epsilon then return false end
    local primary = fc:getPrimaryFluid()
    if not primary then return false end
    local fluidType = primary:getFluidTypeString()
    if fluidType ~= "Perfume" and fluidType ~= "Base.Perfume" then return false end
    if math.abs(amount - fc:getPrimaryFluidAmount()) > UsefulPerfumes.Epsilon then return false end
    local targetFluid = Fluid.Get(targetName)
    if not targetFluid then return false end
    fc:removeFluid(amount)
    fc:addFluid(targetFluid, amount)
    if math.abs(fc:getAmount() - amount) <= 0.0005 then return true end
    -- Restore the original fluid if the target fluid was rejected by the container.
    fc:removeFluid(fc:getAmount())
    fc:addFluid(primary, amount)
    return false
end

UsefulPerfumes.VanillaBottles = {
    Perfume = true,
    Cologne = true,
}

--- Vanilla perfume/cologne bottles cannot carry a script whitelist, so give their instances the
--- same single-fluid filter the scripted bottles get. `inputLocked` would also stop a player from
--- pouring an identical perfume into a half-used bottle, which is a legitimate move.
function UsefulPerfumes.applyFluidWhitelist(item)
    if not item then return false end
    local itemType = item:getType()
    if not UsefulPerfumes.VanillaBottles[itemType] then return false end
    local fluidName = UsefulPerfumes.RequiredFluidByType[itemType]
    if not fluidName then return false end
    local ok = pcall(function()
        local fc = item:getFluidContainer()
        if not fc then return end
        local wl = fc:getWhitelist()
        if wl and wl:contains(fluidName) then return end
        local filter = FluidFilter.new()
        filter:add(fluidName)
        fc:setWhitelist(filter)
    end)
    return ok
end

function UsefulPerfumes.applyIntakeLock(item)
    if not item then return false end
    local itemType = item:getType()
    if itemType ~= "Perfume" and itemType ~= "Cologne" then return false end
    local ok = pcall(function()
        local fc = item:getFluidContainer()
        if fc and not fc:isInputLocked() then
            fc:setInputLocked(true)
        end
    end)
    return ok
end

function UsefulPerfumes.guardItem(item)
    if not item then return false end
    if UsefulPerfumes.applyFluidWhitelist(item) then return true end
    return UsefulPerfumes.applyIntakeLock(item)
end

function UsefulPerfumes.guardInventoryRows(pane)
    if not pane or not pane.itemslist then return false end
    local changed = false
    for _, row in ipairs(pane.itemslist) do
        if type(row) == "table" and row.items then
            for _, item in ipairs(row.items) do
                if instanceof(item, "InventoryItem") then
                    UsefulPerfumes.guardItem(item)
                    if not UsefulPerfumes.isRemoteClient() and UsefulPerfumes.migratePerfumeFluid(item) then
                        changed = true
                    end
                end
            end
        end
    end
    return changed
end

function UsefulPerfumes.applyItemTooltip(item)
    if not item then return false end
    local itemType = item:getType()
    if not UsefulPerfumes.Profiles[itemType] then return false end
    local existing = nil
    pcall(function() existing = item:getTooltip() end)
    if existing ~= nil and existing ~= "" then return false end
    local key = UsefulPerfumes.getTooltipKey(itemType)
    local ok = pcall(function() item:setTooltip(key) end)
    return ok, key
end

function UsefulPerfumes.getProfileForItem(item)
    if not item then return nil end
    return UsefulPerfumes.Profiles[item:getType()]
end

function UsefulPerfumes.now()
    return getGameTime():getWorldAgeHours()
end

function UsefulPerfumes.isRemoteClient()
    return isClient() and not isServer()
end

function UsefulPerfumes.getPlayerNum(player)
    local ok, num = pcall(function() return player:getPlayerNum() end)
    if ok then return num end
    return nil
end

function UsefulPerfumes.readState(player)
    if UsefulPerfumes.isRemoteClient() then
        local num = UsefulPerfumes.getPlayerNum(player)
        local cached = num and UsefulPerfumes.clientState[num]
        if cached and cached.type then
            return cached.type, cached.expiry
        end
    end
    local md = player:getModData()
    return md.UP_AromaType, md.UP_AromaExpiry
end

function UsefulPerfumes.getState(player)
    if not player then return nil end
    local itemType, expiry = UsefulPerfumes.readState(player)
    if not itemType or not expiry then return nil end
    if not UsefulPerfumes.Profiles[itemType] then return nil end
    if expiry <= UsefulPerfumes.now() then
        if UsefulPerfumes.isRemoteClient() then
            local num = UsefulPerfumes.getPlayerNum(player)
            if num then UsefulPerfumes.clientState[num] = nil end
        else
            UsefulPerfumes.clearAroma(player)
        end
        return nil
    end
    return itemType, expiry
end

function UsefulPerfumes.isAromaActive(player)
    return UsefulPerfumes.getState(player) ~= nil
end

function UsefulPerfumes.getActiveProfile(player)
    local itemType = UsefulPerfumes.getState(player)
    if not itemType then return nil end
    return UsefulPerfumes.Profiles[itemType]
end

function UsefulPerfumes.hasSleepBuff(player)
    local profile = UsefulPerfumes.getActiveProfile(player)
    return profile ~= nil and profile.sleepAnywhere == true
end

function UsefulPerfumes.getRemainingParts(hours)
    if not hours or hours <= 0 then return 0, 0, true end
    local totalMinutes = math.floor(hours * 60 + 0.0001)
    if totalMinutes <= 0 then return 0, 0, true end
    return math.floor(totalMinutes / 60), totalMinutes % 60, false
end

function UsefulPerfumes.formatRemainingHours(hours)
    local h, m, less = UsefulPerfumes.getRemainingParts(hours)
    if less then return getText("UI_UP_Time_LessMin") end
    if h > 0 then return getText("UI_UP_Time_HM", h, m) end
    return getText("UI_UP_Time_M", m)
end

function UsefulPerfumes.setAroma(player, itemType, expiry)
    local md = player:getModData()
    md.UP_AromaType = itemType
    md.UP_AromaExpiry = expiry
    if UsefulPerfumes.isRemoteClient() then
        local num = UsefulPerfumes.getPlayerNum(player)
        if num then
            UsefulPerfumes.clientState[num] = { type = itemType, expiry = expiry }
        end
    end
    local stats = player:getStats()
    if stats then
        UsefulPerfumes.lastStats[player] = {
            unhappiness = stats:get(CharacterStat.UNHAPPINESS),
            stress = stats:get(CharacterStat.STRESS),
            endurance = stats:get(CharacterStat.ENDURANCE),
            fatigue = stats:get(CharacterStat.FATIGUE),
        }
    else
        UsefulPerfumes.lastStats[player] = nil
    end
end

function UsefulPerfumes.clearAroma(player)
    local md = player:getModData()
    md.UP_AromaType = nil
    md.UP_AromaExpiry = nil
    if UsefulPerfumes.isRemoteClient() then
        local num = UsefulPerfumes.getPlayerNum(player)
        if num then UsefulPerfumes.clientState[num] = nil end
    end
    UsefulPerfumes.lastStats[player] = nil
end

function UsefulPerfumes.setClientState(player, itemType, expiry)
    local num = UsefulPerfumes.getPlayerNum(player)
    if not num then return end
    if itemType and expiry and expiry > UsefulPerfumes.now() then
        UsefulPerfumes.clientState[num] = { type = itemType, expiry = expiry }
        local md = player:getModData()
        md.UP_AromaType = itemType
        md.UP_AromaExpiry = expiry
    else
        UsefulPerfumes.clientState[num] = nil
        local md = player:getModData()
        md.UP_AromaType = nil
        md.UP_AromaExpiry = nil
    end
end

function UsefulPerfumes.findItemById(container, itemId)
    if not container or not itemId then return nil end
    local okItems, items = pcall(function() return container:getItems() end)
    if not okItems or not items then return nil end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and instanceof(item, "InventoryItem") and item:getID() == itemId then
            return item
        end
    end
    for i = 0, items:size() - 1 do
        local item = items:get(i)
        if item and item:IsInventoryContainer() then
            local ok, childContainer = pcall(function() return item:getInventory() end)
            if ok and childContainer then
                local found = UsefulPerfumes.findItemById(childContainer, itemId)
                if found then return found end
            end
        end
    end
    return nil
end

function UsefulPerfumes.findPlayerItem(player, itemId)
    if not player or not itemId then return nil end
    return UsefulPerfumes.findItemById(player:getInventory(), itemId)
end

function UsefulPerfumes.getOwnFluid(item)
    if not item then return nil end
    local name = UsefulPerfumes.RequiredFluidByType[item:getType()]
    if not name then return nil end
    local ok, fluid = pcall(function() return Fluid.Get(name) end)
    if not ok then return nil end
    return fluid
end

--- Only the bottle's own perfume fluid counts. A bottle that was diluted before the blend rule
--- existed still holds liquid, but none of it is perfume.
function UsefulPerfumes.getOwnFluidAmount(item)
    if not item then return 0 end
    local fc = item:getFluidContainer()
    if not fc then return 0 end
    local fluid = UsefulPerfumes.getOwnFluid(item)
    if not fluid then return fc:getAmount() end
    local ok, amount = pcall(function() return fc:getSpecificFluidAmount(fluid) end)
    if ok and amount and amount >= 0 then return amount end
    return fc:getAmount()
end

function UsefulPerfumes.getUseAmount(item)
    return UsefulPerfumes.FluidPerUse
end

function UsefulPerfumes.hasFluidForOneUse(item)
    if not item then return false end
    if not item:getFluidContainer() then return false end
    return UsefulPerfumes.getOwnFluidAmount(item) >= UsefulPerfumes.getUseAmount(item) - UsefulPerfumes.FluidTolerance
end

--- Remove the dose from the perfume itself, so a mixed bottle loses perfume rather than water.
--- `adjustSpecificFluidAmount` takes an absolute amount, not a delta.
local function drainOwnFluid(fc, fluid, amount)
    local mixed = false
    if fluid then pcall(function() mixed = fc:isMixture() end) end
    if mixed then
        local ok = pcall(function()
            fc:adjustSpecificFluidAmount(fluid, math.max(0, fc:getSpecificFluidAmount(fluid) - amount))
        end)
        if ok then return end
    end
    fc:removeFluid(amount)
end

function UsefulPerfumes.consumeUse(item)
    if not item then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    local amount = UsefulPerfumes.getUseAmount(item)
    if UsefulPerfumes.getOwnFluidAmount(item) < amount - UsefulPerfumes.FluidTolerance then return false end
    drainOwnFluid(fc, UsefulPerfumes.getOwnFluid(item), amount)
    item:syncItemFields()
    return true
end

function UsefulPerfumes.getUseBlockReason(player, item)
    if not player or not item then return "invalid" end
    if not UsefulPerfumes.getProfileForItem(item) then return "invalid" end
    if player:isDead() or player:isAsleep() then return "busy" end
    if not UsefulPerfumes.hasFluidForOneUse(item) then return "empty" end
    return nil
end

function UsefulPerfumes.calcSleepTraitMod(insomniac, nightOwl, needsLessSleep, needsMoreSleep)
    local mod = 1.0
    if insomniac then mod = mod * UsefulPerfumes.SleepInsomniacMod end
    if nightOwl then mod = mod * UsefulPerfumes.SleepNightOwlMod end
    -- IsoPlayer.updateStats_Sleeping divides the recovery period by this
    -- need-sleep factor. NeedsLessSleep takes precedence if both are present.
    if needsLessSleep then
        mod = mod / 0.75
    elseif needsMoreSleep then
        mod = mod / 1.18
    end
    return mod
end

function UsefulPerfumes.getSleepTraitMod(player)
    if not player then return 1.0 end
    local ok, mod = pcall(function()
        return UsefulPerfumes.calcSleepTraitMod(
            player:hasTrait(CharacterTrait.INSOMNIAC),
            player:hasTrait(CharacterTrait.NIGHT_OWL),
            player:hasTrait(CharacterTrait.NEEDS_LESS_SLEEP),
            player:hasTrait(CharacterTrait.NEEDS_MORE_SLEEP))
    end)
    if ok and mod then return mod end
    return 1.0
end

function UsefulPerfumes.getSleepBedMod(bedType)
    if not bedType then return 1.0 end
    return UsefulPerfumes.SleepBedMods[bedType] or 1.0
end

function UsefulPerfumes.getSleepPlayerBedMod(player)
    local ok, mod = pcall(function()
        return UsefulPerfumes.getSleepBedMod(player:getBedType())
    end)
    if ok and mod then return mod end
    return 1.0
end

function UsefulPerfumes.getSleepFatigueRate(fatigue)
    if fatigue and fatigue > UsefulPerfumes.SleepFatigueBreakpoint then
        return UsefulPerfumes.SleepFatigueFastRate
    end
    return UsefulPerfumes.SleepFatigueSlowRate
end

function UsefulPerfumes.calcSleepFatigueBase(fatigue, hours, bedMod, traitMod)
    if not fatigue or fatigue <= 0 then return 0 end
    if not hours or hours <= 0 then return 0 end
    return UsefulPerfumes.getSleepFatigueRate(fatigue) * (bedMod or 1.0) * (traitMod or 1.0) * hours
end

-- timeScale 0.7 means the night must end in 70% of the normal duration, so the bonus drain
-- is the remainder of the vanilla amount: base * (1/0.7 - 1).
function UsefulPerfumes.calcSleepFatigueExtra(fatigue, hours, bedMod, traitMod, timeScale)
    if not timeScale or timeScale <= 0 or timeScale >= 1 then return 0 end
    local base = UsefulPerfumes.calcSleepFatigueBase(fatigue, hours, bedMod, traitMod)
    if base <= 0 then return 0 end
    return base * (1 / timeScale - 1)
end

function UsefulPerfumes.applySleepComfortStats(player, itemType, hours)
    local profile = itemType and UsefulPerfumes.Profiles[itemType]
    local rate = profile and profile.sleepComfortRate
    if not rate or not hours or hours <= 0 then return false end
    local stats = player and player:getStats()
    if not stats then return false end
    for _, stat in ipairs({ CharacterStat.UNHAPPINESS, CharacterStat.PANIC, CharacterStat.STRESS }) do
        local maximum = stat == CharacterStat.STRESS and 1 or 100
        pcall(function()
            local value = stat:getMaximumValue()
            if value and value > 0 then maximum = value end
        end)
        stats:remove(stat, maximum * rate * hours)
    end
    return true
end

function UsefulPerfumes.applyMoodEffects(player, profile)
    if not profile then return end
    local stats = player:getStats()
    if profile.unhappiness and profile.unhappiness > 0 then
        stats:remove(CharacterStat.UNHAPPINESS, profile.unhappiness)
    end
    if profile.stress and profile.stress > 0 then
        stats:remove(CharacterStat.STRESS, profile.stress)
    end
end

function UsefulPerfumes.applyPerfumeUse(player, item)
    if not player or not item then return false, "invalid" end
    local itemType = item:getType()
    local profile = UsefulPerfumes.Profiles[itemType]
    if not profile then return false, "invalid" end
    if player:isDead() or player:isAsleep() then return false, "busy" end
    local current = UsefulPerfumes.getState(player)
    if not UsefulPerfumes.consumeUse(item) then return false, "empty" end
    local mode
    if not current then
        mode = "new"
    elseif current == itemType then
        mode = "refresh"
    else
        mode = "switch"
    end
    if mode ~= "refresh" then
        UsefulPerfumes.applyMoodEffects(player, profile)
    end
    local expiry = UsefulPerfumes.now() + UsefulPerfumes.AromaHours
    UsefulPerfumes.setAroma(player, itemType, expiry)
    return true, itemType, expiry, mode
end

function UsefulPerfumes.sprayPerfume(player, item)
    if not player or not item then return false, "invalid" end
    if UsefulPerfumes.isRemoteClient() then
        sendClientCommand(player, UsefulPerfumes.ModId, "spray", { itemId = item:getID() })
        return nil, "sent"
    end
    return UsefulPerfumes.applyPerfumeUse(player, item)
end

--- A diluted legacy bottle would pour water into a clean one, so only pure bottles take part.
--- Empty bottles are left out: they have nothing to give and filling one never reduces the count.
--- Purity is read from the instance list, not by comparing amounts: getAmount() snaps up to capacity
--- within 1 ml of full while getSpecificFluidAmount() does not, so a 99.2 ml bottle looks diluted.
function UsefulPerfumes.isMergeCandidate(item)
    if not item then return false end
    if not UsefulPerfumes.Profiles[item:getType()] then return false end
    local fc = item:getFluidContainer()
    if not fc then return false end
    if UsefulPerfumes.getOwnFluidAmount(item) <= UsefulPerfumes.FluidTolerance then return false end
    local mixed = false
    pcall(function() mixed = fc:isMixture() end)
    return not mixed
end

local function collectMergeInto(container, itemType, out)
    if not container or #out >= UsefulPerfumes.MergeMaxBottles then return end
    local okItems, items = pcall(function() return container:getItems() end)
    if not okItems or not items then return end
    for i = 0, items:size() - 1 do
        if #out >= UsefulPerfumes.MergeMaxBottles then return end
        local item = items:get(i)
        if item and instanceof(item, "InventoryItem") then
            if item:getType() == itemType and UsefulPerfumes.isMergeCandidate(item) then
                out[#out + 1] = item
            end
            if item:IsInventoryContainer() then
                local ok, child = pcall(function() return item:getInventory() end)
                if ok and child then collectMergeInto(child, itemType, out) end
            end
        end
    end
end

function UsefulPerfumes.collectMergeBottles(player, itemType)
    local out = {}
    if not player or not itemType then return out end
    collectMergeInto(player:getInventory(), itemType, out)
    return out
end

--- Fill the fullest bottles first. All perfume bottles share one capacity, so this reaches
--- ceil(total/capacity) non-empty bottles, which is the fewest possible. The returned indices refer
--- to the input order; `amounts` is never mutated.
function UsefulPerfumes.planMergeAmounts(amounts, capacities)
    local entries = {}
    for i = 1, #amounts do
        entries[i] = { index = i, amount = amounts[i], capacity = capacities[i] }
    end
    table.sort(entries, function(a, b)
        if a.amount ~= b.amount then return a.amount > b.amount end
        return a.index < b.index
    end)
    local transfers = {}
    for i = 1, #entries do
        local target = entries[i]
        local need = target.capacity - target.amount
        for j = i + 1, #entries do
            if need <= UsefulPerfumes.FluidTolerance then break end
            local source = entries[j]
            local give = math.min(need, source.amount)
            if give > UsefulPerfumes.FluidTolerance then
                transfers[#transfers + 1] = { from = source.index, to = target.index, amount = give }
                source.amount = source.amount - give
                target.amount = target.amount + give
                need = need - give
            end
        end
    end
    return transfers, entries
end

function UsefulPerfumes.planMerge(bottles)
    local amounts, capacities = {}, {}
    for i, item in ipairs(bottles) do
        local fc = item:getFluidContainer()
        amounts[i] = fc:getAmount()
        capacities[i] = fc:getCapacity()
    end
    local transfers = UsefulPerfumes.planMergeAmounts(amounts, capacities)
    local plan = {}
    for _, step in ipairs(transfers) do
        plan[#plan + 1] = { from = bottles[step.from], to = bottles[step.to], amount = step.amount }
    end
    return plan
end

function UsefulPerfumes.countNonEmpty(bottles)
    local count = 0
    for _, item in ipairs(bottles) do
        local fc = item:getFluidContainer()
        if fc and fc:getAmount() > UsefulPerfumes.FluidTolerance then count = count + 1 end
    end
    return count
end

--- The engine moves exact amounts, so this bypasses the 10 ml quantum that makes the vanilla
--- transfer UI refuse the last few millilitres. Emptied bottles are kept, never destroyed.
function UsefulPerfumes.applyMerge(player, item)
    if not player or not item then return false, "invalid" end
    local itemType = item:getType()
    if not UsefulPerfumes.Profiles[itemType] then return false, "invalid" end
    if player:isDead() or player:isAsleep() then return false, "busy" end
    if not UsefulPerfumes.findPlayerItem(player, item:getID()) then return false, "invalid" end
    UsefulPerfumes.guardItem(item)
    local bottles = UsefulPerfumes.collectMergeBottles(player, itemType)
    local before = #bottles
    local plan = UsefulPerfumes.planMerge(bottles)
    if #plan == 0 then return false, "nothing" end
    local touched = {}
    local moved = 0
    for _, step in ipairs(plan) do
        pcall(function()
            local fromFc = step.from:getFluidContainer()
            local toFc = step.to:getFluidContainer()
            -- CanTransfer also refuses every bottle carried directly by a player whose inventory
            -- weight is full, even though merging changes no weight.
            if not FluidContainer.CanTransfer(fromFc, toFc) then return end
            local amount = math.min(step.amount, fromFc:getAmount(), toFc:getCapacity() - toFc:getAmount())
            if amount <= UsefulPerfumes.FluidTolerance then return end
            local sourceBefore = fromFc:getAmount()
            fromFc:transferTo(toFc, amount)
            local gone = sourceBefore - fromFc:getAmount()
            if gone <= UsefulPerfumes.FluidTolerance then return end
            moved = moved + gone
            touched[step.from] = true
            touched[step.to] = true
        end)
    end
    for touchedItem in pairs(touched) do
        pcall(function() touchedItem:syncItemFields() end)
    end
    if moved <= UsefulPerfumes.FluidTolerance then return false, "blocked" end
    local after = UsefulPerfumes.countNonEmpty(bottles)
    return true, {
        itemType = itemType,
        before = before,
        after = after,
        emptied = before - after,
    }
end

function UsefulPerfumes.mergePerfume(player, item)
    if not player or not item then return false, "invalid" end
    if UsefulPerfumes.isRemoteClient() then
        sendClientCommand(player, UsefulPerfumes.ModId, "merge", { itemId = item:getID() })
        return nil, "sent"
    end
    return UsefulPerfumes.applyMerge(player, item)
end

function UsefulPerfumes.compensateEndurance(stats, previous, current, reduction)
    if not reduction or previous == nil then return current end
    local delta = current - previous
    if delta < 0 then
        stats:add(CharacterStat.ENDURANCE, -delta * reduction)
        return stats:get(CharacterStat.ENDURANCE)
    end
    return current
end

function UsefulPerfumes.compensateFatigue(stats, previous, current, reduction, asleep)
    if not reduction or previous == nil or asleep then return current end
    local delta = current - previous
    if delta > 0 then
        stats:remove(CharacterStat.FATIGUE, delta * reduction)
        return stats:get(CharacterStat.FATIGUE)
    end
    return current
end

function UsefulPerfumes.compensateMoodRise(stats, stat, previous, current, reduction)
    if not reduction or previous == nil or reduction <= 0 then return current end
    local delta = current - previous
    if delta > 0 then
        stats:remove(stat, delta * reduction)
        return stats:get(stat)
    end
    return current
end

function UsefulPerfumes.compensateCorpseSmell(stats, rate, multiplier, factor)
    if not rate or rate <= 0 or not factor or factor >= 1 then return end
    stats:remove(CharacterStat.FOOD_SICKNESS, rate * multiplier * (1 - factor))
end

function UsefulPerfumes.compensateCorpseRecovery(stats, rate, multiplier)
    if rate and rate > 0 then return false end
    if not stats:isAtMinimum(CharacterStat.POISON) then return false end
    if not stats:isAboveMinimum(CharacterStat.FOOD_SICKNESS) then return false end
    local base = (ZomboidGlobals and ZomboidGlobals.FoodSicknessDecrease) or 0.0015
    stats:remove(CharacterStat.FOOD_SICKNESS, base * multiplier)
    return true
end

local function applyPerfumeTick(player)
    local itemType = UsefulPerfumes.getState(player)
    if not itemType then
        UsefulPerfumes.lastStats[player] = nil
        return
    end
    local profile = UsefulPerfumes.Profiles[itemType]
    local stats = player:getStats()
    local last = UsefulPerfumes.lastStats[player]
    if not last then
        last = {}
        UsefulPerfumes.lastStats[player] = last
    end

    local unhappiness = stats:get(CharacterStat.UNHAPPINESS)
    if profile.moodRiseReduction then
        unhappiness = UsefulPerfumes.compensateMoodRise(stats, CharacterStat.UNHAPPINESS, last.unhappiness, unhappiness, profile.moodRiseReduction)
    end
    last.unhappiness = unhappiness

    local stress = stats:get(CharacterStat.STRESS)
    if profile.moodRiseReduction then
        stress = UsefulPerfumes.compensateMoodRise(stats, CharacterStat.STRESS, last.stress, stress, profile.moodRiseReduction)
    end
    last.stress = stress

    local endurance = stats:get(CharacterStat.ENDURANCE)
    if profile.enduranceReduction then
        endurance = UsefulPerfumes.compensateEndurance(stats, last.endurance, endurance, profile.enduranceReduction)
    end
    last.endurance = endurance

    local fatigue = stats:get(CharacterStat.FATIGUE)
    if profile.fatigueReduction then
        fatigue = UsefulPerfumes.compensateFatigue(stats, last.fatigue, fatigue, profile.fatigueReduction, player:isAsleep())
    end
    last.fatigue = fatigue

    if profile.smellFactor and profile.smellFactor < 1 then
        local rate = player:getCorpseSicknessRate()
        local multiplier = getGameTime():getMultiplier()
        if rate and rate > 0 then
            UsefulPerfumes.compensateCorpseSmell(stats, rate, multiplier, profile.smellFactor)
        else
            UsefulPerfumes.compensateCorpseRecovery(stats, rate, multiplier)
        end
    end
end

local DETECT_SCAN_INTERVAL_MS = 500
local DETECT_RADIUS = 10
local DETECT_BLIND_MS = 4000

local function breakZombieSight(zombie)
    zombie:setTarget(nil)
    zombie:setTargetSeenTime(0)
    if zombie.memory ~= nil then zombie.memory = 0 end
end

local function applyDetectionTick(player)
    local itemType = UsefulPerfumes.getState(player)
    local profile = itemType and UsefulPerfumes.Profiles[itemType]
    if not profile or not profile.detectionReduction then return end
    local nowMs = getTimestamp()
    local lastScan = UsefulPerfumes.lastDetectScan[player]
    if lastScan and nowMs - lastScan < DETECT_SCAN_INTERVAL_MS then return end
    UsefulPerfumes.lastDetectScan[player] = nowMs

    local sq = player:getCurrentSquare()
    if not sq then return end
    local px, py, pz = sq:getX(), sq:getY(), sq:getZ()
    local cell = getCell()
    if not cell then return end
    local blindUntil = UsefulPerfumes.zombieBlindUntil
    local seen = UsefulPerfumes.zombieSeen
    for dx = -DETECT_RADIUS, DETECT_RADIUS do
        for dy = -DETECT_RADIUS, DETECT_RADIUS do
            local square = cell:getGridSquare(px + dx, py + dy, pz)
            if square then
                local objects = square:getMovingObjects()
                if objects then
                    for i = 0, objects:size() - 1 do
                        local obj = objects:get(i)
                        if obj and instanceof(obj, "IsoZombie") then
                            local target = obj:getTarget()
                            local untilMs = blindUntil[obj]
                            local blind = untilMs and untilMs > nowMs
                            if target == player then
                                if blind then
                                    breakZombieSight(obj)
                                elseif not seen[obj] then
                                    seen[obj] = true
                                    if ZombRand(100) < math.floor(profile.detectionReduction * 100 + 0.5) then
                                        blindUntil[obj] = nowMs + DETECT_BLIND_MS
                                        breakZombieSight(obj)
                                    end
                                end
                            elseif not blind then
                                seen[obj] = nil
                                blindUntil[obj] = nil
                            end
                        end
                    end
                end
            end
        end
    end
end

function UsefulPerfumes.applyAromaTick(player)
    applyPerfumeTick(player)
    applyDetectionTick(player)
end

Events.OnPlayerUpdate.Add(function(player)
    if not player or UsefulPerfumes.isRemoteClient() then return end
    UsefulPerfumes.applyAromaTick(player)
end)

Events.OnPlayerDeath.Add(function(player)
    if not player or UsefulPerfumes.isRemoteClient() then return end
    UsefulPerfumes.clearAroma(player)
    UsefulPerfumes.SleepForce[player:getPlayerNum()] = nil
end)
