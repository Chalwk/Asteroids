-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local ipairs, sin = ipairs, math.sin

local BUTTON_DATA = {
    MENU = {
        { text = "Engage Thrusters", action = "start",   width = 260, height = 55, color = { 0.7, 0.7, 0.7 } },
        { text = "Ship Systems",     action = "options", width = 260, height = 55, color = { 0.5, 0.6, 0.9 } },
        { text = "Abort Mission",    action = "quit",    width = 260, height = 55, color = { 0.9, 0.4, 0.3 } }
    },
    OPTIONS = {
        DIFFICULTY = {
            { text = "Cadet", action = "diff easy",   width = 110, height = 40, color = { 0.5, 0.9, 0.5 } },
            { text = "Pilot", action = "diff medium", width = 110, height = 40, color = { 0.9, 0.8, 0.4 } },
            { text = "Ace",   action = "diff hard",   width = 110, height = 40, color = { 0.9, 0.5, 0.4 } }
        },
        NAVIGATION = {
            { text = "Return to Hangar", action = "back", width = 200, height = 45, color = { 0.6, 0.6, 0.6 } }
        }
    }
}

local HELP_TEXT = {
    "Welcome to Nebula Frontier!",
    "",
    "Mission Objectives:",
    "• Destroy asteroids and debris to survive.",
    "• Avoid collisions with space rocks.",
    "• Score points by blasting asteroids into fragments.",
    "",
    "Flight Controls:",
    "• Rotate: A/D or Left/Right Arrow",
    "• Thrust: W or Up Arrow",
    "• Shoot: Spacebar",
    "• Hyperspace Jump: Left Shift",
    "• Pause: P or ESC",
    "",
    "Tips:",
    "• Momentum carries you forward in zero-G.",
    "• Smaller asteroids move faster—stay sharp!",
    "• Use hyperspace carefully; it’s unpredictable.",
    "",
    "Click anywhere to close the flight manual."
}

local lg = love.graphics

local Menu = {}
Menu.__index = Menu

local LAYOUT = {
    DIFF_BUTTON = { W = 110, H = 40, SPACING = 20 },
    TOTAL_SECTIONS_HEIGHT = 280,
    HELP_BOX = { W = 650, H = 600, LINE_HEIGHT = 24 }
}

local function initButton(button, x, y, section)
    button.x, button.y, button.section = x, y, section
    return button
end

local function updateOptionsButtonPositions(self)
    local centerX, centerY = screenWidth * 0.5, screenHeight * 0.5
    local startY = centerY - LAYOUT.TOTAL_SECTIONS_HEIGHT * 0.5

    local diff = LAYOUT.DIFF_BUTTON
    local diffTotalW = 3 * diff.W + 2 * diff.SPACING
    local diffStartX = centerX - diffTotalW * 0.5
    local diffY = startY + 40

    local navY = startY + 278

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
        color = { 0.8, 0.6, 0.3 }
    }, 10, screenHeight - 30, "help")

    updateButtonPositions(self)
end

local function createOptionsButtons(self)
    self.optionsButtons = {}
    local index = 1

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
    local pulse = sin(self.time * 6) * 0.1 + 0.9

    -- Metallic background with glow
    local glow = isHovered and 0.25 or 0.1
    lg.setColor(button.color[1] + glow, button.color[2] + glow, button.color[3] + glow, 0.9)
    lg.rectangle("fill", button.x, button.y, button.width, button.height, 12)

    -- Border highlight
    lg.setColor(1, 0.7, 0.2, isHovered and 1 or 0.6)
    lg.setLineWidth(isHovered and 3 or 2)
    lg.rectangle("line", button.x, button.y, button.width, button.height, 12)

    -- Text
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)
    local textWidth = font:getWidth(button.text)
    local textHeight = font:getHeight()
    local textX = button.x + (button.width - textWidth) * 0.5
    local textY = button.y + (button.height - textHeight) * 0.5

    lg.setColor(0, 0, 0, 0.5)
    lg.print(button.text, textX + 2, textY + 2)
    lg.setColor(1, 1, 1, pulse)
    lg.print(button.text, textX, textY)
    lg.setLineWidth(1)
end

local function drawHelpButton(self)
    local button = self.helpButton
    local isHovered = self.buttonHover == "help"
    local pulse = sin(self.time * 5) * 0.2 + 0.8
    local cx, cy = button.x + button.width * 0.5, button.y + button.height * 0.5

    lg.setColor(button.color[1], button.color[2], button.color[3], isHovered and 1 or 0.8)
    lg.circle("fill", cx, cy, button.width * 0.5)

    lg.setColor(1, 0.7, 0.2, isHovered and 1 or 0.6)
    lg.setLineWidth(isHovered and 3 or 2)
    lg.circle("line", cx, cy, button.width * 0.5)

    lg.setColor(1, 1, 1, pulse)
    local font = self.fonts:getFont("mediumFont")
    self.fonts:setFont(font)
    local w, h = font:getWidth(button.text), font:getHeight()
    lg.print(button.text, button.x + (button.width - w) * 0.5, button.y + (button.height - h) * 0.5)
    lg.setLineWidth(1)
end

