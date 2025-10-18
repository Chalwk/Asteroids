-- Asteroids - Love2D Game for Android & Windows
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Starfield = {}
Starfield.__index = Starfield

function Starfield:new(screenWidth, screenHeight)
    local instance = setmetatable({}, Starfield)
    instance.screenWidth = screenWidth
    instance.screenHeight = screenHeight
    instance.stars = {}
    instance.planets = {}

    instance:initStars()
    instance:initPlanets()

    return instance
end

-- Initialize star field
function Starfield:initStars()
    self.stars = {}
    for i = 1, 200 do -- Increased number of stars
        self.stars[i] = {
            x = love.math.random(0, self.screenWidth),
            y = love.math.random(0, self.screenHeight),
            size = love.math.random(1, 3),             -- Different star sizes
            brightness = love.math.random(3, 10) / 10, -- Different brightness levels
            speed = love.math.random(5, 20) / 100      -- Parallax effect speeds
        }
    end
end

-- Initialize planets
function Starfield:initPlanets()
    self.planets = {}
    local planetCount = love.math.random(2, 4) -- 2-4 planets

    for i = 1, planetCount do
        local planetTypes = {
            -- Gas giant with rings
            {
                radius = love.math.random(40, 80),
                color = { love.math.random(150, 255) / 255, love.math.random(100, 200) / 255, love.math.random(50, 150) / 255 },
                hasRings = true,
                ringColor = { love.math.random(150, 220) / 255, love.math.random(150, 220) / 255, love.math.random(150, 220) / 255 },
                speed = love.math.random(3, 8) / 100,
                features = "gas"
            },
            -- Rocky planet with craters
            {
                radius = love.math.random(30, 60),
                color = { love.math.random(100, 180) / 255, love.math.random(80, 150) / 255, love.math.random(60, 120) / 255 },
                hasRings = false,
                speed = love.math.random(2, 6) / 100,
                features = "rocky"
            },
            -- Ice planet
            {
                radius = love.math.random(35, 70),
                color = { love.math.random(180, 220) / 255, love.math.random(200, 240) / 255, love.math.random(220, 255) / 255 },
                hasRings = love.math.random() > 0.7,
                ringColor = { love.math.random(200, 240) / 255, love.math.random(200, 240) / 255, love.math.random(220, 255) / 255 },
                speed = love.math.random(2, 5) / 100,
                features = "ice"
            },
            -- Lava planet
            {
                radius = love.math.random(25, 55),
                color = { love.math.random(180, 255) / 255, love.math.random(50, 100) / 255, love.math.random(20, 60) / 255 },
                hasRings = false,
                speed = love.math.random(4, 9) / 100,
                features = "lava"
            }
        }

        local planetType = planetTypes[love.math.random(#planetTypes)]

        self.planets[i] = {
            x = love.math.random(-100, self.screenWidth + 100),
            y = love.math.random(-100, self.screenHeight + 100),
            radius = planetType.radius,
            color = planetType.color,
            hasRings = planetType.hasRings,
            ringColor = planetType.ringColor,
            speed = planetType.speed,
            features = planetType.features,
            rotation = love.math.random() * 2 * math.pi,
            rotationSpeed = (love.math.random() - 0.5) * 0.5,
            pulse = love.math.random() * 2 * math.pi,
            pulseSpeed = love.math.random(0.5, 2)
        }
    end
end

function Starfield:update(dt)
    -- Update star field (parallax effect)
    for i, star in ipairs(self.stars) do
        star.y = star.y + star.speed
        if star.y > self.screenHeight then
            star.y = 0
            star.x = love.math.random(0, self.screenWidth)
        end
    end

    -- Update planets (much slower movement)
    for i, planet in ipairs(self.planets) do
        planet.y = planet.y + planet.speed * 0.3 -- Even slower than stars
        planet.rotation = planet.rotation + planet.rotationSpeed * dt
        planet.pulse = planet.pulse + planet.pulseSpeed * dt

        -- Reset planet position when it goes off screen
        if planet.y > self.screenHeight + planet.radius * 2 then
            planet.y = -planet.radius * 2
            planet.x = love.math.random(0, self.screenWidth)
        end
    end
end

function Starfield:draw()
    -- Draw space background
    love.graphics.setColor(0.05, 0.05, 0.15) -- Darker blue for better contrast
    love.graphics.rectangle("fill", 0, 0, self.screenWidth, self.screenHeight)

    -- Draw planets first (furthest back)
    for i, planet in ipairs(self.planets) do
        love.graphics.push()
        love.graphics.translate(planet.x, planet.y)
        love.graphics.rotate(planet.rotation)

        -- Calculate pulse effect for some planets
        local pulseEffect = 1 + math.sin(planet.pulse) * 0.05

        -- Draw planet rings (if any)
        if planet.hasRings then
            love.graphics.setColor(planet.ringColor[1], planet.ringColor[2], planet.ringColor[3], 0.6)
            love.graphics.ellipse("fill", 0, 0, planet.radius * 1.8 * pulseEffect, planet.radius * 0.4)
            love.graphics.setColor(0.05, 0.05, 0.15, 0.7)
            love.graphics.ellipse("fill", 0, 0, planet.radius * 1.6 * pulseEffect, planet.radius * 0.3)
        end

        -- Draw the planet itself
        love.graphics.setColor(planet.color[1], planet.color[2], planet.color[3])
        love.graphics.circle("fill", 0, 0, planet.radius * pulseEffect)

        -- Add planet features based on type
        if planet.features == "gas" then
            -- Gas giant bands
            love.graphics.setColor(planet.color[1] * 0.7, planet.color[2] * 0.7, planet.color[3] * 0.7)
            for j = 1, 3 do
                local bandWidth = planet.radius * 0.1
                local bandY = (j - 2) * planet.radius * 0.3
                love.graphics.arc("fill", 0, 0, planet.radius * 0.9, math.pi / 2, 3 * math.pi / 2)
                love.graphics.rectangle("fill", -planet.radius * 0.9, bandY - bandWidth / 2, planet.radius * 1.8,
                    bandWidth)
            end
        elseif planet.features == "rocky" then
            -- Rocky planet craters
            love.graphics.setColor(planet.color[1] * 0.5, planet.color[2] * 0.5, planet.color[3] * 0.5)
            for j = 1, 4 do
                local craterAngle = (j / 4) * 2 * math.pi
                local craterX = math.cos(craterAngle) * planet.radius * 0.5
                local craterY = math.sin(craterAngle) * planet.radius * 0.5
                love.graphics.circle("fill", craterX, craterY, planet.radius * 0.15)
            end
        elseif planet.features == "lava" then
            -- Lava planet glowing spots
            love.graphics.setColor(1, 0.8, 0.2, 0.6)
            for j = 1, 3 do
                local lavaAngle = (j / 3) * 2 * math.pi
                local lavaX = math.cos(lavaAngle) * planet.radius * 0.6
                local lavaY = math.sin(lavaAngle) * planet.radius * 0.6
                love.graphics.circle("fill", lavaX, lavaY, planet.radius * 0.2)
            end
        end

        love.graphics.pop()
    end

    -- Draw enhanced star field (in front of planets)
    for i, star in ipairs(self.stars) do
        love.graphics.setColor(1, 1, 1, star.brightness) -- Use alpha for brightness
        love.graphics.circle("fill", star.x, star.y, star.size)
    end
end

return Starfield
