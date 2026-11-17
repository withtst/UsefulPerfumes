if not isServer() then return end

UsefulPerfumes = UsefulPerfumes or {}

local function sendState(player)
    local itemType, expiry = UsefulPerfumes.getState(player)
    if itemType then
        sendServerCommand(player, UsefulPerfumes.ModId, "state", { type = itemType, expiry = expiry })
    else
        sendServerCommand(player, UsefulPerfumes.ModId, "state", { clear = true })
    end
end

local function deny(player, reason)
    sendServerCommand(player, UsefulPerfumes.ModId, "denied", { reason = reason })
end

local lastMerge = setmetatable({}, { __mode = "k" })
local MERGE_COOLDOWN_MS = 1000

local function handleSpray(player, args)
    local itemId = args and args.itemId
    local item = UsefulPerfumes.findPlayerItem(player, itemId)
    if not item or not UsefulPerfumes.getProfileForItem(item) then
        deny(player, "invalid")
        return
    end
    local reason = UsefulPerfumes.getUseBlockReason(player, item)
    if reason then
        deny(player, reason)
        return
    end
    local ok, itemType, _, mode = UsefulPerfumes.applyPerfumeUse(player, item)
    if not ok then
        deny(player, itemType)
        return
    end
    sendServerCommand(player, UsefulPerfumes.ModId, "sprayed", { type = itemType, mode = mode })
    sendState(player)
end

local function handleMerge(player, args)
    local item = UsefulPerfumes.findPlayerItem(player, args and args.itemId)
    if not item or not UsefulPerfumes.getProfileForItem(item) then
        deny(player, "nothing")
        return
    end
    local nowMs = getTimestamp()
    local last = lastMerge[player]
    if last and nowMs - last < MERGE_COOLDOWN_MS then
        deny(player, "cooldown")
        return
    end
    lastMerge[player] = nowMs
    local ok, result = UsefulPerfumes.applyMerge(player, item)
    if not ok then
        if result == "blocked" then
            deny(player, "blocked")
        else
            deny(player, "nothing")
        end
        return
    end
    sendServerCommand(player, UsefulPerfumes.ModId, "merged", result)
end

Events.OnClientCommand.Add(function(module, command, player, args)
    if module ~= UsefulPerfumes.ModId or not player then return end
    if command == "query" then
        sendState(player)
    elseif command == "spray" then
        handleSpray(player, args)
    elseif command == "merge" then
        handleMerge(player, args)
    end
end)

Events.OnPlayerDeath.Add(function(player)
    if not player then return end
    UsefulPerfumes.clearAroma(player)
    sendState(player)
end)

Events.OnPlayerUpdate.Add(function(player)
    if not player then return end
    local md = player:getModData()
    if md.UP_AromaType and md.UP_AromaExpiry and md.UP_AromaExpiry <= UsefulPerfumes.now() then
        UsefulPerfumes.clearAroma(player)
        sendState(player)
    end
end)
