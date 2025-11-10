-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Enemy = require("src.entities.Enemy")
local Asteroid = require("src.entities.Asteroid")
local Powerup = require("src.entities.Powerup")
local Bullet = require("src.entities.Bullet")

local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, cos, pi, min, max = math.sin, math.cos, math.pi, math.min, math.max

local Game = {}
Game.__index = Game

local HALF_PI = pi * 0.5
local TWO_PI = pi * 2
local PLAYER_SPAWN_X
local PLAYER_SPAWN_Y

local asteroidManager, enemy, powerupManager, bulletManager

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
        score = 0,
        shootCooldown = 0
    }
end

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

local function createPauseButtons(self)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5

    self.pauseButtons = {
        {
            text = "Resume",
            action = "resume",
            x = centerX - 120,
            y = centerY - 70,
            width = 240,
            height = 56,
            color = { 0.18, 0.72, 0.35 }
        },
        {
            text = "Restart",
            action = "restart",
            x = centerX - 120,
            y = centerY + 2,
            width = 240,
            height = 56,
            color = { 0.95, 0.7, 0.18 }
        },
        {
            text = "Main Menu",
            action = "menu",
            x = centerX - 120,
            y = centerY + 74,
            width = 240,
            height = 56,
            color = { 0.82, 0.28, 0.32 }
        }
    }
end

