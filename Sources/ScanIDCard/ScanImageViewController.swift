
#if canImport(UIKit)
import UIKit
import Vision
//import AVFoundation //RAMAN---

import VisionKit//Venkat
import AVFoundation


@available(iOS 13.0, *)
@MainActor public class ScanImageViewController: UIViewController {
    @IBOutlet weak var doneButton: UIBarButtonItem!
    @IBOutlet weak var cameraBaseView: UIView!
    @IBOutlet weak var activityIndicatorView: UIView!
    
    
    @IBOutlet weak var sampleImageView2: UIImageView!
    
    @IBOutlet weak var imageCropperView: UIView!
    
    @IBOutlet weak var cameraClickBtnView: UIView!
    
    @IBOutlet weak var btnImageCapture: UIButton!
    
    @IBOutlet weak var btnAutoManual: UIButton!
    
    @IBOutlet weak var sampleImageView: UIImageView!
    
    var sampleImage2: UIImage!
    
    @objc var accessTokenValue: String = "";
   
    var finalOCRString: String = "";//Venkat
    private var ocrRequest = VNRecognizeTextRequest(completionHandler: nil)//Venkat

    private var detectionLayer = CAShapeLayer()
    private var isCapturingPhoto = false
    
    private var lastStableRectangle: VNRectangleObservation?
    private var rectangleDetectionStartTime: Date?
    private let stabilityDuration: TimeInterval = 0.4 // Stability duration in seconds
    private let confidenceThreshold: Float = 1.0 // Minimum rectangle confidence
    var imageBufer : CVPixelBuffer?
    private var isManualCaptureImage = false
    
    var isAutoCaptureProccesing = false
    
    var isOrientationHappened = false
    
    var orientationName = "Portrait"
    
    let sessionHandler = ObjectDetectionSessionHandler()
    
