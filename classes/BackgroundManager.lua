-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local lg = love.graphics
local random = love.math.random
local sin, cos, pi = math.sin, math.cos, math.pi

local BackgroundManager = {}
BackgroundManager.__index = BackgroundManager

local function initObjects(self)
    self.objects = {}

    -- Create stars
    for _ = 1, 200 do
        self.objects[#self.objects + 1] = {
            type = "star",
            x = random(0, 1000),
            y = random(0, 1000),
            size = random(1, 3),
            alpha = random() * 0.8 + 0.2,
            twinkleSpeed = random(1, 4)
        }
    end

    -- Create drifting asteroid fragments
    for _ = 1, 25 do
        local size = random(10, 40)
        local speed = random(10, 40)
        self.objects[#self.objects + 1] = {
            type = "asteroid",
            x = random(0, 1000),
            y = random(0, 1000),
            size = size,
            speedX = (random() - 0.5) * speed,
            speedY = (random() - 0.5) * speed,
            rotation = random() * pi * 2,
            rotationSpeed = (random() - 0.5) * 0.8,
            alpha = random() * 0.3 + 0.4,
            color = {
                random(90, 160) / 255,
                random(90, 160) / 255,
                random(90, 160) / 255
            }
        }
    end
end

function BackgroundManager.new()
    local instance = setmetatable({}, BackgroundManager)
    instance.time = 0
    initObjects(instance)
    return instance
end

function BackgroundManager:update(dt)
    self.time = self.time + dt

    for _, obj in ipairs(self.objects) do
        if obj.type == "asteroid" then
            obj.x = obj.x + obj.speedX * dt
            obj.y = obj.y + obj.speedY * dt
            obj.rotation = obj.rotation + obj.rotationSpeed * dt

            -- Wrap edges
            if obj.x < -50 then
                obj.x = 1050
            elseif obj.x > 1050 then
                obj.x = -50
            end
            if obj.y < -50 then
                obj.y = 1050
            elseif obj.y > 1050 then
                obj.y = -50
            end
        end
    end
end

function BackgroundManager:drawMenuBackground()
    local t = self.time
    -- Deep space background
    lg.setColor(0.0, 0.0, 0.02, 1)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    for _, obj in ipairs(self.objects) do
        if obj.type == "star" then
            local twinkle = (sin(t * obj.twinkleSpeed + obj.x) + 1) * 0.5
            lg.setColor(1, 1, 1, obj.alpha * twinkle)
            lg.circle("fill", obj.x, obj.y, obj.size)
        elseif obj.type == "asteroid" then
            lg.push()
            lg.translate(obj.x, obj.y)
            lg.rotate(obj.rotation)
            lg.setColor(obj.color[1], obj.color[2], obj.color[3], obj.alpha)
            lg.polygon("line",
                -obj.size * 0.6, -obj.size * 0.4,
                obj.size * 0.8, -obj.size * 0.3,
                obj.size * 0.6, obj.size * 0.5,
                -obj.size * 0.5, obj.size * 0.6
            )
            lg.pop()
        end
    end
end

function BackgroundManager:drawGameBackground()
    local t = self.time
    -- Darker space during gameplay
    lg.setColor(0, 0, 0.015, 1)
    lg.rectangle("fill", 0, 0, screenWidth, screenHeight)

    for _, obj in ipairs(self.objects) do
        if obj.type == "star" then
            local twinkle = (sin(t * obj.twinkleSpeed + obj.x * 0.5) + 1) * 0.5
            lg.setColor(1, 1, 1, obj.alpha * (0.6 + twinkle * 0.4))
            lg.circle("fill", obj.x, obj.y, obj.size)
        elseif obj.type == "asteroid" then
            lg.push()
            lg.translate(obj.x, obj.y)
            lg.rotate(obj.rotation)
            lg.setColor(obj.color[1], obj.color[2], obj.color[3], obj.alpha)
            lg.polygon("line",
                -obj.size * 0.5, -obj.size * 0.4,
                obj.size * 0.7, -obj.size * 0.3,
                obj.size * 0.5, obj.size * 0.6,
                -obj.size * 0.4, obj.size * 0.7
            )
            lg.pop()
        end
    end
end

return BackgroundManager
