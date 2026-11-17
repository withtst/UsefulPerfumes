require "ISUI/ISToolTipInv"

UsefulPerfumes = UsefulPerfumes or {}

if UsefulPerfumes.tooltipInstalled then return end
UsefulPerfumes.tooltipInstalled = true
UsefulPerfumes.origToolTipSetItem = ISToolTipInv.setItem

ISToolTipInv.setItem = function(self, item)
    UsefulPerfumes.origToolTipSetItem(self, item)
    UsefulPerfumes.applyItemTooltip(item)
end

function UsefulPerfumes.uninstallTooltips()
    if not UsefulPerfumes.tooltipInstalled then return end
    ISToolTipInv.setItem = UsefulPerfumes.origToolTipSetItem
    UsefulPerfumes.tooltipInstalled = false
end
