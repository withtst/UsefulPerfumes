require "ISUI/ISWorldObjectContextMenu"

UsefulPerfumes = UsefulPerfumes or {}

if UsefulPerfumes.sleepInstalled then return end
UsefulPerfumes.sleepInstalled = true
UsefulPerfumes.origSleepWalkToComplete = ISWorldObjectContextMenu.onSleepWalkToComplete
UsefulPerfumes.origGetBedQuality = ISWorldObjectContextMenu.getBedQuality

local function zombiesNear(playerObj)
    local stats = playerObj:getStats()
    return stats:getNumVisibleZombies() > 0 or stats:getNumChasingZombies() > 0 or stats:getNumVeryCloseZombies() > 0
end

local function painBlocks(playerObj)
    if playerObj:getSleepingTabletEffect() >= 2000 then return false end
    return playerObj:getMoodles():getMoodleLevel(MoodleType.PAIN) >= 2
        and playerObj:getStats():get(CharacterStat.FATIGUE) <= 0.85
end

local function wrappedSleepWalkToComplete(player, bed)
    local playerObj = getSpecificPlayer(player)
    if not playerObj or not UsefulPerfumes.hasSleepBuff(playerObj) then
        return UsefulPerfumes.origSleepWalkToComplete(player, bed)
    end
    if zombiesNear(playerObj) then
        HaloTextHelper.addBadText(playerObj, getText("IGUI_Sleep_NotSafe"))
        return
    end
    if painBlocks(playerObj) then
        HaloTextHelper.addBadText(playerObj, getText("ContextMenu_PainNoSleep"))
        return
    end
    if playerObj:getVariableBoolean("ExerciseEnded") == false then
        return
    end

    local oldEffect = playerObj:getSleepingTabletEffect()
    playerObj:setSleepingTabletEffect(2000)
    local ok, err = pcall(UsefulPerfumes.origSleepWalkToComplete, player, bed)
    playerObj:setSleepingTabletEffect(oldEffect)
    if not ok then
        print("UsefulPerfumes: sleep error " .. tostring(err))
        return
    end
    if playerObj:isAsleep() then
        playerObj:setBedType("goodBedPillow")
        playerObj:setForceWakeUpTime((getGameTime():getTimeOfDay() + 16) % 24)
        UsefulPerfumes.SleepForce[playerObj:getPlayerNum()] = true
    end
end

local function wrappedGetBedQuality(playerObj, bed)
    if playerObj and UsefulPerfumes.hasSleepBuff(playerObj) then
        return "goodBedPillow"
    end
    return UsefulPerfumes.origGetBedQuality(playerObj, bed)
end

ISWorldObjectContextMenu.onSleepWalkToComplete = wrappedSleepWalkToComplete
ISWorldObjectContextMenu.getBedQuality = wrappedGetBedQuality

local function sleepOptionNames()
    return {
        [getText("ContextMenu_Sleep")] = true,
        [getText("ContextMenu_SleepOnGround")] = true,
        [getText("ContextMenu_SleepOnGroundPillow")] = true,
        [getText("ContextMenu_Sleep_in_tent")] = true,
    }
end

UsefulPerfumes.sleepFillHandler = function(playerNum, context, worldObjects, test)
    local playerObj = getSpecificPlayer(playerNum)
    if not playerObj or not UsefulPerfumes.hasSleepBuff(playerObj) then return end
    if zombiesNear(playerObj) then return end
    local names = sleepOptionNames()
    local options = context.options
    if not options then return end
    for i = 1, #options do
        local option = options[i]
        -- ModernStatus/vanilla may store the disabled reason in different tooltip
        -- shapes. If the perfume is active and pain does not block, enable every
        -- sleep option; the walk-to-complete wrapper still enforces pain/zombies.
        if option and names[option.name] and option.notAvailable and not painBlocks(playerObj) then
            option.notAvailable = false
            option.isDisabled = false
            option.toolTip = nil
        end
    end
end

local sleepSessions = {}

local function newSession(playerObj)
    local itemType = UsefulPerfumes.getState(playerObj)
    local profile = itemType and UsefulPerfumes.Profiles[itemType]
    if not profile then return nil end
    if not profile.sleepComfortRate and not profile.sleepTimeScale then return nil end
    local now = UsefulPerfumes.now()
    return { itemType = itemType, start = now, last = now, banked = 0 }
end

-- The aroma only lasts 4 hours but a night is longer, so the perfume that was worn when the
-- player fell asleep keeps working until they actually wake up.
function UsefulPerfumes.getSleepSession(playerIndex)
    local session = sleepSessions[playerIndex]
    if session then return session end
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj or not playerObj:isAsleep() then return nil end
    session = newSession(playerObj)
    sleepSessions[playerIndex] = session
    return session
end

function UsefulPerfumes.applySleepComfort(playerIndex)
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj or not playerObj:isAsleep() then
        sleepSessions[playerIndex] = nil
        return
    end
    local session = UsefulPerfumes.getSleepSession(playerIndex)
    if not session then return end
    local now = UsefulPerfumes.now()
    if now > session.last then
        session.banked = session.banked + (now - session.last)
        session.last = now
    end
    if session.banked < UsefulPerfumes.SleepSettleHours then return end
    local hours = session.banked
    session.banked = 0
    local profile = UsefulPerfumes.Profiles[session.itemType]
    UsefulPerfumes.applySleepComfortStats(playerObj, session.itemType, hours)
    if profile.sleepTimeScale then
        local stats = playerObj:getStats()
        local fatigue = stats:get(CharacterStat.FATIGUE)
        local extra = UsefulPerfumes.calcSleepFatigueExtra(
            fatigue, hours,
            UsefulPerfumes.getSleepPlayerBedMod(playerObj),
            UsefulPerfumes.getSleepTraitMod(playerObj),
            profile.sleepTimeScale)
        if extra > 0 then
            stats:remove(CharacterStat.FATIGUE, extra)
        end
    end
end

UsefulPerfumes.sleepTickHandler = function(playerIndex, hourOfDay)
    local playerObj = getSpecificPlayer(playerIndex)
    if not playerObj then return end
    if not playerObj:isAsleep() then
        sleepSessions[playerIndex] = nil
        UsefulPerfumes.SleepForce[playerIndex] = nil
        return
    end
    UsefulPerfumes.applySleepComfort(playerIndex)
    if not UsefulPerfumes.SleepForce[playerIndex] then return end
    if playerObj:getStats():get(CharacterStat.FATIGUE) <= 0.01 then
        playerObj:forceAwake()
        UsefulPerfumes.SleepForce[playerIndex] = nil
        sleepSessions[playerIndex] = nil
    end
end

Events.OnFillWorldObjectContextMenu.Add(UsefulPerfumes.sleepFillHandler)
Events.OnSleepingTick.Add(UsefulPerfumes.sleepTickHandler)

function UsefulPerfumes.uninstallSleep()
    if not UsefulPerfumes.sleepInstalled then return end
    pcall(function() Events.OnFillWorldObjectContextMenu.Remove(UsefulPerfumes.sleepFillHandler) end)
    pcall(function() Events.OnSleepingTick.Remove(UsefulPerfumes.sleepTickHandler) end)
    ISWorldObjectContextMenu.onSleepWalkToComplete = UsefulPerfumes.origSleepWalkToComplete
    ISWorldObjectContextMenu.getBedQuality = UsefulPerfumes.origGetBedQuality
    sleepSessions = {}
    UsefulPerfumes.sleepInstalled = false
end
