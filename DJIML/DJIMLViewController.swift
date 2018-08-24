//
//  DJIMLViewController.swift
//  SummerHolidayProject
//
//  Created by Darko on 2018/7/30.
//  Copyright © 2018 Darko. All rights reserved.
//

import UIKit
import Metal
import Vision
import AVFoundation
import CoreMedia
import VideoToolbox
import VideoPreviewer
import DJISDK
import Accelerate


var ENABLE_BRIDGE_MODE = false
let BRIDGE_IP = "192.168.0.105"

var labels = [""]

class DJIMLViewController: UIViewController {
    
    @IBOutlet weak var fpvPreviewerView: UIView!
    
    @IBOutlet weak var videoPreviewer: UIView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var debugImageView: UIImageView!
    
    var datasetBtn: UIButton!
    
    var videoDataProcessor: DJICustomVideoFrameExtractor? = DJICustomVideoFrameExtractor(extractor: ())
    
    
    let yolo = YOLO()
    
    var videoCapture: DJIVideoCapture!
    var request: VNCoreMLRequest!
    var startTimes: [CFTimeInterval] = []
    
    var boundingBoxes = [BoundingBox]()
    var colors: [UIColor] = []
    
    let ciContext = CIContext()
    var resizedPixelBuffer: CVPixelBuffer?
    var tmpBuffer: CVPixelBuffer?
    
    var framesDone = 0
    var frameCapturingStartTime = CACurrentMediaTime()
    
    let semaphore = DispatchSemaphore(value: 2)
    var lastTimestamp = CACurrentMediaTime()
    var fps = 15
    static var deltaTime = 0
    
//    var isPredicting = false
    var previousBuffer: CVPixelBuffer?
    
    var delegate: DJIFrameCaptureDelegate?
    
    
    var device: MTLDevice!
    var commandQueue: MTLCommandQueue!
    var textureCache: CVMetalTextureCache?
    var mpsYOLO: MPSYOLO!

    var useCoreML: Bool = true
    
    var currentTrackingTargetRect: CGRect?
    var trackingRenderView: TrackingRenderView!
    
//    var isTrackingMissionRunning = false
    var isNeedConfirm = true
    
    var shouldRunPrediction = true
    
    var trackTapGestureRecognizer: UITapGestureRecognizer!
    
    var stopTrackBtn: UIButton!
    var stopFollowingBtn: UIButton!
    var confirmTargetBtn: UIButton!

        
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        self.registerApp()
        
        labels = cocoLabels
        
        self.setupTrackingRenderView()
        
        self.datasetBtn = UIButton(frame: CGRect(x: self.fpvPreviewerView.bounds.width - 116, y: self.timeLabel.frame.minY, width: 96, height: 36))
        self.datasetBtn.titleLabel?.adjustsFontSizeToFitWidth = true
        self.datasetBtn.setTitle("Default: COCO(CoreML)", for: .normal)
        self.trackingRenderView.addSubview(self.datasetBtn)
        
