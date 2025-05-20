//
//  HyperView.swift
//  MoonStroke
//
//  Created by Adam Mcgregor on 9/23/24.
//
import UIKit
import SwiftUI //for @Binding

final class HyperView: UIView {
  //static let nib = Nib.default // TODO: have nib saved but separately associated
	@Binding var nib: NibMatrix {//= NibMatrix.standard
			didSet { // 2024.09.29.141925 GPT's #2 suggestion
				setNeedsDisplay()
				setNeedsLayout()
			}
		}
	@Binding var strokeData: PencilStrokesArray //{
//		didSet {
//			setNeedsDisplay() // append gets it, but when ContentView changes nib, this...does something...? (It refreshes all AFTER
//												// lifting the pencil after a stroke after changing the nib
//			setNeedsLayout() // this seems no action, setNeedsDisplay() seems to be the one doing whatever
//		}
//	}
  var currentStroke: PencilStroke
	
	var drawingLayer: CAShapeLayer? // many get created anyway, maybe do not need this handle
	var layerCount = 0 // keep the number of draw rendered layers limited,
	let layerLimit: Int = 2<<12 // flatten the rest to an image layer at a threshold
	var loadDataNeedsDisplay: Bool = true // need to grab the load data and view it but only once
	var isSelecting: Bool = false {
		didSet { // send the selection boxes up the hierarchy chain
			if isSelecting {
				//comment("Bool didset: sending the selected strokes up the hierarchy chain")
				self.sendSelectedStrokes?(self.selectedStrokes)
			} else {
				//comment("Bool didset: sending        []      array up the hierarchy chain")
				self.sendSelectedStrokes?([])
			}
		}
	}
	
