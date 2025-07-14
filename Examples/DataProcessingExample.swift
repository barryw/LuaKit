//
//  DataProcessingExample.swift
//  LuaKit Examples
//
//  Demonstrates using Lua for data processing:
//  - CSV/JSON processing
//  - Data transformation
//  - Report generation
//  - ETL pipelines
//

import Foundation
import Lua
import LuaKit

// MARK: - Data Processing Components

@LuaBridgeable
public class DataRecord: LuaBridgeable {
    public var id: String
    public var fields: [String: Any] = [:]
    
    public init(id: String) {
        self.id = id
    }
    
    public func get(_ key: String) -> Any? {
        return fields[key]
    }
    
    public func set(_ key: String, value: Any) {
        fields[key] = value
    }
    
    public func has(_ key: String) -> Bool {
        return fields[key] != nil
    }
    
    public func remove(_ key: String) {
        fields.removeValue(forKey: key)
    }
    
    public func toJSON() -> String {
        do {
            let data = try JSONSerialization.data(withJSONObject: fields, options: .prettyPrinted)
            return String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            return "{}"
        }
    }
}

@LuaBridgeable
public class DataSet: LuaBridgeable {
    public var name: String
    public var records: [DataRecord] = []
    
    public init(name: String) {
        self.name = name
    }
    
    public func addRecord(_ record: DataRecord) {
        records.append(record)
    }
    
    public func getRecord(id: String) -> DataRecord? {
        return records.first { $0.id == id }
    }
    
    public func filter(by key: String, value: Any) -> [DataRecord] {
        return records.filter { record in
            if let recordValue = record.get(key) {
                return String(describing: recordValue) == String(describing: value)
            }
            return false
        }
    }
    
    public func count() -> Int {
        return records.count
    }
    
    public func clear() {
        records.removeAll()
    }
}

@LuaBridgeable
public class CSVProcessor: LuaBridgeable {
    public init() {}
    
    public func parse(_ csvString: String, delimiter: String = ",") -> DataSet {
        let lines = csvString.components(separatedBy: .newlines).filter { !$0.isEmpty }
        let dataset = DataSet(name: "CSV Import")
        
        guard lines.count > 0 else { return dataset }
        
        // First line is headers
        let headers = lines[0].components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Process data rows
        for i in 1..<lines.count {
            let values = lines[i].components(separatedBy: delimiter).map { $0.trimmingCharacters(in: .whitespaces) }
            let record = DataRecord(id: String(i))
            
            for (index, header) in headers.enumerated() {
                if index < values.count {
                    record.set(header, value: values[index])
                }
            }
            
            dataset.addRecord(record)
        }
        
        return dataset
    }
    
    public func generate(from dataset: DataSet, headers: [String]) -> String {
        var csv = headers.joined(separator: ",") + "\n"
        
        for record in dataset.records {
            let values = headers.map { header in
                String(describing: record.get(header) ?? "")
            }
            csv += values.joined(separator: ",") + "\n"
        }
        
        return csv
    }
}

@LuaBridgeable
public class DataTransformer: LuaBridgeable {
    public init() {}
    
    public func mapField(dataset: DataSet, fromField: String, toField: String, transform: (Any) -> Any) {
        for record in dataset.records {
            if let value = record.get(fromField) {
                let transformed = transform(value)
                record.set(toField, value: transformed)
            }
        }
    }
    
    public func aggregate(dataset: DataSet, groupBy: String) -> [String: Int] {
        var groups: [String: Int] = [:]
        
        for record in dataset.records {
            if let groupValue = record.get(groupBy) {
                let key = String(describing: groupValue)
                groups[key, default: 0] += 1
            }
        }
        
        return groups
    }
    
    public func sum(dataset: DataSet, field: String) -> Double {
        var total = 0.0
        
        for record in dataset.records {
            if let value = record.get(field) {
                if let number = Double(String(describing: value)) {
                    total += number
                }
            }
        }
        
        return total
    }
    
    public func average(dataset: DataSet, field: String) -> Double {
        let total = sum(dataset: dataset, field: field)
        let count = dataset.records.filter { $0.get(field) != nil }.count
        return count > 0 ? total / Double(count) : 0
    }
}

@LuaBridgeable
public class ReportGenerator: LuaBridgeable {
    private var sections: [(title: String, content: String)] = []
    
    public init() {}
    
    public func addSection(title: String, content: String) {
        sections.append((title: title, content: content))
    }
    