        self.datasetBtn.addTarget(self, action: #selector(datasetSwitch), for: UIControlEvents.touchUpInside)
        
        self.timeLabel.textColor = UIColor.white
        self.trackingRenderView.addSubview(self.timeLabel)
        
        if videoDataProcessor != nil {
            videoDataProcessor!.delegate = self
        }
        
        
//        timeLabel.text = ""
        
        self.device = MTLCreateSystemDefaultDevice()
        if device == nil {
            print("Error: this device does not support Metal")
            return
        }
        self.commandQueue = device.makeCommandQueue()
        
        mpsYOLO = MPSYOLO(commandQueue: commandQueue)
        
//        setUpCamera()
        setUpBoundingBoxes()
        setUpCoreImage()
        setUpVision()
        setUpCamera()
        
        frameCapturingStartTime = CACurrentMediaTime()
        
//        self.trackingRenderView.delegate = self
        
        self.missionOperator()?.addListener(toEvents: self, with: DispatchQueue.main, andBlock: { [weak self] (event: DJIActiveTrackMissionEvent) in
            self!.didUpdateActiveTrackEvent(event)
        })
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        if let camera = self.fetchCamera(), camera.delegate === self {
            camera.delegate = nil
        }
        self.resetVideoPreviewer()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        print(#function)
    }
    
    @objc func datasetSwitch() {
        if useCoreML {
            useCoreML = false
            labels = vocLabels
            self.datasetBtn.setTitle("Using VOC(MPS)", for: UIControlState.normal)
        } else {
            useCoreML = true
            labels = cocoLabels
            self.datasetBtn.setTitle("Using COCO(CoreML)", for: .normal)
        }
    }
    
    // MARK: - Initialization
    
    func setupTrackingRenderView() {
        
        self.trackingRenderView = TrackingRenderView(frame: self.fpvPreviewerView.bounds)
        self.trackingRenderView.backgroundColor = UIColor.clear
        self.fpvPreviewerView.addSubview(self.trackingRenderView)
        
        self.trackTapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(startTargetTrackingWithRect(_:)))

        self.trackingRenderView.addGestureRecognizer(self.trackTapGestureRecognizer)
        
        self.stopTrackBtn = UIButton(frame: CGRect(x: 5, y: self.timeLabel.frame.maxY + 5, width: 64, height: 48))
        self.stopTrackBtn = UIButton(type: UIButtonType.custom)
        self.stopTrackBtn.frame = CGRect(x: 5, y: self.timeLabel.frame.maxY + 5, width: 64, height: 36)
        self.stopTrackBtn.titleLabel?.adjustsFontSizeToFitWidth = true
//        self.stopTrackBtn.contentHorizontalAlignment = .left
        self.stopTrackBtn.setTitle("STOP", for: .normal)
//        self.stopTrackBtn.titleLabel!.text = "STOP"
        self.stopTrackBtn.titleLabel?.isUserInteractionEnabled = true
//        self.stopTrackBtn.titleEdgeInsets = UIEdgeInsetsMake(20, 20, 20, 20)
//        self.stopTrackBtn.titleLabel?.numberOfLines = 2
        self.stopTrackBtn.isUserInteractionEnabled = true
        self.stopTrackBtn.titleLabel?.font = UIFont.systemFont(ofSize: 11)
//        self.stopTrackBtn.backgroundColor = UIColor.blue
        self.trackingRenderView.addSubview(self.stopTrackBtn)
        
        self.stopTrackBtn.addTarget(self, action: #selector(stopTargetTracking), for: .touchUpInside)
        
        self.confirmTargetBtn = UIButton(frame: CGRect(x: 5, y: self.fpvPreviewerView.bounds.maxY - 165, width: 64, height: 36))
        self.confirmTargetBtn.titleLabel?.adjustsFontSizeToFitWidth = true
//        self.confirmTargetBtn.backgroundColor = .blue
//        self.confirmTargetBtn.contentHorizontalAlignment = .left
        self.confirmTargetBtn.setTitle("CONFIRM", for: .normal)
//        self.confirmTargetBtn.titleLabel?.numberOfLines = 2
        self.confirmTargetBtn.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        self.trackingRenderView.addSubview(self.confirmTargetBtn)
        
        self.confirmTargetBtn.addTarget(self, action: #selector(targetAcceptConfirmation), for: .touchUpInside)

        self.stopFollowingBtn = UIButton(frame: CGRect(x: 5, y: self.fpvPreviewerView.bounds.maxY - 116, width: 64, height: 36))
        self.stopFollowingBtn.titleLabel?.adjustsFontSizeToFitWidth = true
//        self.stopFollowingBtn.backgroundColor = .blue
//        self.stopFollowingBtn.contentHorizontalAlignment = .left
        self.stopFollowingBtn.setTitle("RECONFIRM", for: .normal)
//        self.stopFollowingBtn.titleLabel?.numberOfLines = 2
        self.stopFollowingBtn.titleLabel?.font = UIFont.systemFont(ofSize: 10)
        self.trackingRenderView.addSubview(self.stopFollowingBtn)
        
        self.stopFollowingBtn.addTarget(self, action: #selector(stopFollowingTarget), for: .touchUpInside)

    }
    
    func setUpBoundingBoxes() {
        
        for _ in 0..<YOLO.maxBoundingBoxes {
            boundingBoxes.append(BoundingBox())
        }
        
        // Make colors for the bounding boxes. There is one color for each class,
        // 20 classes in total.
        for r: CGFloat in [0.2, 0.4, 0.6, 0.8, 1.0] {
            for g: CGFloat in [0.1, 0.3, 0.5, 0.7] {
                for b: CGFloat in [0.2, 0.4, 0.6, 0.8] {
                    let color = UIColor(red: r, green: g, blue: b, alpha: 1)
                    colors.append(color)
                }
            }
        }
    }
    
    func setUpCoreImage() {
        
//        let status1 = CVPixelBufferCreate(nil, YOLO.inputWidth, YOLO.inputHeight, kCVPixelFormatType_32BGRA, nil, &resizedPixelBuffer)
        let status2 = CVPixelBufferCreate(nil, 1280, 720, kCVPixelFormatType_32BGRA, [kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue] as CFDictionary, &resizedPixelBuffer)

        if status2 != kCVReturnSuccess {
            print("Error: could not create resized pixel buffer", status2)
        }
    }
    
    func setUpVision() {
        
        guard let visionModel = try? VNCoreMLModel(for: yolo.model.model) else {
            print("Error: could not create Vision Model")
            return
        }
        
        request = VNCoreMLRequest(model: visionModel, completionHandler: visionRequestDidComplete)
        
        // NOTE: If you choose another crop/scale option, then you must also
        // change how the BoundingBox objects get scaled when they are drawn.
        // Currently they assume the full input image is used.
        request.imageCropAndScaleOption = .scaleFill
    }
    
    func setUpCamera() {
        
//        if !useCoreML {
        guard CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, device, nil, &textureCache) == kCVReturnSuccess else {
            print("Error: could not create a texture cache")
            return
        }
//        }
        
        videoCapture = DJIVideoCapture()
        videoCapture.delegate = self
        videoCapture.fps = 50
        
        // Add the video preview into the UI.
//        if let previewLayer = self.videoCapture {
////            self.fpvPreviewerView.previewLayer.addSubview(previewLayer)
////            self.fpvPreviewerView.layer.addSublayer(previewLayer.layer)
//            self.resizePreviewLayer()
//        }
        self.resizePreviewLayer()
        
        // Add the bounding box layers to the UI, on top of the video preview.
        for box in self.boundingBoxes {
//            box.addToLayer(self.videoPreviewer.layer)
            box.addToLayer(self.trackingRenderView.layer)
        }
        
//        // Once everything is set up, we can start capturing live video.
//        self.videoCapture.start()
    }

    // MARK: - UI stuff
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        resizePreviewLayer()
        self.timeLabel.textColor = UIColor.white
        self.trackingRenderView.addSubview(self.timeLabel)
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func resizePreviewLayer() {
        videoCapture.frame = self.trackingRenderView.bounds
    }
    
    func convertToMTLTexture(imageBuffer: CVPixelBuffer?) -> MTLTexture? {
        
        print("convert to MTLTexure")
        
        guard let resizedPixelBuffer = resizedPixelBuffer else { return nil }
        
        if let textureCache = textureCache, let pixelBuffer = imageBuffer {
            
            print("Convert begin")
            
//            let width = CVPixelBufferGetWidth(imageBuffer)
//            let height = CVPixelBufferGetHeight(imageBuffer)
//
//            print("convert width: \(width), height: \(height)")
//
//            var texture: CVMetalTexture?
////            CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, imageBuffer, nil, .bgra8Unorm, width, height, 0, &texture)
////            CVPixelBufferCreate(nil, MPSYOLO.inputWidth, MPSYOLO.inputHeight, kCVPixelFormatType_32BGRA, nil, &resizedPixelBuffer)
//            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, [kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue] as CFDictionary, &resizedPixelBuffer)
//
//            guard let resizedPixelBuffer = resizedPixelBuffer else { return nil }
//
//            let ciImage = CIImage(cvPixelBuffer: imageBuffer)
////            let sx = CGFloat(CVPixelBufferGetWidth(imageBuffer))
////            let sy = CGFloat(CVPixelBufferGetHeight(imageBuffer))
////            let scaleTransform = CGAffineTransform(scaleX: 1, y: 1)
////            let scaledImage = ciImage.transformed(by: scaleTransform)
//            ciContext.render(ciImage, to: resizedPixelBuffer)
//
//            CVPixelBufferGetPixelFormatType(imageBuffer)
//            CVPixelBufferGetPixelFormatType(resizedPixelBuffer)
//
//
//            print("converted width: \(CVPixelBufferGetWidth(resizedPixelBuffer)), height: \(CVPixelBufferGetHeight(resizedPixelBuffer))")

            var texture: CVMetalTexture?

            
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            
            CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, [kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue] as CFDictionary, &tmpBuffer)
            
            print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")
            
            
            //        let tmpImage = CIImage(cvPixelBuffer: pixelBuffer)
            //        ciContext.render(tmpImage, to: tmpBuffer)
            //        if let tmpImage = UIImage(pixelBuffer: pixelBuffer, context: ciContext) {
            //            print("tmpBuffer")
            //            ciContext.render(tmpImage.ciImage!, to: tmpBuffer)
            //        }
            
            
            CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            guard let srcData = CVPixelBufferGetBaseAddress(pixelBuffer) else {
                print("Error: Cound not get pixel buffer base address")
                return nil
            }
            
            
            let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            var srcBuffer = vImage_Buffer(data: srcData.advanced(by: 0), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: srcBytesPerRow)
            let destBytesPerRow = width * 4
            guard let destData = malloc(height * destBytesPerRow) else {
                print("Error: Out of memory")
                return nil
            }
            var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: destBytesPerRow)
            
            let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
            CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
            
            print("\(CVPixelBufferGetWidth(pixelBuffer))")
            print("\(CVPixelBufferGetHeight(pixelBuffer))")
            print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")
            
            if error != kvImageNoError {
                print("Error:", error)
                free(destData)
                return nil
            }
            
            let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
                if let ptr = ptr {
                    free(UnsafeMutableRawPointer(mutating: ptr))
                }
            }
            
            //        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            let pixelFormat = kCVPixelFormatType_32BGRA
            var dstPixelBuffer: CVPixelBuffer?
            let status = CVPixelBufferCreateWithBytes(nil, width, height, pixelFormat, destData, destBytesPerRow, releaseCallback, nil, [kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue] as CFDictionary, &dstPixelBuffer)
            if status != kCVReturnSuccess {
                print("Error: Could not create new pixel buffer")
                free(destData)
                return nil
            }
            
            print("\(CVPixelBufferGetWidth(dstPixelBuffer!))")
            print("\(CVPixelBufferGetHeight(dstPixelBuffer!))")
            print("\(CVPixelBufferGetPixelFormatType(dstPixelBuffer!))")
            
            
//            let ciImage = CIImage(cvPixelBuffer: dstPixelBuffer!)
//            let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(dstPixelBuffer!))
//            let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(dstPixelBuffer!))
//            let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
//            let scaledImage = ciImage.transformed(by: scaleTransform)
//            ciContext.render(scaledImage, to: resizedPixelBuffer!)

            let rgbImage = UIImage(pixelBuffer: pixelBuffer)
            let ciImage = CIImage(image: rgbImage!)
//            let sx = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
//            let sy = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
//            let scaleTransform = CGAffineTransform(scaleX: 1, y: 1)
//            let scaledImage = ciImage!.transformed(by: scaleTransform)
            ciContext.render(ciImage!, to: resizedPixelBuffer)

            print("bounding: \(CVPixelBufferGetPixelFormatType(resizedPixelBuffer))")

            if CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, resizedPixelBuffer, nil, MTLPixelFormat.bgra8Unorm, width, height, 0, &texture) != kCVReturnSuccess {
                print("Convert failed")
            }
            
            
            if let texture = texture {
                print("convert MTLTexture success")
                return CVMetalTextureGetTexture(texture)
            }
        }
        
        return nil
    }
    
    // MARK: - Doing inference
    
    func predict(texture: MTLTexture) {
        
        mpsYOLO.predict(texture: texture) { result in
                        
            DispatchQueue.main.async {
                
                self.show(predictions: result.predictions)
                
//                if let texture = result.debugTexture {
//                    self.debugImageView.image = UIImage.image(texture: texture)
//                }
                
                let fps = self.measureFPS()
                self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", result.elapsed, fps)
                
                self.semaphore.signal()
            }
        }
    }
    
    func predict(image: UIImage) {
        if let pixelBuffer = image.pixelBuffer(width: YOLO.inputWidth, height: YOLO.inputHeight) {
            predict(pixelBuffer: pixelBuffer)
        }
    }
    
    func predict(pixelBuffer: CVPixelBuffer) {
        
        print("Predicting...")
        
        // Measure how long it takes to predict a single video frame.
        let startTime = CACurrentMediaTime()
        
        // Resize the input with Core Image to 416x416.
        guard let resizedPixelBuffer = resizedPixelBuffer else { return }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, [kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue] as CFDictionary, &tmpBuffer)
        
        print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")
        print("\(CVPixelBufferGetPixelFormatType(resizedPixelBuffer))")

        guard let tmpBuffer = tmpBuffer else { return }
        
        print("\(CVPixelBufferGetPixelFormatType(tmpBuffer))")
        