    public var delegate: ScanImageOCRTextSendToView?

    
    public  init() {
        super.init(nibName: "ScanImageViewController", bundle: Bundle.module)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
  // MARK: - Override Functions
    public override func viewDidLoad() {
    super.viewDidLoad()
      configureOCR()//Altab
      cameraBaseView.isHidden = false
      imageCropperView.isHidden = true
      rectangleDetectionStartTime = Date()
      
    let notificationCenter = NotificationCenter.default
       notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
      
//      NotificationCenter.default.addObserver(self, selector: #selector(ScanImageViewController.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
      
      NotificationCenter.default.addObserver(self, selector: #selector(onAppDidBecomeActive(_:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
    activityIndicatorView.isHidden = true
        self.cameraBaseView.layer.addSublayer(self.sessionHandler.captureLayer)
        setupDetectionLayer()
        designCaptureButton()
        self.sessionHandler.delegate = self
        self.navigationController?.navigationBar.barStyle = .blackTranslucent
        switch AVCaptureDevice.authorizationStatus(for: AVMediaType.video) {
        case .authorized:
            self.sessionHandler.setupCamera()
        case .notDetermined:
            self.sessionHandler.imageConversionOperationQueue.isSuspended = true
            AVCaptureDevice.requestAccess(for: AVMediaType.video, completionHandler: { [weak self] granted in
                guard let `self` = self else {
                    return
                }
                if granted {
                    self.sessionHandler.setupCamera()
                } else {
                   // self.cancel()
                }
            })
        default:
            self.sessionHandler.imageConversionOperationQueue.isSuspended = true
//            guard let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String else {
//                return
//            }
//            let alert = UIAlertController(title: "Camera permission required", message: "ID capture requires camera permission. Please enable camera for \(appName) in settings", preferredStyle: .alert)
//            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
//                self.cancel()
//            }))
//            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in
//                self.cancel()
//            }))
//            self.present(alert, animated: true, completion: nil)
            break
        }
       
//        self.backgroundOperationQueue.isSuspended = false
//        self.backgroundOperationQueue.cancelAllOperations()
//        self.updateCameraOrientation()
        self.view.layoutIfNeeded()
  }
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        self.sessionHandler.captureLayer.frame = self.cameraBaseView.bounds
        createCorners()
        
      }
    deinit {
       NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
@objc func rotated() {
        if UIDevice.current.orientation.isLandscape {
            print("Landscape---")
            orientationName = "Landscape"
        } else {
            print("Portrait---")
            orientationName = "Portrait"
        }
//    updatePreview()
    }
    
    public override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
           super.viewWillTransition(to: size, with: coordinator)
           if UIDevice.current.orientation.isLandscape {
               print("Landscape")
               orientationName = "Landscape"
           } else {
               print("Portrait")
               orientationName = "Portrait"
           }
        isOrientationHappened = false
        updatePreview()
       }
    

    public override var preferredStatusBarStyle: UIStatusBarStyle {
           return .lightContent
       }

    
    @objc func appMovedToBackground() {
            // do whatever event you want
//        captureSession.stopRunning() //RAMAN--- check
//        self.cameraPreviewLayer.removeFromSuperlayer() //RAMAN--- check
        if isAutoCaptureProccesing {
            return
        }else if isCapturingPhoto {
            return
        }
        let containerDict:[String:String] =  ["payload": ""]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue:"OCRDataHandling"), object: self, userInfo: containerDict)
        self.dismiss(animated: false, completion: nil);
        }
    @objc func onAppDidBecomeActive(_ notification: Notification) {
        if isAutoCaptureProccesing {
            return
        }
        // Your code here
        self.activityIndicatorView.isHidden = true
        self.isAutoCaptureProccesing = false
        //                  self.btnAutoManual.isHidden =  true
        //                  self.cameraClickBtnView.isHidden = true
        DispatchQueue.main.async {
            
            self.resetRectangleStability()
            self.clearDetectionLayer()
           // self.captureSession!.startRunning()
        }
       // DispatchQueue.global(qos: .background).async {
//            self.captureSession.startRunning()
        //}
    }
   

    
    private func configureOCR() {
        ocrRequest = VNRecognizeTextRequest { (request, error) in
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            
            var ocrText = ""
            for observation in observations {
                guard let topCandidate = observation.topCandidates(1).first else { return }
                
                ocrText += topCandidate.string + "\n"
            }
            
            
            DispatchQueue.main.async {
                self.finalOCRString = ocrText
                if (self.finalOCRString != ""){
                    self.activityIndicatorView.isHidden = false
                    self.doneButton.isEnabled = false
//                    self.captureSession.stopRunning()
                    self.sessionHandler.stopCamera()
//                    self.view.bringSubviewToFront(self.activityIndicatorView);
                    let containerDict:[String:String] =  ["payload": self.finalOCRString]
                    NotificationCenter.default.post(name: NSNotification.Name(rawValue:"OCRDataHandling"), object: self, userInfo: containerDict)
                    self.delegate?.sendOCRText(str: self.finalOCRString)
                    self.dismiss(animated: true, completion: nil)
                
                    
                }else{
                    self.showAlert(withTitle: "No Data", message: "No Data Captured")//venkat-16sep2024 - check this code
                }
            }
        }
        
        ocrRequest.recognitionLevel = .accurate
        ocrRequest.recognitionLanguages = ["en-US", "en-GB"]
        ocrRequest.usesLanguageCorrection = true
    }
   
    
    private func setupDetectionLayer() {
        detectionLayer.frame = cameraBaseView.bounds
        detectionLayer.strokeColor = UIColor.green.cgColor
        detectionLayer.lineWidth = 2.0
        detectionLayer.fillColor = UIColor.clear.cgColor
        cameraBaseView.layer.addSublayer(detectionLayer)
    }
    private func designCaptureButton() {
//        imageEditerContainer.isHidden = false
        cameraClickBtnView.layer.borderColor = UIColor.white.cgColor
        cameraClickBtnView.layer.borderWidth = 5
        cameraClickBtnView.layer.cornerRadius = 30
        cameraClickBtnView.layer.masksToBounds = true
        btnImageCapture.layer.cornerRadius = 22
        btnImageCapture.layer.masksToBounds = true
        cameraClickBtnView.backgroundColor = .clear
        btnAutoManual.isHidden = false
        cameraClickBtnView.isHidden = true
    }
    func createCorners() -> Void {
        
        let countt = cameraBaseView.layer.sublayers?.count ?? 100
        
        if (countt > 1 && countt != 100){
            for layer in self.cameraBaseView.layer.sublayers! {
                if layer.name == "CornerBorders" {
                  layer.removeFromSuperlayer()
               }
            }
        }
        
            //Calculate the length of corner to be shown
            let cornerLengthToShow = self.cameraBaseView.bounds.size.height * 0.08
            print(cornerLengthToShow)

            // Create Paths Using BeizerPath for all four corners
            let topLeftCorner = UIBezierPath()
            topLeftCorner.move(to: CGPoint(x: self.cameraBaseView.bounds.minX, y: self.cameraBaseView.bounds.minY + cornerLengthToShow))
            topLeftCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.minX, y: self.cameraBaseView.bounds.minY))
            topLeftCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.minX + cornerLengthToShow, y: self.cameraBaseView.bounds.minY))

            let topRightCorner = UIBezierPath()
            topRightCorner.move(to: CGPoint(x: self.cameraBaseView.bounds.maxX - cornerLengthToShow, y: self.cameraBaseView.bounds.minY))
            topRightCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.maxX, y: self.cameraBaseView.bounds.minY))
            topRightCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.maxX, y: self.cameraBaseView.bounds.minY + cornerLengthToShow))

            let bottomRightCorner = UIBezierPath()
            bottomRightCorner.move(to: CGPoint(x: self.cameraBaseView.bounds.maxX, y: self.cameraBaseView.bounds.maxY - cornerLengthToShow))
            bottomRightCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.maxX, y: self.cameraBaseView.bounds.maxY))
            bottomRightCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.maxX - cornerLengthToShow, y: self.cameraBaseView.bounds.maxY ))

            let bottomLeftCorner = UIBezierPath()
            bottomLeftCorner.move(to: CGPoint(x: self.cameraBaseView.bounds.minX, y: self.cameraBaseView.bounds.maxY - cornerLengthToShow))
            bottomLeftCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.minX, y: self.cameraBaseView.bounds.maxY))
            bottomLeftCorner.addLine(to: CGPoint(x: self.cameraBaseView.bounds.minX + cornerLengthToShow, y: self.cameraBaseView.bounds.maxY))

            let combinedPath = CGMutablePath()
            combinedPath.addPath(topLeftCorner.cgPath)
            combinedPath.addPath(topRightCorner.cgPath)
            combinedPath.addPath(bottomRightCorner.cgPath)
            combinedPath.addPath(bottomLeftCorner.cgPath)

            let shapeLayer = CAShapeLayer()
            shapeLayer.path = combinedPath
        shapeLayer.strokeColor = UIColor.blue.cgColor
            shapeLayer.fillColor = UIColor.clear.cgColor
            shapeLayer.lineWidth = 10
            shapeLayer.lineCap = .round
            shapeLayer.lineJoin = .round
            shapeLayer.name = "CornerBorders"

        cameraBaseView.layer.addSublayer(shapeLayer)
