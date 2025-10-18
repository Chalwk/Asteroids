-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local math_sqrt = math.sqrt
local math_max = math.max
local table_insert = table.insert
local table_remove = table.remove

local Player = require("classes/player")
local Asteroid = require("classes/asteroid")
local Bullet = require("classes/bullet")
local Alien = require("classes/alien")
local Starfield = require("classes/starfield")

local gameState = "menu" -- menu, playing, gameOver
local score = 0
local highScore = 0
local lives = 3
local level = 1
local player = {}
local asteroids = {}
local bullets = {}
local aliens = {}
local particles = {}
local starfield = {} -- Starfield instance
local screenWidth, screenHeight
local gameFont, titleFont
local spawnTimer = 0
local alienSpawnTimer = 0
local levelClearTimer = 0

local colors = {
    white = { 1, 1, 1 },
    red = { 1, 0, 0 },
    green = { 0, 1, 0 },
    blue = { 0.2, 0.4, 1 },
    yellow = { 1, 1, 0 },
    purple = { 0.6, 0.2, 0.8 }
}

local function distance(x1, y1, x2, y2)
    return math_sqrt((x2 - x1) ^ 2 + (y2 - y1) ^ 2)
end

local function spawnAsteroids(count)
    for _ = 1, count do
        local size = "large"
        local x, y

        -- Spawn asteroids away from player
        repeat
            x = love.math.random(0, screenWidth)
            y = love.math.random(0, screenHeight)
        until distance(x, y, player.x, player.y) > 200

        table_insert(asteroids, Asteroid:new(x, y, size))
    end
end

local function spawnAlien()
    local side = love.math.random(4)
    local x, y, vx, vy

    if side == 1 then -- Top
        x = love.math.random(screenWidth)
        y = -50
        vx = (love.math.random() - 0.5) * 50
        vy = love.math.random(30, 60)
    elseif side == 2 then -- Right
        x = screenWidth + 50
        y = love.math.random(screenHeight)
        vx = -love.math.random(30, 60)
        vy = (love.math.random() - 0.5) * 50
    elseif side == 3 then -- Bottom
        x = love.math.random(screenWidth)
        y = screenHeight + 50
        vx = (love.math.random() - 0.5) * 50
        vy = -love.math.random(30, 60)
    else -- Left
        x = -50
        y = love.math.random(screenHeight)
        vx = love.math.random(30, 60)
        vy = (love.math.random() - 0.5) * 50
    end

    table_insert(aliens, Alien:new(x, y, vx, vy))
end

local function resetGame()
    gameState = "playing"
    score = 0
    lives = 3
    level = 1
    asteroids = {}
    bullets = {}
    aliens = {}
    particles = {}
    spawnTimer = 0
    alienSpawnTimer = 0
    levelClearTimer = 0

    player = Player:new(screenWidth / 2, screenHeight / 2)
    spawnAsteroids(4 + level)
end

local function createParticles(x, y, count, color)
    for i = 1, count do
        table_insert(particles, {
            x = x,
            y = y,
            vx = (love.math.random() - 0.5) * 100,
            vy = (love.math.random() - 0.5) * 100,
            life = 1,
            color = color or colors.white
        })
    end
end

