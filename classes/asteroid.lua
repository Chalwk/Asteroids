-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Asteroid = {}
Asteroid.__index = Asteroid

function Asteroid:new(x, y, size, vx, vy)
    local instance = setmetatable({}, Asteroid)
    instance.x = x
    instance.y = y
    instance.size = size or "large"
    instance.angle = love.math.random() * 2 * math.pi
    instance.rotationSpeed = (love.math.random() - 0.5) * 2
    instance.vx = vx or (love.math.random() - 0.5) * 50
    instance.vy = vy or (love.math.random() - 0.5) * 50

    -- Set properties based on size
    if instance.size == "large" then
        instance.radius = 30
        instance.vertices = instance:generateVertices(12, 25, 35)
    elseif instance.size == "medium" then
        instance.radius = 15
        instance.vertices = instance:generateVertices(8, 12, 18)
    else -- small
        instance.radius = 8
        instance.vertices = instance:generateVertices(6, 6, 10)
    end

    return instance
end

function Asteroid:generateVertices(count, minDist, maxDist)
    local vertices = {}
    local angleStep = 2 * math.pi / count

    for i = 1, count do
        local angle = (i - 1) * angleStep
        local distance = love.math.random(minDist, maxDist)
        local x = math.cos(angle) * distance
        local y = math.sin(angle) * distance
        table.insert(vertices, x)
        table.insert(vertices, y)
    end

    return vertices
end

function Asteroid:update(dt)
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt
    self.angle = self.angle + self.rotationSpeed * dt

    -- Wrap around screen
    self.x, self.y = wrapPosition(self.x, self.y)
end

function Asteroid:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)

    love.graphics.setColor(0.7, 0.7, 0.7)
    love.graphics.polygon("line", self.vertices)

    love.graphics.pop()
end

return Asteroid
