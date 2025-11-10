-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, cos, pi = math.sin, math.cos, math.pi

local Asteroid = {}
Asteroid.__index = Asteroid

local TWO_PI = pi * 2

local asteroidPool = {}

local function getFromPool() return #asteroidPool > 0 and remove(asteroidPool) or {} end

local function returnToPool(obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(asteroidPool, obj)
end

local function generateAsteroidShape(asteroid)
    local vertices = {}
    local numPoints = random(8, 12)

    for i = 1, numPoints do
        local angle = (i / numPoints) * TWO_PI
        local distance = asteroid.size * (0.7 + random() * 0.3)
        insert(vertices, cos(angle) * distance)
        insert(vertices, sin(angle) * distance)
    end

    asteroid.vertices = vertices
end

function Asteroid.new(screenWidth, screenHeight)
    local instance = setmetatable({}, Asteroid)

    instance.screenWidth = screenWidth
    instance.screenHeight = screenHeight
    instance.asteroids = {}

    return instance
end

function Asteroid:createAsteroid(x, y, size, level)
    local speed = random(50, 150) / (level or 1)
    local angle = random() * TWO_PI

    local asteroid = {
        x = x or random(0, self.screenWidth),
        y = y or random(0, self.screenHeight),
        vx = cos(angle) * speed,
        vy = sin(angle) * speed,
        size = size or random(30, 80),
        rotation = random() * TWO_PI,
        rotationSpeed = (random() - 0.5) * 2,
        level = level or 1,
        vertices = {}
    }

    generateAsteroidShape(asteroid)
    return asteroid
end

function Asteroid:spawn(count, level, playerX, playerY)
    for _ = 1, count do
        local asteroid = getFromPool()
        local newAsteroid = self:createAsteroid(nil, nil, nil, level)
        for k, v in pairs(newAsteroid) do asteroid[k] = v end

        -- Ensure asteroids spawn away from player
        local minDistSq = 150 * 150
        while self:distanceSquared(asteroid.x, asteroid.y, playerX, playerY) < minDistSq do
            asteroid.x = random(0, self.screenWidth)
            asteroid.y = random(0, self.screenHeight)
        end

        generateAsteroidShape(asteroid)
        insert(self.asteroids, asteroid)
    end
end

function Asteroid:distanceSquared(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end

function Asteroid:wrapPosition(obj, size)
    size = size or obj.size
    if obj.x < -size then
        obj.x = self.screenWidth + size
    elseif obj.x > self.screenWidth + size then
        obj.x = -size
    end

    if obj.y < -size then
        obj.y = self.screenHeight + size
    elseif obj.y > self.screenHeight + size then
        obj.y = -size
    end
end

function Asteroid:update(dt, player)
    for i = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[i]
        asteroid.x = asteroid.x + asteroid.vx * dt
        asteroid.y = asteroid.y + asteroid.vy * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
        self:wrapPosition(asteroid)

        if player.invulnerable <= 0 and self:checkCollision(player, asteroid) then
            player.lives = player.lives - 1
            player.invulnerable = 2
            return true -- collision occurred
        end
    end
    return false -- no collision
end

function Asteroid:checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    return self:distanceSquared(a.x, a.y, b.x, b.y) < minDist * minDist
end

function Asteroid:draw()
    for _, asteroid in ipairs(self.asteroids) do
        lg.push()
        lg.translate(asteroid.x, asteroid.y)
        lg.rotate(asteroid.rotation)

        -- Fill base
        lg.setColor(0.48, 0.44, 0.38, 0.9)
        lg.polygon("fill", asteroid.vertices)

        -- Subtle inner shadow: smaller scaled polygon in multiply-ish effect
        lg.setColor(0, 0, 0, 0.08)
        local darkVerts = {}
        for i = 1, #asteroid.vertices, 2 do
            local vx, vy = asteroid.vertices[i] * 0.86, asteroid.vertices[i + 1] * 0.86
            insert(darkVerts, vx - 2)
            insert(darkVerts, vy + 2)
        end
        lg.polygon("fill", darkVerts)

        -- Outline
        lg.setColor(0.2, 0.18, 0.16)
        lg.setLineWidth(2)
        lg.polygon("line", asteroid.vertices)

        lg.pop()
    end
    lg.setLineWidth(1)
end

function Asteroid:getAsteroids() return self.asteroids end

function Asteroid:removeAsteroid(index)
    local asteroid = self.asteroids[index]
    if asteroid then
        returnToPool(asteroid)
        remove(self.asteroids, index)
    end
end

function Asteroid:clearAll()
    for _, asteroid in ipairs(self.asteroids) do returnToPool(asteroid) end
    self.asteroids = {}
end

function Asteroid:isEmpty() return #self.asteroids == 0 end

return Asteroid
