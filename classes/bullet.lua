-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Bullet = {}
Bullet.__index = Bullet

function Bullet:new(x, y, vx, vy, isPlayer)
    local instance = setmetatable({}, Bullet)
    instance.x = x
    instance.y = y
    instance.vx = vx
    instance.vy = vy
    instance.life = 2 -- seconds
    instance.isPlayer = isPlayer or false

    return instance
end

function Bullet:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.life = self.life - dt

    -- Wrap around screen
    self.x, self.y = wrapPosition(self.x, self.y)
end

function Bullet:draw()
    if self.isPlayer then
        love.graphics.setColor(1, 1, 0) -- Yellow for player bullets
    else
        love.graphics.setColor(1, 0, 0) -- Red for alien bullets
    end
    love.graphics.circle("fill", self.x, self.y, 2)
end

return Bullet
