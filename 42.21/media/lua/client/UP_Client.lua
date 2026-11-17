require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"

UsefulPerfumes = UsefulPerfumes or {}

local function badText(player, text)
    HaloTextHelper.addBadText(player, text)
end

local function sprayedText(player, item, mode)
    local name = getItemName("Base." .. item:getType()) or item:getName()
    if mode == "switch" then
        HaloTextHelper.addText(player, getText("UI_UP_Switched", name))
    else
        HaloTextHelper.addText(player, getText("UI_UP_Sprayed", name))
    end
end

function UsefulPerfumes.requestSpray(player, item, playerNum)
    local ok, itemType, _, mode = UsefulPerfumes.sprayPerfume(player, item)
    if itemType == "sent" then return end
    if ok then
        sprayedText(player, item, mode)
    elseif itemType == "empty" then
        badText(player, getText("ContextMenu_UP_Empty"))
    else
        badText(player, getText("ContextMenu_UP_Busy"))
    end
end

function UsefulPerfumes.onSpray(player, playerNum, item)
    if not player or not item then return end
    local reason = UsefulPerfumes.getUseBlockReason(player, item)
    if reason == "empty" then
        badText(player, getText("ContextMenu_UP_Empty"))
        return
    elseif reason then
        badText(player, getText("ContextMenu_UP_Busy"))
        return
    end
    ISTimedActionQueue.add(UPPerfumeSprayAction:new(player, item))
end

local function makeTooltip(text)
    local tooltip = ISInventoryPaneContextMenu.addToolTip()
    tooltip.description = text
    return tooltip
end

local function mergedText(player, result)
    local name = getItemName("Base." .. result.itemType) or result.itemType
    HaloTextHelper.addText(player, getText("UI_UP_Merged", name, result.before, result.after, result.emptied))
end

local function mergeFailureText(reason)
    if reason == "blocked" then return getText("UI_UP_MergeBlocked") end
    if reason == "cooldown" then return getText("UI_UP_MergeCooldown") end
    return getText("UI_UP_MergeNothing")
end

function UsefulPerfumes.requestMerge(player, item)
    local ok, result = UsefulPerfumes.mergePerfume(player, item)
    if result == "sent" then return end
    if ok then
        mergedText(player, result)
    else
        badText(player, mergeFailureText(result))
    end
end

function UsefulPerfumes.onMerge(player, playerNum, item)
    if not player or not item then return end
    UsefulPerfumes.requestMerge(player, item)
end

function UsefulPerfumes.addMergeOption(player, context, item, playerNum)
    if not player then return end
    if not UsefulPerfumes.findPlayerItem(player, item:getID()) then return end
    if player:isDead() or player:isAsleep() then return end
    local bottles = UsefulPerfumes.collectMergeBottles(player, item:getType())
    if #bottles < 2 then return end
    if #UsefulPerfumes.planMerge(bottles) == 0 then return end
    playerNum = playerNum or UsefulPerfumes.getPlayerNum(player)
    local name = getItemName("Base." .. item:getType()) or item:getName()
    local option = context:addOptionOnTop(getText("ContextMenu_UP_MergeAll", name), player, UsefulPerfumes.onMerge, playerNum, item)
    option.toolTip = makeTooltip(getText("ContextMenu_UP_MergeAll_Tooltip"))
end

function UsefulPerfumes.addPerfumeOption(player, context, item, playerNum)
    if not player then return end
    if not UsefulPerfumes.findPlayerItem(player, item:getID()) then return end
    UsefulPerfumes.guardItem(item)
    playerNum = playerNum or UsefulPerfumes.getPlayerNum(player)
    local reason = UsefulPerfumes.getUseBlockReason(player, item)
    local label
    local tooltip
    if not reason then
        label = getText("ContextMenu_UP_SprayPerfume")
        if UsefulPerfumes.isAromaActive(player) then
            tooltip = getText("ContextMenu_UP_Respray_Tooltip")
        else
            tooltip = getText("ContextMenu_UP_SprayPerfume_Tooltip")
        end
    elseif reason == "empty" then
        label = getText("ContextMenu_UP_Empty")
        tooltip = getText("ContextMenu_UP_Empty_Tooltip")
    else
        label = getText("ContextMenu_UP_Busy")
        tooltip = getText("ContextMenu_UP_Busy_Tooltip")
    end
    local option = context:addOptionOnTop(label, player, UsefulPerfumes.onSpray, playerNum, item)
    option.toolTip = makeTooltip(tooltip)
    if reason then
        option.notAvailable = true
    end
end

local function onFillInventoryObjectContextMenu(playerNum, context, items)
    local actualItems = ISInventoryPane.getActualItems(items)
    if not actualItems then return end
    for _, item in ipairs(actualItems) do
        if UsefulPerfumes.getProfileForItem(item) then
            local player = getSpecificPlayer(playerNum)
            -- Both options go on top, so the merge row is added first to keep "Use Perfume" first.
            UsefulPerfumes.addMergeOption(player, context, item, playerNum)
            UsefulPerfumes.addPerfumeOption(player, context, item, playerNum)
            return
        end
    end
end

Events.OnFillInventoryObjectContextMenu.Add(onFillInventoryObjectContextMenu)

Events.OnServerCommand.Add(function(module, command, args)
    if module ~= UsefulPerfumes.ModId then return end
    local player = getPlayer()
    if not player then return end
    if command == "state" then
        UsefulPerfumes.stateReceived = true
        if args and args.clear then
            UsefulPerfumes.setClientState(player, nil, nil)
        else
            UsefulPerfumes.setClientState(player, args and args.type, args and args.expiry)
        end
    elseif command == "sprayed" then
        local itemType = args and args.type
        local name = itemType and getItemName("Base." .. itemType) or nil
        name = name or getItemName("Base.Perfume") or "perfume"
        if args and args.mode == "switch" then
            HaloTextHelper.addText(player, getText("UI_UP_Switched", name))
        else
            HaloTextHelper.addText(player, getText("UI_UP_Sprayed", name))
        end
    elseif command == "merged" then
        if args and args.itemType then
            mergedText(player, args)
        end
    elseif command == "denied" then
        local reason = args and args.reason
        if reason == "empty" then
            badText(player, getText("ContextMenu_UP_Empty"))
        elseif reason == "nothing" or reason == "blocked" or reason == "cooldown" then
            badText(player, mergeFailureText(reason))
        else
            badText(player, getText("ContextMenu_UP_Busy"))
        end
    end
end)

if UsefulPerfumes.isRemoteClient() then
    local lastQuery = 0
    local function queryState(player)
        if (UsefulPerfumes.queryTries or 0) >= 10 then return end
        local now = getTimestamp()
        if now - lastQuery < 1000 then return end
        lastQuery = now
        UsefulPerfumes.queryTries = (UsefulPerfumes.queryTries or 0) + 1
        sendClientCommand(player, UsefulPerfumes.ModId, "query", {})
    end
    Events.OnGameStart.Add(function()
        UsefulPerfumes.clientState = {}
        UsefulPerfumes.stateReceived = nil
        UsefulPerfumes.queryTries = 0
        lastQuery = 0
        local player = getPlayer()
        if player then queryState(player) end
    end)
    Events.OnPlayerUpdate.Add(function(player)
        if not UsefulPerfumes.stateReceived and player then
            queryState(player)
        end
    end)
end
