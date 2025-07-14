//
//  ConfigurationExample.swift
//  LuaKit Examples
//
//  Demonstrates using Lua for application configuration:
//  - Loading config from Lua files
//  - Dynamic configuration updates
//  - Environment-specific settings
//  - Config validation
//

import Foundation
import Lua
import LuaKit

// MARK: - Configuration Models

@LuaBridgeable
public class DatabaseConfig: LuaBridgeable {
    public var host: String = "localhost"
    public var port: Int = 5432
    public var database: String = "myapp"
    public var username: String = "user"
    public var password: String = ""
    public var maxConnections: Int = 10
    public var timeout: Double = 30.0
    
    public init() {}
    
    public func validate() throws {
        if host.isEmpty {
            throw ConfigError.invalid("Database host cannot be empty")
        }
        if port < 1 || port > 65535 {
            throw ConfigError.invalid("Invalid port number: \(port)")
        }
        if maxConnections < 1 {
            throw ConfigError.invalid("Max connections must be at least 1")
        }
    }
}

@LuaBridgeable
public class ServerConfig: LuaBridgeable {
    public var host: String = "0.0.0.0"
    public var port: Int = 8080
    public var ssl: Bool = false
    public var sslCertPath: String?
    public var sslKeyPath: String?
    public var maxRequestSize: Int = 10_485_760 // 10MB
    public var requestTimeout: Double = 60.0
    
    public init() {}
    
    public func validate() throws {
        if ssl {
            guard let cert = sslCertPath, !cert.isEmpty else {
                throw ConfigError.invalid("SSL certificate path required when SSL is enabled")
            }
            guard let key = sslKeyPath, !key.isEmpty else {
                throw ConfigError.invalid("SSL key path required when SSL is enabled")
            }
        }
    }
}

@LuaBridgeable
public class LoggingConfig: LuaBridgeable {
    public var level: String = "info"
    public var format: String = "json"
    public var outputs: [String] = ["console"]
    public var maxFileSize: Int = 10_485_760 // 10MB
    public var maxFiles: Int = 5
    public var directory: String = "/var/log/myapp"
    
    public init() {}
    
    public func isValidLevel(_ level: String) -> Bool {
        return ["debug", "info", "warning", "error", "critical"].contains(level.lowercased())
    }
}

@LuaBridgeable
public class FeatureFlags: LuaBridgeable {
    public var enableBetaFeatures: Bool = false
    public var enableAnalytics: Bool = true
    public var enableCaching: Bool = true
    public var debugMode: Bool = false
    public var maintenanceMode: Bool = false
    public var allowedBetaUsers: [String] = []
    
    public init() {}
    
    public func isFeatureEnabled(_ feature: String) -> Bool {
        switch feature {
        case "beta": return enableBetaFeatures
        case "analytics": return enableAnalytics
        case "caching": return enableCaching
        case "debug": return debugMode
        default: return false
        }
    }
}

@LuaBridgeable
public class AppConfig: LuaBridgeable {
    public var appName: String = "MyApp"
    public var version: String = "1.0.0"
    public var environment: String = "development"
    
    public var database = DatabaseConfig()
    public var server = ServerConfig()
    public var logging = LoggingConfig()
    public var features = FeatureFlags()
    
    public init() {}
    
    public func validate() throws {
        try database.validate()
        try server.validate()
        
        if !logging.isValidLevel(logging.level) {
            throw ConfigError.invalid("Invalid log level: \(logging.level)")
        }
    }
}

enum ConfigError: LocalizedError {
    case invalid(String)
    case missingFile(String)
    
    var errorDescription: String? {
        switch self {
        case .invalid(let message): return "Configuration error: \(message)"
        case .missingFile(let path): return "Configuration file not found: \(path)"
        }
    }
}

// MARK: - Configuration Manager

public class ConfigurationManager {
    private let lua: LuaState
    private var config: AppConfig
    private var configPath: String?
    
