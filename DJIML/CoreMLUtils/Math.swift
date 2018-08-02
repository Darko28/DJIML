//
//  Math.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/3.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation

public func clamp<T: Comparable>(_ x: T, min: T, max: T) -> T {
    if x < min { return min }
    if x > max { return max }
    return x
}