local function drawOptionSection(self, section)
    for _, button in ipairs(self.optionsButtons) do
        if button.section == section then
            drawButton(self, button)
            local actionType, value = button.action:match("^(%w+) (.+)$")
            if actionType == "diff" and value == self.difficulty then
                lg.setColor(1, 0.7, 0.2, 0.2)
                lg.rectangle("fill", button.x - 5, button.y - 5, button.width + 10, button.height + 10, 8)
                lg.setColor(1, 0.7, 0.2, 0.8)
                lg.setLineWidth(3)
                lg.rectangle("line", button.x - 5, button.y - 5, button.width + 10, button.height + 10, 8)
                lg.setLineWidth(1)
            end
        end
    end
end

local function drawHelpOverlay(self)
    for i = 1, 3 do
        local alpha = 0.9 - (i * 0.2)
        lg.setColor(0, 0, 0, alpha)
        lg.rectangle("fill", -i, -i, screenWidth + i * 2, screenHeight + i * 2)
    end

    local box = LAYOUT.HELP_BOX
    local boxX = (screenWidth - box.W) * 0.5
    local boxY = (screenHeight - box.H) * 0.5

    for y = boxY, boxY + box.H do
        local p = (y - boxY) / box.H
        local r = 0.05 + p * 0.08
        local g = 0.04 + p * 0.05
        local b = 0.06 + p * 0.08
        lg.setColor(r, g, b, 0.98)
        lg.line(boxX, y, boxX + box.W, y)
    end

    lg.setColor(1, 0.7, 0.2, 0.8)
    lg.setLineWidth(3)
    lg.rectangle("line", boxX, boxY, box.W, box.H, 12)

    lg.setColor(1, 1, 1)
    self.fonts:setFont("mediumFont")
    lg.printf("Nebula Frontier - Flight Manual", boxX, boxY + 25, box.W, "center")

    lg.setColor(0.9, 0.9, 0.9)
    self.fonts:setFont("smallFont")

    for i, line in ipairs(HELP_TEXT) do
        local y = boxY + 90 + (i - 1) * box.LINE_HEIGHT
        lg.setColor(line:sub(1, 2) == "• " and { 1, 0.7, 0.3 } or { 0.9, 0.9, 0.9 })
        lg.printf(line, boxX + 40, y, box.W - 80, "left")
    end
    lg.setLineWidth(1)
end

local function drawGameTitle(self)
    local cx, cy = screenWidth * 0.5, screenHeight * 0.2
    lg.push()
    lg.translate(cx, cy)
    lg.scale(1.6, 1.6)
    local font = self.fonts:getFont("largeFont")
    self.fonts:setFont(font)
    local fontH = font:getHeight(self.title.text) * 0.5
    local offset = 55

    lg.setColor(0, 0, 0, 0.5)
    lg.printf(self.title.text, -300 + 4, -fontH + 4 - offset, 600, "center")
    lg.setColor(1, 0.7, 0.2, self.title.glow)
    lg.printf(self.title.text, -300, -fontH - offset, 600, "center")
    lg.pop()
end

function Menu.new(fontManager)
    local instance = setmetatable({}, Menu)
    instance.difficulty = "easy"
    instance.title = {
        text = "NEBULAR FRONTIER",
        subtitle = "Classic Space Shooter",
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
    self.title.scale = self.title.scale + self.title.scaleDirection * self.title.scaleSpeed * dt
    self.title.glow = sin(self.time * 3) * 0.3 + 0.7
    if self.title.scale > self.title.maxScale then
        self.title.scale, self.title.scaleDirection = self.title.maxScale, -1
    elseif self.title.scale < self.title.minScale then
        self.title.scale, self.title.scaleDirection = self.title.minScale, 1
    end
    self:updateButtonHover(love.mouse.getX(), love.mouse.getY())
end

function Menu:updateButtonHover(x, y)
    self.buttonHover = nil
    local buttons = self.showHelp and {} or (self.state == "options" and self.optionsButtons or self.menuButtons)
    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and y >= button.y and y <= button.y + button.height then
            self.buttonHover = button.action
            return
        end
    end
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
        lg.setColor(1, 0.7, 0.3)
        self.fonts:setFont("sectionFont")
        lg.printf("Select Flight Difficulty", 0, startY, screenWidth, "center")
        drawOptionSection(self, "difficulty")
        drawOptionSection(self, "navigation")
    end
    lg.setColor(1, 1, 1, 0.6)
    self.fonts:setFont("smallFont")
    lg.printf("© 2025 Jericho Crosby - Nebular Frontier", 10, screenHeight - 30, screenWidth - 20, "right")
end

function Menu:handleClick(x, y, state)
    local buttons = state == "menu" and self.menuButtons or self.optionsButtons
    for _, button in ipairs(buttons) do
        if x >= button.x and x <= button.x + button.width and
            y >= button.y and y <= button.y + button.height then
            return button.action
        end
    end
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

function Menu:setDifficulty(d) self.difficulty = d end

function Menu:getDifficulty() return self.difficulty end

function Menu:screenResize()
    updateButtonPositions(self)
    updateOptionsButtonPositions(self)
end

return Menu
