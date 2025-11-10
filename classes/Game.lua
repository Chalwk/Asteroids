-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

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
local emepyPool = {}

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
    self.stars = {}
    for i = 1, 200 do
        self.stars[i] = {
            x = random(0, screenWidth),
            y = random(0, screenHeight),
            speed = random(50, 200),
            size = random(1, 3),
            brightness = random(0.3, 1)
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

local function createEmepy(self)
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
            x = centerX - 100,
            y = centerY - 60,
            width = 200,
            height = 50,
            color = { 0.2, 0.7, 0.3 }
        },
        {
            text = "Restart",
            action = "restart",
            x = centerX - 100,
            y = centerY + 10,
            width = 200,
            height = 50,
            color = { 0.9, 0.7, 0.2 }
        },
        {
            text = "Main Menu",
            action = "menu",
            x = centerX - 100,
            y = centerY + 80,
            width = 200,
            height = 50,
            color = { 0.8, 0.3, 0.3 }
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

local function drawUI(self)
    -- Score
    lg.setColor(1, 1, 1, 0.9)
    self.fonts:setFont("mediumFont")
    lg.print("SCORE: " .. self.player.score, 20, 20)

    -- Lives
    for i = 1, self.player.lives do
        lg.setColor(1, 1, 1, 0.8)
        lg.push()
        lg.translate(20 + (i - 1) * 30, 60)
        lg.rotate(-HALF_PI)
        lg.polygon("fill", 0, -8, -6, 8, 6, 8)
        lg.pop()
    end

    -- Boost meter
    local boostPercent = self.player.boostTime / self.player.maxBoostTime
    local boostWidth = 200
    lg.setColor(0.3, 0.3, 0.5, 0.7)
    lg.rectangle("fill", 20, 90, boostWidth, 15)
    lg.setColor(0.2, 0.6, 1, 0.9)
    lg.rectangle("fill", 20, 90, boostWidth * boostPercent, 15)
    lg.setColor(1, 1, 1, 0.8)
    lg.rectangle("line", 20, 90, boostWidth, 15)

    -- Difficulty and Level
    lg.setColor(1, 1, 1, 0.6)
    self.fonts:setFont("smallFont")
    lg.print("Difficulty: " .. self.difficulty:upper(), screenWidth - 150, 20)
    lg.print("Level: " .. self.level, screenWidth - 150, 45)

    if self.paused then
        lg.setColor(1, 0.8, 0.2, 0.9)
        self.fonts:setFont("mediumFont")
        lg.print("PAUSED - Press P or ESC to resume", screenWidth * 0.5 - 150, 40)
    end
end

local function drawGameOver(self)
    lg.setColor(0, 0, 0, 0.7)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    self.fonts:setFont("largeFont")
    lg.setColor(self.won and { 0.2, 0.8, 0.2 } or { 0.8, 0.2, 0.2 })
    lg.printf(self.won and "MISSION COMPLETE!" or "GAME OVER", 0, screenHeight / 2 - 80, screenWidth, "center")

    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("FINAL SCORE: " .. self.player.score, 0, screenHeight / 2, screenWidth, "center")

    self.fonts:setFont("smallFont")
    lg.printf("Click anywhere to continue", 0, screenHeight / 2 + 60, screenWidth, "center")
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

        lg.setColor(r, g, b, isHovered and 0.9 or 0.7)
        lg.rectangle("fill", button.x, button.y, button.width, button.height, 10)

        lg.setColor(1, 1, 1, isHovered and 1 or 0.8)
        lg.setLineWidth(isHovered and 3 or 2)
        lg.rectangle("line", button.x, button.y, button.width, button.height, 10)

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

    -- Main ship body
    lg.setColor(0.8, 0.9, 1)
    lg.polygon("fill", 0, -p.size, -p.size * 0.7, p.size, p.size * 0.7, p.size)

    -- Engine effects
    if p.speed > 0 then
        local glowSize = p.size * 0.8 * (0.8 + sin(time * 10) * 0.2)
        lg.setColor(1, 0.6, 0.2, 0.8)
        lg.polygon("fill", -p.size * 0.4, p.size, 0, p.size + glowSize, p.size * 0.4, p.size)
    end

    if p.boostTime > 0 then
        local boostSize = p.size * 1.5 * (0.9 + sin(time * 15) * 0.1)
        lg.setColor(0.2, 0.8, 1, 0.7)
        lg.polygon("fill", -p.size * 0.3, p.size, 0, p.size + boostSize, p.size * 0.3, p.size)
    end

    lg.pop()
end

local function drawAsteroids(self)
    for _, asteroid in ipairs(self.asteroids) do
        lg.push()
        lg.translate(asteroid.x, asteroid.y)
        lg.rotate(asteroid.rotation)

        lg.setColor(0.7, 0.6, 0.5)
        lg.polygon("line", asteroid.vertices)
        lg.setColor(0.4, 0.35, 0.3, 0.3)
        lg.polygon("fill", asteroid.vertices)

        lg.pop()
    end
end

local function drawBullets(self)
    for _, bullet in ipairs(self.bullets) do
        lg.setColor(1, 1, 0.5)
        lg.circle("fill", bullet.x, bullet.y, bullet.size)
        lg.setColor(1, 0.8, 0.2)
        lg.circle("line", bullet.x, bullet.y, bullet.size)
    end
end

local function drawPowerups(self)
    for _, powerup in ipairs(self.powerups) do
        lg.push()
        lg.translate(powerup.x, powerup.y)
        lg.rotate(powerup.rotation)

        if powerup.type == "boost" then
            lg.setColor(0.2, 0.6, 1)
            lg.rectangle("fill", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size, powerup.size, 3)
        elseif powerup.type == "shield" then
            lg.setColor(0.2, 1, 0.4)
            lg.circle("fill", 0, 0, powerup.size)
        elseif powerup.type == "rapid" then
            lg.setColor(1, 0.3, 0.3)
            lg.polygon("fill", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size * 0.5, 0, -powerup.size * 0.5,
                powerup.size * 0.5)
        end

        lg.setColor(1, 1, 1, 0.8)
        if powerup.type == "boost" then
            lg.rectangle("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size, powerup.size, 3)
        elseif powerup.type == "shield" then
            lg.circle("line", 0, 0, powerup.size)
        else
            lg.polygon("line", -powerup.size * 0.5, -powerup.size * 0.5, powerup.size * 0.5, 0, -powerup.size * 0.5,
                powerup.size * 0.5)
        end

        lg.pop()
    end
end

local function drawEmepy(self)
    for _, emepy in ipairs(self.emepy) do
        lg.push()
        lg.translate(emepy.x, emepy.y)
        lg.rotate(emepy.rotation)

        lg.setColor(1, 0.3, 0.3)
        lg.polygon("fill", 0, -emepy.size, -emepy.size, emepy.size, emepy.size, emepy.size)

        lg.setColor(1, 0.6, 0.2, 0.7)
        lg.polygon("fill", -emepy.size * 0.3, emepy.size, 0, emepy.size * 1.5, emepy.size * 0.3, emepy.size)

        lg.pop()
    end
end

local function drawStarField(self)
    for _, star in ipairs(self.stars) do
        lg.setColor(1, 1, 1, star.brightness * 0.8)
        lg.circle("fill", star.x, star.y, star.size)
    end
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
    instance.emepy = {}
    instance.particles = {}
    instance.waveCooldown = 0
    instance.emepySpawnCooldown = 0

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
    for _, obj in ipairs(self.emepy) do returnToPool(emepyPool, obj) end

    self.asteroids = {}
    self.bullets = {}
    self.powerups = {}
    self.emepy = {}
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
        local acceleration = p.acceleration * (boosting and p.boostPower or 1)
        p.speed = min(p.speed + acceleration * dt, p.maxSpeed)

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

    -- Update Emepy
    self.emepySpawnCooldown = self.emepySpawnCooldown - dt
    if self.emepySpawnCooldown <= 0 then
        local emepy = getFromPool(emepyPool)
        local newEmepy = createEmepy(self)
        for k, v in pairs(newEmepy) do emepy[k] = v end
        insert(self.emepy, emepy)

        self.emepySpawnCooldown = 15 - (self.difficulty == "easy" and 5 or self.difficulty == "medium" and 2 or 0)
    end

    for i = #self.emepy, 1, -1 do
        local e = self.emepy[i]

        -- Movement
        local dx, dy = p.x - e.x, p.y - e.y
        local dist = (dx * dx + dy * dy) ^ 0.5
        if dist > 0 then
            e.vx = (dx / dist) * e.speed
            e.vy = (dy / dist) * e.speed
        end

        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        e.rotation = atan2(e.vy, e.vx)

        -- Shooting
        e.shootCooldown = e.shootCooldown - dt
        if e.shootCooldown <= 0 then
            local bullet = getFromPool(bulletPool)
            bullet.x = e.x
            bullet.y = e.y
            bullet.vx = cos(e.rotation) * 400
            bullet.vy = sin(e.rotation) * 400
            bullet.life = 3
            bullet.size = 4
            bullet.enemy = true

            insert(self.bullets, bullet)
            e.shootCooldown = 1.5 - (self.difficulty == "hard" and 0.5 or 0)
        end

        -- Check collisions
        for j = #self.bullets, 1, -1 do
            local bullet = self.bullets[j]
            if not bullet.enemy and checkCollision(e, bullet) then
                e.health = e.health - 1
                returnToPool(bulletPool, bullet)
                remove(self.bullets, j)

                if e.health <= 0 then
                    p.score = p.score + 200
                    if random() < 0.3 then
                        local powerup = getFromPool(powerupPool)
                        local newPowerup = createPowerup(e.x, e.y)
                        for k, v in pairs(newPowerup) do powerup[k] = v end
                        insert(self.powerups, powerup)
                    end
                    returnToPool(emepyPool, e)
                    remove(self.emepy, i)
                    break
                end
            end
        end

        if p.invulnerable <= 0 and checkCollision(p, e) then
            p.lives = p.lives - 1
            p.invulnerable = 2
            returnToPool(emepyPool, e)
            remove(self.emepy, i)

            if p.lives <= 0 then
                self.gameOver = true
                self.won = false
            end
        end
    end

    -- Check bullet collisions
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

    -- Update star field
    local speedFactor = p.speed / 300
    local moveX = -sin_angle * speedFactor * dt
    local moveY = cos_angle * speedFactor * dt

    for _, star in ipairs(self.stars) do
        star.x = star.x + moveX * star.speed
        star.y = star.y + moveY * star.speed

        if star.x < -10 then
            star.x = screenWidth + 10
        elseif star.x > screenWidth + 10 then
            star.x = -10
        end

        if star.y < -10 then
            star.y = screenHeight + 10
        elseif star.y > screenHeight + 10 then
            star.y = -10
        end
    end

    -- Check level completion
    if #self.asteroids == 0 and #self.emepy == 0 then
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

    drawStarField(self)
    drawAsteroids(self)
    drawPowerups(self)
    drawEmepy(self)
    drawBullets(self)
    drawPlayer(self, time)
    drawUI(self)

    if self.gameOver then
        drawGameOver(self)
    elseif self.paused then
        drawPauseMenu(self)
    end

    lg.pop()
end

return Game
