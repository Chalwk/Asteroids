-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local sin, cos, pi = math.sin, math.cos, math.pi

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

local function initFloatingShapes(self)
    self.shapes = {}

    for _ = 1, 40 do
        local size = random(10, 40)
        local speed = random(0.5, 2)
        local bob = random(2, 6)
        local rotSpeed = (random() - 0.5) * 1.5
        local alpha = random() * 0.3 + 0.2

        self.shapes[#self.shapes + 1] = {
            x = random(0, 1000),
            y = random(0, 1000),
            size = size,
            speedX = (random() - 0.5) * 30,
            speedY = (random() - 0.5) * 30,
            bobSpeed = speed,
            bobAmount = bob,
            rotation = random() * pi * 2,
            rotationSpeed = rotSpeed,
            alpha = alpha,
            color = {
                random(60, 100) / 255,
                random(80, 150) / 255,
                random(120, 200) / 255
            }
        }
    end
end

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)
    instance.time = 0
    initFloatingShapes(instance)
    return instance
end

function BackgroundManager:update(dt)
    self.time = self.time + dt

    for _, s in ipairs(self.shapes) do
        s.x = s.x + s.speedX * dt
        s.y = s.y + s.speedY * dt
        s.rotation = s.rotation + s.rotationSpeed * dt
        s.y = s.y + sin(self.time * s.bobSpeed) * s.bobAmount * dt

        -- Wrap edges
        if s.x < -50 then
            s.x = 1050
        elseif s.x > 1050 then
            s.x = -50
        end
        if s.y < -50 then
            s.y = 1050
        elseif s.y > 1050 then
            s.y = -50
        end
    end
end

local function drawGradient(width, height, baseR, baseG, baseB, var)
    for y = 0, height, 2 do
        local progress = y / height
        local wave = sin(progress * 6 + var) * 0.05
        lg.setColor(
            baseR + wave,
            baseG + progress * 0.1 + wave,
            baseB + progress * 0.2 + wave,
            1
        )
        lg.rectangle("fill", 0, y, width, 2)
    end
end

function BackgroundManager:drawMenuBackground()
    local t = self.time
    drawGradient(screenWidth, screenHeight, 0.05, 0.03, 0.12, t)

    for _, s in ipairs(self.shapes) do
        local bobOffset = sin(t * s.bobSpeed) * s.bobAmount
        lg.push()
        lg.translate(s.x, s.y + bobOffset)
        lg.rotate(s.rotation)
        lg.setColor(s.color[1], s.color[2], s.color[3], s.alpha)
        lg.circle("fill", 0, 0, s.size)
        lg.pop()
    end

    lg.setColor(1, 1, 1, (sin(t * 2) + 1) * 0.05)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)
end

function BackgroundManager:drawGameBackground()
    local t = self.time
    drawGradient(screenWidth, screenHeight, 0.02, 0.01, 0.08, t * 0.5)

    lg.setColor(0.2, 0.25, 0.3, 0.1)
    local gridSize = 80
    local offset = sin(t * 0.3) * 10
    for x = -offset, screenWidth + offset, gridSize do
        lg.line(x, 0, x, screenHeight)
    end
    for y = -offset, screenHeight + offset, gridSize do
        lg.line(0, y, screenWidth, y)
    end

    for _, s in ipairs(self.shapes) do
        local bobOffset = cos(t * s.bobSpeed) * s.bobAmount
        lg.push()
        lg.translate(s.x, s.y + bobOffset)
        lg.rotate(-s.rotation * 0.5)
        lg.setColor(s.color[1] * 0.7, s.color[2] * 0.7, s.color[3] * 0.7, s.alpha * 0.6)
        lg.circle("line", 0, 0, s.size)
        lg.pop()
    end
end

return BackgroundManager
