-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local CONFIG = {
    nebula = {
        maxCount = 2,
        spawnInterval = 45,
        slowFactorMin = 0.6,
        slowFactorMax = 0.85,
        colors = {
            { 0.5, 0.3, 0.8 },
            { 0.7, 0.5, 0.9 },
            { 0.3, 0.2, 0.6 }
        }
    },
    blackhole = {
        maxCount = 1,
        spawnInterval = 120,
        pullMultiplier = 2.5,
        speedReductionFactor = 0.15
    },
    starField = {
        count = 500
    },
    visual = {
        distortionMax = 1,
        distortionScale = 0.05
    }
}

local lg = love.graphics
local random = love.math.random
local noise = love.math.noise

local ipairs = ipairs
local pi = math.pi
local sin, cos = math.sin, math.cos
local min, max = math.min, math.max
local atan2, sqrt = math.atan2, math.sqrt
local insert, remove = table.insert, table.remove

local function nebulaNoiseOffset(x, y, time, scale, magnitude)
    local nx = x + (noise(x * scale, y * scale, time * 0.1) - 0.5) * magnitude
    local ny = y + (noise(y * scale, x * scale, time * 0.1) - 0.5) * magnitude
    return nx, ny
end

local function drawNebula(nebula, time)
    lg.push()
    lg.setBlendMode("add")

    local pulse = 0.8 + 0.2 * sin(time * 1.5 + nebula.pulse)

    -- Soft, cloud-like blobs
    for _, c in ipairs(CONFIG.nebula.colors) do
        for _ = 1, 5 do
            local radius = nebula.radius * (0.4 + random() * 0.6)
            local offsetX = (random() - 0.5) * nebula.radius * 0.5
            local offsetY = (random() - 0.5) * nebula.radius * 0.5
            local alpha = 0.05 * nebula.density * (0.6 + random() * 0.4) * pulse
            lg.setColor(c[1], c[2], c[3], alpha)

            -- Perlin noise drift
            local nx, ny = nebulaNoiseOffset(nebula.x + offsetX, nebula.y + offsetY, time, 0.01, 50)
            lg.circle("fill", nx, ny, radius)
        end
    end

    -- Subtle swirling blobs for motion
    for i = 1, 12 do
        local angle = nebula.rotation + i * (2 * pi / 12)
        local length = nebula.radius * (0.3 + random() * 0.7)
        local offset = length * (0.5 + 0.5 * sin(time + nebula.pulse))
        lg.setColor(0.6, 0.3, 0.8, 0.1 * nebula.density)
        local nx, ny = nebulaNoiseOffset(nebula.x + cos(angle) * offset, nebula.y + sin(angle) * offset, time, 0.02, 20)
        lg.circle("fill", nx, ny, length * 0.2)
    end

    lg.setBlendMode("alpha")
    lg.pop()
end


local function createStarField(self)
    self.stars = {}
    for i = 1, CONFIG.starField.count do
        local layer = (i % 3) + 1
        self.stars[i] = {
            x = random(0, screenWidth),
            y = random(0, screenHeight),
            layer = layer,
            size = layer == 1 and random(0.8, 1.2)
                or layer == 2 and random(1.2, 2.0)
                or random(2.0, 3.0),
            brightness = layer == 1 and random(0.1, 0.3)
                or layer == 2 and random(0.3, 0.6)
                or random(0.6, 1.0),
            twinkle = random() * 2
        }
    end
end

local function updateStarField(self, dt, player)
    local scrollSpeed = player.speed * dt
    local moveX = sin(player.angle) * scrollSpeed
    local moveY = -cos(player.angle) * scrollSpeed

    for _, star in ipairs(self.stars) do
        local factor = star.layer == 1 and 0.15 or star.layer == 2 and 0.4 or 0.8
        star.x = star.x - moveX * factor
        star.y = star.y - moveY * factor

        if star.x < 0 then star.x = star.x + screenWidth end
        if star.x > screenWidth then star.x = star.x - screenWidth end
        if star.y < 0 then star.y = star.y + screenHeight end
        if star.y > screenHeight then star.y = star.y - screenHeight end
    end
