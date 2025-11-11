-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random

local ipairs = ipairs
local pi = math.pi
local sin, cos = math.sin, math.cos
local atan2, sqrt = math.atan2, math.sqrt
local insert, remove = table.insert, table.remove

local function createStarField(self)
    -- layered starfield: slower layers in the distance, brighter ones close
    self.stars = {}
    for i = 1, 220 do
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
    -- Star field: parallax scrolling
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

local function drawStarField(self, time)
    -- draw layered starfield with gentle parallax and twinkle
    -- background haze
    lg.setColor(0.02, 0.04, 0.08, 0.22)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    for _, star in ipairs(self.stars) do
        -- twinkle effect
        local tw = star.brightness * (0.6 + 0.4 * sin(time * (0.6 + star.twinkle)))
        local px = star.x
        local py = star.y

        -- parallax motion already applied in update; draw glow for larger stars
        if star.size > 2.2 then
            lg.setBlendMode("add")
            lg.setColor(1, 1, 1, 0.06 * tw)
            lg.circle("fill", px, py, star.size * 3.2)
            lg.setColor(1, 1, 1, 0.12 * tw)
            lg.circle("fill", px, py, star.size * 1.8)
            lg.setBlendMode("alpha")
        end

        lg.setColor(1, 1, 1, 0.6 * tw)
        lg.circle("fill", px, py, star.size)
    end
    lg.setBlendMode("alpha")
end

local function createBlackhole()
    -- Spawn away from screen center
    local minDistFromCenter = 200
    local angle = random() * pi * 2
    local distance = minDistFromCenter + random(100, 300)

    local x = screenWidth * 0.5 + cos(angle) * distance
    local y = screenHeight * 0.5 + sin(angle) * distance

    local blackhole = {
        x = x,
        y = y,
        radius = random(60, 100),
        pullStrength = random(800, 1200),
        eventHorizon = random(25, 40), -- Radius where objects get destroyed
        rotation = random() * pi * 2,
        rotationSpeed = (random() - 0.5) * 1.5,
        life = random(15, 25), -- seconds
        pulse = random() * pi * 2,
        accretionDisk = {}
    }

    -- Create accretion disk particles
    for _ = 1, 30 do
        local diskAngle = random() * pi * 2
        local diskRadius = blackhole.eventHorizon + random(10, blackhole.radius - 10)
        local diskSpeed = (blackhole.radius / diskRadius) * 2 -- Keplerian rotation

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

local function createNebula()
    -- Spawn from edges
    local side = random(1, 4)
    local x, y, vx, vy

    local speed = random(20, 40)
    local angle = random() * pi * 2

    if side == 1 then -- Top
        x = random(0, screenWidth)
        y = -100
    elseif side == 2 then -- Right
        x = screenWidth + 100
        y = random(0, screenHeight)
    elseif side == 3 then -- Bottom
        x = random(0, screenWidth)
        y = screenHeight + 100
    else -- Left
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
        density = random(0.3, 0.7),    -- Affects visibility reduction
        slowFactor = random(0.3, 0.6), -- Speed reduction factor
        rotation = random() * pi * 2,
        rotationSpeed = (random() - 0.5) * 0.5,
        life = random(25, 40), -- seconds
        pulse = random() * pi * 2,
        innerRadius = random(40, 80)
    }

    return nebula
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
    instance.nebulaSpawnInterval = 45     -- seconds between nebula spawns
    instance.blackholeSpawnInterval = 120 -- seconds between blackhole spawns

    createStarField(instance)

    return instance
end

