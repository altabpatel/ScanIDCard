//
//  CropperViewController.swift
//  ScanIDCard
//
//  Created by Patel, Altab (Cognizant) on 17/01/25.
//

import UIKit
import AVFoundation
import Vision

public class CropperViewController: UIViewController {
  
  /// Top left button
  private let topLeftButton = UIButton()

  /// Top right button
  private let topRightButton = UIButton()

  /// Bottom left button
  private let bottomLeftButton = UIButton()

  /// Bottom right button
  private let bottomRightButton = UIButton()
  
  /// Layer for showing the dashed lines of the crop area
  private let rectangleLayer = CAShapeLayer()

  /// Layer for showing the darkened background of the crop area
  private let backgroundLayer = CAShapeLayer()

  /// Mask layer to cut out the region of interest
  private let maskLayer = CAShapeLayer()
    
  var isOrientationHappened = true
    
  var orientationName = "Portrait"
  
    @IBOutlet weak var activityIndicator: UILabel!
    @IBOutlet weak var activityIndicatorView: UIView!
    @IBOutlet private weak var imageView: UIImageView!
  @IBOutlet private weak var cropButton: UIButton!
    @IBOutlet weak var lblOCRText: UILabel!
    
  /// Current image frame
  private var imageFrame: CGRect?
  
  /// Button size is twice as big as the icon we use for our button to have a bigger pan space
  private let buttonSize: CGFloat = 64
  
  /// The image we are editing
    public var editableImage: UIImage = UIImage()// = UIImage(named: "editing-image")!
    //public var editableImage: UIImage = UIImage(named: "editing-image")!
    var finalOCRString: String = "";//Venkat
    private var ocrRequest = VNRecognizeTextRequest(completionHandler: nil)//Venkat

    var delegate:CancelImageCropperView?
    public  init() {
        super.init(nibName: "CropperViewController", bundle: Bundle.module)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
    super.viewDidLoad()
      print("didload")
    // Do any additional setup after loading the view.
      NotificationCenter.default.addObserver(self, selector: #selector(CropperViewController.rotated), name: UIDevice.orientationDidChangeNotification, object: nil)
      configureOCR()
        if #available(iOS 15.0, *) {
            setupViews()
        } else {
            // Fallback on earlier versions
        }
    setupConstraints()
      activityIndicatorView.isHidden = true
  }
    
    deinit {
       NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
@objc func rotated() {
        if UIDevice.current.orientation.isLandscape {
            print("Landscape---")
            orientationName = "Landscape"
        } else {
            print("Portrait---")
            orientationName = "Portrait"
        }
    }
    
    public  override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
           super.viewWillTransition(to: size, with: coordinator)
           if UIDevice.current.orientation.isLandscape {
               print("Landscape")
               orientationName = "Landscape"
           } else {
               print("Portrait")
               orientationName = "Portrait"
           }
        isOrientationHappened = true
       }
  
    public   override func viewDidLayoutSubviews() {
        if isOrientationHappened {
           
            /*let rectVal1 = AVMakeRect(aspectRatio: imageValue.size, insideRect: imageView.bounds);
            print("imageSize1",rectVal1)
            print("rectVal", rectVal1.minX,rectVal1.midX,rectVal1.maxX,rectVal1.minY,rectVal1.midY,rectVal1.maxY)
            createLayer1(in: CGRectMake(rectVal1.minX+50, rectVal1.minY+50, rectVal1.width - 100, rectVal1.height - 100))
             */
            setupDefaultCropRectangle()
            isOrientationHappened = false
        }
    }
    
    // MARK: - Lifecycle
    public override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
      print("didappear")
      /*if let image = getSavedImage(named: "fileName") {
          // do something with image
          imageView.image = image
          editableImage = image
      }*/
      