end

local function drawStarField(self, time, fogFactor)
    lg.setColor(0.02, 0.04, 0.08, 0.22)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    for _, star in ipairs(self.stars) do
        local tw = star.brightness * (0.6 + 0.4 * sin(time * (0.6 + star.twinkle)))
        local px, py = star.x, star.y

        local visibility = 1 - (fogFactor or 0)
        if visibility < 0.1 then visibility = 0.1 end

        if star.size > 2.2 then
            lg.setBlendMode("add")
            lg.setColor(1, 1, 1, 0.06 * tw * visibility)
            lg.circle("fill", px, py, star.size * 3.2)
            lg.setColor(1, 1, 1, 0.12 * tw * visibility)
            lg.circle("fill", px, py, star.size * 1.8)
            lg.setBlendMode("alpha")
        end

        lg.setColor(1, 1, 1, 0.6 * tw * visibility)
        lg.circle("fill", px, py, star.size)
    end
    lg.setBlendMode("alpha")
end

local function createNebula()
    local side = random(1, 4)
    local x, y, vx, vy
    local speed = random(20, 40)
    local angle = random() * pi * 2

    if side == 1 then
        x = random(0, screenWidth)
        y = -100
    elseif side == 2 then
        x = screenWidth + 100
        y = random(0, screenHeight)
    elseif side == 3 then
        x = random(0, screenWidth)
        y = screenHeight + 100
    else
        x = -100
        y = random(0, screenHeight)
    end

    vx = cos(angle) * speed
    vy = sin(angle) * speed

    local nebula = {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        radius = random(120, 200),
        density = random(0.6, 0.9),
        slowFactor = random(CONFIG.nebula.slowFactorMin, CONFIG.nebula.slowFactorMax),
        rotation = random() * pi * 2,
        rotationSpeed = (random() - 0.5) * 0.5,
        life = random(25, 40),
        pulse = random() * pi * 2,
        innerRadius = random(40, 80)
    }

    return nebula
end

local function createBlackhole()
    local minDistFromCenter = 200
    local angle = random() * pi * 2
    local distance = minDistFromCenter + random(100, 300)

    local x = screenWidth * 0.5 + cos(angle) * distance
    local y = screenHeight * 0.5 + sin(angle) * distance

    local blackhole = {
        x = x,
        y = y,
        radius = random(60, 100),
        pullStrength = random(2000, 3000),
        eventHorizon = random(25, 40),
        rotation = random() * pi * 2,
        rotationSpeed = (random() - 0.5) * 1.5,
        life = random(15, 25),
        pulse = random() * pi * 2,
        accretionDisk = {}
    }

    for _ = 1, 30 do
        local diskAngle = random() * pi * 2
        local diskRadius = blackhole.eventHorizon + random(10, blackhole.radius - 10)
        local diskSpeed = (blackhole.radius / diskRadius) * 2
        insert(blackhole.accretionDisk, {
            angle = diskAngle,
            radius = diskRadius,
            speed = diskSpeed,
            size = random(2, 5),
            brightness = random(0.6, 1.0)
        })
    end
    return blackhole
end

local Environment = {}
Environment.__index = Environment

function Environment.new(soundManager)
    local instance = setmetatable({}, Environment)
    instance.nebulas = {}
    instance.blackholes = {}
    instance.stars = {}
    instance.soundManager = soundManager
    instance.nebulaSpawnTimer = 0
    instance.blackholeSpawnTimer = 0
    instance.nebulaSpawnInterval = CONFIG.nebula.spawnInterval
    instance.blackholeSpawnInterval = CONFIG.blackhole.spawnInterval
    instance.visualDistortion = 0
    createStarField(instance)
    return instance
end