function Environment:update(dt, player, asteroids, enemies)
    -- Update star field
    updateStarField(self, dt, player)

    -- Update spawn timers
    self.nebulaSpawnTimer = self.nebulaSpawnTimer - dt
    self.blackholeSpawnTimer = self.blackholeSpawnTimer - dt

    -- Spawn nebula if timer expires
    if self.nebulaSpawnTimer <= 0 and #self.nebulas < 2 then -- Max 2 nebulas
        insert(self.nebulas, createNebula())
        self.nebulaSpawnTimer = self.nebulaSpawnInterval + random(-10, 10)
        --self.soundManager:play("nebula_spawn")
    end

    -- Spawn blackhole if timer expires (much rarer)
    if self.blackholeSpawnTimer <= 0 and #self.blackholes < 1 then -- Max 1 blackhole
        insert(self.blackholes, createBlackhole())
        self.blackholeSpawnTimer = self.blackholeSpawnInterval + random(-20, 20)
        --self.soundManager:play("blackhole_spawn")
    end

    -- Update nebulas
    for i = #self.nebulas, 1, -1 do
        local nebula = self.nebulas[i]

        -- Movement
        nebula.x = nebula.x + nebula.vx * dt
        nebula.y = nebula.y + nebula.vy * dt
        nebula.rotation = nebula.rotation + nebula.rotationSpeed * dt
        nebula.pulse = nebula.pulse + dt * 2
        nebula.life = nebula.life - dt

        -- Check if player is in nebula
        local dx, dy = player.x - nebula.x, player.y - nebula.y
        local distance = sqrt(dx * dx + dy * dy)

        if distance < nebula.radius then
            -- Apply speed reduction
            player.speed = player.speed * (1 - nebula.slowFactor * dt * 2)
        end

        -- Remove if expired or far off screen
        if nebula.life <= 0 or
            nebula.x < -nebula.radius * 2 or nebula.x > screenWidth + nebula.radius * 2 or
            nebula.y < -nebula.radius * 2 or nebula.y > screenHeight + nebula.radius * 2 then
            remove(self.nebulas, i)
        end
    end

    -- Update blackholes
    for i = #self.blackholes, 1, -1 do
        local blackhole = self.blackholes[i]

        blackhole.rotation = blackhole.rotation + blackhole.rotationSpeed * dt
        blackhole.pulse = blackhole.pulse + dt * 3
        blackhole.life = blackhole.life - dt

        -- Update accretion disk
        for _, particle in ipairs(blackhole.accretionDisk) do
            particle.angle = particle.angle + particle.speed * dt
        end

        -- Apply gravitational pull to player
        local dx, dy = player.x - blackhole.x, player.y - blackhole.y
        local distance = sqrt(dx * dx + dy * dy)

        if distance < blackhole.radius * 3 then -- Pull range is 3x radius
            local pullForce = blackhole.pullStrength / (distance * distance + 1)
            local angle = atan2(dy, dx)

            player.x = player.x - cos(angle) * pullForce * dt
            player.y = player.y - sin(angle) * pullForce * dt

            -- Check event horizon collision
            if distance < blackhole.eventHorizon and player.invulnerable <= 0 then
                player.lives = 0
                player.health = 0
                --self.soundManager:play("blackhole_collision")
                remove(self.blackholes, i)
                return true -- Signal player death
            end
        end

        -- Apply pull to asteroids
        for j = #asteroids, 1, -1 do
            local asteroid = asteroids[j]
            local astDx, astDy = asteroid.x - blackhole.x, asteroid.y - blackhole.y
            local astDistance = sqrt(astDx * astDy + astDy * astDy)

            if astDistance < blackhole.radius * 3 then
                local astPullForce = (blackhole.pullStrength * 0.5) / (astDistance * astDistance + 1)
                local astAngle = atan2(astDy, astDx)

                asteroid.x = asteroid.x - cos(astAngle) * astPullForce * dt
                asteroid.y = asteroid.y - sin(astAngle) * astPullForce * dt
                asteroid.vx = asteroid.vx - cos(astAngle) * astPullForce * dt * 0.1
                asteroid.vy = asteroid.vy - sin(astAngle) * astPullForce * dt * 0.1

                -- Destroy asteroids that cross event horizon
                if astDistance < blackhole.eventHorizon then
                    remove(asteroids, j)
                    --self.soundManager:play("asteroid_explosion")
                end
            end
        end

        -- Apply pull to enemies
        for j = #enemies, 1, -1 do
            local enemy = enemies[j]
            local enDx, enDy = enemy.x - blackhole.x, enemy.y - blackhole.y
            local enDistance = sqrt(enDx * enDy + enDy * enDy)

            if enDistance < blackhole.radius * 3 then
                local enPullForce = (blackhole.pullStrength * 0.3) / (enDistance * enDistance + 1)
                local enAngle = atan2(enDy, enDx)

                enemy.x = enemy.x - cos(enAngle) * enPullForce * dt
                enemy.y = enemy.y - sin(enAngle) * enPullForce * dt

                -- Destroy enemies that cross event horizon
                if enDistance < blackhole.eventHorizon then
                    remove(enemies, j)
                    --self.soundManager:play("enemy_explosion")
                end
            end
        end

        -- Remove if expired
        if blackhole.life <= 0 then
            remove(self.blackholes, i)
        end
    end

    return false -- No player death from blackhole
