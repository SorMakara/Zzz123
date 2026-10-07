-- https://sitetest1.lua.expert
-- Anti-guard-hit version

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace        = game:GetService("Workspace")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")

local ForestGuardRuntime         = require(script.ForestGuardRuntime)
local GuardComponent             = require(script.GuardComponent)
local GuardEscapeSignController  = require(script.GuardEscapeSignController)
local GuardTutorialController    = require(script.GuardTutorialController)
local Remotes                    = require(ReplicatedStorage.Shared.Remotes)
local Promise                    = require(ReplicatedStorage.Packages.Promise)

local LocalPlayer = Players.LocalPlayer

local v1 = {}
local v2 = {}
local v3 = {}
local v4 = {}

-- ============================================================
-- ANTI-HIT HELPERS
-- ============================================================

local HIT_KEYWORDS = {
    "hit", "damage", "dmg", "attack", "kill", "sword", "weapon",
    "touch", "melee", "punch", "bite", "claw", "hurt", "harm",
    "killzone", "killbrick", "trap",
}

local function nameMatchesHit(name)
    local n = name:lower()
    for _, k in ipairs(HIT_KEYWORDS) do
        if n:find(k, 1, true) then return true end
    end
    return false
end

-- Track connections so we can clean up
local guardDamageConnections = {}
local blockedRemotes          = {}

-- Disable a single instance (part or script)
local function neutralise(inst)
    if inst:IsA("BasePart") then
        if nameMatchesHit(inst.Name) then
            pcall(function()
                inst.CanTouch  = false
                inst.CanQuery  = false
                inst.CanCollide = false
            end)
        end
    elseif inst:IsA("Script") or inst:IsA("LocalScript") or inst:IsA("ModuleScript") then
        if nameMatchesHit(inst.Name) then
            pcall(function() inst.Disabled = true end)
        end
    elseif inst:IsA("RemoteEvent") or inst:IsA("RemoteFunction") then
        if nameMatchesHit(inst.Name) then
            blockedRemotes[inst] = true
        end
    end
end

-- Kill a guard model's ability to hit
local function disableGuardAttacks(guardModel)
    if not guardModel or not guardModel.Parent then return end

    for _, d in ipairs(guardModel:GetDescendants()) do
        neutralise(d)
    end

    if guardDamageConnections[guardModel] then
        pcall(function() guardDamageConnections[guardModel]:Disconnect() end)
    end
    guardDamageConnections[guardModel] = guardModel.DescendantAdded:Connect(neutralise)
end

