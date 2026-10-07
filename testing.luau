-- https://sitetest1.lua.expert

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local ForestGuardRuntime = require(script.ForestGuardRuntime)
local GuardComponent = require(script.GuardComponent)
local GuardEscapeSignController = require(script.GuardEscapeSignController)
local GuardTutorialController = require(script.GuardTutorialController)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Promise = require(ReplicatedStorage.Packages.Promise)
local v1 = {}
local v2 = {}
local v3 = {}
local v4 = {}

-- NEW: track DescendantAdded connections so we can clean them up
local guardDamageConnections = {}

-- NEW: neutralise a guard model so it can't hit the player
local function disableGuardAttacks(guardModel)
    if guardModel == nil then
        return
    end

    local function process(inst)
        if inst:IsA("BasePart") then
            local n = inst.Name:lower()
            if n:find("hit") or n:find("damage") or n:find("attack")
                or n:find("kill") or n:find("sword") or n:find("weapon")
                or n:find("touch") or n:find("melee") then
                pcall(function()
                    inst.CanTouch = false
                    inst.CanQuery = false
                end)
            end
        elseif inst:IsA("Script") or inst:IsA("LocalScript") then
            local n = inst.Name:lower()
            if n:find("hit") or n:find("damage") or n:find("attack")
                or n:find("kill") or n:find("combat") or n:find("melee") then
                pcall(function()
                    inst.Disabled = true
                end)
            end
        end
    end

    for _, d in ipairs(guardModel:GetDescendants()) do
        process(d)
    end

    if guardDamageConnections[guardModel] ~= nil then
        guardDamageConnections[guardModel]:Disconnect()
    end
    guardDamageConnections[guardModel] = guardModel.DescendantAdded:Connect(process)
end

function v4.Start() -- line 32 | captures: Workspace, ForestGuardRuntime, GuardComponent, GuardEscapeSignController, GuardTutorialController, Remotes, Promise, v1, v2, v3
    local v5 = GuardTutorialController.new()
    task.spawn(function() -- line 34 | captures: v5
        v5:Start()
    end)
    local v6 = true
    local v7 = -1
    local World = Workspace:WaitForChild("World")
    local Folder = World:IsA("Folder")
    assert(Folder, "Workspace.World must be a Folder")
    local Areas = World:WaitForChild("Areas")
    local Folder_2 = Areas:IsA("Folder")
    assert(Folder_2, "Workspace.World.Areas must be a Folder")
    local GuardAreas = Areas:WaitForChild("GuardAreas")
    local Folder_3 = GuardAreas:IsA("Folder")
    assert(Folder_3, "Workspace.World.Areas.GuardAreas must be a Folder")

    local function applyGuardsEnabled(v8, v9) -- line 47 | captures: v6, v7, v2
        if v9 < v7 then
            return
        end
        v6 = v8
        v7 = v9
        for v10, v11 in pairs(v2) do
            if v11 ~= nil and v11.ForestRuntime ~= nil then
                v11.ForestRuntime:SetEnabled(v8)
            end
        end
    end

    local function setupAreaModel(v12) -- line 64 | captures: v6, GuardAreas, ForestGuardRuntime, GuardComponent, GuardEscapeSignController, v1, v2, v3
        if v1[v12] == nil then
            v1[v12] = GuardEscapeSignController.new(v12)
        end
        if v2[v12] == nil then
            local v13, v14
            if v12.Name == "Forest" then
                v14 = ForestGuardRuntime.new(v12)
                v13 = GuardComponent.new(v12)
                v14:SetWakeHandler(function(v15) -- line 79 | captures: v13
                    v13:PlayWakeUp()
                end)
            else
                v13 = GuardComponent.new(v12)
            end
            -- NEW: stop this guard from hitting the player
            pcall(disableGuardAttacks, v13:GetGuardModel())

            if v12.Parent == GuardAreas then
                local v16 = {
                    ForestRuntime = v14,
                    Guard = v13
                }
                v2[v12] = v16
                v3[v13:GetGuardModel()] = v13
                if v14 ~= nil then
                    v14:SetEnabled(v6)
                    v14:Start()
                end
            else
                v13:Destroy()
                if v14 ~= nil then
                    v14:Destroy()
                end
            end
        end
    end

    local function cleanupAreaModel(v17) -- line 105 | captures: v1, v2, v3
        local v18 = v1[v17]
        if v18 ~= nil then
            v1[v17] = nil
            v18:Destroy()
        end
        local v19 = v2[v17]
        if v19 == nil then
            return
        end
        v2[v17] = nil
        v3[v19.Guard:GetGuardModel()] = nil

        -- NEW: tear down the anti-hit listener for this guard
        local guardModel = v19.Guard:GetGuardModel()
        if guardModel ~= nil and guardDamageConnections[guardModel] ~= nil then
            guardDamageConnections[guardModel]:Disconnect()
            guardDamageConnections[guardModel] = nil
        end

        v19.Guard:Destroy()
        if v19.ForestRuntime ~= nil then
            v19.ForestRuntime:Destroy()
        end
    end

    GuardAreas.ChildAdded:Connect(function(v20) -- line 128 | captures: setupAreaModel
        local Model = v20:IsA("Model")
        local v21 = ("%* must be a guard area Model"):format((v20:GetFullName()))
        assert(Model, v21)
        setupAreaModel(v20)
    end)
    GuardAreas.ChildRemoved:Connect(function(v22) -- line 136 | captures: cleanupAreaModel
        local Model = v22:IsA("Model")
        local v23 = ("%* must be a guard area Model"):format((v22:GetFullName()))
        assert(Model, v23)
        cleanupAreaModel(v22)
    end)
    for v24, v25 in ipairs(GuardAreas:GetChildren()) do
        local Model = v25:IsA("Model")
        local v26 = ("%* must be a guard area Model"):format((v25:GetFullName()))
        assert(Model, v26)
        task.spawn(setupAreaModel, v25)
    end
    Remotes.GuardPatrol.Rouse.OnClientEvent:Connect(function(v27) -- line 152 | captures: v3
        local v28 = v3[v27]
        if v28 ~= nil then
            v28:PlayWakeUp()
        end
    end)
    Remotes.GuardPatrol.EnabledShifted.OnClientEvent:Connect(applyGuardsEnabled)
    task.spawn(function() -- line 162 | captures: v7, applyGuardsEnabled, Remotes, Promise
        local v29, v30
        while true do
            if v7 < 0 then
                local v31
                v31, v29, v30 = Promise.try(function() -- line 164 | captures: Remotes
                    return Remotes.GuardPatrol.AskEnabled:InvokeServer()
                end):timeout(30):await()
                if v31 and typeof(v29) == "boolean" and typeof(v30) == "number" then
                    break
                end
                task.wait(1)
                continue
            end
            return
        end
        applyGuardsEnabled(v29, v30)
    end)
end

return v4