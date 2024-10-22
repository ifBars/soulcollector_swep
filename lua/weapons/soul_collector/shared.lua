if SERVER then
    AddCSLuaFile()
end

SWEP.PrintName = "Soul Collector"
SWEP.Author = "MrPPenguin"
SWEP.Instructions = "Left Click - Collect souls from recently deceased players\nRight click - Display soul sell location/Scan for souls"
SWEP.Spawnable = true
SWEP.AdminOnly = false
SWEP.Category = "PenguinRP"

SWEP.UseHands = true
SWEP.ViewModel = "models/weapons/c_bugbait.mdl"
SWEP.WorldModel = "models/weapons/w_bugbait.mdl"
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Secondary.Ammo = "none"

SWEP.SoulCollectRadius = 100

local deadPlayers = {}
local showSellPoint = false
local showSouls = false
local sellPointFadeTime = 0
local soulFadeTime = 0

-- Sounds
local collectSound = "ambient/levels/labs/electric_explosion1.wav" -- Replace with your sound path
local sellSound = "ambient/levels/labs/electric_explosion2.wav" -- Replace with your sound path

-- Particles
local collectParticle = "effects/energy_ball" -- Replace with your particle effect name
local sellParticle = "effects/energy_spark" -- Replace with your particle effect name

local sellZonePos = Vector(-10634.49, 7509.16, -2727.30)
local sellZoneRadius = 25

function SWEP:Initialize()
    self:SetHoldType("normal")
end

local soulImage = Material("materials/vgui/penguinrp_soul_icon.png")

-- Function to draw the image
local function DrawSoul()
    
end

-- Show nearby souls
function SWEP:DrawHUD()
    local ply = self:GetOwner()
    local pos = ply:GetPos()

    if showSouls then
        for _, data in pairs(deadPlayers) do
            local dist = pos:Distance(data.pos)
            if dist <= 1000 and CurTime() <= data.expire then -- Show souls within 1000 units
                local screenPos = data.pos:ToScreen()
                surface.SetDrawColor(255, 255, 255, 255)
                surface.SetMaterial(soulImage)
                local width, height = 64, 64 -- Change these values to your desired size
                surface.DrawTexturedRect(screenPos.x, screenPos.y, width, height)
            end
        end
    end

    -- Show sell point marker if active
    if showSellPoint then
        local screenSellPos = sellZonePos:ToScreen()
        draw.SimpleText("Soul Sell Point", "Trebuchet24", screenSellPos.x, screenSellPos.y, Color(0, 255, 0, 255), TEXT_ALIGN_CENTER)
    end
end

-- Primary attack to collect souls
function SWEP:PrimaryAttack()
    if CLIENT then return end

    local ply = self:GetOwner()
    local collected = false

    for k, data in pairs(deadPlayers) do
        local dist = ply:GetPos():Distance(data.pos)
        if dist <= self.SoulCollectRadius and CurTime() <= data.expire then
            collected = true
            ply:SetNWInt("collectedSouls", ply:GetNWInt("collectedSouls") + 1)
            table.remove(deadPlayers, k)

            net.Start("UpdateDeadPlayers")
            net.WriteTable(deadPlayers)
            net.Broadcast()

            -- Play collect sound and effect
            ply:EmitSound(collectSound)
            if CLIENT then
                local effectData = EffectData()
                effectData:SetOrigin(sellZonePos)
                util.Effect(collectParticle, effectData, true, true)
            end

            ply:ChatPrint("You have collected a soul!")
        end
    end

    if not collected then
        ply:ChatPrint("No souls nearby to collect.")
    end

    self:SetNextPrimaryFire(CurTime() + 1)
end

-- Secondary attack to mark sell point
function SWEP:SecondaryAttack()
    if CLIENT then
        showSellPoint = true
        sellPointFadeTime = CurTime() + 5
        showSouls = true
        soulFadeTime = CurTime() + 5
    end
end

-- Fade out the sell point marker after 5 seconds
hook.Add("Think", "FadeSellPointMarker", function()
    if showSellPoint and CurTime() > sellPointFadeTime then
        showSellPoint = false
    end
end)

-- Fade out the souls point marker after 5 seconds
hook.Add("Think", "FadeSoulPointMarker", function()
    if showSouls and CurTime() > soulFadeTime then
        showSouls = false
    end
end)

-- Store dead player souls
if SERVER then
    util.AddNetworkString("UpdateDeadPlayers")

    hook.Add("PlayerDeath", "TrackDeadPlayerSouls", function(victim, inflictor, attacker)
        local pos = victim:GetPos()
        local soulData = {pos = pos, expire = CurTime() + 120}
        
        table.insert(deadPlayers, soulData)
    
        -- Send updated dead players to all clients
        net.Start("UpdateDeadPlayers")
        net.WriteTable(deadPlayers)
        net.Broadcast()
    end)
end

if CLIENT then
    net.Receive("UpdateDeadPlayers", function()
        deadPlayers = net.ReadTable()
    end)
end

hook.Add("Think", "CheckPlayerInSellZone", function()
    for _, ply in ipairs(player.GetAll()) do
        local dist = ply:GetPos():Distance(sellZonePos)
        if dist <= sellZoneRadius and ply:GetNWInt("collectedSouls", 0) > 0 then
            local souls = ply:GetNWInt("collectedSouls")
            local reward = souls * 250
            if SERVER and ply.addMoney and souls > 0 then
                ply:addMoney(reward)
                ply:ChatPrint("You have sold your souls for $" .. reward .. "!")
            end
            ply:SetNWInt("collectedSouls", 0)

            ply:EmitSound(sellSound)
            if CLIENT then
                local effectData = EffectData()
                effectData:SetOrigin(sellZonePos)
                util.Effect(sellParticle, effectData, true, true)
            end
        end
    end
end)

-- Draw the soul selling zone
hook.Add("PostDrawOpaqueRenderables", "DrawSoulSellingZone", function()
    local ply = LocalPlayer()
    local jobTable = ply:getJobTable()

    if jobTable and jobTable.name == "Soul Collector" then
        render.DrawWireframeSphere(sellZonePos, sellZoneRadius, 20, 20, Color(255, 0, 0, 255), true)
    end
end)
