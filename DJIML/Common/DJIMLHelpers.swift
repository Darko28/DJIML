//
//  DJIMLHelpers.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/30.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import UIKit
import CoreML
import Accelerate
import DJISDK


// The labels for the 20 classes.
let vocLabels = [
    "aeroplane", "bicycle", "bird", "boat", "bottle", "bus", "car", "cat",
    "chair", "cow", "diningtable", "dog", "horse", "motorbike", "person",
    "pottedplant", "sheep", "sofa", "train", "tvmonitor"
]
//
//let anchors: [Float] = [1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52]
let cocoLabels = ["person",
              "bicycle",
              "car",
              "motorbike",
              "aeroplane",
              "bus",
              "train",
              "truck",
              "boat",
              "traffic light",
              "fire hydrant",
              "stop sign",
              "parking meter",
              "bench",
              "bird",
              "cat",
              "dog",
              "horse",
              "sheep",
              "cow",
              "elephant",
              "bear",
              "zebra",
              "giraffe",
              "backpack",
              "umbrella",
              "handbag",
              "tie",
              "suitcase",
              "frisbee",
              "skis",
              "snowboard",
              "sports ball",
              "kite",
              "baseball bat",
              "baseball glove",
              "skateboard",
              "surfboard",
              "tennis racket",
              "bottle",
              "wine glass",
              "cup",
              "fork",
              "knife",
              "spoon",
              "bowl",
              "banana",
              "apple",
              "sandwich",
              "orange",
              "broccoli",
              "carrot",
              "hot dog",
              "pizza",
              "donut",
              "cake",
              "chair",
              "sofa",
              "pottedplant",
              "bed",
              "diningtable",
              "toilet",
              "tvmonitor",
              "laptop",
              "mouse",
              "remote",
              "keyboard",
              "cell phone",
              "microwave",
              "oven",
              "toaster",
              "sink",
              "refrigerator",
              "book",
              "clock",
              "vase",
              "scissors",
              "teddy bear",
              "hair drier",
              "toothbrush"
]

let vocAnchors: [Float] = [1.08, 1.19, 3.42, 4.41, 6.63, 11.38, 9.42, 5.11, 16.62, 10.52]
let cocoAnchors: [Float] = [0.57273, 0.677385, 1.87446, 2.06253, 3.33843, 5.47434, 7.88282, 3.52778, 9.77052, 9.16828
]
//let anchors: [Float] = [0.74 ,0.87, 2.42, 2.66, 4.31,
//                        7.04, 10.25, 4.59, 12.69, 11.87]

/**
 Removes bounding boxes that overlap too much with other boxes that have a higher score.
 
 - Parameters:
     - boxes: an array of bounding boxes and their scores
     - limit: the maximum number of boxes that will be selected
     - threshold: used to decide whether boxes overlap too much
 */
func nonMaxSuppression(boxes: [YOLO.Prediction], limit: Int, threshold: Float) -> [YOLO.Prediction] {
    
    // Do an argsort on the confidence scores, from high to low.
    let sortedIndices = boxes.indices.sorted { boxes[$0].score > boxes[$1].score }
    
    var selected: [YOLO.Prediction] = []
    var active = [Bool](repeating: true, count: boxes.count)
    var numActive = active.count
    
    /*
     The algorithm is simple: Start with the box that has the highest score.
        Remove any remaining boxes that overlap it more than the given threshold amount.
        If there are any boxes left (i.e. these did not overlap with any previous boxes),
        then repeat this procedure, until no more boxes remain or the limit has been reached.
     */
    outer: for i in 0..<boxes.count {
        
        if active[i] {
            
            let boxA = boxes[sortedIndices[i]]
            selected.append(boxA)
            if selected.count >= limit { break }
            
            for j in i+1..<boxes.count {
                
                if active[j] {
                    
                    let boxB = boxes[sortedIndices[j]]
                    if IOU(a: boxA.rect, b: boxB.rect) > threshold {
                        
                        active[j] = false
                        numActive -= 1
                        if numActive <= 0 { break outer }
                    }
                }
            }
        }
    }
    
    return selected
}

