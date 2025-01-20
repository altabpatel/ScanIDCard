// The Swift Programming Language
// https://docs.swift.org/swift-book

import UIKit
import AVFoundation
import Vision

//CognizantDeveloper Starts - used to set CameraPosition & CameraOrientation
@objc public class CameraPositionClass:NSObject{//CognizantDeveloper - added @objc to access it inside MyHybridController
    @MainActor @objc public static let shared = CameraPositionClass()//CognizantDeveloper - added @objc to access it inside MyHybridController
    @objc override init() {//CognizantDeveloper - added @objc to access it inside MyHybridController/
    }
    @objc public var camerPositionValueInHandler:String = "front"//CognizantDeveloper - added @objc to access it inside MyHybridController
    @objc public var cameraOrientationValueInHandler:AVCaptureVideoOrientation = .portrait//CognizantDeveloper - added @objc to access it inside MyHybridController
}
//CognizantDeveloper Ends

class ObjectDetectionSessionHandler: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    var session = AVCaptureSession()
    
    lazy var captureLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer(session: self.session)
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    lazy var rectangleDetectionQueue: DispatchQueue = {
        return DispatchQueue(label: "com.appliedrec.Ver-ID.RectangleDetection", attributes: [])
    }()
    
    lazy var imageConversionOperationQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        return queue
    }()
    
    lazy var device: AVCaptureDevice? = {
        let deviceTypes: [AVCaptureDevice.DeviceType]
        if #available(iOS 13.0, *) {
            deviceTypes = [.builtInTripleCamera, .builtInDualWideCamera, .builtInDualCamera, .builtInWideAngleCamera]
        } else {
            // Fallback on earlier versions
            deviceTypes = [.builtInWideAngleCamera]
        }
//        if(CameraPositionClass.shared.camerPositionValueInHandler == "front"){
//            return AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .front).devices.first
//        }else{
            return AVCaptureDevice.DiscoverySession(deviceTypes: deviceTypes, mediaType: .video, position: .back).devices.first
//        }
    }()
    
    /*
    lazy var device: AVCaptureDevice? = {
        print("camerPositionValueInHandler---",CameraPositionClass.shared.camerPositionValueInHandler)
        if(CameraPositionClass.shared.camerPositionValueInHandler == "front"){
            return AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: .front) //CognizantDeveloper
        }else{
            return AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: .back) //CognizantDeveloper - default
        }
        /*
        //CognizantDeveloper - Starts
        guard let device = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .back).devices.first else {
                fatalError("No back camera device found.")
            return AVCaptureDevice.default(.builtInWideAngleCamera , for: .video, position: .back)!
        }
        return device
        //CognizantDeveloper - Ends
         */
    }()*/
    
    var imageOrientation: CGImagePropertyOrientation = .right
    
    weak var delegate: CardDetectionSessionHandlerDelegate?
    
    var isTorchAvailable: Bool {
        guard let device = self.device else {
            return false
        }
        return device.hasTorch && device.isTorchAvailable
    }

