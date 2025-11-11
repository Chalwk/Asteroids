-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Player = {}
Player.__index = Player

local lg = love.graphics
local noise = love.math.noise
local sin, cos, min, max = math.sin, math.cos, math.min, math.max
local abs = math.abs

function Player.new(x, y)
    local instance = setmetatable({}, Player)

    instance.x = x
    instance.y = y
    instance.angle = 0
    instance.speed = 0
    instance.maxSpeed = 300
    instance.acceleration = 200
    instance.rotationSpeed = 4
    instance.size = 15
    instance.boostPower = 2
    instance.boostTime = 0
    instance.maxBoostTime = 3
    instance.boostCooldown = 0
    instance.invulnerable = 0
    instance.lives = 3
    instance.health = 100
    instance.maxHealth = 100
    instance.score = 0
    instance.shootCooldown = 0

    return instance
end

function Player:wrapPosition(screenWidth, screenHeight)
    local size = self.size
    if self.x < -size then
        self.x = screenWidth + size
    elseif self.x > screenWidth + size then
        self.x = -size
    end

    if self.y < -size then
        self.y = screenHeight + size
    elseif self.y > screenHeight + size then
        self.y = -size
    end
end

function Player:update(dt, screenWidth, screenHeight)
    -- Update timers
    if self.invulnerable > 0 then self.invulnerable = self.invulnerable - dt end
    if self.boostCooldown > 0 then self.boostCooldown = self.boostCooldown - dt end
    if self.shootCooldown > 0 then self.shootCooldown = self.shootCooldown - dt end

    -- Handle rotation
    if love.keyboard.isDown("a", "left") then
        self.angle = self.angle - self.rotationSpeed * dt
    end
    if love.keyboard.isDown("d", "right") then
        self.angle = self.angle + self.rotationSpeed * dt
    end

    -- Movement and boosting
    local thrusting = love.keyboard.isDown("w", "up")
    local boosting = love.keyboard.isDown("lshift") and self.boostCooldown <= 0 and self.boostTime > 0

    if thrusting then
        local currentMaxSpeed = self.maxSpeed * (boosting and self.boostPower or 1)
        local acceleration = self.acceleration * (boosting and self.boostPower or 1)
        self.speed = min(self.speed + acceleration * dt, currentMaxSpeed)

        if boosting then
            self.boostTime = max(0, self.boostTime - dt)
            if self.boostTime <= 0 then
                self.boostCooldown = 5
            end
        end
    else
        self.speed = self.speed * (1 - dt * 2)
    end

    -- Movement with pre-calculated trig
    local sin_angle, cos_angle = sin(self.angle), cos(self.angle)
    self.x = self.x + sin_angle * self.speed * dt
    self.y = self.y - cos_angle * self.speed * dt
    self:wrapPosition(screenWidth, screenHeight)

    return sin_angle, cos_angle
end