end

function Environment:draw(time)
    -- Draw star field first (background)
    drawStarField(self, time)

    -- Draw nebulas
    for _, nebula in ipairs(self.nebulas) do
        lg.push()

        -- Nebula glow effect
        lg.setBlendMode("add")
        local pulse = 0.8 + 0.2 * sin(time * 1.5 + nebula.pulse)

        -- Outer glow
        lg.setColor(0.3, 0.2, 0.6, 0.15 * nebula.density * pulse)
        for i = 1, 3 do
            local radius = nebula.radius * (0.8 + i * 0.2)
            lg.circle("fill", nebula.x, nebula.y, radius)
        end

        -- Inner colorful clouds
        lg.setColor(0.5, 0.3, 0.8, 0.25 * nebula.density)
        lg.circle("fill", nebula.x, nebula.y, nebula.radius)

        -- Swirling patterns
        lg.setColor(0.7, 0.5, 0.9, 0.3 * nebula.density)
        for i = 1, 8 do
            local angle = nebula.rotation + (i * pi / 4)
            local armLength = nebula.radius * 0.7
            local armX = nebula.x + cos(angle) * armLength
            local armY = nebula.y + sin(angle) * armLength

            lg.setLineWidth(8)
            lg.line(nebula.x, nebula.y, armX, armY)
        end

        lg.setBlendMode("alpha")
        lg.pop()
    end

    -- Draw blackholes
    for _, blackhole in ipairs(self.blackholes) do
        lg.push()
        lg.translate(blackhole.x, blackhole.y)
        lg.rotate(blackhole.rotation)

        -- Accretion disk
        lg.setBlendMode("add")
        for _, particle in ipairs(blackhole.accretionDisk) do
            local x = cos(particle.angle) * particle.radius
            local y = sin(particle.angle) * particle.radius

            lg.setColor(1, 0.8, 0.3, particle.brightness * 0.6)
            lg.circle("fill", x, y, particle.size)
        end

        -- Black hole core (pure black)
        lg.setColor(0, 0, 0, 1)
        lg.circle("fill", 0, 0, blackhole.eventHorizon * 0.8)

        -- Event horizon glow
        local pulse = 0.7 + 0.3 * sin(time * 4 + blackhole.pulse)
        lg.setColor(0.8, 0.2, 0.1, 0.4 * pulse)
        lg.circle("fill", 0, 0, blackhole.eventHorizon)

        -- Gravitational lensing effect
        lg.setColor(0.9, 0.6, 0.1, 0.2)
        for i = 1, 3 do
            local radius = blackhole.eventHorizon + i * 8
            lg.circle("line", 0, 0, radius)
        end

        lg.setBlendMode("alpha")
        lg.pop()
    end
end

function Environment:clearAll()
    self.nebulas = {}
    self.blackholes = {}
    self.nebulaSpawnTimer = 0
    self.blackholeSpawnTimer = 0
end

function Environment:screenResize() createStarField(self) end

return Environment