function Environment:update(dt, player, asteroids, enemies)
    updateStarField(self, dt, player)

    self.nebulaSpawnTimer = self.nebulaSpawnTimer - dt
    self.blackholeSpawnTimer = self.blackholeSpawnTimer - dt

    if self.nebulaSpawnTimer <= 0 and #self.nebulas < CONFIG.nebula.maxCount then
        insert(self.nebulas, createNebula())
        self.nebulaSpawnTimer = CONFIG.nebula.spawnInterval + random(-10, 10)
    end

    if self.blackholeSpawnTimer <= 0 and #self.blackholes < CONFIG.blackhole.maxCount then
        insert(self.blackholes, createBlackhole())
        self.blackholeSpawnTimer = CONFIG.blackhole.spawnInterval + random(-20, 20)
    end

    local fogFactor = 0
    local fadeSpeed = 0.5 -- alpha reduction per second

    -- Update nebulas
    for i = #self.nebulas, 1, -1 do
        local nebula = self.nebulas[i]

        nebula.x = nebula.x + nebula.vx * dt
        nebula.y = nebula.y + nebula.vy * dt
        nebula.rotation = nebula.rotation + nebula.rotationSpeed * dt
        nebula.pulse = nebula.pulse + dt * 2
        nebula.life = nebula.life - dt

        -- Affect player
        local dx, dy = player.x - nebula.x, player.y - nebula.y
        local distance = sqrt(dx * dx + dy * dy)
        if distance < nebula.radius then
            local slowIntensity = 1 - (distance / nebula.radius)
            local currentSlow = nebula.slowFactor * slowIntensity
            player.speed = player.speed - player.speed * currentSlow * dt * 2

            local inside = 1 - (distance / nebula.radius)
            fogFactor = max(fogFactor, inside * nebula.density)
            --self.soundManager:setGlobalMuffle(fogFactor)
        end

        -- Fade out if life ended
        if nebula.life <= 0 then
            nebula.alpha = (nebula.alpha or 1) - fadeSpeed * dt
            if nebula.alpha <= 0 then remove(self.nebulas, i) end
        end

        -- Remove if out of bounds
        if nebula.x < -nebula.radius * 2 or nebula.x > screenWidth + nebula.radius * 2 or
            nebula.y < -nebula.radius * 2 or nebula.y > screenHeight + nebula.radius * 2 then
            remove(self.nebulas, i)
        end
    end

    -- Update black holes
    for i = #self.blackholes, 1, -1 do
        local blackhole = self.blackholes[i]

        blackhole.rotation = blackhole.rotation + blackhole.rotationSpeed * dt
        blackhole.pulse = blackhole.pulse + dt * 3
        blackhole.life = blackhole.life - dt

        for _, particle in ipairs(blackhole.accretionDisk) do
            particle.angle = particle.angle + particle.speed * dt
        end

        local dx, dy = player.x - blackhole.x, player.y - blackhole.y
        local distance = sqrt(dx * dx + dy * dy)
        local influenceRange = blackhole.radius * 5

        if distance < influenceRange then
            local pullIntensity = 1 - (distance / influenceRange)

            local pullForce = (blackhole.pullStrength * pullIntensity * CONFIG.blackhole.pullMultiplier) / (distance + 1)
            local angle = atan2(dy, dx)
            local maxPullThisFrame = 200 * dt
            local pullX = cos(angle) * min(pullForce * dt, maxPullThisFrame)
            local pullY = sin(angle) * min(pullForce * dt, maxPullThisFrame)
            player.x = player.x - pullX
            player.y = player.y - pullY

            local slowFactor = 1 - pullIntensity * CONFIG.blackhole.speedReductionFactor
            player.speed = player.speed * slowFactor

            self.visualDistortion = min(CONFIG.visual.distortionMax, pullIntensity)

            if distance < blackhole.eventHorizon and player.invulnerable <= 0 then
                player.lives = 0
                player.health = 0
                remove(self.blackholes, i)
                return true
            end
        else
            self.visualDistortion = max(0, self.visualDistortion - dt * 2)
        end

        -- Pull asteroids and enemies
        for j = #asteroids, 1, -1 do
            local asteroid = asteroids[j]
            local astDx, astDy = asteroid.x - blackhole.x, asteroid.y - blackhole.y
            local astDistance = sqrt(astDx * astDx + astDy * astDy)
            local astInfluenceRange = blackhole.radius * 5
            if astDistance < astInfluenceRange then
                local astPullIntensity = 1 - (astDistance / astInfluenceRange)
                local astPullForce = (blackhole.pullStrength * 0.5 * astPullIntensity) / (astDistance + 1)
                local astAngle = atan2(astDy, astDx)
                asteroid.x = asteroid.x - cos(astAngle) * astPullForce * dt
                asteroid.y = asteroid.y - sin(astAngle) * astPullForce * dt
                asteroid.vx = asteroid.vx - cos(astAngle) * astPullForce * dt * 0.1
                asteroid.vy = asteroid.vy - sin(astAngle) * astPullForce * dt * 0.1
                if astDistance < blackhole.eventHorizon then remove(asteroids, j) end
            end
        end

        for j = #enemies, 1, -1 do
            local enemy = enemies[j]
            local enDx, enDy = enemy.x - blackhole.x, enemy.y - blackhole.y
            local enDistance = sqrt(enDx * enDx + enDy * enDy)
            local enInfluenceRange = blackhole.radius * 5
            if enDistance < enInfluenceRange then
                local enPullIntensity = 1 - (enDistance / enInfluenceRange)
                local enPullForce = (blackhole.pullStrength * 0.3 * enPullIntensity) / (enDistance + 1)
                local enAngle = atan2(enDy, enDx)
                enemy.x = enemy.x - cos(enAngle) * enPullForce * dt
                enemy.y = enemy.y - sin(enAngle) * enPullForce * dt
                if enDistance < blackhole.eventHorizon then remove(enemies, j) end
            end
        end

        -- Fade out if life ended
        if blackhole.life <= 0 then
            blackhole.alpha = (blackhole.alpha or 1) - fadeSpeed * dt
            blackhole.eventHorizon = blackhole.eventHorizon * (blackhole.alpha or 1)
            if blackhole.alpha <= 0 then remove(self.blackholes, i) end
        end
    end

    self.currentFog = fogFactor
    return false