	var hoverViewOn: ((Bool) -> Void)? // handle to send messages up to turn on hover view, since pencil hover is SwiftUI not UIKit
	var sendSelectedStrokes: (([PencilStroke]) -> Void)? // didn't figure out how to turn on and off here
	// so I use showSelecting to send the task up the chain hierarchy
	var selectionPoint: CGPoint? {// to allow selection of areas
		didSet { // selecting a stroke or strokes happens here (at least all such route through here)
			if let sp = selectionPoint { // TODO: toggle here not set it...
				//comment("selectionPoint: didSet")
				indicesList = self.strokeData.indices(boxing: sp)
			}
			//comment("selectionPoint: sending selected strokes up the hierarchy chain")
			self.sendSelectedStrokes?(self.selectedStrokes) // alert/callback the changes up the h-chain
		}
	}
	var selectedStrokes: [PencilStroke] { // observer--keep list of selected strokes
		guard let indices = indicesList else { return [] }
		return indices.compactMap { index in
			guard index >= 0 && index <= self.strokeData.value.count else { return nil }
			return self.strokeData.value[index]
		}
	}
	var indicesList: [Int]? // set when selectionPoint is set
	private var tempVec: [CGFloat] = Array(repeating: 0, count: NibMatrix.N) // For randomly changing nib
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
	init(samples: Binding<PencilStrokesArray>, nibMat: Binding<NibMatrix>) {
		
    self._strokeData = samples
    self.currentStroke = PencilStroke() // allot memory for the next/current stroke drawn
		self._nib = nibMat
		
		super.init(frame: .zero)
		isUserInteractionEnabled = true
		if loadDataNeedsDisplay { // maybe not even need the Bool, since always do it on load, but later..
			drawFromLoadData()
			loadDataNeedsDisplay = false
		}
		layer.setNeedsDisplay() // need to show the loaded data, otherwise wont show until a stroke drawn
  }
	
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.drawsAsynchronously = true
  }
	
	func drawFromLoadData() {
		var previousSample = PencilSample()
		for (_, stroke) in self.strokeData.enumerated() {
			// setup color/nib/whatever for each stroke
			for (index, sample) in stroke.enumerated() {
				if index == 0 {
					previousSample = sample
					continue
				} // make sure there are two points to make the line
				let lineLayer = CAShapeLayer()
				
				let (fillColor, fillSize) = nib.map(sample)
				lineLayer.strokeColor = fillColor.cgColor
				lineLayer.lineWidth = fillSize
				lineLayer.lineCap = .round
				let path = UIBezierPath()
				path.move(to: previousSample.location)
				//path.addCurve(to: T##CGPoint, controlPoint1: T##CGPoint, controlPoint2: T##CGPoint)
				path.addLine(to: sample.location)
				lineLayer.path = path.cgPath
				layer.addSublayer(lineLayer)
				previousSample = sample
			}
		}
		
	}
	/*
  // TODO: consider if this is the GPU version (as opposed to CPU) and do it maybe
  // TODO: 2024.09.23.145306---definitely gets some lag after lots of strokes
	override func draw(_ layer: CALayer, in ctx: CGContext) { // do not use ctx if want GPU over CPU
		// Reuse existing layer, or create new
		let drawingLayer = self.drawingLayer ?? CAShapeLayer()
		// Match device scale to avoid pixellation
		drawingLayer.contentsScale = UIScreen.main.scale
		// Create the path that will guide the drawing
		
		// Build the path by looping through the points
		var previousSample = PencilSample()
		for (index, point) in self.currentStroke.enumerated() {
			let (lineColor, lineSize) = nib.map(point)
			if index == 0 {
				previousSample = point
			} else {
				let linePath = UIBezierPath()
				linePath.move(to: previousSample.location)
				linePath.addLine(to: point.location)
				drawingLayer.path = linePath.cgPath
				drawingLayer.opacity = 1
				drawingLayer.lineWidth = lineSize // TODO: get the size from map
				drawingLayer.lineCap = .round
				drawingLayer.fillColor = UIColor.clear.cgColor
				drawingLayer.strokeColor = lineColor.cgColor
				layer.addSublayer(drawingLayer)
				previousSample = point
			}
			
			
		}
//		for (_, stroke) in self.strokeData.enumerated() {
//			// setup color/nib/whatever for each stroke
//			for (_, sample) in stroke.enumerated() {
//				let (fillColor, dLine) = nib.map(sample)
//				fillColor.setFill()
//				dLine.fill()
//			}
//		}
		
		// the self layer is nil when "flatten", then this one is a new one so assign it
		if self.drawingLayer == nil {
			self.drawingLayer = drawingLayer
			layer.addSublayer(drawingLayer)
		}
	//super.draw(layer, in: ctx)
	//  •  Access the optional drawingLayer, which contains everything we drew earlier in draw(layer:ctx:)
//  •  Encode the layers from that drawingLayer into a data object, then decode that object into a brand-new layer (a copy)
//  •  Access the optional value of that brand-new layer
//  •  Add that new layer as a sublayer on the view’s layer to display it
// `https://medium.com/@almalehdev/high-performance-drawing-on-ios-part-2-2cb2bc957f6`
  }
	
	func setupDrawingLayerIfNeeded() {
		guard drawingLayer == nil else { return }
		let sublayer = CAShapeLayer()
		sublayer.frame = bounds
		layer.addSublayer(sublayer)
		drawingLayer = sublayer
	}
	*/
	// TODO: maybe do an array of layers for each color maybe, or for a single possibly long stroke
	fileprivate func drawSInglePoint(_ sample: PencilSample, _ layer: CALayer) {
		// store for the (possibly) continuing stroke
		let circleLayer = CAShapeLayer()
		let (fillColor, fillSize) = nib.map(sample)
		let rect = CGRect(x: sample.location.x - fillSize/2,
											y: sample.location.y - fillSize/2,
											width: fillSize, height: fillSize)
		let circlePath = UIBezierPath(ovalIn: rect)
		//let circlePath = UIBezierPath(arcCenter: sample.location, radius: fillSize, startAngle: 0, endAngle: 1.9 * .pi, clockwise: false) // change this to just ellipse in later
		circleLayer.fillColor = fillColor.cgColor
		circleLayer.path = circlePath.cgPath
		layer.addSublayer(circleLayer)
	}
	
	fileprivate func drawLinePath(from previousSample: PencilSample, to sample: PencilSample, _ lineLayer: CAShapeLayer, _ layer: CALayer) {
		// TODO: this is repeated, functionize
		let (fillColor, fillSize) = nib.map(sample)
		lineLayer.strokeColor = fillColor.cgColor
		lineLayer.lineWidth = fillSize
		lineLayer.lineCap = .round
		let path = UIBezierPath()
		path.move(to: previousSample.location)
		path.addLine(to: sample.location)
		lineLayer.path = path.cgPath
		layer.addSublayer(lineLayer)
	}
	
	override func draw(_ layer: CALayer, in ctx: CGContext) { // do not use ctx if want GPU over CPU
		// TODO: this uses two points at a time. Can maybe use 3 or 4 to get bezier curvature
		var previousSample = PencilSample()
		//let lineLayer = CAShapeLayer()
		//drawingLayer = CAShapeLayer() // just reuse the same variable, is that where the slowdown came?
		//guard let lineLayer = drawingLayer else { return }
		for ( index ,sample) in self.currentStroke.enumerated() {
			if index == 0 {
				previousSample = sample
				drawSInglePoint(sample, layer)
				continue
			} // make sure there are two points to make the line
			drawingLayer = CAShapeLayer() // just reuse the same variable, is that where the slowdown came?
			guard let lineLayer = drawingLayer else { continue }
			layerCount += 1
			drawLinePath(from: previousSample, to: sample, lineLayer,  layer)
			previousSample = sample
		}
		
	}