//        let tmpImage = CIImage(cvPixelBuffer: pixelBuffer)
//        ciContext.render(tmpImage, to: tmpBuffer)
//        if let tmpImage = UIImage(pixelBuffer: pixelBuffer, context: ciContext) {
//            print("tmpBuffer")
//            ciContext.render(tmpImage.ciImage!, to: tmpBuffer)
//        }
        
        
        CVPixelBufferLockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        guard let srcData = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            print("Error: Cound not get pixel buffer base address")
            return
        }
        
        
        let srcBytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        var srcBuffer = vImage_Buffer(data: srcData.advanced(by: 0), height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: srcBytesPerRow)
        let destBytesPerRow = width * 4
        guard let destData = malloc(height * destBytesPerRow) else {
            print("Error: Out of memory")
            return
        }
        var destBuffer = vImage_Buffer(data: destData, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: destBytesPerRow)
        
        let error = vImageScale_ARGB8888(&srcBuffer, &destBuffer, nil, vImage_Flags(0))
        CVPixelBufferUnlockBaseAddress(pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
        
        print("\(CVPixelBufferGetWidth(pixelBuffer))")
        print("\(CVPixelBufferGetHeight(pixelBuffer))")
        print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")
        
        if error != kvImageNoError {
            print("Error:", error)
            free(destData)
            return
        }
        
        let releaseCallback: CVPixelBufferReleaseBytesCallback = { _, ptr in
            if let ptr = ptr {
                free(UnsafeMutableRawPointer(mutating: ptr))
            }
        }
        
//        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        let pixelFormat = kCVPixelFormatType_32BGRA
        var dstPixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreateWithBytes(nil, width, height, pixelFormat, destData, destBytesPerRow, releaseCallback, nil, nil, &dstPixelBuffer)
        if status != kCVReturnSuccess {
            print("Error: Could not create new pixel buffer")
            free(destData)
            return
        }

        print("\(CVPixelBufferGetWidth(dstPixelBuffer!))")
        print("\(CVPixelBufferGetHeight(dstPixelBuffer!))")
        print("\(CVPixelBufferGetPixelFormatType(dstPixelBuffer!))")

//        var ciImage = CIImage(cvPixelBuffer: dstPixelBuffer!)
//        let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(dstPixelBuffer!))
//        let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(dstPixelBuffer!))
//        let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
//        let scaledImage = ciImage.transformed(by: scaleTransform)
//        ciContext.render(scaledImage, to: resizedPixelBuffer)
        
        // This is an alternative way to resize the image (using vImage)
//        if let resizedPixelBuffer = resizedPixelBuffer(pixelBuffer, width: YOLO.inputWidth, height: YOLO.inputHeight)
        
        // Resize the input to 416x416 and give it to our model.
//        if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
//            self.boundingBox = boundingBoxes
//            print("boundingBox: \(boundingBoxes.count)")
//            let elapsed = CACurrentMediaTime() - startTime
//            showOnMainThread(boundingBoxes, elapsed)
        
        let rgbImage = UIImage(pixelBuffer: pixelBuffer)
        let ciImage = CIImage(image: rgbImage!)
        let sx = CGFloat(YOLO.inputWidth) / CGFloat(CVPixelBufferGetWidth(pixelBuffer))
        let sy = CGFloat(YOLO.inputHeight) / CGFloat(CVPixelBufferGetHeight(pixelBuffer))
        let scaleTransform = CGAffineTransform(scaleX: sx, y: sy)
        let scaledImage = ciImage!.transformed(by: scaleTransform)
        ciContext.render(scaledImage, to: resizedPixelBuffer)
        
        
        print("bounding: \(CVPixelBufferGetPixelFormatType(resizedPixelBuffer))")

        
        
//        }
        if let boundingBoxes = try? yolo.predict(image: resizedPixelBuffer) {
            self.boundingBox = boundingBoxes
            print("boundingBox: \(boundingBoxes.count)")
            let elapsed = CACurrentMediaTime() - startTime
            showOnMainThread(boundingBoxes, elapsed)
        }
    }
    
    func predictUsingVision(pixelBuffer: CVPixelBuffer) {
        
        /*
         Measure how long it takes to predict a single video frame.
         Note that predict() can be called on the next frame while the previous ont
         is still being processed. Hence the need to queue up the start times.
         */
        
        print("Predicting using Vision")
        startTimes.append(CACurrentMediaTime())
        
        print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")
        
        // Vision will automatically resize the input image
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        
        print("\(CVPixelBufferGetPixelFormatType(pixelBuffer))")

        try? handler.perform([request])
    }
    
    var boundingBox: [YOLO.Prediction]?
    
    func visionRequestDidComplete(request: VNRequest, error: Error?) {
        
        if let observations = request.results as? [VNCoreMLFeatureValueObservation],
            let features = observations.first?.featureValue.multiArrayValue {
            
            print("Computing bounding box")
            let boundingBoxes = yolo.computeBoundingBoxes(features: features)
            print("visionBoungingBox: \(boundingBoxes.count)")
            self.boundingBox = boundingBoxes
            let elapsed = CACurrentMediaTime() - startTimes.remove(at: 0)
            showOnMainThread(boundingBoxes, elapsed)
        }
    }
    
    func showOnMainThread(_ boundingBoxes: [YOLO.Prediction], _ elapsed: CFTimeInterval) {
        
        DispatchQueue.main.async {
            
            // For debugging, to make sure that resized CVPixelBuffer is correct.
//            var debugImage: CGImage?
//            VTCreateCGImageFromCVPixelBuffer(resizedPixelBuffer, nil, &debugImage)
//            self.debugImageView.image = UIImage(cgImage: debugImage!)
            
            self.show(predictions: boundingBoxes)
            
            let fps = self.measureFPS()
            self.timeLabel.text = String(format: "Elapsed %.5f seconds - %.2f FPS", elapsed, fps)
            
            self.semaphore.signal()
        }
    }
    
    func measureFPS() -> Double {
        
        // Measure how many frames were actually delivered per second.
        framesDone += 1
        let frameCapturingElapsed = CACurrentMediaTime() - frameCapturingStartTime
        let currentFPSDelivered = Double(framesDone) / frameCapturingElapsed
        if frameCapturingElapsed > 1 {
            framesDone = 0
            frameCapturingStartTime = CACurrentMediaTime()
        }
//        frameCapturingStartTime = CACurrentMediaTime()
        
        return frameCapturingElapsed
    }

    func show(predictions: [YOLO.Prediction]) {
        
        print("First `show` bounding box")
        
        for i in 0..<boundingBoxes.count {
            
            if i < predictions.count {
                
                print("about to show")
                
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in the coordinate space of the input image,
                 which is a square image of 416x416 pixels. We want to show it on the video preview,
                 which is as wide as the screen and has a 16:9 aspect ratio.
                 The video preview also may be letterboxed at the top and bottom.
                 */
                let width = view.bounds.width
                let height = width * 9 / 16
                let scaleX = width / CGFloat(YOLO.inputWidth)
                let scaleY = height / CGFloat(YOLO.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
//                self.isPredicting = false
                
                self.currentTrackingTargetRect = rect
                
//                if labels[prediction.classIndex] == "person" {
//                    self.currentTrackingTargetRect = rect
//                    self.trackingRenderView.trackingRect = rect
//                }
                
            } else {
                boundingBoxes[i].hide()
            }
        }
    }
    
    func show(predictions: [MPSYOLO.Prediction]) {
        
        print("MPSYOLO: First `show` bounding box")
        
        for i in 0..<boundingBoxes.count {
            
            if i < predictions.count {
                
                let prediction = predictions[i]
                
                /*
                 The predicted bounding box is in the coordinate space of the input image,
                 which is a square image of 416x416 pixels. We want to show it on the video preview,
                 which is as wide as the screen and has a 4:3 aspect ratio.
                 The video preview also may be letterboxed at the top and bottom.
                 */
                let width = view.bounds.width
                let height = width * 9 / 16
                let scaleX = width / CGFloat(MPSYOLO.inputWidth)
                let scaleY = height / CGFloat(MPSYOLO.inputHeight)
                let top = (view.bounds.height - height) / 2
                
                // Translate and scale the rectangle to our own coordinate system.
                var rect = prediction.rect
                rect.origin.x *= scaleX
                rect.origin.y *= scaleY
                rect.origin.y += top
                rect.size.width *= scaleX
                rect.size.height *= scaleY
                
                // Show the bounding box.
                let label = String(format: "%@ %.1f", labels[prediction.classIndex], prediction.score * 100)
                let color = colors[prediction.classIndex]
                boundingBoxes[i].show(frame: rect, label: label, color: color)
//                self.isPredicting = false
                
                self.currentTrackingTargetRect = rect
                
            } else {
                boundingBoxes[i].hide()
            }
        }
    }

}
