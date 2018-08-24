//
//  TrackingRenderView.swift
//  DJIML
//
//  Created by Darko on 2018/8/23.
//  Copyright © 2018年 Darko. All rights reserved.
//

import UIKit


/**
 Used to track single touch event and drawing rectange touch event.
 
 - Tag: Deprecated
 */
protocol TrackingRenderViewDelegate {
    func renderViewDidTouchAtPoint(_ point: inout CGPoint)
    func renderViewDidMoveToPoint(_ endPoint: CGPoint, fromPoint startPoint: CGPoint, isFinished finished: Bool)
}


let TEXT_RECT_WIDTH: CGFloat = 40.0
let TEXT_RECT_HEIGHT: CGFloat = 40.0

class TrackingRenderView: UIView {
    
    var trackingRect: CGRect?
    var isDottedLine: Bool = false
    var text: String?
    var delegate: TrackingRenderViewDelegate?
    
    var fillColor: UIColor?
    
    var startPoint: CGPoint = .zero
    var endPoint: CGPoint = .zero
    var isMoved: Bool = false

    
    // MARK: - UIResponder Methods
    
//    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.isMoved = false
//        self.startPoint = touches.first!.location(in: self)
//        
//        guard self.trackingRect != nil else {
//            showResult(format: "No tracking object")
//            return
//        }
//        
//        if self.trackingRect!.contains(self.startPoint) {
//            
//        }
//    }
//    
//    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.isMoved = true
//        self.endPoint = (touches as AnyObject).location(in: self)
//        
//        if (self.delegate != nil) {
//            self.delegate!.renderViewDidMoveToPoint(self.endPoint, fromPoint: self.startPoint, isFinished: false)
//        }
//    }
//    
//    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.endPoint = (touches as AnyObject).location(in: self)
//        if self.isMoved {
//            if self.delegate != nil {
//                self.delegate!.renderViewDidMoveToPoint(self.endPoint, fromPoint: self.startPoint, isFinished: true)
//            }
//        } else {
//            if self.delegate != nil {
//                self.delegate!.renderViewDidTouchAtPoint(&self.startPoint)
//            }
//        }
//    }
//    
//    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
//        self.endPoint = (touches as AnyObject).location(in: self)
//        if self.isMoved {
//            if self.delegate != nil {
//                self.delegate!.renderViewDidMoveToPoint(self.endPoint, fromPoint: self.startPoint, isFinished: true)
//            }
//        }
//    }
    
    func updateRect(_ rect: CGRect, fillColor: UIColor?) {
        
//        guard self.trackingRect != nil else { return }
        
        if self.trackingRect != nil {
            if rect.equalTo(self.trackingRect!) {
                return
            }
        }
        
        self.fillColor = fillColor
        self.trackingRect = rect
        
        self.setNeedsDisplay()
    }
    
    func setText(_ text: String) {
        if self.text == text {
            return
        }
        self.text = text
        self.setNeedsDisplay()
    }
    
    // Only override draw() if you perform custom drawing.
    // An empty implementation adversely affects performance during animation.
    override func draw(_ rect: CGRect) {
        // Drawing code
        
        super.draw(rect)
        
        guard self.trackingRect != nil else { return }
        if self.trackingRect!.equalTo(CGRect.null) {
            return
        }
        
        if let context: CGContext = UIGraphicsGetCurrentContext() {
            let strokeColor = UIColor.gray
            context.setStrokeColor(strokeColor.cgColor)
            if let fillColor = self.fillColor {
                context.setFillColor(fillColor.cgColor)
            }
            context.setLineWidth(1.8)
            
            if self.isDottedLine {
                context.setLineDash(phase: 0, lengths: [10, 10])
            }
            
            context.addRect(self.trackingRect!)
            context.drawPath(using: CGPathDrawingMode.fillStroke)
            
            if self.text != nil {
                
                let origin_x = self.trackingRect!.origin.x + 0.5*CGFloat(self.trackingRect!.size.width) - 0.5*TEXT_RECT_WIDTH
                let origin_y = self.trackingRect!.origin.y + 0.5*CGFloat(self.trackingRect!.size.height) - 0.5*TEXT_RECT_HEIGHT
                let textRect = CGRect(x: origin_x, y: origin_y, width: TEXT_RECT_WIDTH, height: TEXT_RECT_HEIGHT)
                
                let paragraphStyle: NSMutableParagraphStyle = NSParagraphStyle.default.mutableCopy() as! NSMutableParagraphStyle
                paragraphStyle.lineBreakMode = NSLineBreakMode.byCharWrapping
                paragraphStyle.alignment = NSTextAlignment.center
                
                let font = UIFont.boldSystemFont(ofSize: 35)
                let dic = [NSAttributedStringKey.font : font, NSAttributedStringKey.paragraphStyle : paragraphStyle, NSAttributedStringKey.foregroundColor : UIColor.white]
                
                self.text!.draw(in: textRect, withAttributes: dic)
            }
        }
    }

}
