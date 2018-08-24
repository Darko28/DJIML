//
//  DJIMLViewController+DJISDK.swift
//  DJIML
//
//  Created by Darko on 2018/8/24.
//  Copyright © 2018年 Darko. All rights reserved.
//

import Foundation
import DJISDK
import VideoPreviewer


extension DJIMLViewController {
    
    func setupVideoPreviewer() {
        
        VideoPreviewer.instance()?.contentClipRect = CGRect(x: 0, y: 0, width: 0.75, height: 0.75)
        VideoPreviewer.instance()?.type = .autoAdapt
        VideoPreviewer.instance()?.setView(self.fpvPreviewerView)
        VideoPreviewer.instance().adjustViewSize()
        
        if let product = DJISDKManager.product() {
            
            if (product.model! == DJIAircraftModelNameA3 || product.model! == DJIAircraftModelNameN3 || product.model! == DJIAircraftModelNameMatrice600 || product.model! == DJIAircraftModelNameMatrice600Pro) {
                DJISDKManager.videoFeeder()?.secondaryVideoFeed.add(self, with: nil)
                self.lastTimestamp = CACurrentMediaTime()
            } else {
                DJISDKManager.videoFeeder()?.primaryVideoFeed.add(self, with: nil)
            }
            
            VideoPreviewer.instance()?.start()
        }
    }
    
    func resetVideoPreviewer() {
        
        VideoPreviewer.instance()?.unSetView()
        
        if let product = DJISDKManager.product() {
            
            if (product.model! == DJIAircraftModelNameA3 || product.model! == DJIAircraftModelNameN3 || product.model! == DJIAircraftModelNameMatrice600 || product.model! == DJIAircraftModelNameMatrice600Pro) {
                DJISDKManager.videoFeeder()?.secondaryVideoFeed.remove(self)
            } else {
                DJISDKManager.videoFeeder()?.primaryVideoFeed.remove(self)
            }
        }
    }
    
    func fetchCamera() -> DJICamera? {
        
        guard DJISDKManager.product() != nil else {
            return nil
        }
        
        if DJISDKManager.product()!.isKind(of: DJIAircraft.self) {
            return (DJISDKManager.product()! as! DJIAircraft).camera
        } else if DJISDKManager.product()!.isKind(of: DJIHandheld.self) {
            return (DJISDKManager.product()! as! DJIHandheld).camera
        }
        
        return nil
    }
    
}

extension DJIMLViewController: DJISDKManagerDelegate, DJIBaseProductDelegate {
    
    func appRegisteredWithError(_ error: Error?) {
        
        var message = "Register App Successed!"
        if (error != nil) {
            message = "Register app failed! Please enter your app key and check the network."
        } else {
            if ENABLE_BRIDGE_MODE {
                DJISDKManager.enableBridgeMode(withBridgeAppIP: BRIDGE_IP)
            }
            DJISDKManager.startConnectionToProduct()
        }
        
        self.showAlertViewWithTitle(title:"Register App", withMessage: message)
    }
    
    func registerApp() {
        DJISDKManager.registerApp(with: self)
    }
    
    func showAlertViewWithTitle(title: String, withMessage message: String) {
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: UIAlertControllerStyle.alert)
        let okAction = UIAlertAction(title:"OK", style: UIAlertActionStyle.default, handler: nil)
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
        
    }
    
    // MARK: - DJISDKManagerDelegate
    
    func productConnected(_ product: DJIBaseProduct?) {
        
        if let product = product {
            product.delegate = self
            if let camera = self.fetchCamera() {
                camera.delegate = self
                
                //                camera.setVideoResolutionAndFrameRate(DJICameraVideoResolutionAndFrameRate(resolution: DJICameraVideoResolution.resolution1920x1080, frameRate: DJICameraVideoFrameRate.rate60FPS), withCompletion: nil)
                //                VideoPreviewer.instance().adjustViewSize()
            }
            self.setupVideoPreviewer()
        }
        
        DJISDKManager.userAccountManager().logIntoDJIUserAccount(withAuthorizationRequired: false) { (state, error) in
            if(error != nil){
                NSLog("Login failed: %@" + String(describing: error))
            }
        }
    }
    
    func productDisconnected() {
        
        if let camera = self.fetchCamera(), camera.delegate === self {
            camera.delegate = nil
        }
        self.resetVideoPreviewer()
    }
    
    //    func productDisconnected() {
    //
    //        NSLog("Product Disconnected")
    //
    //        let camera = self.fetchCamera()
    //        if((camera != nil) && (camera?.delegate?.isEqual(self))!){
    //            camera?.delegate = nil
    //        }
    //        self.resetVideoPreview()
    //    }
}