local function checkCollisions()
    -- Player vs Asteroids
    for i = #asteroids, 1, -1 do
        local asteroid = asteroids[i]
        if distance(player.x, player.y, asteroid.x, asteroid.y) < player.radius + asteroid.radius then
            if player:hit() then
                lives = lives - 1
                createParticles(player.x, player.y, 10, colors.red)
                if lives <= 0 then
                    gameState = "gameOver"
                    highScore = math_max(highScore, score)
                end
            end
            createParticles(player.x, player.y, 10, colors.red)
            if lives <= 0 then
                gameState = "gameOver"
                highScore = math_max(highScore, score)
            end
            break
        end
    end

    -- Bullets vs Asteroids
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        for j = #asteroids, 1, -1 do
            local asteroid = asteroids[j]
            if distance(bullet.x, bullet.y, asteroid.x, asteroid.y) < asteroid.radius then
                -- Split asteroid or destroy it
                if asteroid.size == "large" then
                    table_insert(asteroids,
                        Asteroid:new(asteroid.x, asteroid.y, "medium", asteroid.vx * 0.7, asteroid.vy * 0.7))
                    table_insert(asteroids,
                        Asteroid:new(asteroid.x, asteroid.y, "medium", -asteroid.vx * 0.7, -asteroid.vy * 0.7))
                    score = score + 20
                elseif asteroid.size == "medium" then
                    table_insert(asteroids,
                        Asteroid:new(asteroid.x, asteroid.y, "small", asteroid.vx * 1.2, asteroid.vy * 1.2))
                    table_insert(asteroids,
                        Asteroid:new(asteroid.x, asteroid.y, "small", -asteroid.vx * 1.2, -asteroid.vy * 1.2))
                    score = score + 50
                else
                    score = score + 100
                end

                createParticles(asteroid.x, asteroid.y, 8, colors.white)
                table_remove(asteroids, j)
                table_remove(bullets, i)
                break
            end
        end
    end

    -- Bullets vs Aliens
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        for j = #aliens, 1, -1 do
            local alien = aliens[j]
            if distance(bullet.x, bullet.y, alien.x, alien.y) < alien.radius then
                alien:hit()
                createParticles(alien.x, alien.y, 12, colors.green)
                score = score + 200
                table_remove(aliens, j)
                table_remove(bullets, i)
                break
            end
        end
    end

    -- Alien bullets vs Player
    for _, alien in ipairs(aliens) do
        for i = #alien.bullets, 1, -1 do
            local bullet = alien.bullets[i]
            if distance(bullet.x, bullet.y, player.x, player.y) < player.radius + 2 then
                player:hit()
                createParticles(player.x, player.y, 8, colors.red)
                table_remove(alien.bullets, i)
                if lives <= 0 then
                    gameState = "gameOver"
                    highScore = math.max(highScore, score)
                end
                break
            end
        end
    end
end

local function checkLevelComplete()
    if #asteroids == 0 and #aliens == 0 then
        levelClearTimer = levelClearTimer + love.timer.getDelta()
        if levelClearTimer > 2 then -- 2 second delay before next level
            level = level + 1
            spawnAsteroids(4 + level)
            levelClearTimer = 0
        end
    else
        levelClearTimer = 0
    end
end

function love.load()
    screenWidth = love.graphics.getWidth()
    screenHeight = love.graphics.getHeight()

    gameFont = love.graphics.newFont(20)
    titleFont = love.graphics.newFont(40)

    -- Initialize the starfield
    starfield = Starfield:new(screenWidth, screenHeight)

    -- Don't reset game immediately - start in menu
    player = Player:new(screenWidth / 2, screenHeight / 2)
end

function love.update(dt)
    -- Update starfield
    starfield:update(dt)

    if gameState == "playing" then
        player:update(dt)

        -- Update asteroids
        for i = #asteroids, 1, -1 do
            asteroids[i]:update(dt)
        end

        -- Update bullets
        for i = #bullets, 1, -1 do
            bullets[i]:update(dt)
            if bullets[i].life <= 0 then
                table_remove(bullets, i)
            end
        end

        -- Update aliens
        for i = #aliens, 1, -1 do
            aliens[i]:update(dt, player.x, player.y, screenWidth, screenHeight)
            if aliens[i].life <= 0 then
                table_remove(aliens, i)
            end
        end

        -- Update particles
        for i = #particles, 1, -1 do
            particles[i].x = particles[i].x + particles[i].vx * dt
            particles[i].y = particles[i].y + particles[i].vy * dt
            particles[i].life = particles[i].life - dt

            if particles[i].life <= 0 then
                table_remove(particles, i)
            end
        end

        -- Spawn new asteroids occasionally
        spawnTimer = spawnTimer + dt
        if spawnTimer > 5 and #asteroids < 3 + level then
            spawnAsteroids(1)
            spawnTimer = 0
        end

        -- Spawn aliens
        alienSpawnTimer = alienSpawnTimer + dt
        if alienSpawnTimer > 10 + love.math.random(10) and #aliens == 0 then
            spawnAlien()
            alienSpawnTimer = 0
        end

        checkCollisions()
        checkLevelComplete()
    end
end

