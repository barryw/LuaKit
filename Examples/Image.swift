//
//  Image.swift
//  LuaKit
//
//  Created by Barry Walker on 7/8/25.
//  Example of using LuaBridgeable macro
//

import Foundation
import CLua  // Required for @LuaBridgeable macro
import LuaKit

// Example using the @LuaBridgeable macro
// Note: Must explicitly conform to LuaBridgeable due to current macro limitations
@LuaBridgeable
public class Image: LuaBridgeable, CustomStringConvertible {
    public var width: Int
    public var height: Int
    
    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public var area: Int {
        return width * height
    }
    
    public func resize(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
    
    public var description: String {
        return "Image(\(width)x\(height))"
    }
}