-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local Game = require("src.scenes.Game")
local Menu = require("src.scenes.Menu")
local FontManager = require("src.managers.FontManager")
local BackgroundManager = require("src.managers.BackgroundManager")

local game, menu, background, fonts
local gameState = "menu"
local stateTransition = { alpha = 0, duration = 0.5, timer = 0, active = false }

local math_min = math.min
local lg = love.graphics

-- Globals for all classes
screenWidth, screenHeight = 0, 0

local function startStateTransition(newState)
    stateTransition = {
        alpha = 0,
        duration = 0.3,
        timer = 0,
        active = true,
        targetState = newState
    }
end

function love.load()
    screenWidth, screenHeight = lg.getDimensions()

    lg.setDefaultFilter("nearest", "nearest")
    lg.setLineStyle("smooth")

    fonts = FontManager.new()
    menu = Menu.new(fonts)
    game = Game.new(fonts)
    background = BackgroundManager.new()
end

function love.update(dt)
    if stateTransition.active then
        stateTransition.timer = stateTransition.timer + dt
        stateTransition.alpha = math_min(stateTransition.timer / stateTransition.duration, 1)

        if stateTransition.timer >= stateTransition.duration then
            gameState = stateTransition.targetState
            stateTransition.active = false
            stateTransition.alpha = 0
        end
    end

    if gameState == "menu" then
        menu:update(dt)
    elseif gameState == "playing" and not game:isPaused() then
        game:update(dt)
    elseif gameState == "options" then
        menu:update(dt)
    end

    background:update(dt)
end

function love.draw()
    local time = love.timer.getTime()

    -- Draw background based on state
    if gameState == "menu" or gameState == "options" then
        background:drawMenuBackground(time)
    elseif gameState == "playing" then
        background:drawGameBackground(time)
    end

    -- Draw game content
    if gameState == "menu" or gameState == "options" then
        menu:draw(gameState)
    elseif gameState == "playing" then
        game:draw(time)
    end

    -- Draw transition overlay
    if stateTransition.active then
        lg.setColor(0, 0, 0, stateTransition.alpha)
        lg.rectangle("fill", 0, 0, screenWidth, screenHeight)
    end
end

function love.mousepressed(x, y, button, istouch)
    if button == 1 then
        if gameState == "menu" then
            local action = menu:handleClick(x, y, "menu")
            if action == "start" then
                startStateTransition("playing")
                game:startNewGame(menu:getDifficulty())
            elseif action == "options" then
                startStateTransition("options")
            elseif action == "quit" then
                love.event.quit()
            end
        elseif gameState == "options" then
            local action = menu:handleClick(x, y, "options")
            if not action then return end
            if action == "back" then
                startStateTransition("menu")
            elseif action:sub(1, 4) == "diff" then
                local difficulty = action:sub(6)
                menu:setDifficulty(difficulty)
            end
        elseif gameState == "playing" then
            if game:isGameOver() then
                startStateTransition("menu")
            else
                if game:isPaused() then
                    local action = game:handlePauseClick(x, y)
                    if action == "resume" then
                        game:setPaused(false)
                    elseif action == "menu" then
                        startStateTransition("menu")
                    elseif action == "restart" then
                        game:startNewGame(menu:getDifficulty())
                        game:setPaused(false)
                    end
                else
                    game:handleClick(x, y)
                end
            end
        end
    end
end

function love.keypressed(key)
    if key == "escape" then
        if gameState == "playing" then
            game:setPaused(not game:isPaused())
        elseif gameState == "options" then
            startStateTransition("menu")
        else
            love.event.quit()
        end
    elseif key == "p" and gameState == "playing" then
        game:setPaused(not game:isPaused())
    elseif key == "f11" then
        local fullscreen = love.window.getFullscreen()
        love.window.setFullscreen(not fullscreen)
    elseif gameState == "playing" and not game:isGameOver() then
        ---
    end
end

function love.resize(w, h)
    screenWidth, screenHeight = w, h
    menu:screenResize()
    game:screenResize()
end