//    var cardDetectionSettings: BaseCardDetectionSettings?
//    var barcodeDetectionSettings: BaseBarcodeDetectionSettings?
//    var torchSettings: TorchSettings?
    
    var imageTransform: CGAffineTransform {
        switch self.imageOrientation {
        case .right, .left:
            return CGAffineTransform(scaleX: self.captureLayer.bounds.width, y: 0-self.captureLayer.bounds.height).concatenating(CGAffineTransform(translationX: 0, y: self.captureLayer.bounds.height))
        default:
            return CGAffineTransform(scaleX: 0-self.captureLayer.bounds.width, y: self.captureLayer.bounds.height).concatenating(CGAffineTransform(translationX: self.captureLayer.bounds.width, y: 0))
        }
    }
    
    var stillImageOutput: AVCapturePhotoOutput!
    
    func startCamera() {
        guard let device = self.device else {
            return
        }
    
        do {
            try device.lockForConfiguration()
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            device.unlockForConfiguration()
        } catch {
            
        }
        
        self.imageConversionOperationQueue.isSuspended = false
        
        let input = try! AVCaptureDeviceInput(device: device)
        //CognizantDeveloper - starts
        /*
        let videoPresets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720] //etc. Put them in order to "preferred" to "last preferred"
        let preset = videoPresets.first(where: { device.supportsSessionPreset($0) }) ?? .hd1280x720
        session.sessionPreset = preset
        
        
        //try to enable auto focus
         if(device.isFocusModeSupported(.continuousAutoFocus)) {
             try! device.lockForConfiguration()
             device.focusMode = .continuousAutoFocus
             device.unlockForConfiguration()
         }
         */
        //CognizantDeveloper - ends
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: self.rectangleDetectionQueue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        session.sessionPreset = .hd1920x1080 // Use HD resolution instead of the default one (which could be 4K)//Venkat after 1.9
        session.beginConfiguration()
        
        if session.canAddInput(input) {
            session.addInput(input)
        }
        
        stillImageOutput = AVCapturePhotoOutput()
        if  ((session.canAddOutput(stillImageOutput)) != nil) {
            session.addOutput(stillImageOutput)
            stillImageOutput.isHighResolutionCaptureEnabled = true
            //stillImageOutput.maxPhotoDimensions = .supportedMaxPhotoDimensions
            stillImageOutput.isLivePhotoCaptureEnabled = stillImageOutput.isLivePhotoCaptureSupported
        }
        
        session.commitConfiguration()
        //CognizantDeveloper
        DispatchQueue.global(qos: .background).async {
                      self.session.startRunning()
                  }
    }
    func setupCamera()  {
//        captureSession = AVCaptureSession()
        guard let device = self.device else {
            return
        }
        do {
            try device.lockForConfiguration()
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
            }
            if device.isFocusModeSupported(.continuousAutoFocus) {
                device.focusMode = .continuousAutoFocus
            } else if device.isFocusModeSupported(.autoFocus) {
                device.focusMode = .autoFocus
            }
            if device.isFocusPointOfInterestSupported {
                device.focusPointOfInterest = CGPoint(x: 0.5, y: 0.5)
            }
            device.unlockForConfiguration()
        } catch {
            
        }
        let input = try! AVCaptureDeviceInput(device: device)
        
        
        
        guard let videoInput = try? AVCaptureDeviceInput(device: device) else {
            fatalError("Cannot create video input")
        }
        
        let videoPresets: [AVCaptureSession.Preset] = [.hd4K3840x2160, .hd1920x1080, .hd1280x720,.high,.photo] //etc. Put them in order to "preferred" to "last preferred"
        let preset = videoPresets.first(where: { device.supportsSessionPreset($0) }) ?? .high
        session.sessionPreset = preset
        
        //try to enable auto focus
        if(device.isFocusModeSupported(.continuousAutoFocus)) {
            try! device.lockForConfiguration()
            device.focusMode = .continuousAutoFocus
            device.unlockForConfiguration()
        }
        
        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "com.appliedrec.Ver-ID.RectangleDetection", attributes: []))
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]
        //        captureSession.sessionPreset = .hd1920x1080 // Use HD resolution instead of the default one (which could be 4K)//Venkat after 1.9
        session.beginConfiguration()
        session.sessionPreset = AVCaptureSession.Preset.photo
        
        if ((session.canAddInput(input)) != nil) {
            session.addInput(input)
        }
        
        if ((session.canAddOutput(videoOutput)) != nil) {
            session.addOutput(videoOutput)
        }
        
        
        stillImageOutput = AVCapturePhotoOutput()
        if  ((session.canAddOutput(stillImageOutput)) != nil) {
            session.addOutput(stillImageOutput)
            stillImageOutput.isHighResolutionCaptureEnabled = true
            //stillImageOutput.maxPhotoDimensions = .supportedMaxPhotoDimensions
            stillImageOutput.isLivePhotoCaptureEnabled = stillImageOutput.isLivePhotoCaptureSupported
        }
        
        session.commitConfiguration()
        //CognizantDeveloper
        DispatchQueue.global(qos: .background).async {
                      self.session.startRunning()
                  }
        
//        //CognizantDeveloper
//        DispatchQueue.global(qos: .background).async {
//            DispatchQueue.main.async {
//            Task { @MainActor in
//                 self.captureSession.startRunning()
//                }
//            }
//        }
       
        
//        DispatchQueue.global(qos: .background).async {
//            DispatchQueue.main.async {
////                self.captureSession.startRunning()
//            }
            
            
//        }
       