//        print("insert sublayer-------======================", cameraBaseView.layer.sublayers?.count ?? 100)
        }
    
    //RAMAN---
    
    private func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

    
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try requestHandler.perform([self.ocrRequest])
        } catch {
            print(error)
        }
    }
    
    func updatePreview() {
        let orientation: AVCaptureVideoOrientation
        switch UIDevice.current.orientation {
          
          case .landscapeRight:
            orientation = .landscapeLeft
          case .landscapeLeft:
            orientation = .landscapeRight
        case .portrait:
          orientation = .portrait
        case .portraitUpsideDown:
          orientation = .portraitUpsideDown
          
          default:
            orientation = .portrait
        }
        if sessionHandler.captureLayer.connection?.isVideoOrientationSupported == true {
            sessionHandler.captureLayer.connection?.videoOrientation = orientation
            sessionHandler.stillImageOutput.connection(with: AVMediaType.video)?.videoOrientation = orientation
        }
        sessionHandler.captureLayer.frame = cameraBaseView.bounds
      }
     
    
    //MARK: IBAction Method
    @IBAction func btnAutoManual_action(_ sender: Any) {
        isManualCaptureImage.toggle()
        btnAutoManual.setTitle(isManualCaptureImage ? "Manual" : "Auto", for: .normal)
        cameraClickBtnView.isHidden = !isManualCaptureImage
    }
    
    @IBAction func btnImageManualCapture_action(_ sender: Any) {
        sessionHandler.capturePhoto()
    }
    
    
    @IBAction func closeViewAction(_ sender: Any) {
//        captureSession.stopRunning() //RAMAN--- check
//        self.cameraPreviewLayer.removeFromSuperlayer() //RAMAN--- check
        
        let containerDict:[String:String] =  ["payload": ""]
        NotificationCenter.default.post(name: NSNotification.Name(rawValue:"OCRDataHandling"), object: self, userInfo: containerDict)
        /*self.willMove(toParent: nil)
        self.cameraBaseView.removeFromSuperview()
        self.removeFromParent()*/
        self.dismiss(animated: true, completion: nil);
        }
    
