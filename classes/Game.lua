-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Enemy = require("classes.Enemy")

local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, cos, pi, atan2, min, max = math.sin, math.cos, math.pi, math.atan2, math.min, math.max

local Game = {}
Game.__index = Game

local HALF_PI = pi * 0.5
local TWO_PI = pi * 2
local PLAYER_SPAWN_X
local PLAYER_SPAWN_Y

local bulletPool = {}
local asteroidPool = {}
local powerupPool = {}
local enemyPool = {}

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end

local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
end

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

local function createAsteroid(x, y, size, level)
    local speed = random(50, 150) / (level or 1)
    local angle = random() * TWO_PI

    return {
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

local function createPowerup(x, y)
    local types = { "boost", "shield", "rapid" }
    return {
        x = x,
        y = y,
        vx = (random() - 0.5) * 50,
        vy = (random() - 0.5) * 50,
        type = types[random(1, 3)],
        size = 15,
        rotation = 0,
        life = 10
    }
end

local function createenemy(self)
    local side = random(1, 4)
    local x, y

    if side == 1 then
        x, y = -50, random(0, screenHeight)
    elseif side == 2 then
        x, y = screenWidth + 50, random(0, screenHeight)
    elseif side == 3 then
        x, y = random(0, screenWidth), -50
    else
        x, y = random(0, screenWidth), screenHeight + 50
    end

    local speed = 100 + (self.difficulty == "easy" and 30 or self.difficulty == "medium" and 60 or 90)

    return {
        x = x,
        y = y,
        targetX = PLAYER_SPAWN_X,
        targetY = PLAYER_SPAWN_Y,
        speed = speed,
        size = 25,
        health = 2,
        shootCooldown = 0,
        rotation = 0
    }
end

local function distanceSquared(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end

local function checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    return distanceSquared(a.x, a.y, b.x, b.y) < minDist * minDist
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

local function spawnAsteroids(self, count, level)
    for _ = 1, count do
        local asteroid = getFromPool(asteroidPool)
        local newAsteroid = createAsteroid(nil, nil, nil, level)
        for k, v in pairs(newAsteroid) do asteroid[k] = v end

        -- Ensure asteroids spawn away from player
        local minDistSq = 150 * 150
        while distanceSquared(asteroid.x, asteroid.y, self.player.x, self.player.y) < minDistSq do
            asteroid.x = random(0, screenWidth)
            asteroid.y = random(0, screenHeight)
        end

        generateAsteroidShape(asteroid)
        insert(self.asteroids, asteroid)
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

local function drawPauseMenu(self, time)
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

local function drawAsteroids(self)
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
            table.insert(darkVerts, vx - 2)
            table.insert(darkVerts, vy + 2)
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

local function drawBullets(self, time)
    for _, bullet in ipairs(self.bullets) do
        -- additive glow core
        lg.setBlendMode("add")
        lg.setColor(1, 0.9, 0.45, 0.8)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 2.2)
        lg.setColor(1, 0.85, 0.2, 0.6)
        lg.circle("fill", bullet.x, bullet.y, bullet.size * 1.1)
        lg.setBlendMode("alpha")

        -- crisp core
        lg.setColor(1, 0.95, 0.7)
        lg.circle("fill", bullet.x, bullet.y, bullet.size)
        lg.setColor(1, 0.8, 0.15)
        lg.circle("line", bullet.x, bullet.y, bullet.size)
    end
    lg.setLineWidth(1)
    lg.setBlendMode("alpha")
end

local function drawPowerups(self, time)
    for _, powerup in ipairs(self.powerups) do
        lg.push()
        lg.translate(powerup.x, powerup.y)
        lg.rotate(powerup.rotation)

        -- subtle pulsing
        local pulse = 1 + 0.08 * sin(time * 6 + powerup.x * 0.01)

        if powerup.type == "boost" then
            lg.setBlendMode("add")
            lg.setColor(0.15, 0.55, 1, 0.65)
            lg.rectangle("fill", -powerup.size * 0.5 * pulse, -powerup.size * 0.5 * pulse, powerup.size * pulse,
                powerup.size * pulse, 4)
            lg.setBlendMode("alpha")
            lg.setColor(0.2, 0.6, 1)
            lg.rectangle("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size, powerup.size, 3)
        elseif powerup.type == "shield" then
            lg.setBlendMode("add")
            lg.setColor(0.12, 1, 0.45, 0.55)
            lg.circle("fill", 0, 0, powerup.size * pulse)
            lg.setBlendMode("alpha")
            lg.setColor(0.12, 1, 0.45)
            lg.circle("line", 0, 0, powerup.size)
        elseif powerup.type == "rapid" then
            lg.setBlendMode("add")
            lg.setColor(1, 0.35, 0.35, 0.6)
            lg.polygon("fill", -powerup.size * 0.5 * pulse, -powerup.size * 0.5 * pulse, powerup.size * 0.5 * pulse, 0,
                -powerup.size * 0.5 * pulse,
                powerup.size * 0.5 * pulse)
            lg.setBlendMode("alpha")
            lg.setColor(1, 0.3, 0.3)
            lg.polygon("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size * 0.5, 0, -powerup.size * 0.5,
                powerup.size * 0.5)
        end

        lg.setColor(1, 1, 1, 0.9)
        lg.pop()
    end
end

local function drawEnemy(self, time)
    for _, e in ipairs(self.enemy) do
        lg.push()
        lg.translate(e.x, e.y)
        lg.rotate(e.rotation)

        -- Base hue shifts slightly with time for alien feel
        local pulse = 0.6 + 0.4 * sin(time * 4 + e.x * 0.05)
        local coreHue = { 0.6 + 0.2 * pulse, 0.1 + 0.3 * pulse, 0.9 - 0.2 * pulse }

        -- Main hull: glowing diamond-like shape
        local s = e.size
        local hull = {
            0, -s * 1.2,        -- top tip
            -s * 0.8, -s * 0.3, -- left upper
            -s * 0.9, s * 0.8,  -- left bottom
            0, s * 1.0,         -- bottom tip
            s * 0.9, s * 0.8,   -- right bottom
            s * 0.8, -s * 0.3   -- right upper
        }

        -- Hull fill with subtle color shift
        lg.setColor(coreHue[1], coreHue[2], coreHue[3], 0.9)
        lg.polygon("fill", hull)

        -- Outer edge shimmer
        lg.setBlendMode("add")
        lg.setColor(0.4 + 0.3 * pulse, 0.8 * pulse, 1, 0.4)
        lg.polygon("line", hull)
        lg.setBlendMode("alpha")

        -- Cockpit dome (center glow)
        lg.setBlendMode("add")
        lg.setColor(0.2, 1, 0.7, 0.5 + 0.3 * pulse)
        lg.circle("fill", 0, -s * 0.3, s * 0.35 + 1.5 * pulse)
        lg.setBlendMode("alpha")

        -- Thruster glow behind
        lg.setBlendMode("add")
        local thrusterSize = s * (0.8 + 0.3 * sin(time * 10 + e.y))
        lg.setColor(1, 0.4, 0.1, 0.6 + 0.2 * sin(time * 8 + e.x))
        lg.circle("fill", 0, s * 1.2, thrusterSize * 0.4)
        lg.setBlendMode("alpha")

        -- Aggression indicator ring (based on health)
        if e.health <= 1 then
            lg.setBlendMode("add")
            lg.setColor(1, 0.2, 0.2, 0.3 + 0.2 * pulse)
            lg.circle("line", 0, 0, s * 1.6 + 2 * sin(time * 6))
            lg.setBlendMode("alpha")
        end

        -- Outline for clarity
        lg.setColor(0.1, 0.05, 0.05, 0.9)
        lg.setLineWidth(2)
        lg.polygon("line", hull)
        lg.setLineWidth(1)

        lg.pop()
    end
    lg.setBlendMode("alpha")
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
    instance.asteroids = {}
    instance.bullets = {}
    instance.powerups = {}
    instance.particles = {}
    instance.waveCooldown = 0

    instance.enemy = Enemy.new(instance.difficulty, screenWidth, screenHeight, PLAYER_SPAWN_X, PLAYER_SPAWN_Y)

    createPlayer(instance)
    createStarField(instance)
    createPauseButtons(instance)

    spawnAsteroids(instance, 4 + instance.level, 1)

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

    -- Return objects to pools
    for _, obj in ipairs(self.asteroids) do returnToPool(asteroidPool, obj) end
    for _, obj in ipairs(self.bullets) do returnToPool(bulletPool, obj) end
    for _, obj in ipairs(self.powerups) do returnToPool(powerupPool, obj) end

    self.enemy:reset()
    self.enemy.difficulty = self.difficulty

    self.asteroids = {}
    self.bullets = {}
    self.powerups = {}
    self.particles = {}

    createPlayer(self)
    spawnAsteroids(self, 4 + self.level, 1)
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
        local bullet = getFromPool(bulletPool)
        bullet.x = p.x + sin_angle * 20
        bullet.y = p.y - cos_angle * 20
        bullet.vx = sin_angle * 500
        bullet.vy = -cos_angle * 500
        bullet.life = 2
        bullet.size = 3
        bullet.enemy = nil

        insert(self.bullets, bullet)
        p.shootCooldown = 0.2
    end

    -- Update bullets
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        bullet.life = bullet.life - dt

        if bullet.life <= 0 or bullet.x < -50 or bullet.x > screenWidth + 50 or bullet.y < -50 or bullet.y > screenHeight + 50 then
            returnToPool(bulletPool, bullet)
            remove(self.bullets, i)
        end
    end

    -- Update asteroids
    for i = #self.asteroids, 1, -1 do
        local asteroid = self.asteroids[i]
        asteroid.x = asteroid.x + asteroid.vx * dt
        asteroid.y = asteroid.y + asteroid.vy * dt
        asteroid.rotation = asteroid.rotation + asteroid.rotationSpeed * dt
        wrapPosition(asteroid)

        if p.invulnerable <= 0 and checkCollision(p, asteroid) then
            p.lives = p.lives - 1
            p.invulnerable = 2

            if p.lives <= 0 then
                self.gameOver = true
                self.won = false
            end
        end
    end

    -- Update powerups
    for i = #self.powerups, 1, -1 do
        local powerup = self.powerups[i]
        powerup.x = powerup.x + powerup.vx * dt
        powerup.y = powerup.y + powerup.vy * dt
        powerup.rotation = powerup.rotation + dt
        powerup.life = powerup.life - dt

        wrapPosition(powerup)

        if powerup.life <= 0 then
            returnToPool(powerupPool, powerup)
            remove(self.powerups, i)
        elseif checkCollision(p, powerup) then
            if powerup.type == "boost" then
                p.boostTime = p.maxBoostTime
                p.boostCooldown = 0
            elseif powerup.type == "shield" then
                p.invulnerable = 5
            elseif powerup.type == "rapid" then
                p.shootCooldown = 0.1
            end
            returnToPool(powerupPool, powerup)
            remove(self.powerups, i)
        end
    end

    -- Update enemy using the Enemy module
    self.enemy:update(dt, p, self.bullets, self.powerups, bulletPool, powerupPool)

    -- Check enemy collision with player
    if self.enemy:checkPlayerCollision(p) and p.lives <= 0 then
        self.gameOver = true
        self.won = false
    end

    -- Check bullet collisions with player (enemy bullets)
    for i = #self.bullets, 1, -1 do
        local bullet = self.bullets[i]
        if bullet.enemy then
            if p.invulnerable <= 0 and checkCollision(p, bullet) then
                p.lives = p.lives - 1
                p.invulnerable = 2
                returnToPool(bulletPool, bullet)
                remove(self.bullets, i)

                if p.lives <= 0 then
                    self.gameOver = true
                    self.won = false
                end
            end
        else
            -- Player bullets vs asteroids
            for j = #self.asteroids, 1, -1 do
                local asteroid = self.asteroids[j]
                if checkCollision(bullet, asteroid) then
                    p.score = p.score + (4 - asteroid.level) * 25

                    if asteroid.level < 3 then
                        for _ = 1, 2 do
                            local newAsteroid = getFromPool(asteroidPool)
                            local created = createAsteroid(asteroid.x, asteroid.y, asteroid.size * 0.6,
                                asteroid.level + 1)
                            for k, v in pairs(created) do newAsteroid[k] = v end
                            newAsteroid.vx = newAsteroid.vx + (random() - 0.5) * 100
                            newAsteroid.vy = newAsteroid.vy + (random() - 0.5) * 100
                            generateAsteroidShape(newAsteroid)
                            insert(self.asteroids, newAsteroid)
                        end
                    end

                    if random() < 0.2 then
                        local powerup = getFromPool(powerupPool)
                        local newPowerup = createPowerup(asteroid.x, asteroid.y)
                        for k, v in pairs(newPowerup) do powerup[k] = v end
                        insert(self.powerups, powerup)
                    end

                    returnToPool(asteroidPool, asteroid)
                    remove(self.asteroids, j)
                    returnToPool(bulletPool, bullet)
                    remove(self.bullets, i)
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
    if #self.asteroids == 0 and self.enemy:getCount() == 0 then
        self.level = self.level + 1
        spawnAsteroids(self, 4 + self.level, 1)

        if self.level >= 5 then
            self.gameOver = true
            self.won = true
        end
    end
end

function Game:draw(time)
    lg.push()

    drawStarField(self, time)
    drawAsteroids(self)
    drawPowerups(self, time)
    self.enemy:draw(time)
    drawBullets(self, time)
    drawPlayer(self, time)
    drawUI(self, time)

    if self.gameOver then
        drawGameOver(self, time)
    elseif self.paused then
        drawPauseMenu(self, time)
    end

    lg.pop()
end

return Game
