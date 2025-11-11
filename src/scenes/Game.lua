-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Enemy = require("src.entities.Enemy")
local Asteroid = require("src.entities.Asteroid")
local Powerup = require("src.entities.Powerup")
local Bullet = require("src.entities.Bullet")
local Comet = require("src.entities.Comet")
local Environment = require("src.entities.Environment")
local SoundManager = require("src.managers.SoundManager")

local ipairs = ipairs
local lg = love.graphics
local random = love.math.random
local noise = love.math.noise
local insert = table.insert
local sin, cos, pi, min, max, sqrt, floor = math.sin, math.cos, math.pi, math.min, math.max, math.sqrt, math.floor
local abs = math.abs

local Game = {}
Game.__index = Game

local HALF_PI = pi * 0.5
local TWO_PI = pi * 2
local PLAYER_SPAWN_X, PLAYER_SPAWN_Y

local asteroidManager, enemy, powerupManager, bulletManager
local cometManager, environmentManager
local soundManager

local function createPlayer(self)
    self.player = {
        x = PLAYER_SPAWN_X,
        y = PLAYER_SPAWN_Y,
        angle = 0,
        speed = 0,
        maxSpeed = 300,
        acceleration = 200,
        rotationSpeed = 4,
        size = 15,
        boostPower = 2,
        boostTime = 0,
        maxBoostTime = 3,
        boostCooldown = 0,
        invulnerable = 0,
        lives = 3,
        health = 100,
        maxHealth = 100,
        score = 0,
        shootCooldown = 0
    }
end

local function wrapPosition(obj, size)
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

local function drawUI(self, time)
    lg.push()
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", 12, 12, 310, 170, 8)
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("line", 12, 12, 310, 170, 8)
    lg.pop()

    -- Score
    lg.setColor(1, 1, 1, 0.95)
    self.fonts:setFont("mediumFont")
    lg.print("SCORE", 24, 24)
    self.fonts:setFont("largeFont")
    lg.print(tostring(self.player.score), 24, 48)

    -- Lives (stylized ships)
    for i = 1, self.player.lives do
        local lx = 220 + (i - 1) * 36
        local ly = 36
        lg.push()
        lg.translate(lx, ly)
        lg.rotate(-HALF_PI + 0.12 * sin(time * 8 + i))
        lg.setColor(1, 1, 1, 0.95)
        lg.polygon("fill", 0, -8, -6, 8, 6, 8)
        lg.setColor(0, 0, 0, 0.6)
        lg.polygon("line", 0, -8, -6, 8, 6, 8)
        lg.pop()
    end

    -- Health bar
    local healthPercent = self.player.health / self.player.maxHealth
    local healthX, healthY, healthW, healthH = 24, 115, 240, 12

    -- Health bar background
    lg.setColor(0.12, 0.12, 0.18, 0.6)
    lg.rectangle("fill", healthX, healthY, healthW, healthH, 6)

    -- Health bar fill with color based on health percentage
    local r, g
    if healthPercent > 0.6 then
        r = 0.2
        g = 0.8
    elseif healthPercent > 0.3 then
        r = 0.8
        g = 0.8
    else
        r = 0.8
        g = 0.2
    end

    lg.setBlendMode("add")
    lg.setColor(r, g, 0.2, 0.8)
    lg.rectangle("fill", healthX, healthY, healthW * healthPercent, healthH, 6)

    -- Health bar glow effect
    lg.setColor(r, g, 0.2, 0.12 + 0.12 * sin(time * 6))
    lg.rectangle("fill", healthX - 4, healthY - 6, (healthW * healthPercent) + 8, healthH + 12, 8)
    lg.setBlendMode("alpha")

    -- Health text
    lg.setColor(1, 1, 1, 0.85)
    self.fonts:setFont("smallFont")
    lg.print("HEALTH", healthX + healthW + 8, healthY - 2)

    -- Health value text
    lg.print(floor(self.player.health) .. "/" .. self.player.maxHealth, healthX, healthY + healthH + 2)

    -- Boost meter
    local boostPercent = self.player.boostTime / self.player.maxBoostTime
    local boostX, boostY, boostW, boostH = 24, 165, 240, 12 -- Moved from 120 to 145

    lg.setColor(0.12, 0.12, 0.18, 0.6)
    lg.rectangle("fill", boostX, boostY, boostW, boostH, 6)
    lg.setBlendMode("add")
    lg.setColor(0.12, 0.6, 1, 0.8)
    lg.rectangle("fill", boostX, boostY, boostW * boostPercent, boostH, 6)
    -- soft glow overlay
    lg.setColor(0.12, 0.6, 1, 0.12 + 0.12 * sin(time * 6))
    lg.rectangle("fill", boostX - 4, boostY - 6, (boostW * boostPercent) + 8, boostH + 12, 8)
    lg.setBlendMode("alpha")

    lg.setColor(1, 1, 1, 0.85)
    self.fonts:setFont("smallFont")
    lg.print("BOOST", boostX + boostW + 8, boostY - 2)

    -- Difficulty and Level (top-right)
    lg.setColor(1, 1, 1, 0.8)
    self.fonts:setFont("smallFont")
    lg.print("Difficulty: " .. self.difficulty:upper(), screenWidth - 200, 20)
    lg.print("Level: " .. self.level, screenWidth - 200, 42)
