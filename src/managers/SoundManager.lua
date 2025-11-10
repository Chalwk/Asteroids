-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local pairs = pairs

local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
    local instance = setmetatable({
        sounds = {
            player_bullet = love.audio.newSource("assets/sounds/laser-104024.mp3", "static"),
            enemy_bullet = love.audio.newSource("assets/sounds/laser-312360.mp3", "static"),
            ambience = love.audio.newSource("assets/sounds/ambient-soundscapes-004-space-atmosphere-303243.mp3", "stream"),
            asteroid_explosion = love.audio.newSource("assets/sounds/explosion-312361.mp3", "static")
        }
    }, SoundManager)


    for name, sound in pairs(instance.sounds) do
        if name == "ambience" then
            sound:setVolume(0.3)
            sound:setLooping(true)
            sound:play()
        else
            sound:setVolume(0.8)
        end
    end
    return instance
end

function SoundManager:play(soundName, loop)
    if loop then self.sounds[soundName]:setLooping(true) end

    if not self.sounds[soundName] then return end

    self.sounds[soundName]:stop()
    self.sounds[soundName]:play()
end

function SoundManager:setVolume(sound, volume) sound:setVolume(volume) end

return SoundManager