//	override func draw(_ rect: CGRect) {
//		for (_,sample) in self.currentStroke.enumerated() {
//			// TODO: this is repeated, functionize
//			let (fillColor, fillSize) = nib.map(sample)
//			fillColor.setFill()
//			let sSize = CGSize(width: fillSize, height: fillSize)
//			var pointSquare = CGRect(origin: sample.location, size: sSize)
//			pointSquare.center = sample.location
//			let dLine = UIBezierPath(ovalIn: pointSquare)
//			dLine.fill()
//		}
//		for (_, stroke) in self.strokeData.enumerated() {
//			// setup color/nib/whatever for each stroke
//			for (_, sample) in stroke.enumerated() {
//				let (fillColor, fillSize) = nib.map(sample)
//				fillColor.setFill()
//				let sSize = CGSize(width: fillSize, height: fillSize)
//				var pointSquare = CGRect(origin: sample.location, size: sSize)
//				pointSquare.center = sample.location
//				let dLine = UIBezierPath(ovalIn: pointSquare)
//				dLine.fill()
//			}
//		}
//		if self.showSelecting { // if the "s" key is held down to see selecion boxes of stroke(s)
//			guard let context = UIGraphicsGetCurrentContext() else { return }
//			if self.showSelecting {
//				if let il = self.indicesList {
//					for i in il {
//						//comment("draw(): selectionIndex: \(i)")
//						drawOutline(for: i, using: context)
//					}
//					//drawOutline(for: si, using: context)
//				}
//			}
//		}
//	}
	
	
}

// get strokes and append them to the self data
extension HyperView {
  func appendTo(current touch: UITouch, with event: UIEvent?) {
    if let last = currentStroke.last {
      if (last.location - touch.location(in: self)).quadrance < 2.0 {
        //comment(".", terminator: "")
        return
      }
    }
    if let event = event { // also append coalesded touches
      if let coalescedTouches = event.coalescedTouches(for: touch) {
        for ct in coalescedTouches {
          self.currentStroke.append(ct, in: self)
					let frame = CGRect(origin: ct.location(in: self), size: .zero)
					layer.setNeedsDisplay(frame.insetBy(dx: -20, dy: -20))
        }
      }
    }
    self.currentStroke.append(touch, in: self)
		let frame = CGRect(origin: touch.location(in: self), size: .zero)
		layer.setNeedsDisplay(frame.insetBy(dx: -20, dy: -20))
  }
  func append(final lastTouch: UITouch, with event: UIEvent?) {
    self.appendTo(current: lastTouch, with: event)
    self.strokeData.append(self.currentStroke)
    self.currentStroke = PencilStroke()
		let frame = CGRect(origin: lastTouch.location(in: self), size: .zero)
		layer.setNeedsDisplay(frame.insetBy(dx: -20, dy: -20))
  }
  // touches.first is pencil, rest would be multi-touch stuff which is not used here
	override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		guard let newTouch = touches.first else { return } // pencil is first one, rest is multi-touch
		if self.isSelecting { // selection index is nil unless the "s" key is held down
			debugPrint("touchesBegan():")
			self.selectionPoint = newTouch.location(in: self) // if the "s" key is indicating selection
			debugPrint("selectionPoint is \(String(describing: self.selectionPoint))")
			return // then get the point of touch and just return as no drawing is taking place here
		}
		self.appendTo(current: newTouch, with: event)
	}
  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesCancelled(touches, with: event)
    self.currentStroke = PencilStroke()
	}
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesMoved(touches, with: event)
		guard let newTouch = touches.first else { return } // pencil is first one, rest is multi-touch
		if self.isSelecting { // selection index is nil unless the "s" key is held down
			//comment("touchesMoved():")
			//self.selectionPoint = newTouch.location(in: self) // if the "s" key is indicating selection
			//comment("Moved: selectionPoint is \(String(describing: self.selectionPoint))")
			return // then get the point of touch and just return as no drawing is taking place here
		}
		self.appendTo(current: newTouch, with: event)
	}
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
		if self.isSelecting { return } // "s" key do not want to draw
    // TODO: here is the last point that can show some "velocity" like ....  . where the last is a bit further, use that also
    // TODO: maybe check if current stroke is empty, but that may be extra unneccessarry
		guard let newTouch = touches.first else { return }// pencil is first one, rest is multi-touch
		self.append(final: newTouch, with: event) // this is possibly a point further out
		// TODO: can use the further out point as a velocity measure maybe, like a tapering of the stroke
