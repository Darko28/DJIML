//
//  MLMultiArray+Image.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/3.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation
import UIKit
import CoreML

extension MLMultiArray {
    /**
     Converts the multi-array to a UIImage.
     */
    public func image<T: MultiArrayType>(offset: T, scale: T) -> UIImage? {
        return MultiArray<T>(self).image(offset: offset, scale: scale)
    }
}