function love.draw()
    -- Draw starfield (background, planets, and stars)
    starfield:draw()

    if gameState == "menu" then
        -- Menu title with glow effect
        love.graphics.setColor(colors.blue)
        love.graphics.setFont(titleFont)
        love.graphics.printf("ASTEROIDS", 2, screenHeight / 3 - 2, screenWidth, "center")

        love.graphics.setColor(colors.white)
        love.graphics.printf("ASTEROIDS", 0, screenHeight / 3, screenWidth, "center")

        love.graphics.setFont(gameFont)

        -- Menu options
        love.graphics.setColor(colors.yellow)
        love.graphics.printf("Press SPACE to Start Game", 0, screenHeight / 2, screenWidth, "center")

        love.graphics.setColor(colors.green)
        love.graphics.printf("Arrow Keys or WASD: Move", 0, screenHeight / 2 + 40, screenWidth, "center")
        love.graphics.printf("Space: Shoot", 0, screenHeight / 2 + 70, screenWidth, "center")
        love.graphics.printf("Ctrl: Boost", 0, screenHeight / 2 + 100, screenWidth, "center")

        love.graphics.setColor(colors.purple)
        love.graphics.printf("Press ESC to Quit", 0, screenHeight / 2 + 140, screenWidth, "center")

        -- High score display
        if highScore > 0 then
            love.graphics.setColor(colors.white)
            love.graphics.printf("High Score: " .. highScore, 0, screenHeight / 2 + 170, screenWidth, "center")
        end
    elseif gameState == "playing" then
        -- Draw all game objects
        for _, asteroid in ipairs(asteroids) do
            asteroid:draw()
        end

        for _, bullet in ipairs(bullets) do
            bullet:draw()
        end

        for _, alien in ipairs(aliens) do
            alien:draw()
        end

        for _, particle in ipairs(particles) do
            love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], particle.life)
            love.graphics.points(particle.x, particle.y)
        end

        player:draw()

        -- Draw UI
        love.graphics.setColor(colors.white)
        love.graphics.setFont(gameFont)
        love.graphics.print("Score: " .. score, 10, 10)
        love.graphics.print("Lives: " .. lives, 10, 40)
        love.graphics.print("Level: " .. level, 10, 70)

        if #asteroids == 0 and #aliens == 0 then
            love.graphics.printf("LEVEL " .. level .. " COMPLETE!", 0, screenHeight / 2 - 50, screenWidth, "center")
        end
        -- Draw boost UI
        if player.boostCooldownRemaining > 0 then
            love.graphics.setColor(0.5, 0.5, 0.5) -- Gray when on cooldown
            love.graphics.print("Boost: " .. string_format("%.1f", player.boostCooldownRemaining) .. "s", 10, 100)
        elseif player.boostActive then
            love.graphics.setColor(0.2, 0.8, 1) -- Cyan when active
            love.graphics.print("BOOST ACTIVE!", 10, 100)
        else
            love.graphics.setColor(0, 1, 0) -- Green when ready
            love.graphics.print("Boost: READY (CTRL)", 10, 100)
        end
    elseif gameState == "gameOver" then
        love.graphics.setColor(colors.red)
        love.graphics.setFont(titleFont)
        love.graphics.printf("GAME OVER", 2, screenHeight / 3 - 2, screenWidth, "center")

        love.graphics.setColor(colors.white)
        love.graphics.printf("GAME OVER", 0, screenHeight / 3, screenWidth, "center")

        love.graphics.setFont(gameFont)
        love.graphics.printf("Final Score: " .. score, 0, screenHeight / 2, screenWidth, "center")
        love.graphics.printf("High Score: " .. highScore, 0, screenHeight / 2 + 40, screenWidth, "center")

        love.graphics.setColor(colors.yellow)
        love.graphics.printf("Press SPACE to Play Again", 0, screenHeight / 2 + 100, screenWidth, "center")

        love.graphics.setColor(colors.green)
        love.graphics.printf("Press ESC for Main Menu", 0, screenHeight / 2 + 140, screenWidth, "center")
    end
end

function love.keypressed(key)
    if key == "space" then
        if gameState == "menu" or gameState == "gameOver" then
            resetGame()
        elseif gameState == "playing" then
            local bullet = player:shoot()
            if bullet then
                table_insert(bullets, bullet)
            end
        end
    elseif key == "lctrl" or key == "rctrl" then
        if gameState == "playing" then
            player:activateBoost()
        end
    elseif key == "escape" then
        if gameState == "gameOver" or gameState == "playing" then
            -- Return to main menu
            gameState = "menu"
            -- Clear game objects
            asteroids = {}
            bullets = {}
            aliens = {}
            particles = {}
        else
            love.event.quit()
        end
    end
end

-- Make player shoot function available to love.keypressed
function getPlayer() return player end

-- Make bullets table available for alien to add bullets
function getBulletsTable() return bullets end

function wrapPosition(x, y)
    if x < 0 then x = screenWidth end
    if x > screenWidth then x = 0 end
    if y < 0 then y = screenHeight end
    if y > screenHeight then y = 0 end
    return x, y
end

function getScreenWidth() return screenWidth end

function getScreenHeight() return screenHeight end