      imageView.image = editableImage
      setupDefaultCropRectangle()
  }
    @IBAction func btnRescan_action(_ sender: Any) {
        self.dismiss(animated:false)
        DispatchQueue.main.async {
            self.delegate?.cancelView()
        }
    }
    
    @IBAction func cancelButtonActino(_ sender: Any) {
        
        self.dismiss(animated:false)
        self.delegate?.cancelView()
    }
    /*
    func getSavedImage(named: String) -> UIImage? {
        if let dir = try? FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false) {
            return UIImage(contentsOfFile: URL(fileURLWithPath: dir.absoluteString).appendingPathComponent(named).path)
        }
        return nil
    }*/
    
    @available(iOS 15.0, *)
    private func setupViews() {
    //imageView.image = editableImage
        
        
    imageView.isUserInteractionEnabled = true

    imageView.layer.addSublayer(backgroundLayer)
    imageView.layer.addSublayer(rectangleLayer)

    maskLayer.fillRule = .evenOdd

    backgroundLayer.mask = maskLayer
    backgroundLayer.fillColor = UIColor.black.cgColor
    backgroundLayer.opacity = Float(0.5)

    /// Stroke
    rectangleLayer.strokeColor = UIColor.white.cgColor
    rectangleLayer.fillColor = UIColor.clear.cgColor
    rectangleLayer.lineWidth = 2
    rectangleLayer.lineJoin = .round
    let dashPatternFour = NSNumber(floatLiteral: 4)
    rectangleLayer.lineDashPattern = [dashPatternFour, dashPatternFour]
    
    imageView.addSubview(topLeftButton)
    imageView.addSubview(topRightButton)
    imageView.addSubview(bottomLeftButton)
    imageView.addSubview(bottomRightButton)

    var configuration = UIButton.Configuration.plain()
    configuration.cornerStyle = .capsule

    [topLeftButton, topRightButton, bottomLeftButton, bottomRightButton].forEach { button in
      let panGestureRecognizer = UIPanGestureRecognizer(target: self, action: #selector(buttonPanGestureAction))
      button.addGestureRecognizer(panGestureRecognizer)
      button.configuration = configuration
    }

    /// Here we use different images for each button to visualize the button origin.
    /// If you want to use one image for each button you can do in in the button config above.
        topLeftButton.configuration?.image = UIImage(systemName: "circle")?.resized(to: CGSize(width: 20, height: 20)).withTintColor(.white)
        topRightButton.configuration?.image = UIImage(systemName: "circle")?.resized(to: CGSize(width: 20, height: 20)).withTintColor(.white)
        bottomLeftButton.configuration?.image = UIImage(systemName: "circle")?.resized(to: CGSize(width: 20, height: 20)).withTintColor(.white)
        bottomRightButton.configuration?.image = UIImage(systemName: "circle")?.resized(to: CGSize(width: 20, height: 20)).withTintColor(.white)
  }
  
  /// Setup of the constraining
  private func setupConstraints() {
    imageView.translatesAutoresizingMaskIntoConstraints = false

    [topLeftButton, topRightButton, bottomLeftButton, bottomRightButton].forEach { button in
      button.translatesAutoresizingMaskIntoConstraints = false
      button.widthAnchor.constraint(equalToConstant: buttonSize).isActive = true
      button.heightAnchor.constraint(equalToConstant: buttonSize).isActive = true
    }

    cropButton.translatesAutoresizingMaskIntoConstraints = false
  }
  
  /// Setup of the initial crop rectangle
  private func setupDefaultCropRectangle() {
    updateImageFrame()

    guard let imageFrame else {
//      Log.warning("Could not unwrap otiginal image bounds", error: LogError.warning)
      return
    }

    let inset = imageView.frame.width / 10
    let topLeft = CGPoint(
      x: imageFrame.minX + inset,
      y: imageFrame.minY + inset
    )
    let topRight = CGPoint(
      x: imageFrame.maxX - inset,
      y: imageFrame.minY + inset
    )
    let bottomLeft = CGPoint(
      x: imageFrame.minX + inset,
      y: imageFrame.maxY - inset
    )
    let bottomRight = CGPoint(
      x: imageFrame.maxX - inset,
      y: imageFrame.maxY - inset
    )

      DispatchQueue.main.async {
          self.topLeftButton.center = topLeft
          self.topRightButton.center = topRight
          self.bottomLeftButton.center = bottomLeft
          self.bottomRightButton.center = bottomRight

          self.drawRectangle()
      }
    
  }
  
  /// Draws the crop area
  private func drawRectangle() {
    guard let imageFrame else {
//      Log.warning("Could not unwrap current image frame", error: LogError.warning)
      return
    }

    /// Rectangle layer path with dashed lines
    let rectangle = UIBezierPath.init()

    rectangle.move(to: topLeftButton.center)

    rectangle.addLine(to: topLeftButton.center)
    rectangle.addLine(to: topRightButton.center)
    rectangle.addLine(to: bottomRightButton.center)
    rectangle.addLine(to: bottomLeftButton.center)
    rectangle.addLine(to: topLeftButton.center)

    rectangle.close()

    rectangleLayer.path = rectangle.cgPath

    /// Mask for centered rectangle cut
    let mask = UIBezierPath.init(rect: imageFrame)

    mask.move(to: topLeftButton.center)

    mask.addLine(to: topLeftButton.center)
    mask.addLine(to: topRightButton.center)
    mask.addLine(to: bottomRightButton.center)
    mask.addLine(to: bottomLeftButton.center)
    mask.addLine(to: topLeftButton.center)

    mask.close()

    maskLayer.path = mask.cgPath

    /// Background layer
    let path = UIBezierPath(rect: imageFrame)
    backgroundLayer.path = path.cgPath
  }
  
  /// Updates the 'imageFrame' property
  private func updateImageFrame() {
    let originalImageSize = editableImage.size
    let heightAspectRatio = originalImageSize.height / originalImageSize.width
    let imageHeight = min(imageView.frame.width * heightAspectRatio, imageView.frame.height)
    let imageWidth = imageHeight / heightAspectRatio
    let imageSize = CGSize(width: imageWidth, height: imageHeight)
    let verticalInset = max(0, (imageView.frame.height - imageSize.height) / 2)
    let horizontalInset = (imageView.frame.width - imageSize.width) / 2

    self.imageFrame = CGRect(origin: CGPoint(x: horizontalInset, y: verticalInset), size: imageSize)
  }


  @objc
  private func buttonPanGestureAction(_ gesture: UIPanGestureRecognizer) {
    /// Unwrap the button that triggered the pan gesture
    guard let button = gesture.view else {
//      Log.warning("buttonPanGestureAction received no view for positioning update", error: LogError.warning)
      return
    }

    /// Custom duration of the animation
    let animationDuration: CGFloat = 0.1
    /// Custom maximum scale of the animation
    let buttonMaxScale: CGFloat = 2

    /// Handle began and ended states for button scale animation
    switch gesture.state {
      case .began:
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveLinear) {
          button.transform = CGAffineTransform(scaleX: buttonMaxScale, y: buttonMaxScale)
        }
      case .ended:
        UIView.animate(withDuration: animationDuration, delay: 0, options: .curveLinear) {
          button.transform = .identity
        }
      default:
        print("UIPanGestureRecognizer state \(gesture.state) not handled in ReceiptEditCropImageView")
//        Log.debug("UIPanGestureRecognizer state \(gesture.state) not handled in ReceiptEditCropImageView")
    }

    guard let imageFrame else {
//      Log.warning("Could not unwrap current image frame", error: LogError.warning)
      return
    }

    /// Here we calculate our min, max x and y values
    let minXSafeArea: CGFloat = imageFrame.origin.x
    let maxXSafeArea: CGFloat = imageFrame.origin.x + imageFrame.width
    let minYSafeArea: CGFloat = imageFrame.origin.y
    let maxYSafeArea: CGFloat = imageFrame.height + minYSafeArea

    /// Maximum x for the left buttons gets calculated
    let topLeftButtonMaxX = topRightButton.center.x
    let bottomLeftButtonMaxX = bottomRightButton.center.x
    let leftButtonsMaxX = min(topLeftButtonMaxX, bottomLeftButtonMaxX)

    /// Minimum x for the right buttons gets calculated
    let topRightButtonMinX = topLeftButton.center.x
    let bottomRightButtonMinX = bottomLeftButton.center.x
    let rightButtonsMinX = max(topRightButtonMinX, bottomRightButtonMinX)

    /// Maximum y for the top buttons gets calculated
    let topRightButtonMaxY = bottomRightButton.center.y
    let topLeftButtonMaxY = bottomLeftButton.center.y
    let topButtonsMaxY = min(topRightButtonMaxY, topLeftButtonMaxY)

    /// Minimum y for the bottom buttons gets calculated
    let bottomRightButtonMinY = topRightButton.center.y
    let bottomLeftButtonMinY = topLeftButton.center.y
    let bottomButtonsMinY = max(bottomRightButtonMinY, bottomLeftButtonMinY)

      if(button == topLeftButton){
                  /// Maximum y for the top buttons gets calculated
                  bottomLeftButton.center.x = topLeftButton.center.x
                  topRightButton.center.y = topLeftButton.center.y
              }else if(button == topRightButton){
                  bottomRightButton.center.x = topRightButton.center.x
                  topLeftButton.center.y = topRightButton.center.y
              }
              else if(button == bottomLeftButton){
                  topLeftButton.center.x = bottomLeftButton.center.x
                  bottomRightButton.center.y = bottomLeftButton.center.y
              }
              else if(button == bottomRightButton){
                  topRightButton.center.x = bottomRightButton.center.x
                  bottomLeftButton.center.y = bottomRightButton.center.y
              }
    
    /// Current point of the gesture in relation to the ImageCropperView
    let point = gesture.translation(in: view)

    /// Here we work with the previously calculated max and min x,y values
    /// to ensure that the buttons can not be panned outside of the image
    /// frame or the buttons do not overlap and invalidate our final frame.
    let xPosition: CGFloat
    let yPosition: CGFloat
    if button === topLeftButton {
      xPosition = max(minXSafeArea, min(button.center.x + point.x, leftButtonsMaxX))
      yPosition = max(minYSafeArea, min(button.center.y + point.y, topButtonsMaxY))
    } else if button === topRightButton {
      xPosition = min(maxXSafeArea, max(button.center.x + point.x, rightButtonsMinX))
      yPosition = max(minYSafeArea, min(button.center.y + point.y, topButtonsMaxY))
    } else if button === bottomLeftButton {
      xPosition = max(minXSafeArea, min(button.center.x + point.x, leftButtonsMaxX))
      yPosition = min(maxYSafeArea, max(button.center.y + point.y, bottomButtonsMinY))
    } else if button === bottomRightButton {
      xPosition = min(maxXSafeArea, max(button.center.x + point.x, rightButtonsMinX))
      yPosition = min(maxYSafeArea, max(button.center.y + point.y, bottomButtonsMinY))
    } else { return }

    /// Set the new position of the button
    button.center = CGPoint(x: xPosition, y: yPosition)
    gesture.setTranslation(CGPoint.zero, in: view)

    drawRectangle()
  }
  
  @IBAction private func cropAction() {
    guard let imageFrame else {
//      Log.warning("Could not unwrap otiginal image bounds or editableOriginalImage", error: LogError.warning)
      return
    }

    /// imageFrame x and y equal the half of the total vertical (y) and horizontal (x) inset.
    let verticalInset = imageFrame.origin.y
    let horizontalInset = imageFrame.origin.x

    /// Subtract the insets from the calculated rect so they do not get considered in the cropping process
    let minX = min(topLeftButton.center.x, bottomLeftButton.center.x) - horizontalInset
    let maxX = max(topRightButton.center.x, bottomRightButton.center.x) - horizontalInset
    let minY = min(topLeftButton.center.y, topRightButton.center.y) - verticalInset
    let maxY = max(bottomLeftButton.center.y, bottomRightButton.center.y) - verticalInset
    let width = maxX - minX
    let height = maxY - minY

    /// Rect to crop
    let rect = CGRect(x: minX, y: minY, width: width, height: height)

    guard let croppedImage = cropImage(
      editableImage,
      toRect: rect,
      viewWidth: imageFrame.width,
      viewHeight: imageFrame.height
    ) else {
//      Log.warning("Could not crop the image", error: LogError.warning)
      return
    }

    /// imageView image update
    imageView.image = nil
    imageView.image = croppedImage
    editableImage = croppedImage

    /// Reset the default crop rectangle due to rotation
//    setupDefaultCropRectangle()
      self.processImage(croppedImage)
  }

  /// Returns the cropped image for given rect
  func cropImage(_ inputImage: UIImage, toRect cropRect: CGRect, viewWidth: CGFloat, viewHeight: CGFloat) -> UIImage? {
    let imageViewScale = max(inputImage.size.width / viewWidth, inputImage.size.height / viewHeight)

    /// Scale cropRect to handle images larger than shown-on-screen size
    let cropZone = CGRect(
      x: cropRect.origin.x * imageViewScale,
      y: cropRect.origin.y * imageViewScale,
      width: cropRect.size.width * imageViewScale,
      height: cropRect.size.height * imageViewScale
    )

    guard let cutImageRef: CGImage = inputImage.cgImage?.cropping(to: cropZone) else {
//      Log.warning("Crop failed", error: LogError.warning)
      return nil
    }
      //let croppedImage: UIImage = UIImage(cgImage: cutImageRef, scale: inputImage.scale, orientation: inputImage.imageOrientation)
        //    return croppedImage
    return UIImage(cgImage: cutImageRef)
  }
}
extension CropperViewController {
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
                    print("OCR text \(self.finalOCRString)")
                    DispatchQueue.main.async {
                        self.lblOCRText.text = self.finalOCRString
                    }
                    self.activityIndicatorView.isHidden = false
//                    self.doneButton.isEnabled = false
                    self.view.bringSubviewToFront(self.activityIndicatorView);
                    DispatchQueue.main.asyncAfter(deadline: .now(), execute: {
//                        let textEditVC = TextEditViewController(nibName: "TextEditViewController", bundle: nil)
//                       textEditVC.ocrText = ocrText
//                       textEditVC.delegate = self
//                       textEditVC.modalPresentationStyle = .overFullScreen
//                       self.present(textEditVC, animated: true, completion: nil)
                        
                        let containerDict:[String:String] =  ["payload": self.finalOCRString]
                        NotificationCenter.default.post(name: NSNotification.Name(rawValue:"OCRDataHandling"), object: self, userInfo: containerDict)
                    })
                   
//                    self.dismiss(animated: true, completion: nil)
                }else{
                    self.showAlert(withTitle: "No Data", message: "No Data Captured")//venkat-16sep2024 - check this code
                }
            }
        }
        
        ocrRequest.recognitionLevel = .accurate
        ocrRequest.recognitionLanguages = ["en-US", "en-GB"]
        ocrRequest.usesLanguageCorrection = true
    }
    private func processImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }

    
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
//            self.activityIndicatorView.isHidden = false
            try requestHandler.perform([self.ocrRequest])
        } catch {
            print(error)
        }
    }
    
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
              
              self.dismiss(animated: true, completion: nil)
              self.delegate?.cancelView()
