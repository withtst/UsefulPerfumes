require "ISUI/ISInventoryPane"

UsefulPerfumes = UsefulPerfumes or {}

if UsefulPerfumes.namesInstalled then return end
UsefulPerfumes.namesInstalled = true
UsefulPerfumes.origInventoryRefresh = ISInventoryPane.refreshContainer

ISInventoryPane.refreshContainer = function(self, ...)
    local result = UsefulPerfumes.origInventoryRefresh(self, ...)
    if self._upSkipFluidMigration then return result end
    if UsefulPerfumes.guardInventoryRows(self) then
        self._upSkipFluidMigration = true
        result = UsefulPerfumes.origInventoryRefresh(self, ...)
        self._upSkipFluidMigration = nil
    end
    return result
end

function UsefulPerfumes.uninstallNames()
    if not UsefulPerfumes.namesInstalled then return end
    ISInventoryPane.refreshContainer = UsefulPerfumes.origInventoryRefresh
    UsefulPerfumes.namesInstalled = false
end
