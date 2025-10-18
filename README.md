# Asteroids - Love2D Game for Android & Windows

A modern take on the classic Asteroids arcade game built with Love2D

## 🎮 Features

### Core Gameplay
- **Classic Asteroids Action**: Break large asteroids into smaller ones in this space shooter
- **Progressive Difficulty**: Levels increase in challenge with more asteroids and enemies
- **Score System**: Earn points for destroying asteroids and aliens
- **High Score Tracking**: Compete for the highest score across sessions

### Player Mechanics
- **Spaceship Control**:
    - Arrow Keys or WASD for movement and rotation
    - Spacebar to shoot lasers
    - Boost system with cooldown (Ctrl key)
- **Boost Ability**:
    - Temporary speed and bullet velocity increase
    - Visual ship color change when active
    - Strategic cooldown management
- **Damage System**:
    - Three lives with respawn invulnerability
    - Visual flashing effect when invulnerable

### Enemy Variety
- **Asteroids**: Three sizes (large, medium, small) that split when destroyed
- **Alien Enemies**: Three distinct types with unique behaviors:
    - **Green Aliens**: Basic saucer-shaped enemies
    - **Orange Aliens**: Fast-moving triangular ships
    - **Red Aliens**: Strong diamond-shaped enemies with health bars and spikes

### Visual Enhancements
- **Dynamic Starfield Background**: Parallax scrolling starfield with multiple star sizes and brightness levels
- **Planetary Objects**: Randomly generated planets with unique features:
    - Gas giants with ring systems
    - Rocky planets with crater details
    - Ice planets with optional rings
    - Lava planets with glowing spots
- **Particle Effects**: Explosion particles for destroyed objects and player damage
- **UI Elements**: Clean HUD displaying score, lives, level, and boost status

### Game States
- **Main Menu**: Attractive title screen with game instructions and high score display
- **Playing**: Core gameplay experience
- **Game Over**: Final score display with restart options
- **Level Transitions**: Clear indicators between levels

### Technical Features
- **Object-Oriented Design**: Clean class structure for game entities
- **Screen Wrapping**: Objects seamlessly wrap around screen edges
- **Collision Detection**: Precise hit detection for bullets and ships
- **Randomized Spawning**: Intelligent enemy spawning away from player

## 🕹️ Controls
- **Movement**: Arrow Keys or WASD
- **Shoot**: Spacebar
- **Boost**: Left Ctrl or Right Ctrl
- **Menu Navigation**: Spacebar to start, ESC to quit/return to menu