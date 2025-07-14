//
//  AutomationExample.swift
//  LuaKit Examples
//
//  Demonstrates using Lua for task automation:
//  - Build automation
//  - File processing
//  - System tasks
//  - Workflow automation
//

import Foundation
import Lua
import LuaKit

// MARK: - Automation Components

@LuaBridgeable
public class FileSystem: LuaBridgeable {
    public init() {}
    
    public func exists(_ path: String) -> Bool {
        return FileManager.default.fileExists(atPath: path)
    }
    
    public func createDirectory(_ path: String) throws {
        try FileManager.default.createDirectory(
            atPath: path,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    public func copy(from source: String, to destination: String) throws {
        if FileManager.default.fileExists(atPath: destination) {
            try FileManager.default.removeItem(atPath: destination)
        }
        try FileManager.default.copyItem(atPath: source, toPath: destination)
    }
    
    public func delete(_ path: String) throws {
        try FileManager.default.removeItem(atPath: path)
    }
    
    public func listFiles(_ directory: String) -> [String] {
        do {
            return try FileManager.default.contentsOfDirectory(atPath: directory)
        } catch {
            print("Error listing directory: \(error)")
            return []
        }
    }
    
    public func readFile(_ path: String) -> String? {
        return try? String(contentsOfFile: path, encoding: .utf8)
    }
    
    public func writeFile(_ path: String, content: String) throws {
        try content.write(toFile: path, atomically: true, encoding: .utf8)
    }
    
    public func getFileInfo(_ path: String) -> [String: Any]? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: path) else {
            return nil
        }
        
        return [
            "size": attributes[.size] ?? 0,
            "modificationDate": (attributes[.modificationDate] as? Date)?.description ?? "",
            "isDirectory": (attributes[.type] as? FileAttributeType) == .typeDirectory
        ]
    }
}

@LuaBridgeable
public class ProcessRunner: LuaBridgeable {
    public init() {}
    
    public func run(_ command: String, args: [String] = []) -> [String: Any] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["sh", "-c", command + " " + args.joined(separator: " ")]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
            
            return [
                "exitCode": Int(process.terminationStatus),
                "output": String(data: outputData, encoding: .utf8) ?? "",
                "error": String(data: errorData, encoding: .utf8) ?? "",
                "success": process.terminationStatus == 0
            ]
        } catch {
            return [
                "exitCode": -1,
                "output": "",
                "error": error.localizedDescription,
                "success": false
            ]
        }
    }
    
    public func runAsync(_ command: String, callback: @escaping (Bool, String) -> Void) {
        DispatchQueue.global().async {
            let result = self.run(command)
            let success = result["success"] as? Bool ?? false
            let output = result["output"] as? String ?? ""
            
            DispatchQueue.main.async {
                callback(success, output)
            }
        }
    }
}

@LuaBridgeable
public class TaskScheduler: LuaBridgeable {
    private var tasks: [String: Timer] = [:]
    
    public init() {}
    
    public func scheduleTask(_ name: String, interval: Double, repeats: Bool, task: @escaping () -> Void) {
        // Cancel existing task with same name
        cancelTask(name)
        
        let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats) { _ in
            task()
        }
        
        tasks[name] = timer
        print("Scheduled task '\(name)' to run every \(interval) seconds")
    }
    
    public func cancelTask(_ name: String) {
        if let timer = tasks[name] {
            timer.invalidate()
            tasks.removeValue(forKey: name)
            print("Cancelled task '\(name)'")
        }
    }
    
    public func cancelAllTasks() {
        for (_, timer) in tasks {
            timer.invalidate()
        }
        tasks.removeAll()
        print("Cancelled all scheduled tasks")
    }
}

@LuaBridgeable
public class BuildAutomation: LuaBridgeable {
    private let fileSystem = FileSystem()
    private let runner = ProcessRunner()
    
    public var projectPath: String = "."
    public var buildDirectory: String = "build"
    public var configuration: String = "Release"
    
    public init() {}
    
    public func clean() throws {
        let buildPath = "\(projectPath)/\(buildDirectory)"
        if fileSystem.exists(buildPath) {
            try fileSystem.delete(buildPath)
            print("Cleaned build directory")
        }
    }
    
    public func build() -> Bool {
        print("Building project in \(configuration) configuration...")
        
        let result = runner.run("swift build", args: [
            "--configuration", configuration.lowercased(),
            "--build-path", buildDirectory
        ])
        
        if let success = result["success"] as? Bool, success {
            print("Build successful!")
            return true
        } else {
            print("Build failed:")
            print(result["error"] as? String ?? "Unknown error")
            return false
        }
    }
    
