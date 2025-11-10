-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local pairs, ipairs = pairs, ipairs
local lg = love.graphics
local random = love.math.random
local insert, remove = table.insert, table.remove
local sin, cos, atan2, pi, sqrt = math.sin, math.cos, math.atan2, math.pi, math.sqrt

local Enemy = {}
Enemy.__index = Enemy

local enemyPool = {}
local HALF_PI = pi * 0.5

local function getFromPool(pool) return #pool > 0 and remove(pool) or {} end
local function returnToPool(pool, obj)
    for k in pairs(obj) do obj[k] = nil end
    insert(pool, obj)
end

local BEHAVIOR_STATES = {
    APPROACH = 1, -- Move toward player
    EVADE = 2,    -- Move away from player/danger
    FLANK = 3,    -- Move to player's side
    ORBIT = 4,    -- Circle around player
    STRAFING = 5, -- Side-to-side movement while approaching
    SWARM = 6,    -- Group coordination
    AMBUSH = 7    -- Wait and attack from position
}

function Enemy.new(difficulty, playerSpawnX, playerSpawnY)
    local instance = setmetatable({}, Enemy)

    instance.difficulty = difficulty
    instance.playerSpawnX = playerSpawnX
    instance.playerSpawnY = playerSpawnY
    instance.enemies = {}
    instance.spawnCooldown = 0
    instance.swarmCenter = { x = screenWidth / 2, y = screenHeight / 2 }
    instance.lastSwarmUpdate = 0

    return instance
end

function Enemy:create()
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

    local baseSpeed = 100 + (self.difficulty == "easy" and 30 or self.difficulty == "medium" and 60 or 90)
    local health = self.difficulty == "easy" and 2 or self.difficulty == "medium" and 3 or 4

    -- Assign AI personality based on difficulty
    local aiProfile
    if self.difficulty == "easy" then
        aiProfile = {
            aggression = 0.3,
            accuracy = 0.4,
            evasion = 0.2,
            preferredRange = 200,
            behaviorChangeRate = 0.1
        }
    elseif self.difficulty == "medium" then
        aiProfile = {
            aggression = 0.6,
            accuracy = 0.7,
            evasion = 0.4,
            preferredRange = 150,
            behaviorChangeRate = 0.2
        }
    else
        aiProfile = {
            aggression = 0.9,
            accuracy = 0.85,
            evasion = 0.7,
            preferredRange = 100,
            behaviorChangeRate = 0.3
        }
    end

    return {
        x = x,
        y = y,
        targetX = self.playerSpawnX,
        targetY = self.playerSpawnY,
        speed = baseSpeed,
        size = 25,
        health = health,
        shootCooldown = 0,
        rotation = 0,

        -- AI System
        behavior = BEHAVIOR_STATES.APPROACH,
        behaviorTimer = 0,
        lastBehaviorChange = 0,
        aiProfile = aiProfile,

        -- Movement patterns
        orbitAngle = random() * pi * 2,
        orbitDistance = 150 + random(100),
        strafeDirection = random() > 0.5 and 1 or -1,
        strafeTimer = 0,

        -- Advanced targeting
        predictiveTargeting = false,
        targetLead = 0,
        lastPlayerPositions = {},

        -- Swarm behavior
        swarmOffsetAngle = random() * pi * 2,
        swarmDistance = 80 + random(40)
    }
end

function Enemy:spawn()
    local enemy = getFromPool(enemyPool)
    local newEnemy = self:create()
    for k, v in pairs(newEnemy) do enemy[k] = v end
    insert(self.enemies, enemy)

    self.spawnCooldown = 15 - (self.difficulty == "easy" and 5 or self.difficulty == "medium" and 2 or 0)
end

