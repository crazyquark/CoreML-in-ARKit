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
    @IBOutlet weak var accuracyControl: UISlider!
    @IBOutlet weak var confidenceLabel: UILabel!
    
    // Displayed rectangle outline
    private var selectedRectangleOutlineLayer: CAShapeLayer?
    
    // Current 3D object
    private var currentSceneNode: SCNNode?
    
    // COREML
    private var observedRectangle : VNRectangleObservation?
    private var visionRequests = [VNRequest]()
    private let dispatchQueueML = DispatchQueue(label: "com.hw.dispatchqueueml") // A Serial Queue
    private var rectDetectionRequest : VNDetectRectanglesRequest?
    private let visionSequenceHandler = VNSequenceRequestHandler()
    
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
        
        // Begin Loop to Update CoreML
        self.rectDetectionRequest = VNDetectRectanglesRequest(completionHandler: rectangleDetectionHandler)
        rectDetectionRequest!.maximumObservations = 1
        rectDetectionRequest!.minimumConfidence = 1.0
        
        loopCoreMLUpdate()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        // Enable plane detection
        configuration.planeDetection = .horizontal
        
        self.confidenceLabel.text = String(format: "Confidence: %.2f", self.accuracyControl.value)
        
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
    
    @IBAction func confidenceSliderChanged(_ sender: Any) {
        self.confidenceLabel.text = String(format: "Confidence: %.2f", self.accuracyControl.value)
    }
    // MARK: - ARSCNViewDelegate
    
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        DispatchQueue.main.async {
            // Draw detected rectangle
            self.drawElementsInAR()
        }
    }
    
    // MARK: - Status Bar: Hide
    override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Interaction
    
    @objc func handleTap(gestureRecognize: UITapGestureRecognizer) {
        // Seed detector anew
        self.visionRequests.removeAll()
        
        // Adjust confidence
        rectDetectionRequest!.minimumConfidence = accuracyControl.value
        
        self.visionRequests.append(rectDetectionRequest!)
    }
    
    private func drawElementsInAR() {
        // Remove previous layers
        self.sceneView.layer.sublayers?.removeAll()
        
        guard let rectangle = self.observedRectangle else {
            return
        }
        
        // Recognition rectangle for debugging for now
        let points = [rectangle.topLeft, rectangle.topRight, rectangle.bottomRight, rectangle.bottomLeft]
        let convertedPoints = points.map { self.sceneView.convertFromCamera($0) }
        self.selectedRectangleOutlineLayer = self.drawPolygon(convertedPoints, color: UIColor.green)
        
        self.sceneView.layer.addSublayer(self.selectedRectangleOutlineLayer!)
    }
    
    func create3Dobj(_ position: SCNVector3) -> SCNNode {
        let sphere = SCNSphere(radius: 0.005)
        sphere.firstMaterial?.diffuse.contents = UIColor.orange
        let sphereNode = SCNNode(geometry: sphere)
        
        sphereNode.position = position
        
        return sphereNode
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
    
    private func rectangleDetectionHandler(request: VNRequest, error: Error?) {
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
        
        // Did we detect rectangle?
        if let rectangle = observations.first as? VNRectangleObservation {
            self.observedRectangle = rectangle
            
            // Remove the detect request
            self.visionRequests.remove(at: 0)
            
            // Add a track request instead
            let trackRequest = VNTrackRectangleRequest(rectangleObservation: rectangle, completionHandler: self.rectangleDetectionHandler)
            trackRequest.trackingLevel = .accurate
            self.visionRequests.append(trackRequest)
            
            // Let's compute the center of the rectangle
            let midPoint2D = CGPoint(x: (rectangle.topLeft.x - rectangle.bottomRight.x) / 2.0, y: (rectangle.topLeft.y - rectangle.bottomRight.y) / 2.0)
            // Let's transpose this in 3D
            
            let arHitTestResults : [ARHitTestResult] = self.sceneView.hitTest(midPoint2D, types: [.featurePoint])
            if let closestResult = arHitTestResults.first {
                let transform : matrix_float4x4 = closestResult.worldTransform
                let worldCoord : SCNVector3 = SCNVector3Make(transform.columns.3.x, transform.columns.3.y, transform.columns.3.z)
                
                
                // Update node
                let newNode = create3Dobj(worldCoord)
                if let oldNode = self.currentSceneNode {
                    self.sceneView.scene.rootNode.replaceChildNode(oldNode, with: newNode)
                } else {
                    self.sceneView.scene.rootNode.addChildNode(newNode)
                }
                
                self.currentSceneNode = newNode
            }
        }
        
        DispatchQueue.main.async {
            // Print detections
            print(rectangleObservations)
            print("--")

            // Display Debug Text on screen
            var debugText:String = ""
            debugText += rectangleObservations
            self.debugTextView.text = debugText
        }
    }
    
    func updateCoreML() {
        ///////////////////////////
        // Get Camera Image as RGB
        let pixbuff : CVPixelBuffer? = (sceneView.session.currentFrame?.capturedImage)
        if pixbuff == nil { return }
        //  let ciImage = CIImage(cvPixelBuffer: pixbuff!)
        // Note: Not entirely sure if the ciImage is being interpreted as RGB, but for now it works with the Inception model.
        // Note2: Also uncertain if the pixelBuffer should be rotated before handing off to Vision (VNImageRequestHandler) - regardless, for now, it still works well with the Inception model.
        
        ///////////////////////////
        // Prepare CoreML/Vision Request
        // let imageRequestHandler = VNImageRequestHandler(cgImage: cgImage!, orientation: myOrientation, options: [:]) // Alternatively; we can convert the above to an RGB CGImage and use that. Also UIInterfaceOrientation can inform orientation values.
        
        ///////////////////////////
        // Run Image Request
        do {
            try self.visionSequenceHandler.perform(self.visionRequests, on: pixbuff!)
        } catch {
            print(error)
        }
        
    }
}