end

local function drawGameOver(self, time)
    lg.setColor(0, 0, 0, 0.75)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    self.fonts:setFont("largeFont")
    lg.setColor(self.won and { 0.2, 0.95, 0.2 } or { 0.95, 0.2, 0.25 })
    lg.printf(self.won and "MISSION COMPLETE!" or "GAME OVER", 0, screenHeight / 2 - 100, screenWidth, "center")

    lg.setColor(1, 1, 1, 0.95)
    self.fonts:setFont("mediumFont")
    lg.printf("FINAL SCORE: " .. self.player.score, 0, screenHeight / 2 - 30, screenWidth, "center")

    self.fonts:setFont("smallFont")
    lg.printf("Click anywhere to continue", 0, screenHeight / 2 + 30, screenWidth, "center")

    -- small animated particle ring for celebration / defeat
    lg.setBlendMode("add")
    for i = 1, 16 do
        local a = (time * 2 + i) % TWO_PI
        local r = 120 + sin(time * 3 + i) * 12
        local x = screenWidth * 0.5 + cos(a) * r
        local y = screenHeight * 0.5 + sin(a) * r
        local s = 2 + (sin(time * 5 + i) + 1) * 1.5
        lg.setColor(1, 1, 0.7, 0.08 + 0.06 * sin(time * 7 + i))
        lg.circle("fill", x, y, s)
    end
    lg.setBlendMode("alpha")
end

local function drawPlayer(self, time)
    local p = self.player

    -- Keep original invulnerability flash behaviour (skip draw on odd flashes)
    if p.invulnerable > 0 and p.invulnerable % 0.2 > 0.1 then return end

    lg.push()
    lg.translate(p.x, p.y)
    lg.rotate(p.angle)

    local s = p.size or 24
    local pulse = 0.6 + 0.4 * sin(time * 6) -- subtle global pulse
    local boostPulse = (p.boostTime and p.boostTime > 0) and (1 + 0.6 * abs(sin(time * 40))) or 1

    -- Drop shadow to ground the sprite
    lg.setColor(0, 0, 0, 0.25 * (0.6 + 0.4 * (s / 30)))
    lg.ellipse("fill", 0, s * 1.05, s * 0.9, s * 0.35)

    -- Main hull base: layered shapes for depth
    -- Base color
    local baseR, baseG, baseB = 0.85, 0.92, 1.0
    -- Add a tiny noisy tint
    local n = (noise(p.x * 0.01, p.y * 0.01, time * 0.3) - 0.5) * 0.06
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
    local finTwitch = 0.06 * sin(time * 18 + p.x * 0.01)
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
            0.28 + 0.18 * (p.speed > 1 and 1 or 0) + 0.15 * ((p.boostTime and p.boostTime > 0) and 1 or 0))
        lg.circle("fill", 0, coreY, coreSize * 0.6)
        lg.setColor(1, 0.75, 0.35, 0.12 + 0.08 * pulse)
        lg.circle("fill", 0, coreY, coreSize)
        -- blue afterburner layer for boost
        if p.boostTime and p.boostTime > 0 then
            lg.setColor(0.2, 0.85, 1.0, 0.18 + 0.12 * abs(sin(time * 60)))
            lg.circle("fill", 0, coreY + sin(time * 50) * 1.5, coreSize * 1.1)
        end
        lg.setBlendMode("alpha")

        -- Soft thrust cone polygon (glow) — larger when moving/boosting
        if p.speed > 1 or (p.boostTime and p.boostTime > 0) or love.keyboard.isDown("w", "up") then
            lg.setBlendMode("add")
            local t = (sin(time * 20) + 1) * 0.5
            local coneW = s * (1.0 + 0.55 * t + (p.boostTime and (p.boostTime > 0 and 0.6 or 0) or 0))
            lg.setColor(1, 0.6, 0.18, 0.45 * (0.6 + 0.4 * t))
            lg.polygon("fill",
                -s * 0.5, coreY,
                0, coreY + coneW,
                s * 0.5, coreY
            )
            if p.boostTime and p.boostTime > 0 then
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
    if p.invulnerable and p.invulnerable > 0 then
        lg.setBlendMode("add")
        local tAlpha = 0.35 + 0.25 * abs(sin(time * 18))
        local shieldRadius = s * (1.25 + 0.06 * sin(time * 8))
        lg.setColor(0.2, 0.9, 1.0, tAlpha)
        lg.setLineWidth(2 + (s / 24))
        -- multiple concentric pulses
        lg.circle("line", 0, 0, shieldRadius)
        lg.setColor(0.2, 0.9, 1.0, tAlpha * 0.6)
        lg.setLineWidth(1)
        lg.circle("line", 0, 0, shieldRadius * 1.08 + 1.5 * sin(time * 10))
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

