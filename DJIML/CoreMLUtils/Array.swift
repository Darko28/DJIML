//
//  Array.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/3.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Swift

extension Array where Element: Comparable {
    /**
     Returns the index and value of the largest element in the array.
     */
    public func argmax() -> (Int, Element) {
        precondition(self.count > 0)
        var maxIndex = 0
        var maxValue = self[0]
        for i in 1..<self.count {
            if self[i] > maxValue {
                maxValue = self[i]
                maxIndex = i
            }
        }
        return (maxIndex, maxValue)
    }
    
    /**
     Returns the indices of the array's elements in sorted order.
     */
    public func argsort(by areInIncreasingOrder: (Element, Element) -> Bool) -> [Array.Index] {
        return self.indices.sorted { areInIncreasingOrder(self[$0], self[$1]) }
    }
    
    /**
     Returns a new array containing the elements at the specified indices.
     */
    public func gather(indices: [Array.Index]) -> [Element] {
        var a = [Element]()
        for i in indices { a.append(self[i]) }
        return a
    }
}
