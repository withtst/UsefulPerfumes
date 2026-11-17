require "TimedActions/ISBaseTimedAction"

UPPerfumeSprayAction = ISBaseTimedAction:derive("UPPerfumeSprayAction")

function UPPerfumeSprayAction:isValid()
    local item = UsefulPerfumes.findPlayerItem(self.character, self.itemId)
    return item ~= nil
end

function UPPerfumeSprayAction:start()
    self.item = UsefulPerfumes.findPlayerItem(self.character, self.itemId)
    if self.item then
        self.itemId = self.item:getID()
    end
    self.sound = self.character:playSound("UP_PerfumeSpray")
end

function UPPerfumeSprayAction:update()
end

function UPPerfumeSprayAction:stop()
    if self.sound then
        self.character:stopOrTriggerSound(self.sound)
        self.sound = nil
    end
    ISBaseTimedAction.stop(self)
end

function UPPerfumeSprayAction:perform()
    if self.sound then
        self.sound = nil
    end
    local item = UsefulPerfumes.findPlayerItem(self.character, self.itemId)
    if item and not UsefulPerfumes.getUseBlockReason(self.character, item) then
        UsefulPerfumes.requestSpray(self.character, item, self.character:getPlayerNum())
    end
    ISBaseTimedAction.perform(self)
end

function UPPerfumeSprayAction:adjustMaxTime(maxTime)
    return maxTime
end

function UPPerfumeSprayAction:new(character, item)
    local o = ISBaseTimedAction.new(self, character)
    o.item = item
    o.itemId = item:getID()
    o.stopOnWalk = false
    o.maxTime = 10
    o.forceProgressBar = true
    o.ignoreHandsWounds = true
    return o
end