extension DJIMLViewController: DJICameraDelegate {
    
    // MARK: - DJICameraDelegate
    
    func camera(_ camera: DJICamera, didUpdate systemState: DJICameraSystemState) {
        
    }
}


extension DJIMLViewController: DJIFrameCaptureDelegate {
    
    func videoCapture(_ capture: DJIVideoFeed, didCaptureDJIVideoTexture texture: MTLTexture?) {
        
        print("didCaptureTexture")
        
        semaphore.wait()
        
        if let texture = texture {
            
            /*
             For better throughput, perform the prediction on a background queue
             instead of on the VideoCapture queue. We use the semaphore to block
             the capture queue and drop frames when CoreML can't keep up.
             */
            DispatchQueue.global().async {
                //                self.predict(pixelBuffer: pixelBuffer)
                self.predict(texture: texture)
            }
        }
    }
    
    
    func videoCapture(_ capture: DJIVideoFeed, didCaptureDJIVideoFrame pixelBuffer: CVPixelBuffer?) {
        
        print("didCaptureFrame")
        
        semaphore.wait()
        
        if let pixelBuffer = pixelBuffer {
            
            /*
             For better throughput, perform the prediction on a background queue
             instead of on the VideoCapture queue. We use the semaphore to block
             the capture queue and drop frames when CoreML can't keep up.
             */
            DispatchQueue.global().async {
                //                self.predict(pixelBuffer: pixelBuffer)
                self.predictUsingVision(pixelBuffer: pixelBuffer)
            }
        }
    }
}


extension DJIMLViewController: DJIVideoFeedListener, DJIVideoDataProcessDelegate {
    
    // MARK: - DJIVideoFeedListener
    