//        setupDetectionLayer()
//        designCaptureButton()
//        updatePreview()
    }
    
    func stopCamera() {
//        self.toggleTorch(on: false)
//        self.imageConversionOperationQueue.cancelAllOperations()
//        self.imageConversionOperationQueue.isSuspended = true
        session.stopRunning()
//        self.captureLayer.removeFromSuperlayer()//CognizantDeveloper
    }
    func startCameraSession() {
        DispatchQueue.global(qos: .background).async {
            self.session.startRunning()
        }
    }
    func capturePhoto() {
//        isCapturingPhoto = true
        /*let settings = AVCapturePhotoSettings()
        stillImageOutput.capturePhoto(with: settings, delegate: self)*/
        
        let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        stillImageOutput.capturePhoto(with: settings, delegate: self)
        
        
        //           let settings = AVCapturePhotoSettings(format: [AVVideoCodecKey: AVVideoCodecType.jpeg])
        //           stillImageOutput.capturePhoto(with: settings, delegate: self)
    }
//    func toggleTorch(on: Bool) {
//        guard let device = self.device else {
//            return
//        }
//        if device.hasTorch && device.isTorchAvailable {
//            do {
//                try device.lockForConfiguration()
//                if on {
//                    if let torchLevel = self.torchSettings?.torchLevel {
//                        try device.setTorchModeOn(level: torchLevel)
//                    } else {
//                        device.torchMode = .on
//                    }
//                } else {
//                    device.torchMode = .off
//                }
//                device.unlockForConfiguration()
//            } catch {
//                NSLog("Unable to lock device for configuation: %@", error.localizedDescription)
//            }
//        }
//    }
    
    func featureTransform(fromSize size: CGSize, atOrientation orientation: CGImagePropertyOrientation) -> CGAffineTransform {
        switch orientation {
        case .right, .left:
            return CGAffineTransform(scaleX: size.width, y: 0-size.height).concatenating(CGAffineTransform(translationX: 0, y: size.height))
        default:
            return CGAffineTransform(scaleX: 0-size.width, y: size.height).concatenating(CGAffineTransform(translationX: size.width, y: 0))
        }
    }
    
//    func rectangleDetectionRequest(withPixelBuffer pixelBuffer: CVImageBuffer) -> VNDetectRectanglesRequest? {
//        guard let delegate = self.delegate, delegate.shouldDetectCardImageWithSessionHandler(self) && !self.imageConversionOperationQueue.isSuspended && self.imageConversionOperationQueue.operationCount == 0 else {
//            return nil
//        }
//        let orientation = self.imageOrientation
//        let rectangleDetectionRequest = VNDetectRectanglesRequest() { (request, error) in
////            if let rect = request.results?.first as? VNRectangleObservation, !self.imageConversionOperationQueue.isSuspended && self.imageConversionOperationQueue.operationCount == 0 {
////                let op = PerspectiveCorrectionParamsOperation(pixelBuffer: pixelBuffer, orientation: orientation, rect: rect)
////                op.completionBlock = { [weak self, weak op] in
////                    let sharpness = op?.sharpness
////                    if let cgImage = op?.cgImage, let corners = op?.corners, let params = op?.perspectiveCorrectionParams {
////                        DispatchQueue.main.async {
//////                            guard let `self` = self else {
//////                                return
//////                            }
//////                            delegate.sessionHandler( didDetectCardInImage: cgImage, withTopLeftCorner: corners.topLeft, topRightCorner: corners.topRight, bottomRightCorner: corners.bottomRight, bottomLeftCorner: corners.bottomLeft, perspectiveCorrectionParams: params, sharpness: sharpness)
////                            
////                        }
////                        
////                    }
////                }
////                self.imageConversionOperationQueue.addOperation(op)
////            }
//        }
//        
//        //CognizantDeveloper - starts
//        /*
//        rectangleDetectionRequest.minimumAspectRatio = VNAspectRatio(1.3)
//        rectangleDetectionRequest.maximumAspectRatio = VNAspectRatio(1.6)
//        rectangleDetectionRequest.minimumSize = Float(0.5)
//         */
//        //CognizantDeveloper - ends
//        
//        rectangleDetectionRequest.maximumObservations = 1
//        return rectangleDetectionRequest
//    }
    
