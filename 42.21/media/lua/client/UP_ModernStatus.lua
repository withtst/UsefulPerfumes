UsefulPerfumes = UsefulPerfumes or {}
UP = UP or {}

if UP.modernStatusInstalled then return end

local INDICATOR_TYPE = "UP_PerfumeStatusIndicator"
local ICON_NAME = "UP_Perfume"

local function getAroma(player)
    player = player or getPlayer()
    if not player then return nil end
    local itemType, expiry = UsefulPerfumes.getState(player)
    if not itemType or not expiry then return nil end
    return itemType, expiry
end

function UP.installModernStatus()
    if UP.modernStatusInstalled then return true end

    -- ModernStatus is optional; load it lazily so this mod still works without it.
    pcall(require, "MS/MS_StatusIndicator")
    pcall(require, "MS/StatusWidget_Main")
    if not (MS_StatusIndicator and StatusWidget and MSConfig) then
        return false
    end

    local indicatorClass = MS_StatusIndicator:derive(INDICATOR_TYPE)

    function indicatorClass:new(x, y, width, height, player)
        local o = MS_StatusIndicator.new(self, x, y, width, height, player)
        o.baseIconName = ICON_NAME
        o.preferModernStatusColorIcon = true
        o.__type = INDICATOR_TYPE
        o.indicatorColor = { r = 0.95, g = 0.72, b = 0.82 }
        return o
    end

    function indicatorClass:getValue()
        local itemType, expiry = getAroma(self.player)
        if not itemType or not expiry then return 0 end
        local remaining = expiry - UsefulPerfumes.now()
        if remaining <= 0 then return 0 end
        return math.min(1, remaining / UsefulPerfumes.AromaHours)
    end

    function indicatorClass:getHoverText(value)
        local itemType, expiry = getAroma(self.player)
        if not itemType or not expiry then return "" end
        return UsefulPerfumes.formatRemainingHours(expiry - UsefulPerfumes.now())
    end

    function indicatorClass:getIndicatorDisplayName()
        return getText("UI_UP_ModernStatus_Title")
    end

    function indicatorClass:getTooltipDescription(value)
        local itemType, expiry = getAroma(self.player)
        if not itemType or not expiry then return "" end
        local itemName = getItemName("Base." .. itemType) or itemType
        local effect = getText("UI_UP_Effect_" .. itemType) or ""
        local time = getText("UI_UP_Status_Time", UsefulPerfumes.formatRemainingHours(expiry - UsefulPerfumes.now()))
        return getText("UI_UP_Status_Name", itemName) .. " <LINE> "
            .. getText("UI_UP_Status_Effect") .. effect .. " <LINE> " .. time
    end

    if MS_IndicatorSettingsPanel and MS_IndicatorSettingsPanel.IndicatorNames then
        MS_IndicatorSettingsPanel.IndicatorNames[INDICATOR_TYPE] = "UI_UP_ModernStatus_Title"
    end

    local function configureIndicator(playerIndex)
        local config = MSConfig.getIndicatorConfig(playerIndex, INDICATOR_TYPE)
        config.style = "bar"
        config.barSize = config.barSize or { width = 168, height = 18 }
        config.autoHide = true
        config.autoHideThreshold = 0
        config.showIcon = true
        config.showName = true
        config.updateIntervalMs = 250
        config.color = config.color or { r = 0.95, g = 0.72, b = 0.82 }
        return config
    end

    local function addIndicator(playerIndex, player)
        if not StatusWidget.indicators[playerIndex] then
            StatusWidget.indicators[playerIndex] = {}
        end
        if StatusWidget.indicators[playerIndex][INDICATOR_TYPE] then return end
        if not StatusWidget.indicatorsByType[playerIndex] then
            StatusWidget.indicatorsByType[playerIndex] = {}
        end

        local config = configureIndicator(playerIndex)
        local width, height
        if config.style == "bar" then
            width = config.barSize.width
            height = config.barSize.height
        else
            width = config.circularSize
            height = config.circularSize
        end
        local x = config.position and config.position.x or 364
        local y = config.position and config.position.y or 64

        local indicator = indicatorClass:new(x, y, width, height, player)
        indicator:initialise()
        indicator:addToUIManager()
        StatusWidget.indicators[playerIndex][INDICATOR_TYPE] = indicator
        StatusWidget.indicatorsByType[playerIndex][INDICATOR_TYPE] = indicator
    end

    local origCreateUI = StatusWidget.createUI
    if not UP.modernStatusOrigCreateUI then
        UP.modernStatusOrigCreateUI = origCreateUI
    end
    StatusWidget.createUI = function(playerIndex, player)
        origCreateUI(playerIndex, player)
        if not player or not player:isLocalPlayer() then return end
        addIndicator(playerIndex, player)
    end

    UP.PerfumeStatusIndicator = indicatorClass
    UP.modernStatusInstalled = true
    return true
end

function UP.uninstallModernStatus()
    if not UP.modernStatusInstalled then return end
    if StatusWidget and UP.modernStatusOrigCreateUI then
        StatusWidget.createUI = UP.modernStatusOrigCreateUI
    end
    if StatusWidget and StatusWidget.indicators then
        for _, indicators in pairs(StatusWidget.indicators) do
            local indicator = indicators[INDICATOR_TYPE]
            if indicator then
                indicator:removeFromUIManager()
                indicators[INDICATOR_TYPE] = nil
            end
        end
    end
    if StatusWidget and StatusWidget.indicatorsByType then
        for _, indicators in pairs(StatusWidget.indicatorsByType) do
            indicators[INDICATOR_TYPE] = nil
        end
    end
    UP.modernStatusInstalled = false
end

Events.OnGameBoot.Add(function()
    UP.installModernStatus()
end)
