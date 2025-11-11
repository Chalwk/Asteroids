-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local sin, cos = math.sin, math.cos
local atan2 = math.atan2
local sqrt = math.sqrt
local pi = math.pi
local insert, remove = table.insert, table.remove

local Comet = {}
Comet.__index = Comet

function Comet.new(soundManager)
    local instance = setmetatable({}, Comet)
    instance.comets = {}
    instance.soundManager = soundManager
    instance.spawnInterval = 30
    instance.spawnTimer = instance.spawnInterval + random(-5, 5)
    return instance
end

function Comet:createComet()
    -- Decide which edge to spawn from (0: top, 1: right, 2: bottom, 3: left)
    local spawnEdge = random(0, 3)
    local x, y, vx, vy

    -- Speed and direction
    local speed = 600
    local targetX, targetY = screenWidth * 0.5, screenHeight * 0.5

    if spawnEdge == 0 then -- Top
        x = random(0, screenWidth)
        y = -50
        local angle = atan2(targetY - y, targetX - x)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
    elseif spawnEdge == 1 then -- Right
        x = screenWidth + 50
        y = random(0, screenHeight)
        local angle = atan2(targetY - y, targetX - x)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
    elseif spawnEdge == 2 then -- Bottom
        x = random(0, screenWidth)
        y = screenHeight + 50
        local angle = atan2(targetY - y, targetX - x)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
    else -- Left
        x = -50
        y = random(0, screenHeight)
        local angle = atan2(targetY - y, targetX - x)
        vx = cos(angle) * speed
        vy = sin(angle) * speed
    end

    local comet = {
        x = x,
        y = y,
        vx = vx,
        vy = vy,
        size = 25,
        rotation = 0,
        rotationSpeed = (random() - 0.5) * 3,
        tailParticles = {},
        lastParticleTime = 0,
        particleInterval = 0.02,
        life = 15 -- seconds until auto-removal
    }

    return comet
end

function Comet:update(dt, player)
    -- Update spawn timer
    self.spawnTimer = self.spawnTimer - dt
    if self.spawnTimer <= 0 then
        self.spawnTimer = self.spawnInterval + random(-5, 5) -- Add some randomness
        insert(self.comets, self:createComet())
        self.soundManager:play("comet_spawn")
    end

    -- Update existing comets
    for i = #self.comets, 1, -1 do
        local comet = self.comets[i]

        -- Update position
        comet.x = comet.x + comet.vx * dt
        comet.y = comet.y + comet.vy * dt
        comet.rotation = comet.rotation + comet.rotationSpeed * dt
        comet.life = comet.life - dt

        -- Add tail particles
        comet.lastParticleTime = comet.lastParticleTime - dt
        if comet.lastParticleTime <= 0 then
            comet.lastParticleTime = comet.particleInterval

            -- Add new tail particle
            insert(comet.tailParticles, {
                x = comet.x,
                y = comet.y,
                life = 1.5,
                size = random(3, 8),
                brightness = random(0.6, 1.0)
            })
        end

        -- Update tail particles
        for j = #comet.tailParticles, 1, -1 do
            local particle = comet.tailParticles[j]
            particle.life = particle.life - dt
            if particle.life <= 0 then
                remove(comet.tailParticles, j)
            end
        end

        -- Check if comet is off screen or expired
        local margin = 100
        if comet.life <= 0 or
            comet.x < -margin or comet.x > screenWidth + margin or
            comet.y < -margin or comet.y > screenHeight + margin then
            remove(self.comets, i)
        end

        -- Check collision with player
        if player.invulnerable <= 0 then
            local dx, dy = comet.x - player.x, comet.y - player.y
            local distance = sqrt(dx * dx + dy * dy)
            if distance < (comet.size + player.size) then
                -- Insta-kill
                player.lives = 0
                player.health = 0
                --self.soundManager:play("comet_collision")
                remove(self.comets, i)
                return true
            end
        end
    end
end

function Comet:draw(time)
    for _, comet in ipairs(self.comets) do
        -- Draw jagged tail particles (behind comet)
        lg.push()
        lg.setBlendMode("add")
        for _, particle in ipairs(comet.tailParticles) do
            local alpha = particle.life / 1.5
            local tailLength = particle.size * 2 + random() * 4
            local angle = atan2(-comet.vy, -comet.vx) + (random() - 0.5) * 0.5 -- slight wobble

            lg.setColor(0.5 + random() * 0.3, 0.7 + random() * 0.2, 1, alpha * particle.brightness * 0.8)
            lg.push()
            lg.translate(particle.x, particle.y)
            lg.rotate(angle)
            lg.rectangle("fill", -tailLength / 2, -particle.size / 2, tailLength, particle.size)
            lg.pop()
        end
        lg.setBlendMode("alpha")
        lg.pop()

        -- Draw jagged comet core
        lg.push()
        lg.translate(comet.x, comet.y)
        lg.rotate(comet.rotation)
        local spikes = 6 + random(2) -- jagged points
        for i = 1, spikes do
            local angle = i * 2 * pi / spikes + random() * 0.3
            local radius = comet.size * (0.7 + random() * 0.5)
            local x = cos(angle) * radius
            local y = sin(angle) * radius
            lg.setColor(0.8, 0.9, 1, 0.9)
            lg.circle("fill", x, y, 3)
        end

        -- Bright inner core
        lg.setColor(1, 1, 1, 0.7)
        lg.circle("fill", 0, 0, comet.size * 0.6)

        -- Glowing aura with pulse
        lg.setBlendMode("add")
        local pulse = 0.8 + 0.2 * sin(time * 8)
        lg.setColor(0.4, 0.6, 1, 0.2 * pulse)
        lg.circle("fill", 0, 0, comet.size * 1.8)
        lg.setBlendMode("alpha")
        lg.pop()
    end
end

function Comet:clearAll()
    self.comets = {}
    self.spawnTimer = self.spawnInterval + random(-5, 5)
end

return Comet