//    func barcodeDetectionRequest(settings: BaseBarcodeDetectionSettings) -> VNDetectBarcodesRequest? {
//        guard let delegate = self.delegate, delegate.shouldDetectBarcodeWithSessionHandler(self) else {
//            return nil
//        }
//        let request = VNDetectBarcodesRequest { request, error in
//            guard let barcodes = request.results?.compactMap({ $0 as? VNBarcodeObservation }), !barcodes.isEmpty else {
//                return
//            }
//            DispatchQueue.main.async {
//                self.delegate?.sessionHandler(self, didDetectBarcodes: barcodes)
//            }
//        }
//        request.symbologies = settings.barcodeSymbologies
//        return request
//    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        if let adjustingFocus = self.device?.isAdjustingFocus, adjustingFocus {
//            return
//        }
//        guard let delegate = self.delegate else {
//            return
//        }
        DispatchQueue.global(qos: .userInitiated).async { [self] in
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                    print("Failed to get pixel buffer")
                    return
                }
                Task { @MainActor in
                    delegate!.detectRectangles1(from: sampleBuffer)
                }
            }
        
//        if !delegate.shouldDetectBarcodeWithSessionHandler(self) && !delegate.shouldDetectCardImageWithSessionHandler(self) {
//            return
//        }
        
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
//            return
//        }
//        let requestOptions: [VNImageOption:Any] = [:]
//        
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: self.imageOrientation, options: requestOptions)
//        
//        var requests: [VNRequest] = []
//        if let rectangleDetectionRequest = self.rectangleDetectionRequest(withPixelBuffer: pixelBuffer) {
//            requests.append(rectangleDetectionRequest)
//        }
//        if delegate.shouldDetectBarcodeWithSessionHandler(self), let settings = self.barcodeDetectionSettings, let request = self.barcodeDetectionRequest(settings: settings) {
//            requests.append(request)
//        }
//        if !requests.isEmpty {
//            do {
//                try handler.perform(requests)
//            } catch {
//                
//            }
//        }
    }
}
extension ObjectDetectionSessionHandler: AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: data) else { return }
        
        session.stopRunning()
        
        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let newImage = capturedImage.rotate(radians: 0.0)
                Task { @MainActor in
                    delegate!.sendCaptureImage(image: newImage)
                }
            }
        
    }
}

protocol CardDetectionSessionHandlerDelegate: AnyObject {
    func sessionHandler( didDetectCardInImage image: CGImage, withTopLeftCorner topLeftCorner: CGPoint, topRightCorner: CGPoint, bottomRightCorner: CGPoint, bottomLeftCorner: CGPoint, perspectiveCorrectionParams: [String:CIVector], sharpness: Float?)
    func sessionHandler(_ handler: ObjectDetectionSessionHandler, didDetectBarcodes barcodes: [VNBarcodeObservation])
    func shouldDetectCardImageWithSessionHandler(_ handler: ObjectDetectionSessionHandler) -> Bool
    func shouldDetectBarcodeWithSessionHandler(_ handler: ObjectDetectionSessionHandler) -> Bool
    @MainActor func detectRectangles1(from sampleBuffer: CMSampleBuffer)
    
    @MainActor func sendCaptureImage(image:UIImage)
}
extension CMSampleBuffer {
    func copy() -> CMSampleBuffer? {
        guard let imageBuffer = CMSampleBufferGetImageBuffer(self) else { return nil }
        var timingInfo = CMSampleTimingInfo()
        CMSampleBufferGetSampleTimingInfo(self, at: 0, timingInfoOut: &timingInfo)
        
        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: nil,
            imageBuffer: imageBuffer,
            formatDescriptionOut: &formatDescription
        )
        
        var copiedBuffer: CMSampleBuffer?
        CMSampleBufferCreateForImageBuffer(
            allocator: nil,
            imageBuffer: imageBuffer,
            dataReady: true,
            makeDataReadyCallback: nil,
            refcon: nil,
            formatDescription: formatDescription!,
            sampleTiming: &timingInfo,
            sampleBufferOut: &copiedBuffer
        )
        return copiedBuffer
    }
}
