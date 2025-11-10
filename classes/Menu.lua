-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs, math_sin, math_floor = ipairs, math.sin, math.floor

local BUTTON_DATA = {
    MENU = {
        { text = "Start Game", action = "start",   width = 240, height = 55, color = { 0.2, 0.7, 0.3 } },
        { text = "Options",    action = "options", width = 240, height = 55, color = { 0.3, 0.5, 0.8 } },
        { text = "Quit Game",  action = "quit",    width = 240, height = 55, color = { 0.8, 0.3, 0.3 } }
    },
    OPTIONS = {
        DIFFICULTY = {
            { text = "Easy",   action = "diff easy",   width = 110, height = 40, color = { 0.3, 0.8, 0.4 } },
            { text = "Medium", action = "diff medium", width = 110, height = 40, color = { 0.9, 0.7, 0.2 } },
            { text = "Hard",   action = "diff hard",   width = 110, height = 40, color = { 0.8, 0.3, 0.3 } }
        },
        NAVIGATION = {
            { text = "Back to Menu", action = "back", width = 180, height = 45, color = { 0.6, 0.6, 0.6 } }
        }
    }
}

local HELP_TEXT = {
    "Welcome to Nebula Frontier!",
    "",
    "Gameplay:",
    "• Destroy asteroids and enemy ships",
    "• Collect power-ups to enhance your ship",
    "• Survive through 5 levels to win!",
    "",
    "Controls:",
    "• Rotate: A/D or Left/Right Arrow",
    "• Thrust: W or Up Arrow",
    "• Boost: Left Shift",
    "• Shoot: Spacebar",
    "• Pause: P or ESC",
    "",
    "Power-ups:",
    "• Blue: Boost refill",
    "• Green: Temporary shield",
    "• Red: Rapid fire",
    "",
    "Click anywhere to close"
}

local lg = love.graphics

local Menu = {}
Menu.__index = Menu

local LAYOUT = {
    DIFF_BUTTON = { W = 110, H = 40, SPACING = 20 },
    TOTAL_SECTIONS_HEIGHT = 280,
    HELP_BOX = { W = 650, H = 500, LINE_HEIGHT = 24 }
}

local function initButton(button, x, y, section)
    button.x, button.y, button.section = x, y, section
    return button
end

local function updateOptionsButtonPositions(self)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5
    local startY = centerY - LAYOUT.TOTAL_SECTIONS_HEIGHT * 0.5

    -- Difficulty buttons
    local diff = LAYOUT.DIFF_BUTTON
    local diffTotalW = 3 * diff.W + 2 * diff.SPACING
    local diffStartX = centerX - diffTotalW * 0.5
    local diffY = startY + 40

    -- Navigation button
    local navY = startY + 278

    -- Update all options buttons
    for i, button in ipairs(self.optionsButtons) do
        if button.section == "difficulty" then
            button.x = diffStartX + (i - 1) * (diff.W + diff.SPACING)
            button.y = diffY
        elseif button.section == "navigation" then
            button.x = centerX - button.width * 0.5
            button.y = navY
        end
    end
end

local function updateButtonPositions(self)
    local startY = screenHeight * 0.5 - 80
    for i, button in ipairs(self.menuButtons) do
        button.x = (screenWidth - button.width) * 0.5
        button.y = startY + (i - 1) * 70
    end
    self.helpButton.y = screenHeight - 60
end

local function createMenuButtons(self)
    self.menuButtons = {}
    for i, data in ipairs(BUTTON_DATA.MENU) do
        self.menuButtons[i] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "menu")
    end

    self.helpButton = initButton({
        text = "?",
        action = "help",
        width = 50,
        height = 50,
        x = 10,
        y = screenHeight - 30,
        color = { 0.3, 0.6, 0.9 }
    }, 10, screenHeight - 30, "help")

    updateButtonPositions(self)
end

local function createOptionsButtons(self)
    self.optionsButtons = {}
    local index = 1

    -- Add difficulty buttons
    for _, data in ipairs(BUTTON_DATA.OPTIONS.DIFFICULTY) do
        self.optionsButtons[index] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "difficulty")
        index = index + 1
    end

    -- Add navigation button
    for _, data in ipairs(BUTTON_DATA.OPTIONS.NAVIGATION) do
        self.optionsButtons[index] = initButton({
            text = data.text,
            action = data.action,
            width = data.width,
            height = data.height,
            color = data.color
        }, 0, 0, "navigation")
    end

    updateOptionsButtonPositions(self)
end

