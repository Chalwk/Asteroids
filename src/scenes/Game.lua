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
local Player = require("src.entities.Player")

local sin, cos, pi, sqrt, floor = math.sin, math.cos, math.pi, math.sqrt, math.floor
local random = love.math.random
local insert = table.insert
local lg = love.graphics

local HALF_PI = pi * 0.5
local TWO_PI = pi * 2
local PLAYER_SPAWN_X, PLAYER_SPAWN_Y

local Game = {}
Game.__index = Game

local asteroidManager, cometManager
local enemy, bulletManager, powerupManager
local environmentManager, soundManager

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
    environmentManager = Environment.new()

    instance.player = Player.new(PLAYER_SPAWN_X, PLAYER_SPAWN_Y)

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

    self.player = Player.new(PLAYER_SPAWN_X, PLAYER_SPAWN_Y)
    asteroidManager:spawn(4 + self.level, 1, self.player.x, self.player.y)
end

function Game:handleClick() if self.gameOver or self.paused then return end end

function Game:update(dt)
    if self.paused or self.gameOver then return end

    local p = self.player

    -- Update player and get sin/cos values for shooting
    local sin_angle, cos_angle = p:update(dt, screenWidth, screenHeight)

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

    self.player:draw(time)
    drawUI(self, time)

    if self.gameOver then drawGameOver(self, time) end

    lg.pop()
end

return Game