local function updatePauseButtonHover(self, x, y)
    self.pauseButtonHover = nil
    for _, button in ipairs(self.pauseButtons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            self.pauseButtonHover = button.action
            return
        end
    end
end

local function drawUI(self, time)
    -- HUD background
    lg.push()
    lg.setColor(0, 0, 0, 0.35)
    lg.rectangle("fill", 12, 12, 310, 130, 8)
    lg.setColor(1, 1, 1, 0.06)
    lg.rectangle("line", 12, 12, 310, 130, 8)
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

    -- Boost meter with glowing bar
    local boostPercent = self.player.boostTime / self.player.maxBoostTime
    local boostX, boostY, boostW, boostH = 24, 120, 240, 12

    lg.setColor(0.12, 0.12, 0.18, 0.6)
    lg.rectangle("fill", boostX, boostY, boostW, boostH, 6)
    lg.setBlendMode("add", "premultiplied")
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

    if self.paused then
        lg.setColor(1, 0.95, 0.6, 0.95)
        self.fonts:setFont("mediumFont")
        lg.printf("PAUSED - Press P or ESC to resume", 0, screenWidth * 0.5 - 20, screenWidth, "center")
    end
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

local function drawPauseMenu(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    lg.setColor(1, 1, 1)
    self.fonts:setFont("largeFont")
    lg.printf("PAUSED", 0, screenHeight * 0.3, screenWidth, "center")

    for _, button in ipairs(self.pauseButtons) do
        local isHovered = self.pauseButtonHover == button.action
        local r, g, b = unpack(button.color)

        -- nice elevated button with rim highlight
        lg.setColor(r, g, b, isHovered and 0.96 or 0.78)
        lg.rectangle("fill", button.x, button.y, button.width, button.height, 10)

        lg.setColor(1, 1, 1, isHovered and 0.98 or 0.82)
        lg.setLineWidth(isHovered and 3 or 2)
        lg.rectangle("line", button.x, button.y, button.width, button.height, 10)

        -- subtle inner glow if hovered
        if isHovered then
            lg.setBlendMode("add")
            lg.setColor(r, g, b, 0.06)
            lg.rectangle("fill", button.x + 6, button.y + 6, button.width - 12, button.height - 12, 8)
            lg.setBlendMode("alpha")
        end

        lg.setColor(1, 1, 1)
        self.fonts:setFont("mediumFont")
        local textWidth = self.fonts:getFont("mediumFont"):getWidth(button.text)
        local textHeight = self.fonts:getFont("mediumFont"):getHeight()
        lg.print(button.text, button.x + (button.width - textWidth) * 0.5, button.y + (button.height - textHeight) * 0.5)
    end
    lg.setLineWidth(1)
end

local function drawPlayer(self, time)
    local p = self.player

    if p.invulnerable > 0 and p.invulnerable % 0.2 > 0.1 then return end

    lg.push()
    lg.translate(p.x, p.y)
    lg.rotate(p.angle)

    -- Ship body: filled with soft gradient illusion via two draws
    lg.setColor(0.86, 0.92, 1)
    lg.polygon("fill", 0, -p.size, -p.size * 0.75, p.size, p.size * 0.75, p.size)
    lg.setColor(0.06, 0.08, 0.12, 0.6)
    lg.setLineWidth(2)
    lg.polygon("line", 0, -p.size, -p.size * 0.75, p.size, p.size * 0.75, p.size)

    -- Thrust glow (additive) if thrusting or moving
    if p.speed > 1 or love.keyboard.isDown("w", "up") then
        lg.setBlendMode("add")
        local t = (sin(time * 20) + 1) * 0.5
        local glowSize = p.size * (1 + 0.6 * t + (p.boostTime > 0 and 0.6 or 0))
        lg.setColor(1, 0.55, 0.25, 0.65 + 0.25 * t)
        lg.polygon("fill", -p.size * 0.45, p.size, 0, p.size + glowSize, p.size * 0.45, p.size)
        if p.boostTime > 0 then
            lg.setColor(0.2, 0.75, 1, 0.45 + 0.2 * t)
            lg.polygon("fill", -p.size * 0.28, p.size, 0, p.size + glowSize * 1.2, p.size * 0.28, p.size)
        end
        lg.setBlendMode("alpha")
    end

    lg.pop()
    lg.setLineWidth(1)
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

    powerupManager = Powerup.new()
    asteroidManager = Asteroid.new(screenWidth, screenHeight)
    enemy = Enemy.new(instance.difficulty, screenWidth, screenHeight, PLAYER_SPAWN_X, PLAYER_SPAWN_Y)
    bulletManager = Bullet.new()

    createPlayer(instance)
    createStarField(instance)
    createPauseButtons(instance)

    asteroidManager:spawn(4 + instance.level, 1, PLAYER_SPAWN_X, PLAYER_SPAWN_Y)

    return instance
end

function Game:isGameOver() return self.gameOver end

function Game:isPaused() return self.paused end

function Game:setPaused(paused)
    self.paused = paused
    if paused then
        updatePauseButtonHover(self, love.mouse.getX(), love.mouse.getY())
    end
end

function Game:screenResize()
    createPauseButtons(self)
    createStarField(self)
end

function Game:startNewGame(difficulty)
    self.difficulty = difficulty or "medium"
    self.gameOver = false
    self.won = false
    self.paused = false
    self.level = 1

    asteroidManager:clearAll()
    bulletManager:clear()
    powerupManager:clear()

    enemy:reset()
    enemy.difficulty = self.difficulty

    self.particles = {}

    createPlayer(self)
    asteroidManager:spawn(4 + self.level, 1, self.player.x, self.player.y)
end

function Game:handleClick()
    if self.gameOver or self.paused then return end
end

function Game:handlePauseClick(x, y)
    for _, button in ipairs(self.pauseButtons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end
end

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
    end

    -- Update bullets
    bulletManager:update(dt)

    -- Update asteroids using asteroid manager
    local asteroidCollision = asteroidManager:update(dt, p)
    if asteroidCollision and p.lives <= 0 then
        self.gameOver = true
        self.won = false
    end

    -- Update powerups
    powerupManager:update(dt, p)

    -- Update enemy
    enemy:update(dt, p, bulletManager)

    -- Check enemy collision with player
    if enemy:checkPlayerCollision(p) and p.lives <= 0 then
        self.gameOver = true
        self.won = false
    end

    -- Check enemy bullet collisions with player
    for i = #bulletManager:getBullets(), 1, -1 do
        local bullet = bulletManager:getBullets()[i]
        if bullet.enemy and p.invulnerable <= 0 then
            local dx, dy = bullet.x - p.x, bullet.y - p.y
            local distance = math.sqrt(dx * dx + dy * dy)
            if distance < (bullet.size + p.size) then
                p.lives = p.lives - 1
                p.invulnerable = 2
                bulletManager:removeBullet(i)

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

                    if asteroid.level < 3 then
                        for _ = 1, 2 do
                            local newAsteroid = asteroidManager:createAsteroid(asteroid.x, asteroid.y,
                                asteroid.size * 0.6, asteroid.level + 1)
                            newAsteroid.vx = newAsteroid.vx + (random() - 0.5) * 100
                            newAsteroid.vy = newAsteroid.vy + (random() - 0.5) * 100
                            insert(asteroidManager:getAsteroids(), newAsteroid)
                        end
                    end

                    if random() < 0.2 then
                        powerupManager:spawn(asteroid.x, asteroid.y)
                    end

                    asteroidManager:removeAsteroid(j)
                    bulletManager:removeBullet(i)
                    break
                end
            end
        end
    end

    -- Star field: parallax scrolling
    local scrollSpeed = p.speed * dt
    local moveX = sin(p.angle) * scrollSpeed
    local moveY = -cos(p.angle) * scrollSpeed

    for _, star in ipairs(self.stars) do
        local factor = star.layer == 1 and 0.15 or star.layer == 2 and 0.4 or 0.8
        star.x = star.x - moveX * factor
        star.y = star.y - moveY * factor

        if star.x < 0 then star.x = star.x + screenWidth end
        if star.x > screenWidth then star.x = star.x - screenWidth end
        if star.y < 0 then star.y = star.y + screenHeight end
        if star.y > screenHeight then star.y = star.y - screenHeight end
    end

    -- Check level completion
    if asteroidManager:isEmpty() and enemy:getCount() == 0 then
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

    drawStarField(self, time)

    asteroidManager:draw()
    powerupManager:draw(time)
    enemy:draw(time)

    bulletManager:draw()
    drawPlayer(self, time)
    drawUI(self, time)

    if self.gameOver then
        drawGameOver(self, time)
    elseif self.paused then
        drawPauseMenu(self)
    end

    lg.pop()
end

return Game
