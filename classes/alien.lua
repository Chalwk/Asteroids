-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Alien = {}
Alien.__index = Alien

function Alien:new(x, y, vx, vy)
    local instance = setmetatable({}, Alien)
    instance.x = x
    instance.y = y
    instance.vx = vx
    instance.vy = vy
    instance.angle = 0
    instance.radius = 15
    instance.type = love.math.random(3) -- 3 different alien types
    instance.shootTimer = 0
    instance.shootCooldown = 2 + love.math.random(3)
    instance.life = 1
    instance.bullets = {}

    -- Type-specific properties
    if instance.type == 1 then
        instance.color = { 0, 1, 0 } -- Green - Basic
        instance.speed = 40
        instance.health = 1
    elseif instance.type == 2 then
        instance.color = { 1, 0.5, 0 } -- Orange - Fast
        instance.speed = 80
        instance.health = 1
    else
        instance.color = { 1, 0, 0 } -- Red - Strong
        instance.speed = 30
        instance.health = 3
    end

    return instance
end

function Alien:update(dt, playerX, playerY, screenWidth, screenHeight)
    -- Move
    self.x = self.x + self.vx * dt
    self.y = self.y + self.vy * dt

    -- Face towards player
    local dx = playerX - self.x
    local dy = playerY - self.y
    self.angle = math.atan2(dy, dx)

    -- Change direction occasionally
    if love.math.random() < 0.02 then
        self.vx = (love.math.random() - 0.5) * self.speed
        self.vy = (love.math.random() - 0.5) * self.speed
    end

    -- Keep alien on screen (only if screen dimensions are provided)
    if screenWidth and screenHeight then
        if self.x < 50 then self.vx = math.abs(self.vx) end
        if self.x > screenWidth - 50 then self.vx = -math.abs(self.vx) end
        if self.y < 50 then self.vy = math.abs(self.vy) end
        if self.y > screenHeight - 50 then self.vy = -math.abs(self.vy) end
    end

    -- Shooting
    self.shootTimer = self.shootTimer + dt
    if self.shootTimer >= self.shootCooldown then
        self:shoot(playerX, playerY)
        self.shootTimer = 0
        self.shootCooldown = 2 + love.math.random(3)
    end

    -- Update bullets
    for i = #self.bullets, 1, -1 do
        self.bullets[i]:update(dt)
        if self.bullets[i].life <= 0 then
            table.remove(self.bullets, i)
        end
    end
end

function Alien:draw()
    love.graphics.push()
    love.graphics.translate(self.x, self.y)
    love.graphics.rotate(self.angle)

    -- Draw alien based on type
    love.graphics.setColor(self.color[1], self.color[2], self.color[3])

    if self.type == 1 then
        -- Basic alien - saucer shape
        love.graphics.circle("fill", 0, 0, self.radius)
        love.graphics.setColor(0, 0, 0)
        love.graphics.circle("fill", 0, 0, self.radius - 3)
        love.graphics.setColor(self.color[1], self.color[2], self.color[3])
        love.graphics.circle("fill", 0, 0, self.radius - 6)
    elseif self.type == 2 then
        -- Fast alien - triangular
        love.graphics.polygon("fill",
            self.radius, 0,
            -self.radius / 2, -self.radius,
            -self.radius / 2, self.radius
        )
        love.graphics.setColor(1, 1, 1)
        love.graphics.circle("fill", self.radius / 2, 0, 3)
    else
        -- Strong alien - diamond with spikes
        love.graphics.polygon("fill",
            0, -self.radius,
            self.radius, 0,
            0, self.radius,
            -self.radius, 0
        )
        -- Spikes
        for i = 0, 3 do
            local angle = i * math.pi / 2
            local spikeX = math.cos(angle) * (self.radius + 5)
            local spikeY = math.sin(angle) * (self.radius + 5)
            love.graphics.line(0, 0, spikeX, spikeY)
        end
    end

    -- Health bar for strong alien
    if self.type == 3 then
        love.graphics.setColor(1, 0, 0)
        love.graphics.rectangle("fill", -self.radius, -self.radius - 8, self.radius * 2 * (self.health / 3), 4)
    end

    love.graphics.pop()

    -- Draw bullets
    for _, bullet in ipairs(self.bullets) do
        bullet:draw()
    end
end

function Alien:shoot(playerX, playerY)
    local dx = playerX - self.x
    local dy = playerY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)

    if dist > 0 then
        dx = dx / dist
        dy = dy / dist

        local bullet = {
            x = self.x + dx * (self.radius + 5),
            y = self.y + dy * (self.radius + 5),
            vx = dx * 200,
            vy = dy * 200,
            life = 3,
            update = function(self, dt)
                self.x = self.x + self.vx * dt
                self.y = self.y + self.vy * dt
                self.life = self.life - dt
            end,
            draw = function(self)
                love.graphics.setColor(1, 0, 0)
                love.graphics.circle("fill", self.x, self.y, 3)
            end
        }

        table.insert(self.bullets, bullet)
    end
end

function Alien:hit()
    self.health = self.health - 1
    if self.health <= 0 then
        self.life = 0
    end
end

return Alien
