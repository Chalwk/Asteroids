-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Powerup = {}
Powerup.__index = Powerup

local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin = math.sin

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
    local screenWidth, screenHeight = love.graphics.getDimensions()
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

function Powerup:update(dt, player)
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]
        powerup.x = powerup.x + powerup.vx * dt
        powerup.y = powerup.y + powerup.vy * dt
        powerup.rotation = powerup.rotation + dt
        powerup.life = powerup.life - dt

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
                player.health = math.min(player.maxHealth, player.health + 50)
            end
            returnToPool(powerupPool, powerup)
            remove(self.powerups, i)
            return true
        end
    end
    return false
end

function Powerup:checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    local dx, dy = b.x - a.x, b.y - a.y
    return dx * dx + dy * dy < minDist * minDist
end

function Powerup:draw(time)
    for _, powerup in ipairs(self.powerups) do
        lg.push()
        lg.translate(powerup.x, powerup.y)
        lg.rotate(powerup.rotation)

        local pulse = 1 + 0.08 * sin(time * 6 + powerup.x * 0.01)

        if powerup.type == "boost" then
            lg.setBlendMode("add")
            lg.setColor(0.15, 0.55, 1, 0.65)
            lg.rectangle("fill", -powerup.size * 0.5 * pulse, -powerup.size * 0.5 * pulse, powerup.size * pulse,
                powerup.size * pulse, 4)
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
            lg.setBlendMode("add")
            lg.setColor(1, 0.35, 0.35, 0.6)
            lg.polygon("fill",
                -powerup.size * 0.5 * pulse,
                -powerup.size * 0.5 * pulse, powerup.size * 0.5 * pulse,
                0,
                -powerup.size * 0.5 * pulse,
                powerup.size * 0.5 * pulse
            )
            lg.setBlendMode("alpha")
            lg.setColor(1, 0.3, 0.3)
            lg.polygon("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size * 0.5, 0, -powerup.size * 0.5,
                powerup.size * 0.5)
        elseif powerup.type == "health" then
            lg.setBlendMode("add")
            lg.setColor(1, 0.2, 0.2, 0.65)
            lg.circle("fill", 0, 0, powerup.size * 0.8 * pulse)
            lg.setBlendMode("alpha")
            lg.setColor(1, 0.3, 0.3)
            lg.circle("line", 0, 0, powerup.size * 0.8)
            -- Plus sign inside
            lg.setColor(1, 1, 1, 0.9)
            lg.setLineWidth(3)
            lg.line(-powerup.size * 0.3, 0, powerup.size * 0.3, 0)
            lg.line(0, -powerup.size * 0.3, 0, powerup.size * 0.3)
            lg.setLineWidth(1)
        end

        lg.setColor(1, 1, 1, 0.9)
        lg.pop()
    end
end

function Powerup:clear()
    for _, powerup in ipairs(self.powerups) do returnToPool(powerupPool, powerup) end
    self.powerups = {}
end

function Powerup:getCount() return #self.powerups end

return Powerup
