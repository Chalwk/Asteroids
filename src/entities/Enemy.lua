-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, atan2, pi, sqrt = math.sin, math.atan2, math.pi, math.sqrt

local Enemy = {}
Enemy.__index = Enemy

local enemyPool = {}
local HALF_PI = pi * 0.5

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end
local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
end

function Enemy.new(difficulty, screenWidth, screenHeight, playerSpawnX, playerSpawnY)
    local instance = setmetatable({}, Enemy)

    instance.difficulty = difficulty
    instance.screenWidth = screenWidth
    instance.screenHeight = screenHeight
    instance.playerSpawnX = playerSpawnX
    instance.playerSpawnY = playerSpawnY
    instance.enemies = {}
    instance.spawnCooldown = 0

    return instance
end

function Enemy:create()
    local side = random(1, 4)
    local x, y

    if side == 1 then
        x, y = -50, random(0, self.screenHeight)
    elseif side == 2 then
        x, y = self.screenWidth + 50, random(0, self.screenHeight)
    elseif side == 3 then
        x, y = random(0, self.screenWidth), -50
    else
        x, y = random(0, self.screenWidth), self.screenHeight + 50
    end

    local speed = 100 + (self.difficulty == "easy" and 30 or self.difficulty == "medium" and 60 or 90)

    return {
        x = x,
        y = y,
        targetX = self.playerSpawnX,
        targetY = self.playerSpawnY,
        speed = speed,
        size = 25,
        health = 2,
        shootCooldown = 0,
        rotation = 0
    }
end

function Enemy:spawn()
    local enemy = getFromPool(enemyPool)
    local newEnemy = self:create()
    for k, v in pairs(newEnemy) do enemy[k] = v end
    insert(self.enemies, enemy)

    self.spawnCooldown = 15 - (self.difficulty == "easy" and 5 or self.difficulty == "medium" and 2 or 0)
end

function Enemy:update(dt, player, bulletManager)
    self.spawnCooldown = self.spawnCooldown - dt
    if self.spawnCooldown <= 0 then self:spawn() end

    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]

        -- Movement
        local dx, dy = player.x - e.x, player.y - e.y
        local dist = (dx * dx + dy * dy) ^ 0.5
        if dist > 0 then
            e.vx = (dx / dist) * e.speed
            e.vy = (dy / dist) * e.speed
        end

        e.x = e.x + e.vx * dt
        e.y = e.y + e.vy * dt
        e.rotation = atan2(e.vy, e.vx) + HALF_PI

        -- Shooting
        e.shootCooldown = e.shootCooldown - dt
        if e.shootCooldown <= 0 then
            -- Calculate direction towards player
            local px, py = player.x - e.x, player.y - e.y
            local pdist = sqrt(px * px + py * py)
            local vx, vy = 0, 400
            if pdist > 0 then
                vx = (px / pdist) * 400
                vy = (py / pdist) * 400
            end

            bulletManager:create(e.x, e.y, vx, vy, 3, 4, true)
            e.shootCooldown = 1.5 - (self.difficulty == "hard" and 0.5 or 0)
        end

        -- Check collisions with player bullets
        for j = #bulletManager:getBullets(), 1, -1 do
            local bullet = bulletManager:getBullets()[j]
            if not bullet.enemy and self:checkCollision(e, bullet) then
                e.health = e.health - 1
                bulletManager:removeBullet(j)

                if e.health <= 0 then
                    player.score = player.score + 200
                    returnToPool(enemyPool, e)
                    remove(self.enemies, i)
                    break
                end
            end
        end
    end
end

function Enemy:checkCollision(a, b)
    local minDist = (a.size or a.radius or 0) + (b.size or b.radius or 0)
    local dx, dy = b.x - a.x, b.y - a.y
    return dx * dx + dy * dy < minDist * minDist
end

function Enemy:checkPlayerCollision(player)
    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]
        if player.invulnerable <= 0 and self:checkCollision(player, e) then
            player.lives = player.lives - 1
            player.invulnerable = 2
            returnToPool(enemyPool, e)
            remove(self.enemies, i)
            return true
        end
    end
    return false
end

function Enemy:draw(time)
    for _, e in ipairs(self.enemies) do
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

function Enemy:reset()
    for _, obj in ipairs(self.enemies) do returnToPool(enemyPool, obj) end
    self.enemies = {}
    self.spawnCooldown = 0
end

function Enemy:getCount() return #self.enemies end

return Enemy