function Game.new(fontManager)
    local instance = setmetatable({}, Game)

    PLAYER_SPAWN_X = screenWidth * 0.5
    PLAYER_SPAWN_Y = screenHeight * 0.5

    instance.fonts = fontManager
    instance.gameOver = false
    instance.won = false
    instance.difficulty = "medium"
    instance.paused = false
    instance.level = 1
    instance.particles = {}
    instance.waveCooldown = 0

    soundManager = SoundManager.new()
    powerupManager = Powerup.new()
    asteroidManager = Asteroid.new(soundManager)
    enemy = Enemy.new(instance.difficulty, PLAYER_SPAWN_X, PLAYER_SPAWN_Y, soundManager)
    bulletManager = Bullet.new()
    cometManager = Comet.new(soundManager)
    environmentManager = Environment.new(soundManager)

    createPlayer(instance)

    asteroidManager:spawn(4 + instance.level, 1, PLAYER_SPAWN_X, PLAYER_SPAWN_Y)

    return instance
end

function Game:isGameOver() return self.gameOver end

function Game:isPaused() return self.paused end

function Game:setPaused(paused) self.paused = paused end

function Game:screenResize() environmentManager:screenResize() end

function Game:startNewGame(difficulty)
    self.difficulty = difficulty or "easy"
    self.gameOver = false
    self.won = false
    self.paused = false
    self.level = 1

    asteroidManager:clearAll()
    bulletManager:clear()
    powerupManager:clear()
    cometManager:clearAll()
    environmentManager:clearAll()

    enemy:reset()
    enemy.difficulty = self.difficulty

    self.particles = {}

    createPlayer(self)
    asteroidManager:spawn(4 + self.level, 1, self.player.x, self.player.y)
end

function Game:handleClick() if self.gameOver or self.paused then return end end

