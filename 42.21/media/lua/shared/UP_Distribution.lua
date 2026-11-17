-- Loaded from shared so single-player also patches its local loot tables.
UsefulPerfumes = UsefulPerfumes or {}

-- Per-loot-list shares of X, where X is the original Perfume + Cologne weight.
-- The shares sum to 1.0, so the total perfume weight of each list is unchanged.
UsefulPerfumes.DistributionShares = {
    { key = "Perfume", share = 0.30 },
    { key = "Cologne", share = 0.10 },
    { key = "UP_CheapKnockoff", share = 0.30 },
    { key = "UP_FirstLoveBlueberry", share = 0.05 },
    { key = "UP_ElegantMiss", share = 0.10 },
    { key = "UP_HerbalBlend", share = 0.05 },
    { key = "UP_ColdCotton", share = 0.05 },
    { key = "UP_SlumberFloral", share = 0.05 },
}

local function baseName(name)
    if type(name) ~= "string" then return nil end
    if name:sub(1, 5) == "Base." then return name:sub(6) end
    return name
end

local function patchItemList(list, stats)
    if type(list) ~= "table" then return end

    local prefix = nil
    local originalTotal = 0
    local entryWeights = {}
    for i = 1, #list - 1, 2 do
        local name = list[i]
        local weight = list[i + 1]
        local base = baseName(name)
        if (base == "Perfume" or base == "Cologne") and type(weight) == "number" then
            prefix = prefix or (name:sub(1, 5) == "Base." and "Base." or "")
            originalTotal = originalTotal + weight
            entryWeights[base] = (entryWeights[base] or 0) + weight
        end
    end
    if not prefix or originalTotal <= 0 then return end

    local existingByKey = {}
    for i = 1, #list - 1, 2 do
        local base = baseName(list[i])
        if base then
            existingByKey[base] = existingByKey[base] or {}
            existingByKey[base][#existingByKey[base] + 1] = i
        end
    end

    local added = 0
    for _, target in ipairs(UsefulPerfumes.DistributionShares) do
        local key = target.key
        local targetWeight = originalTotal * target.share
        local indices = existingByKey[key]
        if indices and #indices > 0 then
            local existingTotal = 0
            for _, idx in ipairs(indices) do
                existingTotal = existingTotal + (tonumber(list[idx + 1]) or 0)
            end
            if existingTotal > 0 then
                local factor = targetWeight / existingTotal
                for _, idx in ipairs(indices) do
                    list[idx + 1] = (tonumber(list[idx + 1]) or 0) * factor
                end
            end
        else
            list[#list + 1] = prefix .. key
            list[#list + 1] = targetWeight
            added = added + 1
        end
    end

    stats.entries = stats.entries + added
    stats.lists = stats.lists + 1
end

local function walk(t, seen, stats)
    if type(t) ~= "table" or seen[t] then return end
    seen[t] = true
    patchItemList(t, stats)
    for _, v in pairs(t) do
        if type(v) == "table" then
            walk(v, seen, stats)
        end
    end
end

function UsefulPerfumes.installDistribution()
    if UsefulPerfumes.distributionInstalled then return UsefulPerfumes.distributionStats end
    local stats = { lists = 0, entries = 0 }
    if not UsefulPerfumes.DistributionShares then return stats end
    local seen = {}
    if ProceduralDistributions and ProceduralDistributions.list then
        walk(ProceduralDistributions.list, seen, stats)
    end
    if ClutterTables then
        walk(ClutterTables, seen, stats)
    end
    UsefulPerfumes.distributionStats = stats
    if stats.lists > 0 then
        UsefulPerfumes.distributionInstalled = true
        print(string.format("UsefulPerfumes: patched %d weighted loot lists, %d new entries", stats.lists, stats.entries))
    end
    return stats
end

UsefulPerfumes.installDistribution()
Events.OnPreDistributionMerge.Add(UsefulPerfumes.installDistribution)
Events.OnGameStart.Add(UsefulPerfumes.installDistribution)