    public func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
        
        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: (videoData as NSData).length)
        (videoData as NSData).getBytes(videoBuffer, length: (videoData as NSData).length)
        VideoPreviewer.instance()?.push(videoBuffer, length: Int32((videoData as NSData).length))
        
        
        if shouldRunPrediction {
            
            /*
             Because lowering the capture device's FPS looks ugly in the preview,
             we capture at full speed but only call the delegate at its desired framerate.
             */
            let timestamp = CACurrentMediaTime()
            let deltaTime = timestamp - lastTimestamp
            lastTimestamp = timestamp
            
            print("Current: \(deltaTime), ----, -----\(measureFPS())")
            
            if deltaTime > measureFPS() {
                
                print(">")
                
                if let frameBuffer = VideoPreviewer.instance()?.videoExtractor.getCVImage() {
                    
                    if useCoreML {
                        videoCapture.delegate?.videoCapture(videoFeed, didCaptureDJIVideoFrame: frameBuffer.takeUnretainedValue())
                    } else {
                        let texture = convertToMTLTexture(imageBuffer: frameBuffer.takeUnretainedValue())
                        videoCapture.delegate?.videoCapture(videoFeed, didCaptureDJIVideoTexture: texture)
                    }
                }
            }
        }
        
    }
    
    
    //    func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
    //
    //        var data = videoData.withUnsafeBytes { (pointer: UnsafePointer<UInt8>) -> UInt8 in
    //            return pointer.pointee
    //        }
    //
    //        VideoPreviewer.instance()?.push(&data, length: Int32(videoData.count))
    //
    //
    //        let frameBuffer = videoDataProcessor?.getCVImage()
    //        let frameImage = UIImage(pixelBuffer: frameBuffer!.takeRetainedValue())
    //        print("\(Date())")
    //    }
    
    //    public func videoFeed(_ videoFeed: DJIVideoFeed, didUpdateVideoData videoData: Data) {
    //
    //        let videoBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: (videoData as NSData).length)
    //        (videoData as NSData).getBytes(videoBuffer, length: (videoData as NSData).length)
    //        VideoPreviewer.instance()?.push(videoBuffer, length: Int32((videoData as NSData).length))
    //
    //        /*
    //         Because lowering the capture device's FPS looks ugly in the preview,
    //         we capture at full speed but only call the delegate at its desired framerate.
    //         */
    //
    ////        let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
    ////        let deltaTime = timestamp - lastTimestamp
    ////        if deltaTime >= CMTimeMake(1, Int32(fps)) {
    ////            lastTimestamp = timestamp
    ////            let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
    ////            delegate?.videoCapture(self, didCaptureVideoFrame: imageBuffer, timestamp: timestamp)
    ////        }
    //
    //        let timestamp = VideoPreviewer.instance()!.getTickCount()
    //        let deltaTime = timestamp - lastTimestamp
    //
    //        let cmDelta = CMTimeMake(value: deltaTime, timescale: 1000*1000)
    //
    //        let strDelta = String(format: "%.8f", Double(deltaTime)/1000/1000)
    //        let doubleDelta = Double(strDelta)
    //
    //        let doubleFPS = Double(String(format: "%.8f", Double(1/measureFPS())))
    //
    //        if doubleDelta! >= doubleFPS! {
    //
    //            print("About to get CVPixelBuffer image")
    //            print("delta1: \(cmDelta)")
    //
    //            print("doubleDelta: \(doubleDelta!)")
    //            print("doubleFPS: \(doubleFPS!)")
    //
    //            lastTimestamp = timestamp
    //
    //            DJIMLViewController.deltaTime += 1
    //
    ////            videoDataProcessor?.getYuvFrame(UnsafeMutablePointer<VideoFrameYUV>!)
    //
    ////            DispatchQueue.global().async {
    //
    //
    //            if !self.isPredicting {
    //                if let frameBuffer = VideoPreviewer.instance()?.videoExtractor.getCVImage() {
    //
    //                    self.previousBuffer = frameBuffer.takeUnretainedValue()
    //
    //                    print("Got CVPixelBuffer image")
    //                    let frameImage = UIImage(pixelBuffer: frameBuffer.takeRetainedValue())
    //
    //                    //                fpvPreviewerView.delegate?.videoCapture(self.fpvPreviewerView, didCaptureDJIVideoFrame: frameBuffer.takeRetainedValue())
    //
    //                    self.semaphore.wait()
    //
    //                    let pixelBuffer = frameBuffer.takeUnretainedValue()
    //
    //                    /*
    //                     For better throughput, perform the prediction on a background queue
    //                     instead of on the VideoCapture queue. We use the semaphore to block
    //                     the capture queue and drop frames when CoreML can't keep up.
    //                     */
    //                    DispatchQueue.global().async {
    //                        self.predict(pixelBuffer: pixelBuffer)
    //                        self.isPredicting = true
    //                        //                    self.predictUsingVision(pixelBuffer: pixelBuffer)
    //                    }
    //
    ////                    DispatchQueue.global().asyncAfter(deadline: DispatchTime.distantFuture) {
    ////                        self.predict(pixelBuffer: pixelBuffer)
    ////                        self.isPredicting = true
    ////                    }
    //
    //                }
    //            } else {
    //
    ////                self.semaphore.wait()
    //
    //                DispatchQueue.global().async {
    ////                    self.predict(pixelBuffer: self.previousBuffer!)
    //                    if self.boundingBox != nil {
    //                        self.show(predictions: self.boundingBox!)
    //                        self.isPredicting = true
    //                    }
    //                }
    //            }
    ////            }
    //
    ////            if let frameBuffer = VideoPreviewer.instance()?.videoExtractor.getCVImage() {
    ////
    ////                print("Got CVPixelBuffer image")
    ////                let frameImage = UIImage(pixelBuffer: frameBuffer.takeRetainedValue())
    ////
    //////                fpvPreviewerView.delegate?.videoCapture(self.fpvPreviewerView, didCaptureDJIVideoFrame: frameBuffer.takeRetainedValue())
    ////
    ////                semaphore.wait()
    ////
    ////                let pixelBuffer = frameBuffer.takeUnretainedValue()
    ////
    ////                /*
    ////                 For better throughput, perform the prediction on a background queue
    ////                 instead of on the VideoCapture queue. We use the semaphore to block
    ////                 the capture queue and drop frames when CoreML can't keep up.
    ////                 */
    ////                DispatchQueue.global().async {
    ////                    self.predict(pixelBuffer: pixelBuffer)
    //////                    self.predictUsingVision(pixelBuffer: pixelBuffer)
    ////                }
    ////            }
    //        } else {
    ////            print("FPS: \(measureFPS())")
    //            print("delta2: \(deltaTime)")
    //            print("FramesDone: \(measureFPS())")
    //            DJIMLViewController.deltaTime = 0
    //        }
    //    }
}


