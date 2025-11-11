-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local sqrt = math.sqrt
local pairs, ipairs = pairs, ipairs
local insert, remove = table.insert, table.remove

local Bullet = {}
Bullet.__index = Bullet

local bulletPool = {}

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end
local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
end

function Bullet.new()
    local instance = setmetatable({}, Bullet)
    instance.bullets = {}
    return instance
end

function Bullet:create(x, y, vx, vy, life, size, enemy)
    local bullet = getFromPool(bulletPool)
    bullet.x = x
    bullet.y = y
    bullet.vx = vx
    bullet.vy = vy
    bullet.life = life
    bullet.maxLife = life
    bullet.size = size
    bullet.enemy = enemy

    -- Visual properties
    bullet.trail = {}
    bullet.trailTimer = 0
    bullet.pulse = 0
    bullet.spawnTime = love.timer.getTime()

    insert(self.bullets, bullet)
    return bullet
end

function Bullet:update(dt)
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]

        -- Store previous position for trail
        bullet.prevX = bullet.x
        bullet.prevY = bullet.y

        -- Update position
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        -- Update trail
        bullet.trailTimer = bullet.trailTimer + dt
        if bullet.trailTimer >= 0.02 then -- Add trail point every 20ms
            insert(bullet.trail, 1, { x = bullet.x, y = bullet.y, life = 0.3 })
            bullet.trailTimer = 0
        end

        -- Update trail points
        for j = #bullet.trail, 1, -1 do
            bullet.trail[j].life = bullet.trail[j].life - dt
            if bullet.trail[j].life <= 0 then
                remove(bullet.trail, j)
            end
        end

        -- Update pulse effect
        bullet.pulse = (bullet.pulse + dt * 8) % (math.pi * 2)

        -- Check if bullet should be removed
        if bullet.life <= 0 or
            bullet.x < -100 or bullet.x > screenWidth + 100 or
            bullet.y < -100 or bullet.y > screenHeight + 100 then
            returnToPool(bulletPool, bullet)
            remove(self.bullets, i)
        end
    end
end

function Bullet:draw()
    local currentTime = love.timer.getTime()

    for _, bullet in ipairs(self.bullets) do
        local age = currentTime - bullet.spawnTime
        local lifeRatio = bullet.life / bullet.maxLife

        -- Different colors for player vs enemy bullets
        local r, g, b
        if bullet.enemy then
            -- Enemy bullets: reddish
            r = 1.0
            g = 0.3 + 0.3 * math.sin(age * 10)
            b = 0.3
        else
            -- Player bullets: golden
            r = 1.0
            g = 0.8 + 0.2 * math.sin(age * 8)
            b = 0.2 + 0.3 * math.sin(age * 6)
        end

        -- Draw trail (only for high-velocity bullets)
        local speed = sqrt(bullet.vx * bullet.vx + bullet.vy * bullet.vy)
        if speed > 200 and #bullet.trail > 1 then
            lg.setBlendMode("add")
            for i = 1, #bullet.trail - 1 do
                local point = bullet.trail[i]
                local nextPoint = bullet.trail[i + 1]
                local alpha = (point.life / 0.3) * 0.4 * lifeRatio

                lg.setColor(r, g, b, alpha * 0.5)
                lg.setLineWidth(bullet.size * 0.5 * (i / #bullet.trail))
                lg.line(point.x, point.y, nextPoint.x, nextPoint.y)
            end
            lg.setBlendMode("alpha")
        end

        -- Pulse glow effect
        lg.setBlendMode("add")
        local pulseSize = 1.0 + 0.3 * math.sin(bullet.pulse)

        -- Outer glow
        lg.setColor(r, g, b, 0.3 * lifeRatio)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 3.0 * pulseSize)

        -- Middle glow
        lg.setColor(r, g, b, 0.6 * lifeRatio)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 2.0 * pulseSize)

        -- Inner core glow
        lg.setColor(r, g, b, 0.9 * lifeRatio)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 1.2)

        lg.setBlendMode("alpha")

        -- Bright core
        lg.setColor(1, 1, 0.9, lifeRatio)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 0.8)

        -- Highlight
        lg.setColor(1, 1, 1, 0.8 * lifeRatio)
        lg.circle("fill", bullet.x - bullet.size * 0.3, bullet.y - bullet.size * 0.3, bullet.size * 0.3)
    end
    lg.setLineWidth(1)
end

function Bullet:drawOptimized()
    if #self.bullets == 0 then return end
    self:draw()
end

function Bullet:getBullets() return self.bullets end

function Bullet:removeBullet(index)
    if self.bullets[index] then
        returnToPool(bulletPool, self.bullets[index])
        remove(self.bullets, index)
    end
end

function Bullet:clear()
    for _, bullet in ipairs(self.bullets) do returnToPool(bulletPool, bullet) end
    self.bullets = {}
end

-- Get bullets by type
function Bullet:getPlayerBullets()
    local playerBullets = {}
    for _, bullet in ipairs(self.bullets) do
        if not bullet.enemy then insert(playerBullets, bullet) end
    end
    return playerBullets
end

function Bullet:getEnemyBullets()
    local enemyBullets = {}
    for _, bullet in ipairs(self.bullets) do
        if bullet.enemy then insert(enemyBullets, bullet) end
    end
    return enemyBullets
end

return Bullet
