/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The camera preview view that displays the capture output.
*/

import UIKit
import AVFoundation

protocol Preview: UIView {
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {get}
    var session: AVCaptureSession? { get set }
}

class PreviewView: UIView, Preview {
    
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        guard let layer = layer as? AVCaptureVideoPreviewLayer else {
            fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check PreviewView.layerClass implementation.")
        }
        return layer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