extension DJIMLViewController {
    
    // MARK: - DJIActiveTrackMission
    
    func missionOperator() -> DJIActiveTrackMissionOperator? {
        return DJISDKManager.missionControl()?.activeTrackMissionOperator()
    }
    
    func pointToStreamSpace(point: CGPoint, withView view: UIView) -> CGPoint {
        
        let previewer: VideoPreviewer = VideoPreviewer.instance()
        let videoFrame = previewer.frame
        let videoPoint = previewer.convert(point, toVideoViewFrom: view)
        let normalized = CGPoint(x: videoPoint.x/videoFrame.size.width, y: videoPoint.y/videoFrame.size.height)
        
        return normalized
    }
    
    func pointFromStreamSpace(point: CGPoint) -> CGPoint {
        
        let previewer = VideoPreviewer.instance()!
        let videoFrame = previewer.frame
        let videoPoint = CGPoint(x: point.x*videoFrame.size.width, y: point.y*videoFrame.size.height)
        
        return videoPoint
    }
    
    func pointFromStreamSpace(point: CGPoint, withView view: UIView) -> CGPoint {
        
        let previewer = VideoPreviewer.instance()!
        let videoFrame = previewer.frame
        let videoPoint = CGPoint(x: point.x*videoFrame.size.width, y: point.y*videoFrame.size.height)
        return previewer.convert(videoPoint, fromVideoViewTo: view)
    }
    
    func sizeToStreamSpace(size: CGSize) -> CGSize {
        
        let previewer = VideoPreviewer.instance()!
        let videoFrame = previewer.frame
        return CGSize(width: size.width/videoFrame.size.width, height: size.height/videoFrame.size.height)
    }
    
    func sizeFromStreamSpace(size: CGSize) -> CGSize {
        
        let previewer = VideoPreviewer.instance()!
        let videoFrame = previewer.frame
        return CGSize(width: size.width*videoFrame.size.width, height: size.height*videoFrame.size.height)
    }
    
