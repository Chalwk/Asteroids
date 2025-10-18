-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Player = {}
Player.__index = Player

function Player:new(x, y)
    local instance = setmetatable({}, Player)
    instance.x = x
    instance.y = y
    instance.angle = 0
    instance.vx = 0
    instance.vy = 0
    instance.rotationSpeed = 5
    instance.thrust = 400  -- Increased from 200
    instance.maxSpeed = 1200  -- Increased from 800
    instance.boostMultiplier = 5.5  -- Boost speed multiplier
    instance.boostDuration = 1.5  -- How long boost lasts in seconds
    instance.boostCooldown = 3.0  -- Cooldown after boost in seconds
    instance.boostActive = false
    instance.boostTimeRemaining = 0
    instance.boostCooldownRemaining = 0
    instance.radius = 10
    instance.cooldown = 0
    instance.cooldownTime = 0.3
    instance.invulnerable = 0
    instance.invulnerableTime = 2

    return instance
end

function Player:update(dt)
    -- Update boost timers
    if self.boostActive then
        self.boostTimeRemaining = self.boostTimeRemaining - dt
        if self.boostTimeRemaining <= 0 then
            self.boostActive = false
            self.boostCooldownRemaining = self.boostCooldown
        end
    elseif self.boostCooldownRemaining > 0 then
        self.boostCooldownRemaining = self.boostCooldownRemaining - dt
    end

    -- Rotation (support both arrow keys and A/D)
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then
        self.angle = self.angle - self.rotationSpeed * dt
    end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then
        self.angle = self.angle + self.rotationSpeed * dt
    end

    -- Calculate current thrust and max speed (apply boost if active)
    local currentThrust = self.thrust
    local currentMaxSpeed = self.maxSpeed

    if self.boostActive then
        currentThrust = self.thrust * self.boostMultiplier
        currentMaxSpeed = self.maxSpeed * self.boostMultiplier
    end

    -- Thrust (support both arrow keys and W)
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        self.vx = self.vx + math.cos(self.angle) * currentThrust * dt
        self.vy = self.vy + math.sin(self.angle) * currentThrust * dt

        -- Limit speed
        local speed = math.sqrt(self.vx ^ 2 + self.vy ^ 2)
        if speed > currentMaxSpeed then
            self.vx = (self.vx / speed) * currentMaxSpeed
            self.vy = (self.vy / speed) * currentMaxSpeed
        end
    end

    -- Apply friction (less friction when boosting for more responsive control)
    local friction = self.boostActive and 0.95 or 0.98
    self.vx = self.vx * friction
    self.vy = self.vy * friction

    -- Update position
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Wrap around screen
    self.x, self.y = wrapPosition(self.x, self.y)

    -- Update cooldown
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end

    -- Update invulnerability
    if self.invulnerable > 0 then
        self.invulnerable = self.invulnerable - dt
    end
end

function Player:draw()
    if self.invulnerable > 0 and math.floor(self.invulnerable * 10) % 2 == 0 then
        return -- Flash effect when invulnerable
    end

    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)

    -- Draw ship
    if self.boostActive then
        love.graphics.setColor(0.2, 0.8, 1) -- Cyan when boosting
    else
        love.graphics.setColor(1, 1, 1) -- White normally
    end
    love.graphics.polygon("fill",
        10, 0,
        -8, -6,
        -8, 6
    )

    -- Draw thrust when moving forward (support both arrow keys and W)
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then
        if self.boostActive then
            love.graphics.setColor(1, 0.8, 0.2) -- Bright orange-yellow for boost thrust
            -- Larger thrust effect when boosting
            love.graphics.polygon("fill",
                -8, -6,
                -20, 0,
                -8, 6
            )
        else
            love.graphics.setColor(1, 0.5, 0) -- Normal orange
            love.graphics.polygon("fill",
                -8, -4,
                -12, 0,
                -8, 4
            )
        end
    end

    love.graphics.pop()
end

function Player:activateBoost()
    if not self.boostActive and self.boostCooldownRemaining <= 0 then
        self.boostActive = true
        self.boostTimeRemaining = self.boostDuration
        return true
    end
    return false
end

function Player:shoot()
    if self.cooldown <= 0 then
        self.cooldown = self.cooldownTime

        local bulletSpeed = self.boostActive and 400 or 300  -- Faster bullets when boosting
        local bulletX = self.x + math.cos(self.angle) * 12
        local bulletY = self.y + math.sin(self.angle) * 12
        local bulletVx = self.vx + math.cos(self.angle) * bulletSpeed
        local bulletVy = self.vy + math.sin(self.angle) * bulletSpeed

        return {
            x = bulletX,
            y = bulletY,
            vx = bulletVx,
            vy = bulletVy,
            life = 2,
            update = function(self, dt)
                self.x = self.x + self.vx * dt
                self.y = self.y + self.vy * dt
                self.life = self.life - dt
                self.x, self.y = wrapPosition(self.x, self.y)
            end,
            draw = function(self)
                love.graphics.setColor(1, 1, 0)
                love.graphics.circle("fill", self.x, self.y, 2)
            end
        }
    end
    return nil
end

function Player:hit()
    if self.invulnerable <= 0 then
        self.invulnerable = self.invulnerableTime

        -- Reset position and velocity
        self.x = getScreenWidth() / 2
        self.y = getScreenHeight() / 2
        self.vx = 0
        self.vy = 0

        -- Also cancel any active boost
        self.boostActive = false
        self.boostTimeRemaining = 0
        self.boostCooldownRemaining = self.boostCooldown

        return true -- Life was lost
    end
    return false -- No life lost (invulnerable)
end

return Player