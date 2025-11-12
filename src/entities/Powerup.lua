-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local sin, cos, min = math.sin, math.cos, math.min
local pairs, ipairs = pairs, ipairs
local insert, remove = table.insert, table.remove

local powerupPool = {}

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end
local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
end

local function createPowerup(x, y)
    local types = { "boost", "shield", "rapid", "health" }
    return {
        x = x,
        y = y,
        vx = (random() - 0.5) * 50,
        vy = (random() - 0.5) * 50,
        type = types[random(1, 4)],
        size = 15,
        rotation = 0,
        life = 10
    }
end

local function wrapPosition(obj, size)
    size = size or obj.size
    if obj.x < -size then
        obj.x = screenWidth + size
    elseif obj.x > screenWidth + size then
        obj.x = -size
    end

    if obj.y < -size then
        obj.y = screenHeight + size
    elseif obj.y > screenHeight + size then
        obj.y = -size
    end
end

local Powerup = {}
Powerup.__index = Powerup

function Powerup.new()
    local instance = setmetatable({}, Powerup)
    instance.powerups = {}
    return instance
end

function Powerup:spawn(x, y)
    local powerup = getFromPool(powerupPool)
    local newPowerup = createPowerup(x, y)
    for k, v in pairs(newPowerup) do powerup[k] = v end
    insert(self.powerups, powerup)
    return powerup
end

function Powerup:checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    local dx, dy = b.x - a.x, b.y - a.y
    return dx * dx + dy * dy < minDist * minDist
end

function Powerup:update(dt, player)
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]
        powerup.x = powerup.x + powerup.vx * dt
        powerup.y = powerup.y + powerup.vy * dt + sin(love.timer.getTime() * 2 + powerup.x) * dt * 5
        powerup.life = powerup.life - dt

        if powerup.type == "boost" then
            powerup.rotation = powerup.rotation + dt * 3
        elseif powerup.type == "shield" then
            powerup.rotation = powerup.rotation + dt * 1.2
        elseif powerup.type == "rapid" then
            powerup.rotation = powerup.rotation - dt * 4
        elseif powerup.type == "health" then
            powerup.rotation = powerup.rotation + dt * 2
        else
            powerup.rotation = powerup.rotation + dt
        end

        wrapPosition(powerup)

        if powerup.life <= 0 then
            returnToPool(powerupPool, powerup)
            remove(self.powerups, i)
        elseif self:checkCollision(player, powerup) then
            if powerup.type == "boost" then
                player.boostTime = player.maxBoostTime
                player.boostCooldown = 0
            elseif powerup.type == "shield" then
                player.invulnerable = 5
            elseif powerup.type == "rapid" then
                player.shootCooldown = 0.1
            elseif powerup.type == "health" then
                player.health = min(player.maxHealth, player.health + 50)
            end
            returnToPool(powerupPool, powerup)
            remove(self.powerups, i)
            return true
        end
    end
    return false
end

function Powerup:draw(time)
    for _, powerup in ipairs(self.powerups) do
        lg.push()
        lg.translate(powerup.x, powerup.y)
        lg.rotate(powerup.rotation)

        local pulse = 1 + 0.1 * sin(time * 4 + powerup.x * 0.02)
        local glowPulse = 1 + 0.15 * sin(time * 3 + powerup.y * 0.02)

        -- Outer glow
        lg.setBlendMode("add")
        if powerup.type == "boost" then
            lg.setColor(0.3, 0.7, 1, 0.3)
        elseif powerup.type == "shield" then
            lg.setColor(0.2, 1, 0.6, 0.3)
        elseif powerup.type == "rapid" then
            lg.setColor(1, 0.5, 0.5, 0.3)
        elseif powerup.type == "health" then
            lg.setColor(1, 0.3, 0.3, 0.3)
        end
        lg.circle("fill", 0, 0, powerup.size * 1.5 * glowPulse)
        lg.setBlendMode("alpha")

        -- Sparkles orbiting the powerup
        for j = 1, 3 do
            local angle = time * (1 + j * 0.5) + powerup.x * 0.01
            local r = powerup.size * 0.9 + 3 * sin(time * 5 + j)
            local px = r * cos(angle)
            local py = r * sin(angle)
            lg.setColor(1, 1, 1, 0.6 + 0.4 * sin(time * 10 + j))
            lg.points(px, py)
        end

        -- Main shape
        if powerup.type == "boost" then
            lg.setBlendMode("add")
            lg.setColor(0.15, 0.55, 1, 0.65)
            lg.rectangle("fill", -powerup.size * 0.5 * pulse, -powerup.size * 0.5 * pulse,
                powerup.size * pulse, powerup.size * pulse, 4)
            lg.setBlendMode("alpha")
            lg.setColor(0.2, 0.6, 1)
            lg.rectangle("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size, powerup.size, 3)
        elseif powerup.type == "shield" then
            lg.setBlendMode("add")
            lg.setColor(0.12, 1, 0.45, 0.55)
            lg.circle("fill", 0, 0, powerup.size * pulse)
            lg.setBlendMode("alpha")
            lg.setColor(0.12, 1, 0.45)
            lg.circle("line", 0, 0, powerup.size)
        elseif powerup.type == "rapid" then
            -- Comet-like shape
            lg.setBlendMode("add")
            lg.setColor(1, 0.35, 0.35, 0.6)
            lg.ellipse("fill", -powerup.size * 0.2, 0, powerup.size * 0.8 * pulse, powerup.size * 0.4)
            lg.setBlendMode("alpha")
            lg.setColor(1, 0.3, 0.3)
            lg.polygon("line", -powerup.size * 0.5, -powerup.size * 0.5,
                powerup.size * 0.5, 0, -powerup.size * 0.5, powerup.size * 0.5)
        elseif powerup.type == "health" then
            lg.setBlendMode("add")
            lg.setColor(1, 0.2, 0.2, 0.65)
            lg.circle("fill", 0, 0, powerup.size * 0.8 * pulse)
            lg.setBlendMode("alpha")
            lg.setColor(1, 0.3, 0.3)
            lg.circle("line", 0, 0, powerup.size * 0.8)
            lg.setColor(1, 1, 1, 0.9)
            lg.setLineWidth(3)
            lg.line(-powerup.size * 0.3, 0, powerup.size * 0.3, 0)
            lg.line(0, -powerup.size * 0.3, 0, powerup.size * 0.3)
            lg.setLineWidth(1)
        end

        lg.pop()
    end
end

function Powerup:clear()
    for _, powerup in ipairs(self.powerups) do returnToPool(powerupPool, powerup) end
    self.powerups = {}
end

function Powerup:getCount() return #self.powerups end

return Powerup