function Game:update(dt)
    if self.paused or self.gameOver then return end

    local p = self.player

    -- Update timers
    if p.invulnerable > 0 then p.invulnerable = p.invulnerable - dt end
    if p.boostCooldown > 0 then p.boostCooldown = p.boostCooldown - dt end
    if p.shootCooldown > 0 then p.shootCooldown = p.shootCooldown - dt end

    -- Handle rotation
    if love.keyboard.isDown("a", "left") then
        p.angle = p.angle - p.rotationSpeed * dt
    end
    if love.keyboard.isDown("d", "right") then
        p.angle = p.angle + p.rotationSpeed * dt
    end

    -- Movement and boosting
    local thrusting = love.keyboard.isDown("w", "up")
    local boosting = love.keyboard.isDown("lshift") and p.boostCooldown <= 0 and p.boostTime > 0

    if thrusting then
        local currentMaxSpeed = p.maxSpeed * (boosting and p.boostPower or 1)
        local acceleration = p.acceleration * (boosting and p.boostPower or 1)
        p.speed = min(p.speed + acceleration * dt, currentMaxSpeed)

        if boosting then
            p.boostTime = max(0, p.boostTime - dt)
            if p.boostTime <= 0 then
                p.boostCooldown = 5
            end
        end
    else
        p.speed = p.speed * (1 - dt * 2)
    end

    -- Movement with pre-calculated trig
    local sin_angle, cos_angle = sin(p.angle), cos(p.angle)
    p.x = p.x + sin_angle * p.speed * dt
    p.y = p.y - cos_angle * p.speed * dt
    wrapPosition(p)

    -- Shooting
    if love.keyboard.isDown("space") and p.shootCooldown <= 0 then
        bulletManager:create(
            p.x + sin_angle * 20,
            p.y - cos_angle * 20,
            sin_angle * 500,
            -cos_angle * 500,
            2,
            3,
            nil -- not enemy bullet
        )
        p.shootCooldown = 0.2
        soundManager:play("player_bullet")
    end

    -- Update bullets
    bulletManager:update(dt)

    -- Update asteroids using asteroid manager
    local asteroidCollision = asteroidManager:update(dt, p)
    if asteroidCollision and p.invulnerable <= 0 then
        p.health = p.health - 25 -- Reduce health instead of lives
        p.invulnerable = 2

        if p.health <= 0 then
            p.lives = p.lives - 1
            p.health = p.maxHealth -- Reset health when losing a life
        end

        if p.lives <= 0 then
            self.gameOver = true
            self.won = false
        end
    end

    -- Update powerups
    powerupManager:update(dt, p)

    -- Update enemy
    enemy:update(dt, p, bulletManager)

    -- Check enemy collision with player
    if enemy:checkPlayerCollision(p) and p.invulnerable <= 0 then
        p.health = p.health - 35 -- Reduce health instead of lives
        p.invulnerable = 2

        if p.health <= 0 then
            p.lives = p.lives - 1
            p.health = p.maxHealth -- Reset health when losing a life
        end

        if p.lives <= 0 then
            self.gameOver = true
            self.won = false
        end
    end

    -- Check enemy bullet collisions with player
    for i = #bulletManager:getBullets(), 1, -1 do
        local bullet = bulletManager:getBullets()[i]
        if bullet.enemy and p.invulnerable <= 0 then
            local dx, dy = bullet.x - p.x, bullet.y - p.y
            local distance = sqrt(dx * dx + dy * dy)
            if distance < (bullet.size + p.size) then
                p.health = p.health - 10 -- Reduce health instead of lives
                p.invulnerable = 2
                bulletManager:removeBullet(i)

                if p.health <= 0 then
                    p.lives = p.lives - 1
                    p.health = p.maxHealth -- Reset health when losing a life
                end

                if p.lives <= 0 then
                    self.gameOver = true
                    self.won = false
                end
            end
        end
    end

    -- Check bullet collisions with asteroids
    for i = #bulletManager:getBullets(), 1, -1 do
        local bullet = bulletManager:getBullets()[i]
        if not bullet.enemy then
            -- Player bullets vs asteroids
            for j = #asteroidManager:getAsteroids(), 1, -1 do
                local asteroid = asteroidManager:getAsteroids()[j]
                if asteroidManager:checkCollision(bullet, asteroid) then
                    p.score = p.score + (4 - asteroid.level) * 25
                    soundManager:play("asteroid_explosion")

                    -- Create dust particles for the main asteroid destruction
                    asteroidManager:createDustParticles(asteroid.x, asteroid.y, asteroid.size, random(12, 20))

                    if asteroid.level < 3 then
                        for _ = 1, 2 do
                            local newAsteroid = asteroidManager:createAsteroid(asteroid.x, asteroid.y,
                                asteroid.size * 0.6, asteroid.level + 1)
                            newAsteroid.vx = newAsteroid.vx + (random() - 0.5) * 100
                            newAsteroid.vy = newAsteroid.vy + (random() - 0.5) * 100
                            insert(asteroidManager:getAsteroids(), newAsteroid)

                            -- Create fewer dust particles for smaller asteroid fragments
                            asteroidManager:createDustParticles(
                                asteroid.x,
                                asteroid.y,
                                asteroid.size * 0.6,
                                random(5, 10)
                            )
                        end
                    end

                    if random() < 0.2 then powerupManager:spawn(asteroid.x, asteroid.y) end

                    asteroidManager:removeAsteroid(j)
                    bulletManager:removeBullet(i)
                    break
                end
            end
        end
    end

    local environmentDeath = environmentManager:update(dt, p,
        asteroidManager:getAsteroids(),
        enemy.enemies)

    if environmentDeath then
        self.gameOver = true
        self.won = false
    end

    -- Update comets and check if player died from comet collision
    local cometCollision = cometManager:update(dt, p)
    if cometCollision then
        self.gameOver = true
        self.won = false
    elseif asteroidManager:isEmpty() and enemy:getCount() == 0 then
        self.level = self.level + 1
        asteroidManager:spawn(4 + self.level, 1, self.player.x, self.player.y)

        if self.level >= 5 then
            self.gameOver = true
            self.won = true
        end
    end
end

function Game:draw(time)
    lg.push()

    environmentManager:draw(time)

    asteroidManager:draw()
    cometManager:draw(time)
    powerupManager:draw(time)
    enemy:draw(time)

    bulletManager:draw()
    drawPlayer(self, time)
    drawUI(self, time)

    if self.gameOver then drawGameOver(self, time) end

    lg.pop()
end

return Game
