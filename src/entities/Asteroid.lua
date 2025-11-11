-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local pairs, ipairs = pairs, ipairs
local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, cos, pi = math.sin, math.cos, math.pi

local Asteroid = {}
Asteroid.__index = Asteroid

local TWO_PI = pi * 2

local asteroidPool = {}
local particlePool = {}

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end

local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
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

function Asteroid.new(soundManager)
    local instance = setmetatable({}, Asteroid)

    instance.asteroids = {}
    instance.particles = {}
    instance.soundManager = soundManager

    return instance
end

function Asteroid:createAsteroid(x, y, size, level)
    local speed = random(50, 150) / (level or 1)
    local angle = random() * TWO_PI

    local asteroid = {
        x = x or random(0, screenWidth),
        y = y or random(0, screenHeight),
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

function Asteroid:createDustParticles(x, y, size, count)
    for _ = 1, count do
        local particle = getFromPool(particlePool)

        local angle = random() * TWO_PI
        local speed = random(20, 80)
        local life = random(0.3, 0.8)

        particle.x = x
        particle.y = y
        particle.vx = cos(angle) * speed
        particle.vy = sin(angle) * speed
        particle.life = life
        particle.maxLife = life
        particle.size = random(size * 0.1, size * 0.3)
        particle.rotation = random() * TWO_PI
        particle.rotationSpeed = (random() - 0.5) * 5
        particle.color = {
            0.48 + random(-0.1, 0.1),
            0.44 + random(-0.1, 0.1),
            0.38 + random(-0.1, 0.1)
        }

        insert(self.particles, particle)
    end
end

function Asteroid:spawn(count, level, playerX, playerY)
    for _ = 1, count do
        local asteroid = getFromPool(asteroidPool)
        local newAsteroid = self:createAsteroid(nil, nil, nil, level)
        for k, v in pairs(newAsteroid) do asteroid[k] = v end

        -- Ensure asteroids spawn away from player
        local minDistSq = 150 * 150
        while self:distanceSquared(asteroid.x, asteroid.y, playerX, playerY) < minDistSq do
            asteroid.x = random(0, screenWidth)
            asteroid.y = random(0, screenHeight)
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

function Asteroid:update(dt, player)
    -- Update asteroids
    for i = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[i]
        asteroid.x = asteroid.x + asteroid.vx * dt
        asteroid.y = asteroid.y + asteroid.vy * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
        self:wrapPosition(asteroid)

        if player.invulnerable <= 0 and self:checkCollision(player, asteroid) then
            player.lives = player.lives - 1
            player.invulnerable = 2
            --self.soundManager:play("asteroid_crash")
            return true -- collision occurred
        end
    end

    -- Update particles
    for i = #self.particles, 1, -1 do
        local particle = self.particles[i]
        particle.x = particle.x + particle.vx * dt
        particle.y = particle.y + particle.vy * dt
        particle.rotation = particle.rotation + particle.rotationSpeed * dt
        particle.life = particle.life - dt

        if particle.life <= 0 then
            returnToPool(particlePool, particle)
            remove(self.particles, i)
        end
    end

    return false -- no collision
end

function Asteroid:checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    return self:distanceSquared(a.x, a.y, b.x, b.y) < minDist * minDist
end

function Asteroid:draw()
    -- Draw particles first (so they appear behind asteroids)
    for _, particle in ipairs(self.particles) do
        local alpha = particle.life / particle.maxLife
        lg.push()
        lg.translate(particle.x, particle.y)
        lg.rotate(particle.rotation)

        -- Dust particle as a faded, rotating rectangle
        lg.setColor(particle.color[1], particle.color[2], particle.color[3], alpha * 0.6)
        lg.rectangle("fill", -particle.size * 0.5, -particle.size * 0.5, particle.size, particle.size)

        -- Subtle glow for smaller particles
        if particle.size < 4 then
            lg.setColor(1, 1, 1, alpha * 0.3)
            lg.rectangle("fill", -particle.size * 0.3, -particle.size * 0.3, particle.size * 0.6, particle.size * 0.6)
        end

        lg.pop()
    end

    -- Draw asteroids
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
        -- Create dust particles when asteroid is destroyed
        self:createDustParticles(asteroid.x, asteroid.y, asteroid.size, random(8, 15))

        returnToPool(asteroidPool, asteroid)
        remove(self.asteroids, index)
    end
end

function Asteroid:clearAll()
    for _, asteroid in ipairs(self.asteroids) do returnToPool(asteroidPool, asteroid) end
    for _, particle in ipairs(self.particles) do returnToPool(particlePool, particle) end
    self.asteroids = {}
    self.particles = {}
end

function Asteroid:isEmpty() return #self.asteroids == 0 end

return Asteroid