func nonMaxSuppression1(boxes: [MPSYOLO.Prediction], limit: Int, threshold: Float) -> [MPSYOLO.Prediction] {
    
    // Do an argsort on the confidence scores, from high to low.
    let sortedIndices = boxes.indices.sorted { boxes[$0].score > boxes[$1].score }
    
    var selected: [MPSYOLO.Prediction] = []
    var active = [Bool](repeating: true, count: boxes.count)
    var numActive = active.count
    
    /*
     The algorithm is simple: Start with the box that has the highest score.
     Remove any remaining boxes that overlap it more than the given threshold amount.
     If there are any boxes left (i.e. these did not overlap with any previous boxes),
     then repeat this procedure, until no more boxes remain or the limit has been reached.
     */
    outer: for i in 0..<boxes.count {
        
        if active[i] {
            
            let boxA = boxes[sortedIndices[i]]
            selected.append(boxA)
            if selected.count >= limit { break }
            
            for j in i+1..<boxes.count {
                
                if active[j] {
                    
                    let boxB = boxes[sortedIndices[j]]
                    if IOU(a: boxA.rect, b: boxB.rect) > threshold {
                        
                        active[j] = false
                        numActive -= 1
                        if numActive <= 0 { break outer }
                    }
                }
            }
        }
    }
    
    return selected
}


/**
 Computes intersection-over-union overlap between two bounding boxes.
 */
public func IOU(a: CGRect, b: CGRect) -> Float {
    
    let areaA = a.width * a.height
    if areaA <= 0 { return 0 }
    
    let areaB = b.width * b.height
    if areaB <= 0 { return 0 }
    
    let intersectionMinX = max(a.minX, b.minX)
    let intersectionMinY = max(a.minY, b.minY)
    let intersectionMaxX = min(a.maxX, b.maxY)
    let intersectionMaxY = min(a.maxY, b.maxY)
    let intersectionArea = max(intersectionMaxY - intersectionMinY, 0) *
                           max(intersectionMaxX - intersectionMinX, 0)
    
    return Float(intersectionArea / (areaA + areaB - intersectionArea))
}


/**
 Logistic sigmoid
 */
public func sigmoid(_ x: Float) -> Float {
    return 1 / (1 + exp(-x))
}


/**
 Computes the 'softmax' function over an array.
 
 This is what softmax looks like in "pseudocode"
 (actually using Python and numpy):

    x -= np.max(x)
    exp_scores = np.exp(x)
    softmax = exp_scores / np.sum(exp_scores)
 
 First we shift the values of x so that the highest value in the array is 0.
 This ensures numerical stability with the exponents, so they don't blow up.
 */
public func softmax(_ x: [Float]) -> [Float] {
    
    var x = x
    let len = vDSP_Length(x.count)
    
    // Find the maximum value in the input array.
    var max: Float = 0
    vDSP_maxv(x, 1, &max, len)
    
    // Subtract the maximum from all the elements in the array.
    // Now the highest value in the array is 0.
    max = -max
    vDSP_vsadd(x, 1, &max, &x, 1, len)
    
    // Exponentiate all the elements in the array.
    var count = Int32(x.count)
    vvexpf(&x, x, &count)
    
    // Compute the sum of all exponentiated values.
    var sum: Float = 0
    vDSP_sve(x, 1, &sum, len)
    
    // Divide each element by the sum. This normalizes the array contents
    // so that they all add up to 1.
    vDSP_vsdiv(x, 1, &sum, &x, 1, len)
    
    return x
}


// MARK: - Utility functions

let INVALID_POINT = CGPoint(x: CGFloat.greatestFiniteMagnitude, y: CGFloat.leastNormalMagnitude)

func showResult(format: String, arguments: [CVarArg] = []) {
    
    let message = String(format: format, arguments: arguments)
    let newMessage = message.hasSuffix(":(null)") ? message.replacingOccurrences(of: ":(null)", with: " successful!") : message
    
    DispatchQueue.main.async {
        let alertController: UIAlertController = UIAlertController(title: nil, message: newMessage, preferredStyle: .alert)
        let okAction: UIAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alertController.addAction(okAction)
        
        (UIApplication.shared.keyWindow)!.rootViewController!.present(alertController, animated: true, completion: nil)
    }
}

func stringFromPointingExecutionState(state: DJITapFlyMissionState) -> String {
    switch state {
    case DJITapFlyMissionState.cannotStart:
        return "Can Not Fly"
    case DJITapFlyMissionState.executing:
        return "Normal Flying"
    case DJITapFlyMissionState.unknown:
        return "Unknown"
    case DJITapFlyMissionState.disconnected:
        return "Aircraft disconnected"
    case DJITapFlyMissionState.recovering:
        return "Connection recovering"
    case DJITapFlyMissionState.notSupported:
        return "Not Supported"
    case DJITapFlyMissionState.readyToStart:
        return "Ready to start"
    case DJITapFlyMissionState.executionPaused:
        return "Execution Paused"
    case DJITapFlyMissionState.executionResetting:
        return "Execution Resetting"
    }
}

func stringFromTrackingExecutionState(state: DJIActiveTrackTargetState) -> String {
    switch state {
    case DJIActiveTrackTargetState.trackingWithHighConfidence:
        return "Normal Tracking"
    case DJIActiveTrackTargetState.trackingWithLowConfidence:
        return "Tracking Uncertain Target"
    case DJIActiveTrackTargetState.waitingForConfirmation:
        return "Need Confirm"
    case DJIActiveTrackTargetState.cannotConfirm:
        return "Waiting"
    case DJIActiveTrackTargetState.unknown:
        return "Unknown"
    }
}