//    @IBAction func openCameraAction(_ sender: Any) {
//        captureSession.startRunning()
//        }
    
    private func showAlert(withTitle title: String, message: String) {
      DispatchQueue.main.async {
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
          let okAction = UIAlertAction(title: "Ok", style:
              UIAlertAction.Style.default) {
                 UIAlertAction in
                 print("Yes Pressed")
//              self.scanVC?.view.removeFromSuperview()
//              self.scanVC?.removeFromParent()
//              self.scanVC = nil
//              self.addDocumentCameraView()//venkat-16sep2024 - check this code to avoid adding objects multiple times
              
              if self.isManualCaptureImage {
                  self.imageCropperView.isHidden = true
                  self.cameraBaseView.isHidden = true
                  self.btnAutoManual.isHidden =  false
                  self.cameraClickBtnView.isHidden = false
                  DispatchQueue.main.async {
                      self.resetRectangleStability()
                      self.clearDetectionLayer()
                  }
                  
                  DispatchQueue.main.async {
                      self.sessionHandler.startCameraSession()
                  }
              }else {
                  self.isAutoCaptureProccesing = false
//                  self.btnAutoManual.isHidden =  true
//                  self.cameraClickBtnView.isHidden = true
                  DispatchQueue.main.async {
                     
                      self.resetRectangleStability()
                      self.clearDetectionLayer()
                  }
              }
          }
        //alertController.addAction(UIAlertAction(title: "OK", style: .default))
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
      }
    }
}

// MARK: - Helper
@available(iOS 13.0, *)
extension ScanImageViewController {
   
     func detectRectangles(from sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let request = VNDetectRectanglesRequest { [weak self] request, _ in
            guard let self = self else { return }
            if let rectangles = request.results as? [VNRectangleObservation], let bestRectangle = rectangles.first {
                imageBufer = pixelBuffer
                self.evaluateRectangle(bestRectangle)
            } else {
                self.clearDetectionLayer()
                self.resetRectangleStability()
            }
        }
        request.minimumConfidence = 0.9//confidenceThreshold
        request.minimumAspectRatio = 0.2
        request.maximumObservations = 1
        request.minimumSize = 0.2
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        try? handler.perform([request])
    }
    private func evaluateRectangle(_ rectangle: VNRectangleObservation) {
        DispatchQueue.main.async {
            self.updateDetectionLayer(for: rectangle)
        }
        // Check rectangle stability
        if isManualCaptureImage == false {
            if let lastRectangle = lastStableRectangle {
                if isSimilar(to: lastRectangle, comparedTo: rectangle) {
                    if rectangleDetectionStartTime == nil {
                        rectangleDetectionStartTime = Date()
                    }
                    if let startTime = rectangleDetectionStartTime, Date().timeIntervalSince(startTime) >= stabilityDuration {
                        if !isAutoCaptureProccesing {
                            DispatchQueue.main.async { [self] in
//                                self.capturePhoto()
                                self.isAutoCaptureProccesing = true
                                self.doPerspectiveCorrection(lastRectangle, from: imageBufer!)
                            }
                        }
                    }
                } else {
                    resetRectangleStability()
                }
            } else {
                lastStableRectangle = rectangle
                rectangleDetectionStartTime = Date()
            }
        }
        
    }
    private func updateDetectionLayer(for rectangle: VNRectangleObservation) {
        let transformedRectangle = convertRectangle(rectangle)
        let path = UIBezierPath()
        path.move(to: transformedRectangle.topLeft)
        path.addLine(to: transformedRectangle.topRight)
        path.addLine(to: transformedRectangle.bottomRight)
        path.addLine(to: transformedRectangle.bottomLeft)
        path.close()
        
        // Create a basic animation for the path
        let animation = CABasicAnimation(keyPath: "path")
        animation.fromValue = detectionLayer.path
        animation.toValue = path.cgPath
        animation.duration = 0.1
        
        // Apply the animation to the detection layer
        detectionLayer.add(animation, forKey: "pathAnimation")
        
        // Update the path of the detection layer
        detectionLayer.path = path.cgPath
    }
    
