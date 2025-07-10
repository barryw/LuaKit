//
//  ArrayExample.swift
//  LuaKit
//
//  Demonstrates array property support in LuaKit
//

import Foundation
import Lua
import LuaKit

// MARK: - Example 1: Basic Array Properties

@LuaBridgeable
public class PlaylistManager: LuaBridgeable {
    public var songs: [String] = []
    public var durations: [Double] = []  // in seconds
    public var ratings: [Int] = []       // 1-5 stars
    public var favorites: [Bool] = []
    
    public init() {}
    
    public func addSong(title: String, duration: Double, rating: Int = 3, favorite: Bool = false) {
        songs.append(title)
        durations.append(duration)
        ratings.append(rating)
        favorites.append(favorite)
    }
    
    public func getTotalDuration() -> Double {
        return durations.reduce(0, +)
    }
    
    public func getFavoriteSongs() -> [String] {
        return songs.enumerated().compactMap { index, song in
            favorites[index] ? song : nil
        }
    }
    
    public var description: String {
        return "PlaylistManager(\(songs.count) songs, \(getTotalDuration())s total)"
    }
}

// MARK: - Example 2: Configuration with Arrays

@LuaBridgeable
public class NetworkConfig: LuaBridgeable {
    public var servers: [String] = []
    public var backupServers: [String] = []
    public var allowedPorts: [Int] = [80, 443]
    public var timeout: Int = 30
    
    public init() {}
    
    // Validate server addresses
    public func luaPropertyWillChange(_ propertyName: String, from oldValue: Any?, to newValue: Any?) -> Result<Void, PropertyValidationError> {
        switch propertyName {
        case "servers", "backupServers":
            if let servers = newValue as? [String] {
                for server in servers {
                    // Basic validation - check for empty strings
                    if server.trimmingCharacters(in: .whitespaces).isEmpty {
                        return .failure(PropertyValidationError("Server address cannot be empty"))
                    }
                    // Check for basic URL format
                    if !server.contains(".") && server != "localhost" {
                        return .failure(PropertyValidationError("Invalid server address: \(server)"))
                    }
                }
            }
        case "allowedPorts":
            if let ports = newValue as? [Int] {
                for port in ports {
                    if port < 1 || port > 65535 {
                        return .failure(PropertyValidationError("Port must be between 1 and 65535, got \(port)"))
                    }
                }
            }
        default:
            break
        }
        return .success(())
    }
    
    public func getActiveServers() -> [String] {
        return servers.isEmpty ? backupServers : servers
    }
    
    public var description: String {
        return "NetworkConfig(servers: \(servers.count), backup: \(backupServers.count), ports: \(allowedPorts))"
    }
}

// MARK: - Example 3: Data Processing with Arrays

@LuaBridgeable
public class DataProcessor: LuaBridgeable {
    public var inputData: [Double] = []
    public var filters: [String] = []
    public var results: [Double] = []
    
    public init() {}
    
    public func process() {
        results = inputData
        
        for filter in filters {
            switch filter {
            case "normalize":
                let max = results.max() ?? 1.0
                results = results.map { $0 / max }
            case "abs":
                results = results.map { abs($0) }
            case "square":
                results = results.map { $0 * $0 }
            case "sqrt":
                results = results.map { sqrt(abs($0)) }
            default:
                print("Unknown filter: \(filter)")
            }
        }
    }
    
    public func getStatistics() -> [String: Double] {
        guard !results.isEmpty else { return [:] }
        
        let sum = results.reduce(0, +)
        let mean = sum / Double(results.count)
        let min = results.min() ?? 0
        let max = results.max() ?? 0
        
        return [
            "count": Double(results.count),
            "sum": sum,
            "mean": mean,
            "min": min,
            "max": max
        ]
    }
    
    public var description: String {
        return "DataProcessor(input: \(inputData.count), filters: \(filters.count), results: \(results.count))"
    }
}

