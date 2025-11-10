-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
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
    bullet.size = size
    bullet.enemy = enemy

    insert(self.bullets, bullet)
    return bullet
end

function Bullet:update(dt)
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        if bullet.life <= 0 or bullet.x < -50 or bullet.x > screenWidth + 50 or bullet.y < -50 or bullet.y > screenHeight + 50 then
            returnToPool(bulletPool, bullet)
            remove(self.bullets, i)
        end
    end
end

function Bullet:draw()
    for _, bullet in ipairs(self.bullets) do
        -- additive glow core
        lg.setBlendMode("add")
        lg.setColor(1, 0.9, 0.45, 0.8)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 2.2)
        lg.setColor(1, 0.85, 0.2, 0.6)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 1.1)
        lg.setBlendMode("alpha")

        -- crisp core
        lg.setColor(1, 0.95, 0.7)
        lg.circle("fill", bullet.x, bullet.y, bullet.size)
        lg.setColor(1, 0.8, 0.15)
        lg.circle("line", bullet.x, bullet.y, bullet.size)
    end
    lg.setLineWidth(1)
    lg.setBlendMode("alpha")
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

return Bullet