function Enemy:updateSwarmCenter(player)
    -- Update swarm center less frequently for performance
    self.lastSwarmUpdate = self.lastSwarmUpdate - 1
    if self.lastSwarmUpdate <= 0 then
        local totalX, totalY, count = 0, 0, 0
        for _, e in ipairs(self.enemies) do
            totalX = totalX + e.x
            totalY = totalY + e.y
            count = count + 1
        end

        if count > 0 then
            -- Blend swarm center with player position for more dynamic behavior
            local blend = 0.7
            self.swarmCenter.x = (totalX / count) * blend + player.x * (1 - blend)
            self.swarmCenter.y = (totalY / count) * blend + player.y * (1 - blend)
        else
            self.swarmCenter.x = player.x
            self.swarmCenter.y = player.y
        end
        self.lastSwarmUpdate = 10
    end
end

function Enemy:updateBehavior(dt, enemy, player)
    enemy.behaviorTimer = enemy.behaviorTimer - dt
    enemy.lastBehaviorChange = enemy.lastBehaviorChange - dt

    -- Change behavior periodically or when conditions warrant
    if enemy.lastBehaviorChange <= 0 or enemy.behaviorTimer <= 0 then
        local shouldChange = random() < enemy.aiProfile.behaviorChangeRate

        if shouldChange then
            local distanceToPlayer = sqrt((player.x - enemy.x) ^ 2 + (player.y - enemy.y) ^ 2)
            local nearbyEnemies = 0

            -- Count nearby enemies for swarm behavior
            for _, other in ipairs(self.enemies) do
                if other ~= enemy then
                    local dist = sqrt((other.x - enemy.x) ^ 2 + (other.y - enemy.y) ^ 2)
                    if dist < 120 then nearbyEnemies = nearbyEnemies + 1 end
                end
            end

            -- Behavior selection logic
            if distanceToPlayer < 80 and enemy.health <= 1 then
                enemy.behavior = BEHAVIOR_STATES.EVADE -- Low health enemies evade
            elseif distanceToPlayer > 300 then
                enemy.behavior = BEHAVIOR_STATES.APPROACH
            elseif nearbyEnemies >= 2 and self.difficulty ~= "easy" then
                enemy.behavior = BEHAVIOR_STATES.SWARM
            elseif distanceToPlayer < enemy.aiProfile.preferredRange then
                -- Choose between orbit, strafing, or flanking when in range
                local choices = { BEHAVIOR_STATES.ORBIT, BEHAVIOR_STATES.STRAFING, BEHAVIOR_STATES.FLANK }
                enemy.behavior = choices[random(1, #choices)]
            else
                enemy.behavior = BEHAVIOR_STATES.APPROACH
            end

            enemy.behaviorTimer = 2 + random(3)      -- Behavior duration
            enemy.lastBehaviorChange = 1 + random(2) -- Cooldown between changes
        end
    end

    -- Store recent player positions for predictive targeting
    insert(enemy.lastPlayerPositions, 1, { x = player.x, y = player.y })
    if #enemy.lastPlayerPositions > 5 then
        remove(enemy.lastPlayerPositions)
    end

    -- Enable predictive targeting based on difficulty and conditions
    enemy.predictiveTargeting = #enemy.lastPlayerPositions >= 3 and
        random() < enemy.aiProfile.accuracy and
        self.difficulty ~= "easy"
end

function Enemy:executeBehavior(dt, enemy, player, bulletManager)
    local dx, dy = player.x - enemy.x, player.y - enemy.y
    local distance = sqrt(dx * dx + dy * dy)
    local directionX, directionY = dx / distance, dy / distance

    -- Base movement speed with variations
    local moveSpeed = enemy.speed * (0.8 + random() * 0.4)

    if enemy.behavior == BEHAVIOR_STATES.APPROACH then
        -- Direct approach with slight randomness
        local randomness = self.difficulty == "easy" and 0.1 or 0.05
        enemy.vx = directionX * moveSpeed + (random() - 0.5) * randomness * moveSpeed
        enemy.vy = directionY * moveSpeed + (random() - 0.5) * randomness * moveSpeed
    elseif enemy.behavior == BEHAVIOR_STATES.EVADE then
        -- Evade by moving away from player
        enemy.vx = -directionX * moveSpeed * 1.2
        enemy.vy = -directionY * moveSpeed * 1.2
    elseif enemy.behavior == BEHAVIOR_STATES.FLANK then
        -- Move to player's side
        local flankDirection = random() > 0.5 and 1 or -1
        local perpendicularX = -directionY * flankDirection
        local perpendicularY = directionX * flankDirection

        -- Blend flanking with some approach
        local approachWeight = 0.3
        enemy.vx = (perpendicularX * 0.7 + directionX * approachWeight) * moveSpeed
        enemy.vy = (perpendicularY * 0.7 + directionY * approachWeight) * moveSpeed
    elseif enemy.behavior == BEHAVIOR_STATES.ORBIT then
        -- Circular movement around player
        enemy.orbitAngle = enemy.orbitAngle + dt * 2
        local targetX = player.x + cos(enemy.orbitAngle) * enemy.orbitDistance
        local targetY = player.y + sin(enemy.orbitAngle) * enemy.orbitDistance

        local orbitDx, orbitDy = targetX - enemy.x, targetY - enemy.y
        local orbitDist = sqrt(orbitDx * orbitDx + orbitDy * orbitDy)
        if orbitDist > 0 then
            enemy.vx = (orbitDx / orbitDist) * moveSpeed
            enemy.vy = (orbitDy / orbitDist) * moveSpeed
        end
    elseif enemy.behavior == BEHAVIOR_STATES.STRAFING then
        -- Side-to-side movement while maintaining distance
        enemy.strafeTimer = enemy.strafeTimer + dt
        local strafeAmount = sin(enemy.strafeTimer * 3) * 2

        local perpendicularX = -directionY * enemy.strafeDirection
        local perpendicularY = directionX * enemy.strafeDirection

        -- Maintain preferred range
        local rangeControl = 0
        if distance > enemy.aiProfile.preferredRange + 50 then
            rangeControl = 0.5  -- Move toward preferred range
        elseif distance < enemy.aiProfile.preferredRange - 50 then
            rangeControl = -0.3 -- Move away if too close
        end

        enemy.vx = (perpendicularX * strafeAmount + directionX * rangeControl) * moveSpeed
        enemy.vy = (perpendicularY * strafeAmount + directionY * rangeControl) * moveSpeed
    elseif enemy.behavior == BEHAVIOR_STATES.SWARM then
        -- Coordinated group movement
        local toSwarmX, toSwarmY = self.swarmCenter.x - enemy.x, self.swarmCenter.y - enemy.y
        local swarmDist = sqrt(toSwarmX * toSwarmX + toSwarmY * toSwarmY)

        if swarmDist > 0 then
            toSwarmX, toSwarmY = toSwarmX / swarmDist, toSwarmY / swarmDist
        end

        -- Calculate position in swarm formation
        local formationX = self.swarmCenter.x + cos(enemy.swarmOffsetAngle) * enemy.swarmDistance
        local formationY = self.swarmCenter.y + sin(enemy.swarmOffsetAngle) * enemy.swarmDistance

        local toFormationX, toFormationY = formationX - enemy.x, formationY - enemy.y
        local formationDist = sqrt(toFormationX * toFormationX + toFormationY * toFormationY)

        if formationDist > 0 then
            toFormationX, toFormationY = toFormationX / formationDist, toFormationY / formationDist
        end

        -- Blend swarm cohesion with player approach
        local swarmWeight = 0.6
        local approachWeight = 0.3
        local formationWeight = 0.1

        enemy.vx = (toSwarmX * swarmWeight + directionX * approachWeight + toFormationX * formationWeight) * moveSpeed
        enemy.vy = (toSwarmY * swarmWeight + directionY * approachWeight + toFormationY * formationWeight) * moveSpeed
    elseif enemy.behavior == BEHAVIOR_STATES.AMBUSH then
        -- Minimal movement, focus on positioning
        if distance > enemy.aiProfile.preferredRange then
            enemy.vx = directionX * moveSpeed * 0.5
            enemy.vy = directionY * moveSpeed * 0.5
        else
            enemy.vx = 0
            enemy.vy = 0
        end
    end

    -- Apply evasion from player bullets (advanced AI)
    if self.difficulty ~= "easy" and random() < enemy.aiProfile.evasion then
        self:evadeBullets(enemy, bulletManager, dt)
    end

    -- Boundary avoidance
    self:avoidBoundaries(enemy, dt)
end

function Enemy:evadeBullets(enemy, bulletManager, dt)
    local evadeX, evadeY = 0, 0
    local bulletWeight = 200 -- How strongly to evade bullets

    for _, bullet in ipairs(bulletManager:getBullets()) do
        if not bullet.enemy then -- Player bullet
            local bulletDx, bulletDy = bullet.x - enemy.x, bullet.y - enemy.y
            local bulletDist = sqrt(bulletDx * bulletDx + bulletDy * bulletDy)

            -- Only evade bullets that are close and heading toward us
            if bulletDist < 150 then
                local dotProduct = (enemy.vx or 0) * bulletDx + (enemy.vy or 0) * bulletDy
                if dotProduct < 0 then -- Bullet is moving toward enemy
                    local evadeStrength = bulletWeight / (bulletDist + 1)
                    evadeX = evadeX - bulletDx * evadeStrength
                    evadeY = evadeY - bulletDy * evadeStrength
                end
            end
        end
    end

    -- Apply evasion
    if evadeX ~= 0 or evadeY ~= 0 then
        local evadeMagnitude = sqrt(evadeX * evadeX + evadeY * evadeY)
        if evadeMagnitude > 0 then
            enemy.vx = (enemy.vx or 0) + (evadeX / evadeMagnitude) * 50 * dt
            enemy.vy = (enemy.vy or 0) + (evadeY / evadeMagnitude) * 50 * dt
        end
    end
end

function Enemy:avoidBoundaries(enemy, dt)
    local margin = 50
    local pushForce = 100

    -- Left boundary
    if enemy.x < margin then
        enemy.vx = (enemy.vx or 0) + pushForce * dt
    end
    -- Right boundary
    if enemy.x > screenWidth - margin then
        enemy.vx = (enemy.vx or 0) - pushForce * dt
    end
    -- Top boundary
    if enemy.y < margin then
        enemy.vy = (enemy.vy or 0) + pushForce * dt
    end
    -- Bottom boundary
    if enemy.y > screenHeight - margin then
        enemy.vy = (enemy.vy or 0) - pushForce * dt
    end
end

function Enemy:updateShooting(dt, enemy, player, bulletManager)
    enemy.shootCooldown = enemy.shootCooldown - dt

    if enemy.shootCooldown <= 0 then
        local baseCooldown = 1.5 - (self.difficulty == "hard" and 0.5 or self.difficulty == "medium" and 0.25 or 0)

        -- Accuracy-based cooldown (more accurate = faster shooting)
        local accuracyBonus = enemy.aiProfile.accuracy * 0.3
        local cooldown = baseCooldown * (1 - accuracyBonus)

        -- Aggression affects shooting frequency
        local aggressionBonus = enemy.aiProfile.aggression * 0.2
        cooldown = cooldown * (1 - aggressionBonus)

        -- Add some randomness
        cooldown = cooldown * (0.8 + random() * 0.4)

        local vx, vy

        if enemy.predictiveTargeting and #enemy.lastPlayerPositions >= 3 then
            -- Predictive shooting - aim where player will be
            local playerDx = player.x - enemy.lastPlayerPositions[3].x
            local playerDy = player.y - enemy.lastPlayerPositions[3].y

            -- Predict position based on player movement
            local predictTime = 0.5 -- Time to predict ahead (seconds)
            local predictedX = player.x + (playerDx / 0.1) * predictTime
            local predictedY = player.y + (playerDy / 0.1) * predictTime

            local px, py = predictedX - enemy.x, predictedY - enemy.y
            local pdist = sqrt(px * px + py * py)

            if pdist > 0 then
                vx = (px / pdist) * 400
                vy = (py / pdist) * 400
            else
                vx, vy = 0, 400
            end
        else
            -- Direct shooting at current player position
            local px, py = player.x - enemy.x, player.y - enemy.y
            local pdist = sqrt(px * px + py * py)

            if pdist > 0 then
                -- Add inaccuracy based on AI profile
                local inaccuracy = (1 - enemy.aiProfile.accuracy) * 0.3
                local angleOffset = (random() - 0.5) * inaccuracy * pi

                local currentAngle = atan2(py, px)
                local newAngle = currentAngle + angleOffset

                vx = cos(newAngle) * 400
                vy = sin(newAngle) * 400
            else
                vx, vy = 0, 400
            end
        end

        -- Fire the bullet
        bulletManager:create(enemy.x, enemy.y, vx, vy, 3, 4, true)
        enemy.shootCooldown = cooldown

        -- Burst fire for higher difficulties
        if self.difficulty == "hard" and random() < 0.3 then
            enemy.shootCooldown = cooldown * 0.3 -- Quick follow-up shot
        end
    end
end

function Enemy:update(dt, player, bulletManager)
    self.spawnCooldown = self.spawnCooldown - dt
    if self.spawnCooldown <= 0 then self:spawn() end

    -- Update swarm center for coordinated behavior
    self:updateSwarmCenter(player)

    for i = #self.enemies, 1, -1 do
        local e = self.enemies[i]

        -- Update AI behavior
        self:updateBehavior(dt, e, player)

        -- Execute current behavior
        self:executeBehavior(dt, e, player, bulletManager)

        -- Apply movement
        e.x = e.x + (e.vx or 0) * dt
        e.y = e.y + (e.vy or 0) * dt

        -- Update rotation based on movement direction
        if e.vx or e.vy then
            e.rotation = atan2(e.vy or 0, e.vx or 0) + HALF_PI
        end

        -- Update shooting
        self:updateShooting(dt, e, player, bulletManager)

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

        -- Base color pulse for alien vibe
        local pulse = 0.6 + 0.4 * math.sin(time * 4 + e.x * 0.05)
        local coreColor = {0.6 + 0.2 * pulse, 0.2 + 0.3 * pulse, 0.9 - 0.3 * pulse}

        -- Behavior-based color shifts
        if e.behavior == BEHAVIOR_STATES.EVADE then
            coreColor = {0.9, 0.3, 0.3} -- red alert
        elseif e.behavior == BEHAVIOR_STATES.SWARM then
            coreColor = {0.3, 0.7, 1} -- friendly blue
        end

        local s = e.size

        -- Hull: rounded, bulbous shape
        lg.setColor(coreColor[1], coreColor[2], coreColor[3], 0.95)
        lg.polygon("fill",
            0, -s,           -- nose
            -s * 0.8, -s*0.4,
            -s * 0.6, s*0.6,
            0, s,
            s * 0.6, s*0.6,
            s * 0.8, -s*0.4
        )

        -- Outline for clarity
        lg.setColor(0.1, 0.05, 0.05, 0.9)
        lg.setLineWidth(2)
        lg.polygon("line",
            0, -s,
            -s * 0.8, -s*0.4,
            -s * 0.6, s*0.6,
            0, s,
            s * 0.6, s*0.6,
            s * 0.8, -s*0.4
        )

        -- Cockpit dome (like an eye)
        lg.setBlendMode("add")
        lg.setColor(0.2, 1, 0.7, 0.5 + 0.3 * pulse)
        lg.circle("fill", 0, -s * 0.2, s * 0.35 + 1.5 * pulse)
        lg.setBlendMode("alpha")

        -- Thruster: rounded and soft
        lg.setBlendMode("add")
        local thrusterSize = s * (0.8 + 0.3 * math.sin(time * 10 + e.y))
        lg.setColor(1, 0.5, 0.15, 0.6 + 0.2 * math.sin(time * 8 + e.x))
        lg.circle("fill", 0, s * 0.9, thrusterSize * 0.5)
        lg.setBlendMode("alpha")

        -- Health/aggression indicator: cartoonish pulse ring
        if e.health <= 1 then
            lg.setBlendMode("add")
            lg.setColor(1, 0.2, 0.2, 0.35 + 0.25 * pulse)
            lg.circle("line", 0, 0, s * 1.5 + 2 * math.sin(time * 6))
            lg.setBlendMode("alpha")
        end

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