    private func clearDetectionLayer() {
        DispatchQueue.main.async {
            self.detectionLayer.path = nil
        }
    }
    private func resetRectangleStability() {
        lastStableRectangle = nil
        //           rectangleDetectionStartTime = Date()
    }
    private func convertRectangle(_ rectangle: VNRectangleObservation) -> (topLeft: CGPoint, topRight: CGPoint, bottomLeft: CGPoint, bottomRight: CGPoint) {
        let topLeft = sessionHandler.captureLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rectangle.topLeft.x, y: 1 - rectangle.topLeft.y))
        let topRight = sessionHandler.captureLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rectangle.topRight.x, y: 1 - rectangle.topRight.y))
        let bottomLeft = sessionHandler.captureLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rectangle.bottomLeft.x, y: 1 - rectangle.bottomLeft.y))
        let bottomRight = sessionHandler.captureLayer.layerPointConverted(fromCaptureDevicePoint: CGPoint(x: rectangle.bottomRight.x, y: 1 - rectangle.bottomRight.y))
        return (topLeft, topRight, bottomLeft, bottomRight)
    }
    private func isSimilar(to rect1: VNRectangleObservation, comparedTo rect2: VNRectangleObservation) -> Bool {
        let positionTolerance: CGFloat = 0.05
        let sizeTolerance: CGFloat = 0.1
        let deltaX = abs(rect1.boundingBox.origin.x - rect2.boundingBox.origin.x)
        let deltaY = abs(rect1.boundingBox.origin.y - rect2.boundingBox.origin.y)
        let deltaWidth = abs(rect1.boundingBox.size.width - rect2.boundingBox.size.width)
        let deltaHeight = abs(rect1.boundingBox.size.height - rect2.boundingBox.size.height)
        return deltaX <= positionTolerance &&
        deltaY <= positionTolerance &&
        deltaWidth <= sizeTolerance &&
        deltaHeight <= sizeTolerance
    }
    
    func doPerspectiveCorrection(_ observation: VNRectangleObservation, from buffer: CVImageBuffer) {
        var ciImage = CIImage(cvImageBuffer: buffer)
        
        let topLeft = observation.topLeft.scaled(to: ciImage.extent.size)
        let topRight = observation.topRight.scaled(to: ciImage.extent.size)
        let bottomLeft = observation.bottomLeft.scaled(to: ciImage.extent.size)
        let bottomRight = observation.bottomRight.scaled(to: ciImage.extent.size)
        
        // pass those to the filter to extract/rectify the image
        ciImage = ciImage.applyingFilter("CIPerspectiveCorrection", parameters: [
            "inputTopLeft": CIVector(cgPoint: topLeft),
            "inputTopRight": CIVector(cgPoint: topRight),
            "inputBottomLeft": CIVector(cgPoint: bottomLeft),
            "inputBottomRight": CIVector(cgPoint: bottomRight),
        ])
        
        let context = CIContext()
        let cgImage = context.createCGImage(ciImage, from: ciImage.extent)
        let output = UIImage(cgImage: cgImage!)
        
        processImage(output)
        
    }
    func showAlert(msg:String) {
        // create the alert
        let alert = UIAlertController(title: "My Title", message: msg, preferredStyle: UIAlertController.Style.alert)
        
        // add an action (button)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        
        // show the alert
        self.present(alert, animated: true, completion: nil)
    }
    
    func showAlertWithCompletion(title: String, message: String, completion: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAction = UIAlertAction(title: "OK", style: .default) { _ in
            completion()
        }
        alert.addAction(okAction)
        self.present(alert, animated: true, completion: nil)
    }
    
}



@available(iOS 13.0, *)
extension ScanImageViewController: @preconcurrency AVCapturePhotoCaptureDelegate {
    public func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let capturedImage = UIImage(data: data) else { return }
              
              let newImage = capturedImage.rotate(radians: 0.0)
            
//        connection(with: AVMediaType.video)?.videoOrientation
        //let orientation: AVCaptureVideoOrientation = AVCaptureVideoOrientation(rawValue: (output.connection(with: AVMediaType.video)?.videoOrientation)!.rawValue) ?? .portrait
        /*let orientation = videoPreviewLayer.connection?.videoOrientation
        print("vi ori",orientation!)
        if (orientation == .portrait){
            print("vi ori--port")
            newImage = capturedImage.rotate(radians: 0.0)
        }
        else if (orientation == .portraitUpsideDown){
            print("vi ori--portup")
            newImage = capturedImage.rotate(radians: .pi)
        }
        else if (orientation == .landscapeLeft){
            print("vi ori--landL")
            newImage = capturedImage.rotate(radians: .pi/2)
        }
        else if (orientation == .landscapeRight){
            print("vi ori--landR")
            newImage = capturedImage.rotate(radians: .pi*1.5)
        }
        else{
            print("vi ori--defa")
            newImage = capturedImage.rotate(radians: 0.0)
        }*/
        