func stringFromByPassDirection(direction: DJIBypassDirection) -> String {
    switch direction {
    case DJIBypassDirection.none:
        return "None"
    case DJIBypassDirection.over:
        return "From Top"
    case DJIBypassDirection.left:
        return "From Left"
    case DJIBypassDirection.right:
        return "From Right"
    case DJIBypassDirection.unknown:
        return "Unknown"
    }
}

func stringFromActiveTrackState(state: DJIActiveTrackMissionState) -> String {
    switch state {
    case DJIActiveTrackMissionState.readyToStart:
        return "ReadyToStart"
    case DJIActiveTrackMissionState.unknown:
        return "Unknown"
    case DJIActiveTrackMissionState.recovering:
        return "Recovering"
    case DJIActiveTrackMissionState.cannotStart:
        return "CannotStart"
    case DJIActiveTrackMissionState.disconnected:
        return "Disconnected"
    case DJIActiveTrackMissionState.notSupported:
        return "NotSupported"
    case DJIActiveTrackMissionState.cannotConfirm:
        return "CannotConfirm"
    case DJIActiveTrackMissionState.detectingHuman:
        return "DetectingHuman"
    case DJIActiveTrackMissionState.onlyCameraFollowing:
        return "OnlyCameraFollowing"
    case DJIActiveTrackMissionState.findingTrackedTarget:
        return "FindingTrackedTarget"
    case DJIActiveTrackMissionState.waitingForConfirmation:
        return "WaitingFormConfirmation"
    case DJIActiveTrackMissionState.performingQuickShot:
        return "QuickShot"
    case .aircraftFollowing:
        return "AircraftFollowing"
    case .autoSensing:
        return "AutoSensing"
    case .autoSensingForQuickShot:
        return "AutoSensingForQuickShot"
    }
}

func stringFromTargetState(state: DJIActiveTrackTargetState) -> String {
    switch state {
    case DJIActiveTrackTargetState.trackingWithLowConfidence:
        return "Low Confident"
    case DJIActiveTrackTargetState.trackingWithHighConfidence:
        return "Hight Confident"
    case DJIActiveTrackTargetState.cannotConfirm:
        return "Cannot Confirm"
    case DJIActiveTrackTargetState.unknown:
        return "Unknown"
    case DJIActiveTrackTargetState.waitingForConfirmation:
        return "Waiting For Confirmation"
    }
}

func stringFromCannotConfirmReason(reason: DJIActiveTrackCannotConfirmReason) -> String {
    switch reason {
    case DJIActiveTrackCannotConfirmReason.none:
        return "None"
    case DJIActiveTrackCannotConfirmReason.unknown:
        return "Unknown"
    case DJIActiveTrackCannotConfirmReason.targetTooFar:
        return "Target Too Far"
    case DJIActiveTrackCannotConfirmReason.aircraftTooLow:
        return "Aircraft Too Low"
    case DJIActiveTrackCannotConfirmReason.targetTooHigh:
        return "Target Too Hight"
    case DJIActiveTrackCannotConfirmReason.targetTooClose:
        return "Target Too Close"
    case DJIActiveTrackCannotConfirmReason.unstableTarget:
        return "Unstable Target"
    case DJIActiveTrackCannotConfirmReason.aircraftTooHigh:
        return "Aircraft Too High"
    case DJIActiveTrackCannotConfirmReason.gimbalAttitudeError:
        return "Gimbal Attitude Error"
    case DJIActiveTrackCannotConfirmReason.obstacleSensorError:
        return "Sensor Error"
    case DJIActiveTrackCannotConfirmReason.blockedByObstacle:
        return "Blocked by Obstacle"
    }
}

func stringFromTapFlyState(state: DJITapFlyMissionState) -> String {
    switch state {
    case DJITapFlyMissionState.readyToStart:
        return "ReadyToStart"
    case DJITapFlyMissionState.unknown:
        return "Unknown"
    case DJITapFlyMissionState.executing:
        return "Executing"
    case DJITapFlyMissionState.recovering:
        return "Recovering"
    case DJITapFlyMissionState.cannotStart:
        return "CannotStart"
    case DJITapFlyMissionState.disconnected:
        return "Disconnected"
    case DJITapFlyMissionState.notSupported:
        return "NotSupported"
    case DJITapFlyMissionState.executionPaused:
        return "ExecutionPaused"
    case DJITapFlyMissionState.executionResetting:
        return "ExecutionResetting"
    }
}