-- ============================================================
-- BLOCK DAMAGE REMOTES GLOBALLY (swallow anything damage-ish)
-- ============================================================
do
    local function hookRemote(r)
        if not (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then return end
        if not nameMatchesHit(r.Name) then return end
        if blockedRemotes[r] then return end
        blockedRemotes[r] = true
        if r:IsA("RemoteEvent") then
            -- swallow incoming damage events
            pcall(function()
                r.OnClientEvent:Connect(function() end)
            end)
        elseif r:IsA("RemoteFunction") then
            -- hijack the callback so any invoke returns nil
            pcall(function()
                r.OnClientInvoke = function() return nil end
            end)
        end
    end

    for _, d in ipairs(game:GetDescendants()) do
        hookRemote(d)
    end
    game.DescendantAdded:Connect(hookRemote)
end

-- ============================================================
-- HEALTH RUBBER-BAND (fallback for server-side damage)
-- ============================================================
local function watchCharacter(char)
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end

    local lastMax = hum.MaxHealth

    hum.HealthChanged:Connect(function(h)
        if h < lastMax and h > 0 then
            -- push health back up
            pcall(function() hum.Health = lastMax end)
        end
    end)

    hum:GetPropertyChangedSignal("MaxHealth"):Connect(function()
        lastMax = hum.MaxHealth
    end)

    -- also re-apply on respawn
    hum.Died:Connect(function()
        -- nothing; respawn handler will reattach
    end)
end

if LocalPlayer.Character then
    watchCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(watchCharacter)

-- ============================================================
-- PUSH OUT OF HITBOXES (positional fallback)
-- ============================================================
task.spawn(function()
    local hrp, hum
    local function refresh()
        local c = LocalPlayer.Character
        if c then
            hrp = c:FindFirstChild("HumanoidRootPart")
            hum = c:FindFirstChildOfClass("Humanoid")
        end
    end
    LocalPlayer.CharacterAdded:Connect(function() task.wait(0.2); refresh() end)
    refresh()

    RunService.Heartbeat:Connect(function()
        if not hrp or not hrp.Parent then refresh() return end
        if not hum or hum.Health <= 0 then return end

        local guardFolder = Workspace:FindFirstChild("World")
        if not guardFolder then return end
        local areas = guardFolder:FindFirstChild("Areas")
        if not areas then return end
        local guardAreas = areas:FindFirstChild("GuardAreas")
        if not guardAreas then return end

        for _, inst in ipairs(guardAreas:GetDescendants()) do
            if inst:IsA("BasePart") and nameMatchesHit(inst.Name) then
                local delta = hrp.Position - inst.Position
                local dist  = delta.Magnitude
                if dist < 10 then
                    local push = (dist > 0.01 and delta.Unit or Vector3.new(0,1,0))
                    hrp.CFrame = hrp.CFrame + push * 6
                end
            end
        end
    end)
end)

-- ============================================================
-- ORIGINAL START()
-- ============================================================
function v4.Start()
    local v5 = GuardTutorialController.new()
    task.spawn(function() v5:Start() end)

    local v6 = true
    local v7 = -1
    local World = Workspace:WaitForChild("World")
    assert(World:IsA("Folder"), "Workspace.World must be a Folder")
    local Areas = World:WaitForChild("Areas")
    assert(Areas:IsA("Folder"), "Workspace.World.Areas must be a Folder")
    local GuardAreas = Areas:WaitForChild("GuardAreas")
    assert(GuardAreas:IsA("Folder"), "Workspace.World.Areas.GuardAreas must be a Folder")

    local function applyGuardsEnabled(v8, v9)
        if v9 < v7 then return end
        v6 = v8
        v7 = v9
        for _, v11 in pairs(v2) do
            if v11 and v11.ForestRuntime then
                v11.ForestRuntime:SetEnabled(v8)
            end
        end
    end

    local function setupAreaModel(v12)
        if v1[v12] == nil then
            v1[v12] = GuardEscapeSignController.new(v12)
        end
        if v2[v12] == nil then
            local v13, v14
            if v12.Name == "Forest" then
                v14 = ForestGuardRuntime.new(v12)
                v13 = GuardComponent.new(v12)
                v14:SetWakeHandler(function() v13:PlayWakeUp() end)
            else
                v13 = GuardComponent.new(v12)
            end

            -- ANTI-HIT: neutralise the guard's model
            pcall(function()
                disableGuardAttacks(v13:GetGuardModel())
            end)

            if v12.Parent == GuardAreas then
                v2[v12] = { ForestRuntime = v14, Guard = v13 }
                v3[v13:GetGuardModel()] = v13
                if v14 ~= nil then
                    v14:SetEnabled(v6)
                    v14:Start()
                end
            else
                v13:Destroy()
                if v14 ~= nil then v14:Destroy() end
            end
        end
    end

    local function cleanupAreaModel(v17)
        local v18 = v1[v17]
        if v18 ~= nil then
            v1[v17] = nil
            v18:Destroy()
        end
        local v19 = v2[v17]
        if v19 == nil then return end
        v2[v17] = nil
        v3[v19.Guard:GetGuardModel()] = nil

        local gm = v19.Guard:GetGuardModel()
        if gm and guardDamageConnections[gm] then
            pcall(function() guardDamageConnections[gm]:Disconnect() end)
            guardDamageConnections[gm] = nil
        end

        v19.Guard:Destroy()
        if v19.ForestRuntime ~= nil then v19.ForestRuntime:Destroy() end
    end

    GuardAreas.ChildAdded:Connect(function(v20)
        assert(v20:IsA("Model"),
            ("%* must be a guard area Model"):format(v20:GetFullName()))
        setupAreaModel(v20)
    end)

    GuardAreas.ChildRemoved:Connect(function(v22)
        assert(v22:IsA("Model"),
            ("%* must be a guard area Model"):format(v22:GetFullName()))
        cleanupAreaModel(v22)
    end)

    for _, v25 in ipairs(GuardAreas:GetChildren()) do
        assert(v25:IsA("Model"),
            ("%* must be a guard area Model"):format(v25:GetFullName()))
        task.spawn(setupAreaModel, v25)
    end

    Remotes.GuardPatrol.Rouse.OnClientEvent:Connect(function(v27)
        local v28 = v3[v27]
        if v28 ~= nil then v28:PlayWakeUp() end
    end)

    Remotes.GuardPatrol.EnabledShifted.OnClientEvent:Connect(applyGuardsEnabled)

    task.spawn(function()
        local v29, v30
        while true do
            if v7 < 0 then
                local v31
                v31, v29, v30 = Promise.try(function()
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