//		if let flattenedDrawing = flattenedLayer() {
//			self.layer.addSublayer(flattenedDrawing)
//			debugPrint("flattened drawing")
//		}
		if self.layerCount > self.layerLimit {
			self.imageFlatten()
		}
		
  }
	
//	// Copying a layer this way lets us bypass the requirement to use a CGContext (instead of rendering
//	// the existing layers into a context then generating a bitmap image from that), saving many
//	// CPU cycles -- NO I GUESS NOT ANYMORE (MAYBE, OR SOMETHING BECAUSE) IT DOES NOT LOWER LAYER COUNT!
//	func flattenedLayer() -> CAShapeLayer? {
//		// access the optional drawing layer, which contains everything we drew earlier in draw(_ layer)
//		guard let drawingLayer = layer.sublayers?.compactMap({$0 as? CAShapeLayer}).first else {
//			print("No layer data to flatten was found!")
//			return nil
//		}
//		// encode the layers from that drawing layer into a data object
//		do {
//			let archivedData = try NSKeyedArchiver.archivedData(withRootObject: drawingLayer, requiringSecureCoding: true)
//			let unarchivedLayer = try NSKeyedUnarchiver.unarchivedObject(ofClass: CAShapeLayer.self, from: archivedData)
//			return unarchivedLayer
//		} catch {
//			print("Failed to archive or unarchive the layer(s): \(error)")
//			return nil
//		}
//	}
	
	/*
	 2024.10.12.175808---SOMETHING is crapping out after a lot of strokes on the order of 100
	 *** Terminating app due to uncaught exception 'NSInternalInconsistencyException', reason: 'Call must be made on main thread'
	 *** First throw call stack:
	 (0x195e907cc 0x1931632e4 0x1952608d8 0x1988ce4a8 0x198757350 0x1987571d8 0x198755db0 0x198755918 0x199792c1c 0x1997928ac 0x199790720 0x198b37b24 0x198b377dc 0x104a890d4 0x104a88e4c 0x104a89558 0x1055cca30 0x1055ce71c 0x1055e2e58 0x1055e3618 0x21e283c40 0x21e280488)
	 libc++abi: terminating due to uncaught exception of type NSException
	 */
	
	func imageFlatten() {
		//comment("Saving an image...")
		// 2024.10.12.182612---Originally I thought this was necessary to do on alternate thread
		// because there seemed to be some strokes getting missed. Maybe they still are when doing
		// cursive as that maybe makes too many layers per point of long cursive strokes, but it
		// seems that at least with single stroke decimal digits that it has little problem, it
		// has some noticeable lag during fast stroke input, but nothing gets dropped. It does
		// crash after some time if actually do the global queue so that is out I guess, keep it MAIN
		DispatchQueue.main.async { //DispatchQueue.global(qos: .userInitiated).async { //
			guard let image = self.captureViewImage() else {
				//comment("Failed to capture view image!")
				return
			}
			//DispatchQueue.main.async {
				self.clearLayers()//self.layer.sublayers?.forEach({ $0.removeFromSuperlayer() })
				self.layerCount = 0
				self.restoreViewFromImage(image)
			//}
		}
		/*
		// to clear coule also do this:
		//self.layer.sublayers?.removeAll() // maybe this, AI ass suggested
		// or GPT suggested this:
		//self.layer.sublayers?.forEach({ $0.removeFromSuperlayer() })
		*/
	}
	
	func clearLayers() {
		guard let sublayers = self.layer.sublayers else {
			//comment("No layers showed up fot clearing!")
			return }
		//var count = 0
		for case let layer as CAShapeLayer in sublayers { // for case matches only those that bind as type
			layer.removeFromSuperlayer()
			//count += 1
		}
		// wow (2024.10.12.100357) the strokes 0 1 2 3 gave 1564 layers... for each strokePoint obviously
		//comment("clearLayers() had \(count) layers removed. layerCount = \(layerCount)")
		//self.layerCount = 0
	}
	
	func captureViewImage() -> UIImage? { // was self.bounds.self.size with an extra 'self'...?
		UIGraphicsBeginImageContextWithOptions(self.bounds.size, false, 0) // UIView.bounds must be used from main thread only
		defer { UIGraphicsEndImageContext() }
		self.drawHierarchy(in: self.bounds, afterScreenUpdates: true) // UIView.drawHierarchy(in:afterScreenUpdates:) must be used from main thread only
		return UIGraphicsGetImageFromCurrentImageContext()
	}
	
	func restoreViewFromImage(_ image: UIImage) {
		let imageView = UIImageView(frame: self.bounds)
		imageView.image = image
		imageView.contentMode = .scaleAspectFit // or .scaleAspectFill
		self.addSubview(imageView)
	}
}

