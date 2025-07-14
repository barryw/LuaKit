//
//  GameScriptingExample.swift
//  LuaKit Examples
//
//  Demonstrates how to use LuaKit for game scripting, including:
//  - Game entities with scriptable behaviors
//  - Event handling from Lua
//  - Game state management
//  - Modding support
//

import Foundation
import Lua
import LuaKit

// MARK: - Game Components

@LuaBridgeable
public class GameObject: LuaBridgeable {
    public var name: String
    public var x: Double = 0
    public var y: Double = 0
    public var health: Int = 100
    public var maxHealth: Int = 100
    
    public init(name: String) {
        self.name = name
    }
    
    public func takeDamage(_ amount: Int) {
        health = max(0, health - amount)
        if health == 0 {
            print("\(name) was destroyed!")
        }
    }
    
    public func heal(_ amount: Int) {
        health = min(maxHealth, health + amount)
    }
    
    public func moveTo(x: Double, y: Double) {
        self.x = x
        self.y = y
        print("\(name) moved to (\(x), \(y))")
    }
}

@LuaBridgeable
public class Player: GameObject {
    public var score: Int = 0
    public var level: Int = 1
    public var inventory: [String] = []
    
    public override init(name: String) {
        super.init(name: name)
        self.maxHealth = 200
        self.health = 200
    }
    
    public func addItem(_ item: String) {
        inventory.append(item)
        print("\(name) picked up \(item)")
    }
    
    public func useItem(_ item: String) -> Bool {
        if let index = inventory.firstIndex(of: item) {
            inventory.remove(at: index)
            print("\(name) used \(item)")
            return true
        }
        return false
    }
    
    public func levelUp() {
        level += 1
        maxHealth += 50
        health = maxHealth
        print("\(name) reached level \(level)!")
    }
}

@LuaBridgeable
public class Enemy: GameObject {
    public var attackPower: Int = 10
    public var experienceValue: Int = 50
    
    public func attack(_ target: GameObject) {
        target.takeDamage(attackPower)
        print("\(name) attacks \(target.name) for \(attackPower) damage!")
    }
}

@LuaBridgeable
public class GameWorld: LuaBridgeable {
    public var player: Player?
    public var enemies: [Enemy] = []
    public var gameTime: Double = 0
    
    public init() {}
    
    public func spawnPlayer(name: String) -> Player {
        let player = Player(name: name)
        self.player = player
        print("Player '\(name)' has entered the game!")
        return player
    }
    
    public func spawnEnemy(name: String, x: Double, y: Double) -> Enemy {
        let enemy = Enemy(name: name)
        enemy.x = x
        enemy.y = y
        enemies.append(enemy)
        print("Enemy '\(name)' spawned at (\(x), \(y))")
        return enemy
    }
    
    public func findEnemiesNear(x: Double, y: Double, radius: Double) -> [Enemy] {
        return enemies.filter { enemy in
            let dx = enemy.x - x
            let dy = enemy.y - y
            let distance = sqrt(dx * dx + dy * dy)
            return distance <= radius
        }
    }
    
    public func update(deltaTime: Double) {
        gameTime += deltaTime
        // Update game logic here
    }
}

// MARK: - Usage Example

public func runGameScriptingExample() throws {
    print("=== Game Scripting Example ===\n")
    
    let lua = try LuaState()
    
    // Register game classes
    lua.register(GameObject.self, as: "GameObject")
    lua.register(Player.self, as: "Player")
    lua.register(Enemy.self, as: "Enemy")
    lua.register(GameWorld.self, as: "GameWorld")
    
    // Create game world
    let world = GameWorld()
    lua.globals["world"] = world
    
    // Load and run a game script
    let gameScript = """
    -- Game initialization script
    print("Initializing game world...")
    
    -- Spawn the player
    local player = world:spawnPlayer("Hero")
    player:moveTo(0, 0)
    
    -- Spawn some enemies
    local goblin1 = world:spawnEnemy("Goblin Scout", 10, 10)
    local goblin2 = world:spawnEnemy("Goblin Warrior", 15, 5)
    goblin2.attackPower = 15
    goblin2.health = 150
    
    -- Define enemy AI behavior
    function enemyAI(enemy, player)
        local dx = player.x - enemy.x
        local dy = player.y - enemy.y
        local distance = math.sqrt(dx * dx + dy * dy)
        
        if distance < 3 then
            -- Attack if close enough
            enemy:attack(player)
        else
            -- Move towards player
            local moveX = enemy.x + (dx / distance) * 2
            local moveY = enemy.y + (dy / distance) * 2
            enemy:moveTo(moveX, moveY)
        end
    end
    
    -- Define player actions
    function playerAttackArea(x, y, radius, damage)
        local enemies = world:findEnemiesNear(x, y, radius)
        for i, enemy in ipairs(enemies) do
            enemy:takeDamage(damage)
            if enemy.health == 0 then
                player.score = player.score + enemy.experienceValue
                print("Player gained " .. enemy.experienceValue .. " experience!")
            end
        end
        return #enemies
    end
    
    -- Item usage functions
    function useHealthPotion()
        if player:useItem("Health Potion") then
            player:heal(50)
            return true
        end
        return false
    end
    
    -- Game event handlers
    function onPlayerLevelUp()
        print("Congratulations! New abilities unlocked!")
        player:addItem("Power Scroll")
    end
    
    -- Simulate some gameplay
    print("\\n=== Starting Gameplay ===")
    
    -- Player picks up items
    player:addItem("Health Potion")
    player:addItem("Health Potion")
    player:addItem("Magic Sword")
    
    -- Move player
    player:moveTo(5, 5)
    
    -- Enemy AI turn
    print("\\nEnemy turn:")
    enemyAI(goblin1, player)
    enemyAI(goblin2, player)
    
    -- Player attacks
    print("\\nPlayer attacks area!")
    local hitCount = playerAttackArea(player.x, player.y, 5, 30)
    print("Hit " .. hitCount .. " enemies!")
    
    -- Use item
    print("\\nUsing health potion...")
    useHealthPotion()
    
    -- Check for level up
    if player.score >= 100 then
        player:levelUp()
        onPlayerLevelUp()
    end
    
    print("\\n=== Game State ===")
    print("Player: " .. player.name)
    print("Health: " .. player.health .. "/" .. player.maxHealth)
    print("Level: " .. player.level)
    print("Score: " .. player.score)
    print("Position: (" .. player.x .. ", " .. player.y .. ")")
    print("Inventory: " .. table.concat(player.inventory, ", "))
    """
    
    try lua.execute(gameScript)
    
    // You could also load scripts from files for modding support
    print("\n=== Mod Support Example ===")
    
    let modScript = """
    -- Custom mod that adds a special ability
    function superAttack()
        print(player.name .. " uses SUPER ATTACK!")
        local enemies = world:findEnemiesNear(player.x, player.y, 20)
        for i, enemy in ipairs(enemies) do
            enemy:takeDamage(100)
        end
        print("All nearby enemies devastated!")
    end
    
    -- Add new item type
    function usePowerScroll()
        if player:useItem("Power Scroll") then
            player.attackPower = (player.attackPower or 20) * 2
            print("Attack power doubled!")
            return true
        end
        return false
    end
    
    -- Try the new abilities
    print("Mod loaded! Testing new abilities...")
    superAttack()
    usePowerScroll()
    """
    
    try lua.execute(modScript)
}

// Run the example
// try runGameScriptingExample()