    public init() throws {
        self.lua = try LuaState()
        self.config = AppConfig()
        
        // Register configuration classes
        lua.register(DatabaseConfig.self, as: "DatabaseConfig")
        lua.register(ServerConfig.self, as: "ServerConfig")
        lua.register(LoggingConfig.self, as: "LoggingConfig")
        lua.register(FeatureFlags.self, as: "FeatureFlags")
        lua.register(AppConfig.self, as: "AppConfig")
        
        // Make config available globally
        lua.globals["config"] = config
    }
    
    public func loadFromString(_ configString: String) throws {
        // Execute the configuration script
        try lua.execute(configString)
        
        // Validate the configuration
        try config.validate()
    }
    
    public func loadFromFile(_ path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw ConfigError.missingFile(path)
        }
        
        let configString = try String(contentsOfFile: path, encoding: .utf8)
        self.configPath = path
        try loadFromString(configString)
    }
    
    public func reload() throws {
        guard let path = configPath else {
            throw ConfigError.invalid("No configuration file path set")
        }
        try loadFromFile(path)
    }
    
    public func getConfig() -> AppConfig {
        return config
    }
}

// MARK: - Usage Example

public func runConfigurationExample() throws {
    print("=== Configuration Example ===\n")
    
    let manager = try ConfigurationManager()
    
    // Example 1: Basic configuration
    print("Loading basic configuration...")
    
    let basicConfig = """
    -- Basic application configuration
    config.appName = "LuaKit Demo"
    config.version = "2.0.0"
    config.environment = "development"
    
    -- Database configuration
    config.database.host = "localhost"
    config.database.port = 5432
    config.database.database = "luakit_demo"
    config.database.username = "demo_user"
    config.database.password = "secure_password"
    config.database.maxConnections = 20
    
    -- Server configuration
    config.server.host = "127.0.0.1"
    config.server.port = 8080
    config.server.requestTimeout = 30.0
    
    -- Logging configuration
    config.logging.level = "debug"
    config.logging.format = "plain"
    config.logging.outputs = {"console", "file"}
    config.logging.directory = "/tmp/luakit-demo"
    
    print("Configuration loaded successfully!")
    """
    
    try manager.loadFromString(basicConfig)
    
    let config = manager.getConfig()
    print("\nCurrent configuration:")
    print("- App: \(config.appName) v\(config.version)")
    print("- Environment: \(config.environment)")
    print("- Database: \(config.database.username)@\(config.database.host):\(config.database.port)/\(config.database.database)")
    print("- Server: \(config.server.host):\(config.server.port)")
    print("- Logging: \(config.logging.level) to \(config.logging.outputs.joined(separator: ", "))")
    
    // Example 2: Environment-specific configuration
    print("\n\nLoading production configuration...")
    
    let productionConfig = """
    -- Production environment configuration
    config.environment = "production"
    
    -- Use environment variables for sensitive data
    local env = {
        DB_HOST = "prod-db.example.com",
        DB_PASSWORD = "super-secret-password",
        SSL_CERT = "/etc/ssl/certs/app.crt",
        SSL_KEY = "/etc/ssl/private/app.key"
    }
    
    -- Database configuration for production
    config.database.host = env.DB_HOST
    config.database.password = env.DB_PASSWORD
    config.database.maxConnections = 100
    config.database.timeout = 10.0
    
    -- Enable SSL in production
    config.server.ssl = true
    config.server.sslCertPath = env.SSL_CERT
    config.server.sslKeyPath = env.SSL_KEY
    config.server.port = 443
    
    -- Production logging
    config.logging.level = "warning"
    config.logging.format = "json"
    config.logging.outputs = {"file"}
    config.logging.maxFileSize = 104857600  -- 100MB
    config.logging.maxFiles = 10
    
    -- Feature flags
    config.features.enableAnalytics = true
    config.features.enableCaching = true
    config.features.debugMode = false
    
    print("Production configuration loaded")
    """
    
    try manager.loadFromString(productionConfig)
    
    print("\nProduction settings:")
    print("- SSL: \(config.server.ssl ? "Enabled" : "Disabled")")
    print("- Max DB connections: \(config.database.maxConnections)")
    print("- Log level: \(config.logging.level)")
    print("- Analytics: \(config.features.enableAnalytics ? "Enabled" : "Disabled")")
    
    // Example 3: Dynamic configuration with functions
    print("\n\nLoading dynamic configuration...")
    
    let dynamicConfig = """
    -- Dynamic configuration with helper functions
    
    function isDevelopment()
        return config.environment == "development"
    end
    
    function isProduction()
        return config.environment == "production"
    end
    
    -- Set different values based on environment
    if isDevelopment() then
        config.features.debugMode = true
        config.features.enableBetaFeatures = true
        config.logging.level = "debug"
    else
        config.features.debugMode = false
        config.features.enableBetaFeatures = false
        config.logging.level = "info"
    end
    
    -- Feature flag function for A/B testing
    function enableForUsers(feature, userList)
        if feature == "beta" then
            config.features.allowedBetaUsers = userList
        end
    end
    
    -- Enable beta features for specific users
    enableForUsers("beta", {"user1", "user2", "testuser"})
    
    -- Configuration helper functions
    function setDatabasePool(min, max)
        config.database.maxConnections = max
        print("Database pool set to max " .. max .. " connections")
    end
    
    -- Conditional configuration
    local hostname = "dev-server"  -- In real app, get from system
    
    if string.find(hostname, "dev") then
        setDatabasePool(5, 20)
    else
        setDatabasePool(20, 100)
    end
    
    -- Validation function
    function validateConfig()
        if config.server.port < 1024 and config.environment == "production" then
            error("Production server cannot use privileged port " .. config.server.port)
        end
        
        if config.features.debugMode and config.environment == "production" then
            print("WARNING: Debug mode enabled in production!")
        end
        
        return true
    end
    
    validateConfig()
    """
    
    try manager.loadFromString(dynamicConfig)
    
    print("\nDynamic configuration results:")
    print("- Debug mode: \(config.features.debugMode)")
    print("- Beta features: \(config.features.enableBetaFeatures)")
    print("- Allowed beta users: \(config.features.allowedBetaUsers.joined(separator: ", "))")
    
    // Example 4: Configuration modules
    print("\n\nLoading modular configuration...")
    
    let modularConfig = """
    -- Modular configuration system
    
    -- Define configuration modules
    local modules = {}
    
    modules.redis = {
        host = "localhost",
        port = 6379,
        password = "",
        database = 0,
        maxRetries = 3,
        timeout = 5.0
    }
    
    modules.email = {
        smtp = {
            host = "smtp.example.com",
            port = 587,
            username = "noreply@example.com",
            password = "email-password",
            useTLS = true
        },
        from = "LuaKit App <noreply@example.com>",
        templates = {
            welcome = "templates/welcome.html",
            passwordReset = "templates/password-reset.html"
        }
    }
    
    modules.rateLimit = {
        enabled = true,
        requests = {
            perMinute = 60,
            perHour = 1000,
            perDay = 10000
        },
        storage = "redis"  -- or "memory"
    }
    
    -- Function to merge modules into config
    function loadModule(name, module)
        -- In a real app, you might store these in config
        print("Loaded module: " .. name)
        -- You could extend the config object with module data
    end
    
    -- Load all modules
    for name, module in pairs(modules) do
        loadModule(name, module)
    end
    
    -- Environment-specific overrides
    if config.environment == "production" then
        modules.redis.host = "redis.prod.example.com"
        modules.email.smtp.host = "smtp.prod.example.com"
    end
    
    print("Modular configuration loaded with " .. #modules .. " modules")
    """
    
    try manager.loadFromString(modularConfig)
    
    print("\nConfiguration system demonstration complete!")
}

// Run the example
// try runConfigurationExample()