        //writeToPhotoAlbum(image: capturedImage)
       /* if saveImage1(image: UIImage(named: "editing-image")!){
            print("saved 1")
            
        }
        if saveImage(image: newImage) == true{
            let storyboard: UIStoryboard =
            UIStoryboard.init(name: "CropperViewController",bundle: nil);
            
            let cropperViewController:
            CropperViewController = storyboard.instantiateViewController(withIdentifier: "CropperViewController") as! CropperViewController;
            //cropperViewController.editableImage = capturedImage
            cropperViewController.modalPresentationStyle = .fullScreen
            self.present(cropperViewController, animated: false)
        }*/
//        let storyboard: UIStoryboard =
//        UIStoryboard.init(name: "CropperViewController",bundle: nil);
//        
//        let cropperViewController:
//        CropperViewController = storyboard.instantiateViewController(withIdentifier: "CropperViewController") as! CropperViewController;
//        cropperViewController.editableImage = newImage
//        cropperViewController.modalPresentationStyle = .fullScreen
//        cropperViewController.delegate = self
//        self.present(cropperViewController, animated: false)
        
        sessionHandler.stopCamera()

    }
}
@available(iOS 13.0, *)
extension ScanImageViewController: CancelImageCropperView {
    nonisolated func cancelView() {
        DispatchQueue.main.async {
            self.imageCropperView.isHidden = true
            self.cameraBaseView.isHidden = false
            self.btnAutoManual.isHidden =  false
            self.cameraClickBtnView.isHidden = false
            self.isCapturingPhoto = false
            DispatchQueue.main.async {
                self.resetRectangleStability()
                self.clearDetectionLayer()
            }
            
            DispatchQueue.main.async {
    //            self.captureSession.startRunning()
                self.sessionHandler.startCameraSession()
            }
        }
//        self.setupCamera()
       
    }
}

extension ScanImageViewController :  CardDetectionSessionHandlerDelegate {
    func sendCaptureImage(image: UIImage) {
        print("sendCaptureImage")
        self.sessionHandler.stopCamera()
        let cropperViewController = CropperViewController()
        cropperViewController.editableImage = image
        cropperViewController.modalPresentationStyle = .fullScreen
        cropperViewController.delegate = self
        self.present(cropperViewController, animated: false)
    }
    
    func detectRectangles1(from sampleBuffer: CMSampleBuffer) {
//        print("detectRectangles1")
        self.detectRectangles(from: sampleBuffer)
    }
    
    nonisolated func sessionHandler(didDetectCardInImage image: CGImage, withTopLeftCorner topLeftCorner: CGPoint, topRightCorner: CGPoint, bottomRightCorner: CGPoint, bottomLeftCorner: CGPoint, perspectiveCorrectionParams: [String : CIVector], sharpness: Float?) {
        
    }
    
    nonisolated func sessionHandler(_ handler: ObjectDetectionSessionHandler, didDetectBarcodes barcodes: [VNBarcodeObservation]) {
        
    }
    
    nonisolated func shouldDetectCardImageWithSessionHandler(_ handler: ObjectDetectionSessionHandler) -> Bool {
        return false
    }
    
    nonisolated func shouldDetectBarcodeWithSessionHandler(_ handler: ObjectDetectionSessionHandler) -> Bool {
        return false
    }
    
}

protocol CancelImageCropperView{
    func cancelView()
}
protocol ImageCropDelegate {
    func sendCropImage(img:UIImage)
    func showAlert1( msg: String)
}

extension CGPoint {
   func scaled(to size: CGSize) -> CGPoint {
       return CGPoint(x: self.x * size.width,
                      y: self.y * size.height)
   }
}

extension UIImage {
    func rotate(radians: CGFloat) -> UIImage {
        let rotatedSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: CGFloat(radians)))
            .integral.size
        UIGraphicsBeginImageContext(rotatedSize)
        if let context = UIGraphicsGetCurrentContext() {
            let origin = CGPoint(x: rotatedSize.width / 2.0,
                                 y: rotatedSize.height / 2.0)
            context.translateBy(x: origin.x, y: origin.y)
            context.rotate(by: radians)
            //draw(in: CGRect(x: -origin.y, y: -origin.x, width: size.width, height: size.height))
            draw(in: CGRect(x: -origin.x, y: -origin.y,
                            width: size.width, height: size.height))
            let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            return rotatedImage ?? self
        }

        return self
    }
}

extension UIImage {
    func resized(to size: CGSize) -> UIImage {
        return UIGraphicsImageRenderer(size: size).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

public protocol ScanImageOCRTextSendToView{
    func sendOCRText(str:String)
}
#endif
