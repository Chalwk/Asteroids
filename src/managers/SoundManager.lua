-- Nebula Frontier
-- License: MIT
-- Copyright (c) 2025 Jericho Crosby (Chalwk)

local SoundManager = {}
SoundManager.__index = SoundManager

function SoundManager.new()
    local instance = setmetatable({
        sounds = {
            --sound_name = love.audio.newSource("assets/sounds/sound_name.mp3", "static"),
            --ambience = love.audio.newSource("assets/sounds/ambience.mp3", "stream")
        }
    }, SoundManager)


    for name, sound in pairs(instance.sounds) do
        if not name == "ambience" then
            sound:setVolume(0.5)
        else
            sound:setLooping(true)
            sound:setVolume(0.8)
            sound:play()
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