    public func test() -> Bool {
        print("Running tests...")
        
        let result = runner.run("swift test", args: [
            "--configuration", configuration.lowercased(),
            "--build-path", buildDirectory
        ])
        
        if let success = result["success"] as? Bool {
            print(success ? "All tests passed!" : "Some tests failed")
            return success
        }
        return false
    }
    
    public func archive(outputPath: String) throws {
        print("Creating archive...")
        
        let result = runner.run("tar", args: [
            "-czf", outputPath,
            "-C", buildDirectory,
            "."
        ])
        
        if let success = result["success"] as? Bool, success {
            print("Archive created: \(outputPath)")
        } else {
            throw NSError(domain: "BuildAutomation", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Archive creation failed"])
        }
    }
}

// MARK: - Usage Example

public func runAutomationExample() throws {
    print("=== Automation Example ===\n")
    
    let lua = try LuaState()
    
    // Register automation classes
    lua.register(FileSystem.self, as: "FileSystem")
    lua.register(ProcessRunner.self, as: "ProcessRunner")
    lua.register(TaskScheduler.self, as: "TaskScheduler")
    lua.register(BuildAutomation.self, as: "BuildAutomation")
    
    // Create instances
    let fs = FileSystem()
    let runner = ProcessRunner()
    let scheduler = TaskScheduler()
    let builder = BuildAutomation()
    
    lua.globals["fs"] = fs
    lua.globals["runner"] = runner
    lua.globals["scheduler"] = scheduler
    lua.globals["builder"] = builder
    
    // Example 1: File processing automation
    print("Example 1: File Processing Automation\n")
    
    let fileProcessingScript = """
    -- File processing automation script
    
    function processTextFiles(directory, pattern)
        local files = fs:listFiles(directory)
        local processed = 0
        
        for i, file in ipairs(files) do
            if string.match(file, pattern) then
                local path = directory .. "/" .. file
                local content = fs:readFile(path)
                
                if content then
                    -- Process the content (example: convert to uppercase)
                    local processed_content = string.upper(content)
                    
                    -- Save to new file
                    local output_path = directory .. "/processed_" .. file
                    fs:writeFile(output_path, processed_content)
                    
                    processed = processed + 1
                    print("Processed: " .. file)
                end
            end
        end
        
        return processed
    end
    
    -- Create test files
    fs:createDirectory("/tmp/lua_automation_test")
    fs:writeFile("/tmp/lua_automation_test/file1.txt", "hello world")
    fs:writeFile("/tmp/lua_automation_test/file2.txt", "lua automation")
    fs:writeFile("/tmp/lua_automation_test/readme.md", "# Test Files")
    
    -- Process only .txt files
    local count = processTextFiles("/tmp/lua_automation_test", "%.txt$")
    print("Processed " .. count .. " text files")
    """
    
    try lua.execute(fileProcessingScript)
    
    // Example 2: Build automation
    print("\n\nExample 2: Build Automation\n")
    
    let buildAutomationScript = """
    -- Build automation script
    
    function runBuildPipeline()
        print("Starting build pipeline...")
        
        -- Step 1: Clean
        builder:clean()
        
        -- Step 2: Run pre-build checks
        print("\\nRunning pre-build checks...")
        local lint_result = runner:run("swiftlint", {"--quiet"})
        if not lint_result.success then
            print("Warning: SwiftLint reported issues")
        end
        
        -- Step 3: Build
        if not builder:build() then
            error("Build failed!")
        end
        
        -- Step 4: Test
        if not builder:test() then
            print("Warning: Some tests failed")
        end
        
        -- Step 5: Create archive
        local timestamp = os.date("%Y%m%d_%H%M%S")
        local archive_name = "build_" .. timestamp .. ".tar.gz"
        builder:archive("/tmp/" .. archive_name)
        
        print("\\nBuild pipeline completed!")
        return archive_name
    end
    
    -- Run the pipeline (commented out to avoid actual building)
    -- local archive = runBuildPipeline()
    print("Build pipeline defined - ready to run")
    """
    
    try lua.execute(buildAutomationScript)
    
    // Example 3: System monitoring automation
    print("\n\nExample 3: System Monitoring Automation\n")
    
    let monitoringScript = """
    -- System monitoring automation
    
    local monitoring_data = {
        disk_usage = {},
        memory_usage = {},
        process_count = {}
    }
    
    function checkDiskSpace()
        local result = runner:run("df", {"-h"})
        if result.success then
            print("Disk usage checked")
            table.insert(monitoring_data.disk_usage, {
                time = os.date("%H:%M:%S"),
                output = result.output
            })
        end
    end
    
    function checkMemory()
        local result = runner:run("vm_stat")
        if result.success then
            print("Memory usage checked")
            table.insert(monitoring_data.memory_usage, {
                time = os.date("%H:%M:%S"),
                output = result.output
            })
        end
    end
    
    function checkProcesses()
        local result = runner:run("ps", {"aux", "|", "wc", "-l"})
        if result.success then
            local count = tonumber(string.match(result.output, "%d+")) or 0
            print("Process count: " .. count)
            table.insert(monitoring_data.process_count, {
                time = os.date("%H:%M:%S"),
                count = count
            })
        end
    end
    
    function generateReport()
        print("\\n=== System Monitoring Report ===")
        print("Generated at: " .. os.date("%Y-%m-%d %H:%M:%S"))
        print("\\nProcess Count History:")
        for i, data in ipairs(monitoring_data.process_count) do
            print("  " .. data.time .. ": " .. data.count .. " processes")
        end
    end
    
    -- Schedule monitoring tasks (commented out to avoid continuous execution)
    -- scheduler:scheduleTask("disk_check", 300, true, checkDiskSpace)
    -- scheduler:scheduleTask("memory_check", 60, true, checkMemory)
    -- scheduler:scheduleTask("process_check", 30, true, checkProcesses)
    -- scheduler:scheduleTask("report", 600, true, generateReport)
    
    -- Run once for demonstration
    checkDiskSpace()
    checkMemory()
    checkProcesses()
    generateReport()
    
    print("\\nMonitoring tasks scheduled (disabled for demo)")
    """
    
    try lua.execute(monitoringScript)
    
    // Example 4: Deployment automation
    print("\n\nExample 4: Deployment Automation\n")
    
    let deploymentScript = """
    -- Deployment automation script
    
    local deploy_config = {
        servers = {
            staging = "staging.example.com",
            production = "prod1.example.com"
        },
        paths = {
            remote = "/var/www/app",
            local = "./dist"
        }
    }
    
    function validateDeployment()
        -- Check if build exists
        if not fs:exists(deploy_config.paths.local) then
            error("Build directory not found!")
        end
        
        -- Check configuration files
        local required_files = {
            "config.json",
            "package.json"
        }
        
        for i, file in ipairs(required_files) do
            local path = deploy_config.paths.local .. "/" .. file
            if not fs:exists(path) then
                error("Required file missing: " .. file)
            end
        end
        
        print("Deployment validation passed")
        return true
    end
    
    function deployToServer(environment)
        local server = deploy_config.servers[environment]
        if not server then
            error("Unknown environment: " .. environment)
        end
        
        print("Deploying to " .. environment .. " (" .. server .. ")...")
        
        -- In a real deployment, you would:
        -- 1. Create backup of current version
        -- 2. Upload new files
        -- 3. Run database migrations
        -- 4. Restart services
        -- 5. Verify deployment
        
        -- Simulated deployment steps
        local steps = {
            {name = "Creating backup", command = "echo 'Backup created'"},
            {name = "Uploading files", command = "echo 'Files uploaded'"},
            {name = "Running migrations", command = "echo 'Migrations completed'"},
            {name = "Restarting services", command = "echo 'Services restarted'"},
            {name = "Health check", command = "echo 'Health check passed'"}
        }
        
        for i, step in ipairs(steps) do
            print("  " .. i .. ". " .. step.name .. "...")
            local result = runner:run(step.command)
            if not result.success then
                error("Deployment failed at step: " .. step.name)
            end
        end
        
        print("Deployment to " .. environment .. " completed successfully!")
    end
    
    function rollback(environment)
        print("Rolling back " .. environment .. " deployment...")
        -- Rollback logic here
        print("Rollback completed")
    end
    
    -- Define deployment pipeline
    function deployPipeline(environment)
        print("Starting deployment pipeline for " .. environment)
        
        if validateDeployment() then
            deployToServer(environment)
            
            -- Run smoke tests
            print("Running smoke tests...")
            local test_result = runner:run("curl", {"-s", "-o", "/dev/null", "-w", "%{http_code}", "https://" .. deploy_config.servers[environment]})
            
            if test_result.output ~= "200" then
                print("Smoke tests failed! Starting rollback...")
                rollback(environment)
                error("Deployment failed smoke tests")
            end
            
            print("Deployment successful!")
        end
    end
    
    -- Example usage (not executed)
    print("Deployment automation configured")
    print("To deploy: deployPipeline('staging') or deployPipeline('production')")
    """
    
    try lua.execute(deploymentScript)
    
    // Cleanup scheduled tasks
    scheduler.cancelAllTasks()
    
    print("\n\nAutomation examples completed!")
}

// Run the example
// try runAutomationExample()