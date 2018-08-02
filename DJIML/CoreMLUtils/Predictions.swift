//
//  Predictions.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/4.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Vision

/**
 Returns the top `k` predictions from CoreML classification results as an
 array of `(String, Double)` pairs.
 */
public func top(_ k: Int, _ prob: [String: Double]) -> [(String, Double)] {
    return Array(prob.map { x in (x.key, x.value) }
                     .sorted(by: { a, b -> Bool in a.1 > b.1 })
                     .prefix(through: min(k, prob.count) - 1))
}

/**
 Returns the top `k` predictions from Vision classification results as an
 array of `(String, Double)` pairs.
 */
public func top(_ k: Int, _ observations: [VNClassificationObservation]) -> [(String, Double)] {
    // The Vision observations are sorted by confidence already.
    return observations.prefix(through: min(k, observations.count) - 1).map { ($0.identifier, Double($0.confidence)) }
}