// MARK: - Demo Function

public func demonstrateArraySupport() throws {
    let lua = try LuaState()
    lua.setPrintHandler { print("Lua: \($0)", terminator: "") }
    
    // Example 1: Playlist Manager
    print("=== Example 1: Playlist Manager ===\n")
    
    let playlist = PlaylistManager()
    lua.register(PlaylistManager.self, as: "PlaylistManager")
    lua.globals["playlist"] = playlist
    
    _ = try lua.execute("""
        -- Add songs using arrays
        playlist.songs = {
            "Bohemian Rhapsody",
            "Hotel California", 
            "Stairway to Heaven",
            "Imagine"
        }
        
        playlist.durations = {355, 391, 482, 183}  -- in seconds
        playlist.ratings = {5, 5, 4, 5}
        playlist.favorites = {true, true, false, true}
        
        print("Playlist has", #playlist.songs, "songs")
        print("Total duration:", playlist:getTotalDuration(), "seconds")
        
        -- Iterate through songs
        for i, song in ipairs(playlist.songs) do
            local star = playlist.favorites[i] and "★" or "☆"
            print(string.format("%d. %s %s (%d⭐, %.0fs)", 
                i, star, song, playlist.ratings[i], playlist.durations[i]))
        end
        
        -- Add a new song
        table.insert(playlist.songs, "Wonderwall")
        table.insert(playlist.durations, 258)
        table.insert(playlist.ratings, 4)
        table.insert(playlist.favorites, false)
        
        print("\nAfter adding:", playlist)
    """)
    
    print("\nFavorite songs from Swift:", playlist.getFavoriteSongs())
    
    // Example 2: Network Configuration
    print("\n\n=== Example 2: Network Configuration ===\n")
    
    let netConfig = NetworkConfig()
    lua.register(NetworkConfig.self, as: "NetworkConfig")
    lua.globals["netconfig"] = netConfig
    
    _ = try lua.execute("""
        -- Configure servers
        netconfig.servers = {
            "api1.example.com",
            "api2.example.com",
            "api3.example.com"
        }
        
        netconfig.backupServers = {
            "backup1.example.com",
            "backup2.example.com"
        }
        
        netconfig.allowedPorts = {80, 443, 8080, 8443}
        
        print("Configuration:", netconfig)
        
        -- Try invalid configuration (will be rejected)
        local success, err = pcall(function()
            netconfig.allowedPorts = {80, 443, 99999}  -- Invalid port
        end)
        if not success then
            print("Validation error:", err:match("([^:]+)$"))
        end
        
        -- Dynamic server selection
        print("\nActive servers:")
        local active = netconfig:getActiveServers()
        for i, server in ipairs(active) do
            print("  " .. i .. ". " .. server)
        end
    """)
    
    // Example 3: Data Processing
    print("\n\n=== Example 3: Data Processing ===\n")
    
    let processor = DataProcessor()
    lua.register(DataProcessor.self, as: "DataProcessor")
    lua.globals["processor"] = processor
    
    _ = try lua.execute("""
        -- Set input data
        processor.inputData = {-5, 3, -8, 12, 7, -2, 15, 9, -6, 4}
        
        -- Apply filters
        processor.filters = {"abs", "normalize", "square"}
        
        print("Input data:", table.concat(processor.inputData, ", "))
        print("Filters:", table.concat(processor.filters, " -> "))
        
        -- Process the data
        processor:process()
        
        print("\nResults:")
        for i, value in ipairs(processor.results) do
            print(string.format("  [%d] %.4f", i, value))
        end
        
        -- Get statistics
        local stats = processor:getStatistics()
        print("\nStatistics:")
        print("  Count:", stats.count)
        print("  Mean:", string.format("%.4f", stats.mean))
        print("  Min:", string.format("%.4f", stats.min))
        print("  Max:", string.format("%.4f", stats.max))
    """)
}