//              if self.isManualCaptureImage {
//                  self.imageCropperView.isHidden = true
//                  self.cameraBaseView.isHidden = true
//                  self.btnAutoManual.isHidden =  false
//                  self.cameraClickBtnView.isHidden = false
//                  DispatchQueue.main.async {
//                      self.resetRectangleStability()
//                      self.clearDetectionLayer()
//                  }
//
//                  DispatchQueue.global(qos: .background).async {
//                      self.captureSession.startRunning()
//                  }
//              }else {
//                  self.isAutoCaptureProccesing = false
////                  self.btnAutoManual.isHidden =  true
////                  self.cameraClickBtnView.isHidden = true
//                  DispatchQueue.main.async {
//
//                      self.resetRectangleStability()
//                      self.clearDetectionLayer()
//                  }
//              }
          }
        //alertController.addAction(UIAlertAction(title: "OK", style: .default))
        alertController.addAction(okAction)
        self.present(alertController, animated: true)
      }
    }
    
}
//extension CropperViewController : TextEditerProtocol {
//    func sendEditTextDataToWeb(text: String) {
//        self.activityIndicatorView.isHidden = false
//        let containerDict:[String:String] =  ["payload": text]
//        NotificationCenter.default.post(name: NSNotification.Name(rawValue:"OCRDataHandling"), object: self, userInfo: containerDict)
//
//    }
//    
//    func reScanData() {
//        self.dismiss(animated: true) {
//            self.delegate?.cancelView()
//        }
//    }
//    
//    
//}