local function drawButton(self, button)
    local isHovered = self.buttonHover == button.action
    local pulse = math_sin(self.time * 6) * 0.1 + 0.9

    -- Button background
    lg.setColor(button.color[1], button.color[2], button.color[3], isHovered and 0.9 or 0.7)
    lg.rectangle("fill", button.x, button.y, button.width, button.height, 10)

    -- Button border
    lg.setColor(1, 1, 1, isHovered and 1 or 0.8)
    lg.setLineWidth(isHovered and 3 or 2)
    lg.rectangle("line", button.x, button.y, button.width, button.height, 10)

    -- Button text
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)

    local textWidth = font:getWidth(button.text)
    local textHeight = font:getHeight()
    local textX = button.x + (button.width - textWidth) * 0.5
    local textY = button.y + (button.height - textHeight) * 0.5

    -- Text shadow
    lg.setColor(0, 0, 0, 0.5)
    lg.print(button.text, textX + 2, textY + 2)

    -- Main text
    lg.setColor(1, 1, 1, pulse)
    lg.print(button.text, textX, textY)

    lg.setLineWidth(1)
end

local function drawHelpButton(self)
    local button = self.helpButton
    local isHovered = self.buttonHover == "help"
    local pulse = math_sin(self.time * 5) * 0.2 + 0.8
    local centerX, centerY = button.x + button.width * 0.5, button.y + button.height * 0.5

    -- Button background
    lg.setColor(button.color[1], button.color[2], button.color[3], isHovered and 0.9 or 0.7)
    lg.circle("fill", centerX, centerY, button.width * 0.5)

    -- Button border
    lg.setColor(1, 1, 1, isHovered and 1 or 0.8)
    lg.setLineWidth(isHovered and 3 or 2)
    lg.circle("line", centerX, centerY, button.width * 0.5)

    -- Question mark
    lg.setColor(1, 1, 1, pulse)
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)

    local textWidth = font:getWidth(button.text)
    local textHeight = font:getHeight()

    lg.print(button.text, button.x + (button.width - textWidth) * 0.5, button.y + (button.height - textHeight) * 0.5)

    lg.setLineWidth(1)
end

local function drawOptionSection(self, section)
    for _, button in ipairs(self.optionsButtons) do
        if button.section == section then
            drawButton(self, button)

            -- Draw selection indicator
            local actionType, value = button.action:match("^(%w+) (.+)$")
            if actionType == "diff" and value == self.difficulty then
                lg.setColor(0.2, 0.8, 0.2, 0.3)
                lg.rectangle("fill", button.x - 5, button.y - 5, button.width + 10, button.height + 10, 8)
                lg.setColor(0.2, 1, 0.2, 0.8)
                lg.setLineWidth(3)
                lg.rectangle("line", button.x - 5, button.y - 5, button.width + 10, button.height + 10, 8)
                lg.setLineWidth(1)
            end
        end
    end
end

local function drawHelpOverlay(self)
    -- Overlay background
    for i = 1, 3 do
        local alpha = 0.9 - (i * 0.2)
        lg.setColor(0, 0, 0, alpha)
        lg.rectangle("fill", -i, -i, screenWidth + i * 2, screenHeight + i * 2)
    end

    -- Help box
    local box = LAYOUT.HELP_BOX
    local boxX = (screenWidth - box.W) * 0.5
    local boxY = (screenHeight - box.H) * 0.5

    -- Box background with gradient
    for y = boxY, boxY + box.H do
        local progress = (y - boxY) / box.H
        local r = 0.08 + progress * 0.1
        local g = 0.1 + progress * 0.1
        local b = 0.15 + progress * 0.1
        lg.setColor(r, g, b, 0.98)
        lg.line(boxX, y, boxX + box.W, y)
    end

    -- Box border
    lg.setColor(0.3, 0.6, 0.9, 0.8)
    lg.setLineWidth(4)
    lg.rectangle("line", boxX, boxY, box.W, box.H, 12)

    -- Title
    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("GAME_NAME_HERE - How to Play", boxX, boxY + 25, box.W, "center")

    -- Help text
    lg.setColor(0.9, 0.9, 0.9)
    self.fonts:setFont("smallFont")

    for i, line in ipairs(HELP_TEXT) do
        local y = boxY + 90 + (i - 1) * box.LINE_HEIGHT
        lg.setColor(line:sub(1, 2) == "• " and { 0.5, 0.8, 1 } or { 0.9, 0.9, 0.9 })
        lg.printf(line, boxX + 40, y, box.W - 80, "left")
    end

    lg.setLineWidth(1)
end