    public func addTable(title: String, headers: [String], rows: [[String]]) {
        var table = "\n| " + headers.joined(separator: " | ") + " |\n"
        table += "|" + String(repeating: " --- |", count: headers.count) + "\n"
        
        for row in rows {
            table += "| " + row.joined(separator: " | ") + " |\n"
        }
        
        addSection(title: title, content: table)
    }
    
    public func addChart(title: String, data: [String: Double]) {
        var chart = "\n"
        let maxValue = data.values.max() ?? 1
        let scale = 40.0 / maxValue
        
        for (label, value) in data.sorted(by: { $0.value > $1.value }) {
            let barLength = Int(value * scale)
            let bar = String(repeating: "█", count: barLength)
            chart += String(format: "%-15s %s %.1f\n", label, bar, value)
        }
        
        addSection(title: title, content: chart)
    }
    
    public func generate(title: String) -> String {
        var report = "# \(title)\n\n"
        report += "Generated on: \(Date())\n\n"
        
        for section in sections {
            report += "## \(section.title)\n\n"
            report += section.content + "\n\n"
        }
        
        return report
    }
    
    public func clear() {
        sections.removeAll()
    }
}

// MARK: - Usage Example

public func runDataProcessingExample() throws {
    print("=== Data Processing Example ===\n")
    
    let lua = try LuaState()
    
    // Register data processing classes
    lua.register(DataRecord.self, as: "DataRecord")
    lua.register(DataSet.self, as: "DataSet")
    lua.register(CSVProcessor.self, as: "CSVProcessor")
    lua.register(DataTransformer.self, as: "DataTransformer")
    lua.register(ReportGenerator.self, as: "ReportGenerator")
    
    // Create instances
    let csvProcessor = CSVProcessor()
    let transformer = DataTransformer()
    let reporter = ReportGenerator()
    
    lua.globals["csv"] = csvProcessor
    lua.globals["transform"] = transformer
    lua.globals["report"] = reporter
    
    // Example 1: Sales data processing
    print("Example 1: Sales Data Processing\n")
    
    let salesDataScript = """
    -- Sales data processing example
    
    -- Sample CSV data
    local sales_csv = [[
    Date,Product,Category,Quantity,Price,Customer
    2024-01-15,iPhone 15,Electronics,2,999.99,John Doe
    2024-01-15,MacBook Pro,Electronics,1,2499.99,Jane Smith
    2024-01-16,AirPods,Electronics,3,199.99,Bob Johnson
    2024-01-16,iPad Air,Electronics,1,599.99,John Doe
    2024-01-17,Apple Watch,Electronics,2,399.99,Alice Brown
    2024-01-17,iPhone 15,Electronics,1,999.99,Charlie Davis
    2024-01-18,MacBook Air,Electronics,1,1299.99,Eve Wilson
    2024-01-18,AirPods,Electronics,5,199.99,Frank Miller
    ]]
    
    -- Parse CSV data
    local sales_data = csv:parse(sales_csv)
    print("Loaded " .. sales_data:count() .. " sales records")
    
    -- Add calculated fields
    for i = 1, sales_data:count() do
        local record = sales_data.records[i]
        local quantity = tonumber(record:get("Quantity")) or 0
        local price = tonumber(record:get("Price")) or 0
        local total = quantity * price
        record:set("Total", total)
        
        -- Extract date parts
        local date = record:get("Date")
        if date then
            local year, month, day = string.match(date, "(%d+)-(%d+)-(%d+)")
            record:set("Month", year .. "-" .. month)
        end
    end
    
    -- Calculate metrics
    local total_revenue = transform:sum(sales_data, "Total")
    local avg_order_value = transform:average(sales_data, "Total")
    
    print(string.format("Total Revenue: $%.2f", total_revenue))
    print(string.format("Average Order Value: $%.2f", avg_order_value))
    
    -- Group by product
    local product_sales = {}
    for i = 1, sales_data:count() do
        local record = sales_data.records[i]
        local product = record:get("Product")
        local total = record:get("Total")
        
        if product and total then
            product_sales[product] = (product_sales[product] or 0) + total
        end
    end
    
    -- Generate report
    report:clear()
    report:addSection("Executive Summary", string.format(
        "Total Revenue: $%.2f\\nTotal Orders: %d\\nAverage Order Value: $%.2f",
        total_revenue, sales_data:count(), avg_order_value
    ))
    
    -- Add product performance chart
    report:addChart("Product Performance", product_sales)
    
    -- Create top products table
    local headers = {"Product", "Revenue", "Percentage"}
    local rows = {}
    
    for product, revenue in pairs(product_sales) do
        local percentage = (revenue / total_revenue) * 100
        table.insert(rows, {
            product,
            string.format("$%.2f", revenue),
            string.format("%.1f%%", percentage)
        })
    end
    
    -- Sort by revenue
    table.sort(rows, function(a, b) 
        return tonumber(string.match(a[2], "([%d.]+)")) > tonumber(string.match(b[2], "([%d.]+)"))
    end)
    
    report:addTable("Product Revenue Breakdown", headers, rows)
    
    -- Print report
    local sales_report = report:generate("Sales Analysis Report")
    print("\\n" .. sales_report)
    """
    
    try lua.execute(salesDataScript)
    
    // Example 2: Log file analysis
    print("\n\nExample 2: Log File Analysis\n")
    
    let logAnalysisScript = """
    -- Log file analysis example
    
    -- Sample log data
    local log_data = [[
    2024-01-20 10:15:23 INFO User login: user123
    2024-01-20 10:16:45 ERROR Database connection failed
    2024-01-20 10:17:02 INFO User login: user456
    2024-01-20 10:18:30 WARNING High memory usage detected
    2024-01-20 10:19:15 INFO API request: GET /users
    2024-01-20 10:20:03 ERROR Timeout on external service
    2024-01-20 10:21:45 INFO API request: POST /orders
    2024-01-20 10:22:10 WARNING Slow query detected
    2024-01-20 10:23:55 INFO User logout: user123
    2024-01-20 10:24:30 ERROR Authentication failed for user789
    ]]
    
    -- Parse log entries
    local logs = DataSet("Logs")
    local line_num = 0
    
    for line in string.gmatch(log_data, "[^\\n]+") do
        line_num = line_num + 1
        local date, time, level, message = string.match(line, "(%d+-%d+-%d+) (%d+:%d+:%d+) (%w+) (.+)")
        
        if date and time and level and message then
            local record = DataRecord("log_" .. line_num)
            record:set("DateTime", date .. " " .. time)
            record:set("Level", level)
            record:set("Message", message)
            record:set("Hour", string.match(time, "(%d+):"))
            logs:addRecord(record)
        end
    end
    
    print("Parsed " .. logs:count() .. " log entries")
    
    -- Analyze log levels
    local level_counts = transform:aggregate(logs, "Level")
    
    print("\\nLog Level Distribution:")
    for level, count in pairs(level_counts) do
        print("  " .. level .. ": " .. count)
    end
    
    -- Find errors
    local errors = logs:filter("Level", "ERROR")
    print("\\nError Messages:")
    for i, error_log in ipairs(errors) do
        print("  - " .. error_log:get("Message"))
    end
    
    -- Analyze by hour
    local hourly_counts = transform:aggregate(logs, "Hour")
    
    -- Generate analysis report
    report:clear()
    report:addSection("Log Analysis Summary", string.format(
        "Total Entries: %d\\nTime Range: %s to %s",
        logs:count(),
        logs.records[1]:get("DateTime"),
        logs.records[#logs.records]:get("DateTime")
    ))
    
    report:addChart("Log Levels", level_counts)
    
    -- Error details table
    local error_headers = {"Time", "Error Message"}
    local error_rows = {}
    
    for i, error_log in ipairs(errors) do
        table.insert(error_rows, {
            error_log:get("DateTime"),
            error_log:get("Message")
        })
    end
    
    report:addTable("Error Details", error_headers, error_rows)
    
    -- Activity by hour
    local hourly_data = {}
    for hour, count in pairs(hourly_counts) do
        hourly_data["Hour " .. hour] = count
    end
    report:addChart("Activity by Hour", hourly_data)
    
    local log_report = report:generate("System Log Analysis")
    print("\\n" .. string.sub(log_report, 1, 500) .. "...") -- Truncated for display
    """
    
    try lua.execute(logAnalysisScript)
    
    // Example 3: ETL Pipeline
    print("\n\nExample 3: ETL Pipeline\n")
    
    let etlPipelineScript = """
    -- ETL (Extract, Transform, Load) Pipeline Example
    
    -- Define ETL pipeline functions
    local etl = {
        extractors = {},
        transformers = {},
        loaders = {}
    }
    
    -- Extract phase: Load data from various sources
    function etl.extract_users()
        -- Simulate extracting user data
        local users = DataSet("Users")
        
        local user_data = {
            {id = "U001", name = "Alice Johnson", age = 28, department = "Engineering"},
            {id = "U002", name = "Bob Smith", age = 35, department = "Sales"},
            {id = "U003", name = "Charlie Brown", age = 42, department = "Marketing"},
            {id = "U004", name = "Diana Davis", age = 31, department = "Engineering"},
            {id = "U005", name = "Eve Wilson", age = 29, department = "Sales"}
        }
        
        for _, data in ipairs(user_data) do
            local record = DataRecord(data.id)
            for k, v in pairs(data) do
                record:set(k, v)
            end
            users:addRecord(record)
        end
        
        return users
    end
    
    function etl.extract_performance()
        -- Simulate extracting performance data
        local performance = DataSet("Performance")
        
        local perf_data = {
            {user_id = "U001", quarter = "Q1", rating = 4.5, sales = 0},
            {user_id = "U002", quarter = "Q1", rating = 4.2, sales = 125000},
            {user_id = "U003", quarter = "Q1", rating = 3.8, sales = 95000},
            {user_id = "U004", quarter = "Q1", rating = 4.7, sales = 0},
            {user_id = "U005", quarter = "Q1", rating = 4.0, sales = 110000}
        }
        
        for i, data in ipairs(perf_data) do
            local record = DataRecord("P00" .. i)
            for k, v in pairs(data) do
                record:set(k, v)
            end
            performance:addRecord(record)
        end
        
        return performance
    end
    
    -- Transform phase: Process and enrich data
    function etl.transform_merge(users, performance)
        local merged = DataSet("EmployeeAnalysis")
        
        for _, user in ipairs(users.records) do
            local user_id = user:get("id")
            
            -- Find matching performance data
            for _, perf in ipairs(performance.records) do
                if perf:get("user_id") == user_id then
                    local record = DataRecord(user_id .. "_" .. perf:get("quarter"))
                    
                    -- Copy user data
                    record:set("employee_id", user_id)
                    record:set("name", user:get("name"))
                    record:set("age", user:get("age"))
                    record:set("department", user:get("department"))
                    
                    -- Copy performance data
                    record:set("quarter", perf:get("quarter"))
                    record:set("rating", perf:get("rating"))
                    record:set("sales", perf:get("sales"))
                    
                    -- Calculate derived fields
                    local rating = tonumber(perf:get("rating")) or 0
                    record:set("performance_level", 
                        rating >= 4.5 and "Excellent" or
                        rating >= 4.0 and "Good" or
                        rating >= 3.5 and "Average" or "Needs Improvement"
                    )
                    
                    merged:addRecord(record)
                end
            end
        end
        
        return merged
    end
    
    -- Load phase: Output processed data
    function etl.load_summary(data)
        print("\\nETL Pipeline Results:")
        print("Processed " .. data:count() .. " employee records")
        
        -- Department summary
        local dept_stats = {}
        
        for _, record in ipairs(data.records) do
            local dept = record:get("department")
            if dept then
                if not dept_stats[dept] then
                    dept_stats[dept] = {count = 0, total_rating = 0, total_sales = 0}
                end
                
                dept_stats[dept].count = dept_stats[dept].count + 1
                dept_stats[dept].total_rating = dept_stats[dept].total_rating + (tonumber(record:get("rating")) or 0)
                dept_stats[dept].total_sales = dept_stats[dept].total_sales + (tonumber(record:get("sales")) or 0)
            end
        end
        
        -- Generate summary report
        report:clear()
        report:addSection("ETL Pipeline Summary", 
            "Successfully processed employee and performance data"
        )
        
        -- Department metrics table
        local headers = {"Department", "Employees", "Avg Rating", "Total Sales"}
        local rows = {}
        
        for dept, stats in pairs(dept_stats) do
            table.insert(rows, {
                dept,
                tostring(stats.count),
                string.format("%.2f", stats.total_rating / stats.count),
                string.format("$%d", stats.total_sales)
            })
        end
        
        report:addTable("Department Performance", headers, rows)
        
        -- Performance distribution
        local perf_dist = transform:aggregate(data, "performance_level")
        report:addChart("Performance Distribution", perf_dist)
        
        return report:generate("ETL Pipeline Report")
    end
    
    -- Run the ETL pipeline
    print("Starting ETL Pipeline...")
    
    -- Extract
    print("1. Extracting data...")
    local users = etl.extract_users()
    local performance = etl.extract_performance()
    print("   - Extracted " .. users:count() .. " users")
    print("   - Extracted " .. performance:count() .. " performance records")
    
    -- Transform
    print("2. Transforming data...")
    local merged_data = etl.transform_merge(users, performance)
    print("   - Created " .. merged_data:count() .. " merged records")
    
    -- Load
    print("3. Loading results...")
    local etl_report = etl.load_summary(merged_data)
    print(etl_report)
    """
    
    try lua.execute(etlPipelineScript)
    
    print("\n\nData processing examples completed!")
}

// Run the example
// try runDataProcessingExample()