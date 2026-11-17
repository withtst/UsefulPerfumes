require "ISUI/ISInventoryItem"
require "UP_Core"

UsefulPerfumes = UsefulPerfumes or {}
if UsefulPerfumes.liquidIconsInstalled then return end

local bottleTextures = {
    ["Base.UP_FirstLoveBlueberry"] = "Blueberry",
    ["Base.UP_CheapKnockoff"] = "Cheap",
    ["Base.UP_ElegantMiss"] = "Elegant",
    ["Base.UP_HerbalBlend"] = "Herbal",
    ["Base.UP_ColdCotton"] = "ColdCotton",
    ["Base.UP_SlumberFloral"] = "Slumber",
}
local textures = {}
local originalRender = ISInventoryItem.renderItemIcon

local function levelIndex(amount, capacity)
    if type(amount) ~= "number" or type(capacity) ~= "number" or capacity <= 0 then return nil end
    local fraction = math.max(0, math.min(1, amount / capacity))
    return math.floor(fraction * 20 + 0.5)
end

local function renderPerfumeIcon(self, item, x, y, alpha, w, h)
    local key = item and bottleTextures[item:getFullType()]
    if key then
        local fc = item:getFluidContainer()
        local capacity = fc and fc:getCapacity()
        local amount = fc and UsefulPerfumes.getOwnFluidAmount(item)
        local index = levelIndex(amount, capacity)
        if index then
            local path = "media/textures/UPLiquidLevels/" .. key .. "_" .. string.format("%02d", index) .. ".png"
            local tex = textures[path]
            if not tex then
                tex = getTexture(path)
                if tex then textures[path] = tex end
            end
            if tex then
                local width = w or tex:getWidthOrig()
                local height = h or tex:getHeightOrig()
                self:drawTextureScaled(tex, x, y, width, height, 1.0, 1, 1, 1)
                return
            end
        end
    end
    return originalRender(self, item, x, y, alpha, w, h)
end

UsefulPerfumes.liquidIconsInstalled = true
UsefulPerfumes.originalLiquidIconRender = originalRender
UsefulPerfumes.liquidIconRenderer = renderPerfumeIcon
UsefulPerfumes.liquidLevelIndex = levelIndex
ISInventoryItem.renderItemIcon = renderPerfumeIcon

function UsefulPerfumes.uninstallLiquidIcons()
    if ISInventoryItem.renderItemIcon == renderPerfumeIcon then
        ISInventoryItem.renderItemIcon = originalRender
    end
    UsefulPerfumes.liquidIconsInstalled = false
end