    func rectToStreamSpace(rect: CGRect, withView view: UIView) -> CGRect {
        
        let origin = pointToStreamSpace(point: rect.origin, withView: view)
        let size = sizeToStreamSpace(size: rect.size)
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
    
    func rectFromStreamSpace(rect: CGRect) -> CGRect {
        let origin = pointFromStreamSpace(point: rect.origin)
        let size = sizeFromStreamSpace(size: rect.size)
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
    
    func rectFromStreamSpace(rect: CGRect, withView view: UIView) -> CGRect {
        
        let origin = pointFromStreamSpace(point: rect.origin, withView: view)
        let size = sizeFromStreamSpace(size: rect.size)
        return CGRect(x: origin.x, y: origin.y, width: size.width, height: size.height)
    }
    
    func rectWithPoint(_ point1: CGPoint, and point2: CGPoint) -> CGRect {
        
        let origin_x = min(point1.x, point2.x)
        let origin_y = min(point1.y, point2.y)
        let width = fabs(point1.x - point2.x)
        let height = fabs(point1.y - point2.y)
        let rect = CGRect(x: origin_x, y: origin_y, width: width, height: height)
        
        return rect
    }
        
    @objc func startTargetTrackingWithRect(_ rect: CGRect) {
                
        guard self.currentTrackingTargetRect != nil, self.currentTrackingTargetRect!.contains(trackTapGestureRecognizer.location(in: self.trackingRenderView)) else {
            showResult(format: "Tap location should be inside the trackingTarget rect!")
            return
        }
        
        self.shouldRunPrediction = false
        
        let normalizedRect = rectToStreamSpace(rect: self.currentTrackingTargetRect!, withView: self.trackingRenderView)
        
        let trackMission: DJIActiveTrackMission = DJIActiveTrackMission()
        trackMission.targetRect = normalizedRect
        trackMission.mode = DJIActiveTrackMode.trace
        
        self.missionOperator()?.start(trackMission, withCompletion: { [weak self] error in
            if error != nil {
                showResult(format: "Start Tracking failed, \(error!.localizedDescription)")
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
                self?.shouldRunPrediction = true
            } else {
                
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
            }
        })
    }
    
    @objc func stopTargetTracking() {
        
        self.missionOperator()!.stopMission { (error) in
            if error != nil {
                showResult(format: "Stop Mission failed: \(error!.localizedDescription)")
            } else {
                self.shouldRunPrediction = true
            }
        }
    }
    
    func isTrackingState(state: DJIActiveTrackMissionState) -> Bool {
        switch state {
        // ?
        case DJIActiveTrackMissionState.findingTrackedTarget,
             DJIActiveTrackMissionState.aircraftFollowing,
             DJIActiveTrackMissionState.onlyCameraFollowing,
             DJIActiveTrackMissionState.cannotConfirm,
             DJIActiveTrackMissionState.waitingForConfirmation,
             DJIActiveTrackMissionState.performingQuickShot:
            return true
        default:
            break
        }
        return false
    }
    
    func isTrackingMissionRunning() -> Bool {
        guard self.missionOperator() != nil else {
            return false
        }
        return self.isTrackingState(state: self.missionOperator()!.currentState)
    }
    
    func didUpdateActiveTrackEvent(_ event: DJIActiveTrackMissionEvent) {
        
        let previousState: DJIActiveTrackMissionState = event.previousState
        let currentState: DJIActiveTrackMissionState = event.currentState
        
        if (self.isTrackingState(state: previousState) && self.isTrackingState(state: currentState)) {
            if event.error != nil {
                showResult(format: "Mission Interrupted: \(event.error!.localizedDescription)")
            }
        }
        
        if event.trackingState != nil {
            
            let state = event.trackingState!
            
            let rect = rectFromStreamSpace(rect: state.targetRect, withView: self.trackingRenderView)
            self.currentTrackingTargetRect = rect
            
            if event.trackingState!.state == DJIActiveTrackTargetState.waitingForConfirmation {
                self.isNeedConfirm = true
                self.trackingRenderView.text = "?"
            } else {
                self.isNeedConfirm = false
                self.trackingRenderView.text = nil
            }
            
            var color: UIColor?
            
            switch state.state {
            case DJIActiveTrackTargetState.waitingForConfirmation:
                color = UIColor.orange.withAlphaComponent(0.5)
            case DJIActiveTrackTargetState.cannotConfirm:
                color = UIColor.red.withAlphaComponent(0.5)
            case DJIActiveTrackTargetState.trackingWithHighConfidence:
                color = UIColor.green.withAlphaComponent(0.5)
            case DJIActiveTrackTargetState.trackingWithLowConfidence:
                color = UIColor.yellow.withAlphaComponent(0.5)
            case DJIActiveTrackTargetState.unknown:
                color = UIColor.green.withAlphaComponent(0.5)
            }
            
            self.trackingRenderView.updateRect(rect, fillColor: color)
            
        } else {
            
            self.trackingRenderView.isDottedLine = false
            self.trackingRenderView.text = nil
            self.isNeedConfirm = false
            self.trackingRenderView.updateRect(CGRect.null, fillColor: nil)
        }
    }
    
    @objc
    func targetAcceptConfirmation() {
        
        self.missionOperator()!.acceptConfirmation { [weak self] (error) in
            if error != nil {
                showResult(format: "Accept Confirmation Failed: \(error!.localizedDescription)")
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
            } else {
                self?.shouldRunPrediction = false
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
            }
        }
    }
    
    @objc
    func stopFollowingTarget() {
        
        self.missionOperator()!.stopAircraftFollowing { [weak self] (error) in
            if error != nil {
                showResult(format: "Stop aircraft following failed: \(error!.localizedDescription)")
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
            } else {
                self!.shouldRunPrediction = true
                self!.boundingBoxes.map { (boundingBox) in
                    boundingBox.hide()
                }
            }
        }
    }
    
//    // MARK: - TrackingRenderViewDelegate
//    
//    func renderViewDidTouchAtPoint(_ point: inout CGPoint) {
//        
//        if (self.isTrackingMissionRunning() && !self.isNeedConfirm) {
//            return
//        }
//        
//        if self.isNeedConfirm {
//            
//            let largeRect = self.currentTrackingTargetRect!.insetBy(dx: -10, dy: -10)
//            if largeRect.contains(point) {
//                self.missionOperator()!.acceptConfirmation { (error: Error?) in
//                    print("Confirm Tracking: \(error!.localizedDescription)")
//                }
//            } else {
//                self.missionOperator()?.stopMission(completion: { (error) in
//                    print("Cancel Tracking: \(error!.localizedDescription)")
//                })
//            }
//        } else {
//            
//            point = pointToStreamSpace(point: point, withView: self.trackingRenderView)
//            let mission = DJIActiveTrackMission()
//            mission.targetRect = CGRect(x: point.x, y: point.y, width: 0, height: 0)
//            mission.mode = DJIActiveTrackMode.trace
//            
//            self.missionOperator()!.start(mission) { [weak self] (error) in
//                if error != nil {
//                    print("Start Mission Error: \(error!.localizedDescription)")
//                    self!.trackingRenderView.isDottedLine = false
//                    self!.trackingRenderView.updateRect(CGRect.null, fillColor: nil)
//                } else {
//                    print("Start Mission Success!")
//                }
//            }
//        }
//    }
//    
//    func renderViewDidMoveToPoint(_ endPoint: CGPoint, fromPoint startPoint: CGPoint, isFinished finished: Bool) {
//        
//        self.trackingRenderView.isDottedLine = true
//        self.trackingRenderView.text = nil
//        
//        let rect = rectWithPoint(startPoint, and: endPoint)
//        
//        self.trackingRenderView.updateRect(rect, fillColor: UIColor.green.withAlphaComponent(0.5))
//        
//        if finished {
//            let rect = rectWithPoint(startPoint, and: endPoint)
//            self.startMissionWithRect(rect)
//        }
//    }
//    
//    func startMissionWithRect(_ rect: CGRect) {
//        
//        let normalizedRect: CGRect = rectToStreamSpace(rect: rect, withView: self.trackingRenderView)
//        let trackMission = DJIActiveTrackMission()
//        trackMission.targetRect = normalizedRect
//        trackMission.mode = DJIActiveTrackMode.trace
//        
//        self.missionOperator()!.start(trackMission) { [weak self] (error) in
//            if error != nil {
//                self!.trackingRenderView.isDottedLine = false
//                self!.trackingRenderView.updateRect(CGRect.null, fillColor: nil)
//                print("Start Mission Error: \(error!.localizedDescription)")
//            } else {
//                print("Start Mission Success")
//            }
//        }
//    }
}