end

function Environment:draw(time)
    local distortion = 1 + self.visualDistortion * CONFIG.visual.distortionScale
    if self.visualDistortion > 0 then
        lg.push()
        lg.translate(screenWidth / 2, screenHeight / 2)
        lg.scale(distortion, distortion)
        lg.translate(-screenWidth / 2, -screenHeight / 2)
    end

    drawStarField(self, time, self.currentFog)

    -- Nebulas
    for _, nebula in ipairs(self.nebulas) do drawNebula(nebula, time) end

    -- Black holes
    for _, blackhole in ipairs(self.blackholes) do
        lg.push()
        lg.translate(blackhole.x, blackhole.y)
        lg.rotate(blackhole.rotation)

        lg.setBlendMode("add")
        for _, particle in ipairs(blackhole.accretionDisk) do
            local x = cos(particle.angle) * particle.radius
            local y = sin(particle.angle) * particle.radius
            lg.setColor(1, 0.8, 0.3, particle.brightness * 0.6)
            lg.circle("fill", x, y, particle.size)
        end

        lg.setColor(0, 0, 0, 1)
        lg.circle("fill", 0, 0, blackhole.eventHorizon * 0.8)

        local pulse = 0.7 + 0.3 * sin(time * 4 + blackhole.pulse)
        lg.setColor(0.8, 0.2, 0.1, 0.4 * pulse)
        lg.circle("fill", 0, 0, blackhole.eventHorizon)

        lg.setColor(0.9, 0.6, 0.1, 0.2)
        for i = 1, 3 do
            local radius = blackhole.eventHorizon + i * 8
            lg.circle("line", 0, 0, radius)
        end
        lg.setBlendMode("alpha")
        lg.pop()
    end

    if self.visualDistortion > 0 then lg.pop() end

    if self.currentFog and self.currentFog > 0 then
        lg.setColor(0.1, 0.05, 0.2, 0.7 * self.currentFog)
        lg.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
end

function Environment:clearAll()
    self.nebulas = {}
    self.blackholes = {}
    self.nebulaSpawnTimer = 0
    self.blackholeSpawnTimer = 0
end

function Environment:screenResize()
    createStarField(self)
end

return Environment