local function drawGameTitle(self)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.2

    lg.push()
    lg.translate(centerX, centerY)
    lg.scale(1.6, 1.6)

    local font = self.fonts:getFont("largeFont")
    self.fonts:setFont(font)

    local fontH = font:getHeight(self.title.text) * 0.5
    local height_offset = 55

    -- Title shadow
    lg.setColor(0, 0, 0, 0.5)
    lg.printf(self.title.text, -300 + 4, -fontH + 4 - height_offset, 600, "center")

    -- Title main
    lg.setColor(0.9, 0.2, 0.2, self.title.glow)
    lg.printf(self.title.text, -300, -fontH - height_offset, 600, "center")
    lg.pop()
end

function Menu.new(fontManager)
    local instance = setmetatable({}, Menu)

    instance.difficulty = "medium"
    instance.title = {
        text = "NEBULA FRONTIER",
        subtitle = "A SPACE SURVIVAL ADVENTURE",
        scale = 1,
        scaleDirection = 1,
        scaleSpeed = 0.4,
        minScale = 0.92,
        maxScale = 1.08,
        glow = 0
    }
    instance.showHelp = false
    instance.time = 0
    instance.buttonHover = nil
    instance.fonts = fontManager

    createMenuButtons(instance)
    createOptionsButtons(instance)

    return instance
end

function Menu:update(dt)
    self.time = self.time + dt

    updateButtonPositions(self)
    updateOptionsButtonPositions(self)

    -- Title animation
    self.title.scale = self.title.scale + self.title.scaleDirection * self.title.scaleSpeed * dt
    self.title.glow = math_sin(self.time * 3) * 0.3 + 0.7

    if self.title.scale > self.title.maxScale then
        self.title.scale, self.title.scaleDirection = self.title.maxScale, -1
    elseif self.title.scale < self.title.minScale then
        self.title.scale, self.title.scaleDirection = self.title.minScale, 1
    end

    -- Update button hover state
    self:updateButtonHover(love.mouse.getX(), love.mouse.getY())
end

function Menu:updateButtonHover(x, y)
    self.buttonHover = nil

    local buttons = self.showHelp and {} or (self.state == "options" and self.optionsButtons or self.menuButtons)

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            self.buttonHover = button.action
            return
        end
    end

    -- Check help button
    if not self.showHelp and self.helpButton and
        x >= self.helpButton.x and x <= self.helpButton.x + self.helpButton.width and
        y >= self.helpButton.y and y <= self.helpButton.y + self.helpButton.height then
        self.buttonHover = "help"
    end
end

function Menu:draw(state)
    self.state = state

    drawGameTitle(self)

    if state == "menu" then
        if self.showHelp then
            drawHelpOverlay(self)
        else
            for _, button in ipairs(self.menuButtons) do drawButton(self, button) end

            lg.setColor(0.9, 0.9, 0.9, 0.8)
            self.fonts:setFont("mediumFont")
            lg.printf(self.title.subtitle, 0, screenHeight * 0.20, screenWidth, "center")

            drawHelpButton(self)
        end
    elseif state == "options" then
        updateOptionsButtonPositions(self)

        local startY = (screenHeight - LAYOUT.TOTAL_SECTIONS_HEIGHT) * 0.5

        -- Section headers
        lg.setColor(0.8, 0.9, 1)
        self.fonts:setFont("sectionFont")
        lg.printf("Difficulty", 0, startY, screenWidth, "center")

        drawOptionSection(self, "difficulty")
        drawOptionSection(self, "navigation")
    end

    -- Copyright
    lg.setColor(1, 1, 1, 0.6)
    self.fonts:setFont("smallFont")
    lg.printf("© 2025 Jericho Crosby - GAME_NAME_HERE", 10, screenHeight - 30, screenWidth - 20, "right")
end

function Menu:handleClick(x, y, state)
    local buttons = state == "menu" and self.menuButtons or self.optionsButtons

    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end

    -- Check help button
    if state == "menu" then
        if self.helpButton and x >= self.helpButton.x and x <= self.helpButton.x + self.helpButton.width and
            y >= self.helpButton.y and y <= self.helpButton.y + self.helpButton.height then
            self.showHelp = true
            return "help"
        end

        if self.showHelp then
            self.showHelp = false
            return "help_close"
        end
    end

    return nil
end

function Menu:setDifficulty(difficulty) self.difficulty = difficulty end

function Menu:getDifficulty() return self.difficulty end

function Menu:screenResize()
    updateButtonPositions(self)
    updateOptionsButtonPositions(self)
end

return Menu
