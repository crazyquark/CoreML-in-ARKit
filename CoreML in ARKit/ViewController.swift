//
//  ViewController.swift
//  CoreML in ARKit
//
//  Created by Hanley Weng on 14/7/17.
//  Copyright © 2017 CompanyName. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

import Vision

class ViewController: UIViewController, ARSCNViewDelegate {

    // SCENE
    @IBOutlet var sceneView: ARSCNView!
    var lastDetectedRectangle : VNRectangleObservation?
    
    // Displayed rectangle outline
    private var selectedRectangleOutlineLayer: CAShapeLayer?
    
    // COREML
    var visionRequests = [VNRequest]()
    let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    @IBOutlet weak var debugTextView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        // Create a new scene
        let scene = SCNScene()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        // Enable Default Lighting - makes the 3D text a bit poppier.
        sceneView.autoenablesDefaultLighting = true
        
        //////////////////////////////////////////////////
        // Tap Gesture Recognizer
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(self.handleTap(gestureRecognize:)))
        view.addGestureRecognizer(tapGesture)
        
        //////////////////////////////////////////////////
        
        // Set up Vision Model
//        guard let selectedModel = try? VNCoreMLModel(for: Inceptionv3().model) else { // (Optional) This can be replaced with other models on https://developer.apple.com/machine-learning/
//            fatalError("Could not load model. Ensure model has been drag and dropped (copied) to XCode Project from https://developer.apple.com/machine-learning/ . Also ensure the model is part of a target (see: https://stackoverflow.com/questions/45884085/model-is-not-part-of-any-target-add-the-model-to-a-target-to-enable-generation ")
//        }
        
        // Set up Vision-CoreML Request
//        let classificationRequest = VNCoreMLRequest(model: selectedModel, completionHandler: classificationCompleteHandler)
//        classificationRequest.imageCropAndScaleOption = VNImageCropAndScaleOption.centerCrop // Crop from centre of images and scale to appropriate size.
//        visionRequests = [classificationRequest]
        
        // Setup detection of rectangles in CoreML
        let rectDetectionRequest = VNDetectRectanglesRequest(completionHandler: rectangleDetectionHandler)
        rectDetectionRequest.maximumObservations = 1
        rectDetectionRequest.minimumConfidence = 1.0
        visionRequests = [rectDetectionRequest]
        
        // Begin Loop to Update CoreML
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Pause the view's session
        sceneView.session.pause()
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Release any cached data, images, etc that aren't in use.
    }

    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Do any desired updates to SceneKit here.
        }
    }
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Interaction
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        guard let rectangle = self.lastDetectedRectangle else {
            return
        }
        
        self.drawRectangleOnScreen(rectangle)
    }
    
    private func drawRectangleOnScreen(_ rectangle: VNRectangleObservation) {
        let points = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft]
        let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
        self.selectedRectangleOutlineLayer = self.drawPolygon(convertedPoints, color: UIColor.green)
        
        self.sceneView.layer.addSublayer(self.selectedRectangleOutlineLayer!)
    }
    
    private func drawPolygon(_ points: [CGPoint], color: UIColor) -> CAShapeLayer {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = color.cgColor
        layer.lineWidth = 2
        let path = UIBezierPath()
        path.move(to: points.last!)
        points.forEach { point in
            path.addLine(to: point)
        }
        layer.path = path.cgPath
        return layer
    }
    