function Player:draw(time)
    if self.invulnerable > 0 and self.invulnerable % 0.2 > 0.1 then return end

    lg.push()
    lg.translate(self.x, self.y)
    lg.rotate(self.angle)

    local s = self.size or 24
    local pulse = 0.6 + 0.4 * sin(time * 6) -- subtle global pulse
    local boostPulse = (self.boostTime and self.boostTime > 0) and (1 + 0.6 * abs(sin(time * 40))) or 1

    -- Drop shadow to ground the sprite
    lg.setColor(0, 0, 0, 0.25 * (0.6 + 0.4 * (s / 30)))
    lg.ellipse("fill", 0, s * 1.05, s * 0.9, s * 0.35)

    -- Main hull base: layered shapes for depth
    -- Base color
    local baseR, baseG, baseB = 0.85, 0.92, 1.0
    -- Add a tiny noisy tint
    local n = (noise(self.x * 0.01, self.y * 0.01, time * 0.3) - 0.5) * 0.06
    baseR = max(0, min(1, baseR + n))
    baseG = max(0, min(1, baseG + n * 0.6))
    baseB = max(0, min(1, baseB + n * 0.2))

    -- Lower hull (slightly darker)
    lg.setColor(baseR * 0.78, baseG * 0.82, baseB * 0.86)
    lg.polygon("fill",
        0, -s,               -- nose
        -s * 0.72, s * 0.85, -- left tail
        0, s * 0.6,          -- center bottom
        s * 0.72, s * 0.85   -- right tail
    )

    -- Mid highlight layer for rounded look
    lg.setBlendMode("add")
    lg.setColor(1, 1, 1, 0.08 + 0.06 * pulse)
    lg.polygon("fill",
        0, -s * 0.9,
        -s * 0.45, s * 0.6,
        0, s * 0.4,
        s * 0.45, s * 0.6
    )
    lg.setBlendMode("alpha")

    -- Top plate: slightly glossy panel
    lg.setColor(baseR, baseG, baseB, 0.98)
    local topPoints = {
        0, -s * 0.9,
        -s * 0.55, s * 0.45,
        0, s * 0.35,
        s * 0.55, s * 0.45
    }
    lg.polygon("fill", topPoints)

    -- Thin outline for readability
    lg.setColor(0.06, 0.08, 0.12, 0.85)
    lg.setLineWidth(1.5)
    lg.polygon("line", topPoints)

    -- Animated side fins (small flared wings) — they twitch with time
    local finW = s * 0.45
    local finH = s * 0.28
    local finTwitch = 0.06 * sin(time * 18 + self.x * 0.01)
    -- left fin
    lg.setColor(baseR * 0.92, baseG * 0.95, baseB * 0.98)
    lg.polygon("fill",
        -s * 0.65, s * 0.6,
        -s * 0.65 - finW, s * 0.6 + finH * (0.85 + finTwitch),
        -s * 0.32, s * 0.6 + finH * 0.5
    )
    -- right fin
    lg.polygon("fill",
        s * 0.65, s * 0.6,
        s * 0.65 + finW, s * 0.6 + finH * (0.85 - finTwitch),
        s * 0.32, s * 0.6 + finH * 0.5
    )

    -- Cockpit dome: translucent glass with sheen
    local domeRadius = s * 0.32
    local domeY = -s * 0.28
    lg.setBlendMode("add")
    lg.setColor(0.2, 0.75, 1.0, 0.22 + 0.12 * pulse)
    lg.circle("fill", 0, domeY, domeRadius)
    lg.setBlendMode("alpha")
    -- glass rim
    lg.setColor(0.03, 0.06, 0.12, 0.55)
    lg.setLineWidth(1)
    lg.circle("line", 0, domeY, domeRadius)

    -- cockpit highlight (soft)
    lg.setBlendMode("add")
    lg.setColor(1, 1, 1, 0.10 + 0.06 * pulse)
    lg.circle("fill", -domeRadius * 0.32, domeY - domeRadius * 0.32, domeRadius * 0.55)
    lg.setBlendMode("alpha")

    -- Tiny mechanical decal stripes on nose
    lg.setColor(0.06, 0.08, 0.12, 0.45)
    lg.setLineWidth(1)
    lg.line(0, -s * 0.6, 0, -s * 0.4)
    lg.line(-s * 0.12, -s * 0.52, -s * 0.12, -s * 0.38)
    lg.line(s * 0.12, -s * 0.52, s * 0.12, -s * 0.38)

    -- Engine core + thrust cone
    do
        -- central engine glow behind ship nose
        local coreY = s * 0.9
        local coreSize = s * 0.36 * boostPulse
        lg.setBlendMode("add")
        lg.setColor(1, 0.6, 0.2,
            0.28 + 0.18 * (self.speed > 1 and 1 or 0) + 0.15 * ((self.boostTime and self.boostTime > 0) and 1 or 0))
        lg.circle("fill", 0, coreY, coreSize * 0.6)
        lg.setColor(1, 0.75, 0.35, 0.12 + 0.08 * pulse)
        lg.circle("fill", 0, coreY, coreSize)
        -- blue afterburner layer for boost
        if self.boostTime and self.boostTime > 0 then
            lg.setColor(0.2, 0.85, 1.0, 0.18 + 0.12 * abs(sin(time * 60)))
            lg.circle("fill", 0, coreY + sin(time * 50) * 1.5, coreSize * 1.1)
        end
        lg.setBlendMode("alpha")

        -- Soft thrust cone polygon (glow) — larger when moving/boosting
        if self.speed > 1 or (self.boostTime and self.boostTime > 0) or love.keyboard.isDown("w", "up") then
            lg.setBlendMode("add")
            local t = (sin(time * 20) + 1) * 0.5
            local coneW = s * (1.0 + 0.55 * t + (self.boostTime and (self.boostTime > 0 and 0.6 or 0) or 0))
            lg.setColor(1, 0.6, 0.18, 0.45 * (0.6 + 0.4 * t))
            lg.polygon("fill",
                -s * 0.5, coreY,
                0, coreY + coneW,
                s * 0.5, coreY
            )
            if self.boostTime and self.boostTime > 0 then
                lg.setColor(0.18, 0.85, 1, 0.28)
                lg.polygon("fill",
                    -s * 0.35, coreY,
                    0, coreY + coneW * 0.88,
                    s * 0.35, coreY
                )
            end
            lg.setBlendMode("alpha")
        end
    end

    -- Subtle HUD/engine vents as tiny dots
    lg.setColor(0.06, 0.08, 0.12, 0.6)
    local dotRadius = max(1, s * 0.04) -- keeps dots visible at small sizes
    for i = -2, 2 do
        local dx = i * s * 0.14
        local dy = s * 0.22
        lg.circle("fill", dx, dy, dotRadius)
    end

    -- Shield shimmer when invulnerable
    if self.invulnerable and self.invulnerable > 0 then
        lg.setBlendMode("add")
        local tAlpha = 0.35 + 0.25 * abs(sin(time * 18))
        local shieldRadius = s * (1.25 + 0.06 * sin(time * 8))
        lg.setColor(0.2, 0.9, 1.0, tAlpha)
        lg.setLineWidth(2 + (s / 24))
        local shieldOffsetY = s * 0.25
        -- multiple concentric pulses
        lg.circle("line", 0, shieldOffsetY, shieldRadius)
        lg.setColor(0.2, 0.9, 1.0, tAlpha * 0.6)
        lg.setLineWidth(1)
        lg.circle("line", 0, shieldOffsetY, shieldRadius * 1.08 + 1.5 * sin(time * 10))
        lg.setBlendMode("alpha")
    end

    -- Final outline for clarity
    lg.setLineWidth(1)
    lg.setColor(0.02, 0.04, 0.08, 0.9)
    lg.polygon("line", 0, -s, -s * 0.72, s * 0.85, 0, s * 0.6, s * 0.72, s * 0.85)

    lg.pop()
    lg.setBlendMode("alpha")
    lg.setLineWidth(1)
end

return Player
