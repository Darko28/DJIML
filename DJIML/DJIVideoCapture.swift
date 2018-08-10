//
//  DJIVideoCapture.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/30.
//  Copyright © 2018 Darko. All rights reserved.
//

import Foundation
import UIKit
import AVFoundation
import CoreVideo
import CoreMedia
import VideoPreviewer
import DJISDK


public protocol DJIFrameCaptureDelegate: class {
//    func videoCapture(_ capture: DJIVideoCapture, didCaptureDJIVideoFrame: CVPixelBuffer?, timestamp: CMTime)
    func videoCapture(_ capture: DJIVideoFeed, didCaptureDJIVideoFrame: CVPixelBuffer?)
    func videoCapture(_ capture: DJIVideoFeed, didCaptureDJIVideoTexture: MTLTexture?)
}


public class DJIVideoCapture: UIView {
    
    public var previewLayer: UIView!
    public weak var delegate: DJIFrameCaptureDelegate?
    public var fps = 15
    
//    let captureSession = AVCaptureSession()
//    let videoOutput = AVCaptureVideoDataOutput()
    let queue = DispatchQueue(label: "camera-queue")
    
    var lastTimestamp = CFAbsoluteTimeGetCurrent()
}