//    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
//        // HIT TEST : REAL WORLD
//        // Get Screen Centre
//        let screenCentre : CGPoint = CGPoint(x: self.sceneView.bounds.midX, y: self.sceneView.bounds.midY)
//
//        let arHitTestResults : [ARHitTestResult] = sceneView.hitTest(screenCentre, types: [.featurePoint]) // Alternatively, we could use '.existingPlaneUsingExtent' for more grounded hit-test-points.
//
//        if let closestResult = arHitTestResults.first {
//            // Get Coordinates of HitTest
//            let transform : matrix_float4x4 = closestResult.worldTransform
//            let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
//
//            // Create 3D Text
//            let node : SCNNode = createNewBubbleParentNode(latestPrediction)
//            sceneView.scene.rootNode.addChildNode(node)
//            node.position = worldCoord
//        }
//    }
//
//    func createNewBubbleParentNode(_ text : String) -> SCNNode {
//        // Warning: Creating 3D Text is susceptible to crashing. To reduce chances of crashing; reduce number of polygons, letters, smoothness, etc.
//
//        // TEXT BILLBOARD CONSTRAINT
//        let billboardConstraint = SCNBillboardConstraint()
//        billboardConstraint.freeAxes = SCNBillboardAxis.Y
//
//        // BUBBLE-TEXT
//        let bubble = SCNText(string: text, extrusionDepth: CGFloat(bubbleDepth))
//        var font = UIFont(name: "Futura", size: 0.15)
//        font = font?.withTraits(traits: .traitBold)
//        bubble.font = font
//        bubble.alignmentMode = kCAAlignmentCenter
//        bubble.firstMaterial?.diffuse.contents = UIColor.orange
//        bubble.firstMaterial?.specular.contents = UIColor.white
//        bubble.firstMaterial?.isDoubleSided = true
//        // bubble.flatness // setting this too low can cause crashes.
//        bubble.chamferRadius = CGFloat(bubbleDepth)
//
//        // BUBBLE NODE
//        let (minBound, maxBound) = bubble.boundingBox
//        let bubbleNode = SCNNode(geometry: bubble)
//        // Centre Node - to Centre-Bottom point
//        bubbleNode.pivot = SCNMatrix4MakeTranslation( (maxBound.x - minBound.x)/2, minBound.y, bubbleDepth/2)
//        // Reduce default text size
//        bubbleNode.scale = SCNVector3Make(0.2, 0.2, 0.2)
//
//        // CENTRE POINT NODE
//        let sphere = SCNSphere(radius: 0.005)
//        sphere.firstMaterial?.diffuse.contents = UIColor.cyan
//        let sphereNode = SCNNode(geometry: sphere)
//
//        // BUBBLE PARENT NODE
//        let bubbleNodeParent = SCNNode()
//        bubbleNodeParent.addChildNode(bubbleNode)
//        bubbleNodeParent.addChildNode(sphereNode)
//        bubbleNodeParent.constraints = [billboardConstraint]
//
//        return bubbleNodeParent
//    }
    
    // MARK: - CoreML Vision Handling
    
    func loopCoreMLUpdate() {
        // Continuously run CoreML whenever it's ready. (Preventing 'hiccups' in Frame Rate)
        
        dispatchQueueML.async {
            // 1. Run Update.
            self.updateCoreML()
            
            // 2. Loop this function.
            self.loopCoreMLUpdate()
        }
        
    }
    
    func rectangleDetectionHandler(request: VNRequest, error: Error?) {
         // Catch Errors
        if error != nil {
            print("Error: " + (error?.localizedDescription)!)
            return
        }
        
        guard let observations = request.results else {
            return
        }
        
        let rectangleObservations = observations
            .flatMap({ $0 as? VNRectangleObservation })
            .map({ "\([$0.topLeft, $0.bottomRight]) \(String(format:"- %.2f", $0.confidence))" })
            .joined(separator: "\n")
        
        DispatchQueue.main.async {
            // Print detections
            print(rectangleObservations)
            print("--")

            // Display Debug Text on screen
            var debugText:String = ""
            debugText += rectangleObservations
            self.debugTextView.text = debugText

            // Store the latest prediction if available
            self.lastDetectedRectangle = observations.first as? VNRectangleObservation
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        let imageRequestHandler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        // let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage!, orientation: myOrientation, options: [:]) // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
        
        ///////////////////////////
        // Run Image Request
        do {
            try imageRequestHandler.perform(self.visionRequests)
        } catch {
            print(error)
        }
        
    }
}

