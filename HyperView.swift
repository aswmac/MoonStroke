import UIKit
import SwiftUI 


enum InputEvent: Hashable {
  case fingerTap(postion: CGPoint)
  case doubleTap(position: CGPoint) 
  case keyDown(charCap: Character) 
  case keyUp(charCap: Character)
}

struct InputRulesMap {
  typealias Rule = (InputEvent, DrawingState) -> DrawingState?
  var rules: [Rule]
  
  init(rules: [Rule] = []) {
    self.rules = rules
  }
  
  mutating func append(_ rule: @escaping Rule) {
    rules.append(rule)
  }
  
  func resolve(_ input: InputEvent, with state: DrawingState) -> DrawingState {
    
    for rule in rules {
      if let newState = rule(input, state) {
        return newState
      }
    }
    return state
  }
}


final class HyperView: UIView {
  var nib_H: NibMatrix
  var strokeData_H: PencilStrokesArray
  
  private var lastFlattenTime: Date = .distantPast
  
  
  
  @MainActor private var strokeCache = [Int: UIImage]()
  @MainActor private var strokeCacheIndices = Set<Int>()
  @MainActor private func hasCachedStroke(_ index: Int) -> Bool {
    strokeCacheIndices.contains(index)
  }
  
  @MainActor private func getCachedStroke(_ index: Int) -> UIImage? {
    strokeCache[index]
  }
  
  var appHyperMode: HyperMode
  private var rasterizedImageView: UIImageView? 
  
  private func handleTypeChange(_ type: HyperModeType ) {
    print("handled")
  }

  init(samples: PencilStrokesArray, nibMat: NibMatrix, appHyperMode: HyperMode) {
    
    
    self.state.strokesTransform = AnyTransform(StrokeToGaussian())
    self.strokeData_H = samples
    self.state.isDrawing = true
    self.currentStroke = PencilStroke() 
    self.nib_H = nibMat
    self.appHyperMode = appHyperMode
    
    super.init(frame: .zero)
    layer.drawsAsynchronously = true
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = true 
    if loadDataNeedsDisplay { 
      drawFromStrokesData()
      loadDataNeedsDisplay = false
    }
    layer.setNeedsDisplay() 
  }
  
  var currentStroke: PencilStroke
  var rawStrokeLayers: [CALayer] = [] 
  
  var drawingLayer: CAShapeLayer? 
  var layerCount = 0 
  let layerLimit: Int = 2<<12 
  var loadDataNeedsDisplay: Bool = true 
  var state: DrawingState = DrawingState()
  
  
  
  var fingerViewOn: ((Bool) -> Void)? 
  
  
  var hoverViewOn: ((Bool) -> Void)? 
  
  var sendSelectedStrokes: (([PencilStroke]) -> Void)? 
  
  var sendCursorBox: ((CGRect?) -> Void)? 
  
  var sendFingerPosition: ((CGPoint) -> Void)? 
  var selectionPoint: CGPoint? {
    didSet { 
      if let sp = selectionPoint {  
        
        indicesList = self.strokeData_H.indices(boxing: sp)
      } else {
        indicesList = []
      }
      
      self.sendSelectedStrokes?(self.selectedStrokes) 
    }
  }
  var selectedStrokes: [PencilStroke] { 
    guard let indices = indicesList else { return [] }
    return indices.compactMap { index in
      guard index >= 0 && index < self.strokeData_H.count else { return nil }
      return self.strokeData_H.value[index]
    }
  }
  var indicesList: [Int]? 
  private var tempVec: [CGFloat] = Array(repeating: 0, count: NibMatrix.N) 
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    
    guard window != nil, loadDataNeedsDisplay else { return }
    
    drawFromStrokesData()
    loadDataNeedsDisplay = false
    
    
  }
  
  override func layoutSubviews() {
    super.layoutSubviews()
    
  }
  
  
  fileprivate func drawSinglePoint(_ sample: PencilSample, _ layer: CALayer) {
    
    let circleLayer = CAShapeLayer()
    let (fillColor, fillSize) = nib_H.map(sample)
    
    let rect = CGRect(center: sample.location, size: CGSize(width: fillSize, height: fillSize))
    let circlePath = UIBezierPath(ovalIn: rect)
    
    circleLayer.fillColor = fillColor.cgColor
    circleLayer.path = circlePath.cgPath
    addSublayerAndCount(circleLayer)
  }

  
  override func draw(_ layer: CALayer, in ctx: CGContext) { 


  }
  
  func renderStroke(_ stroke: PencilStroke, in layer: CALayer, offset: CGFloat = 0) {
    guard !stroke.isEmpty else { return }
    
    let index = strokeData_H.firstIndex(of: stroke)
    if let index = index,
        hasCachedStroke(index),
       let cachedImage = getCachedStroke(index) {
      drawCachedStroke(cachedImage, at: layer.bounds.origin, in: layer)
      return
    }
    
    var previousSample = stroke[0]
    drawSinglePoint(previousSample, layer) 
    
    for i in 1..<stroke.count {
      let sample = stroke[i]
      addSegmentLayer(from: previousSample, to: sample) 
      
      previousSample = sample
    }
    
  }
  
  private func drawCachedStroke(_ image: UIImage, at origin: CGPoint, in layer: CALayer) {
    let imageLayer = CALayer()
    imageLayer.frame = CGRect(origin: origin, size: image.size)
    imageLayer.contents = image.cgImage
    layer.addSublayer(imageLayer)
  }
  
  func addSegmentLayer(from previousSample: PencilSample, to currentSample: PencilSample) {
    let (fillColor, fillSize) = nib_H.map(currentSample)
    
    let strokeSegmentPath = UIBezierPath()
    let strokeSegmentLayer = CAShapeLayer()
    strokeSegmentLayer.strokeColor = fillColor.cgColor
    strokeSegmentLayer.lineWidth = fillSize
    strokeSegmentLayer.lineCap = .round
    
    strokeSegmentPath.move(to: previousSample.location)
    strokeSegmentPath.addLine(to: currentSample.location)
    strokeSegmentLayer.path = strokeSegmentPath.cgPath
    addSublayerAndCount(strokeSegmentLayer)
    
  }
  
  fileprivate func addSublayerAndCount(_ newLayer: CALayer) {
    layerCount += 1
    layer.addSublayer(newLayer)
    if state.isInputTransforming { 
      rawStrokeLayers.append(newLayer)
    } else {
      if self.layerCount > self.layerLimit {
        self.imageFlatten()
      }
    }
    
  }
  
  fileprivate func finishTransformAndDrawStroke(_ stroke: PencilStroke) {
    guard !stroke.isEmpty else { return }
    guard var _ = state.strokesTransform else { return }
    
  
    var lastSample = stroke[0] 
    
    for i in 1..<stroke.count {
      let sample = stroke[i]
      addSegmentLayer(from: lastSample, to: sample)
      lastSample = sample
    }
    
  }

  func drawFromStrokesData() {
    
    for (_, stroke) in self.strokeData_H.enumerated() {
      renderStroke(stroke, in: layer)
    }
    
    
  }
}

extension HyperView {
  func appendAndDraw(current touch: UITouch, with event: UIEvent?, drawIt: Bool) { 
    
    if let event = event { 
      if let coalescedTouches = event.coalescedTouches(for: touch) {
        for ct in coalescedTouches {
          self.currentStroke.append(ct, in: self)
          if drawIt, currentStroke.count >= 2 {
            let prev = currentStroke[currentStroke.count - 2]
            let curr = currentStroke.last!
            addSegmentLayer(from: prev, to: curr)

      
          }
        }
      }
    }
    
    self.currentStroke.append(touch, in: self)
    if drawIt, currentStroke.count >= 2 {
      let prev = currentStroke[currentStroke.count - 2]
      let curr = currentStroke.last!
      addSegmentLayer(from: prev, to: curr)
    }
  }
  func appendAs(final lastTouch: UITouch, with event: UIEvent?) {
    self.appendAndDraw(current: lastTouch, with: event, drawIt: true) 
    self.strokeData_H.append(self.currentStroke) 
    self.currentStroke = PencilStroke() 
  }
  
  private func preRenderStroke(_ stroke: PencilStroke, atIndex index: Int, size: CGSize) {
    guard !stroke.isEmpty else { return }
    
    
    
    let renderer = UIGraphicsImageRenderer(size: size) 
    let image = renderer.image { ctx in
      
      let context = ctx.cgContext
      context.setShouldAntialias(true)
      context.setLineCap(.round)
      
      var previous = stroke[0]
      drawSinglePointLayerInContext(previous, context: context)
      
      for i in 1..<stroke.count {
        let sample = stroke[i]
        drawSegmentInContext(from: previous, to: sample, context: context)
        previous = sample
      }
    }
    Task { @MainActor in
      strokeCache[index] = image
      strokeCacheIndices.insert(index)
    }
  }
  
  private func drawSinglePointLayerInContext(_ sample: PencilSample, context: CGContext) {
    let (color, size) = nib_H.map(sample)
    context.setFillColor(color.cgColor)
    context.fill(CGRect(center: sample.location, size: CGSize(width: size, height: size)))
  }
  
  private func drawSegmentInContext(from prev: PencilSample, to curr: PencilSample, context: CGContext) {
    let (color, size) = nib_H.map(curr)
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(size)
    context.move(to: prev.location)
    context.addLine(to: curr.location)
    context.strokePath()
  }
  
  
  func appendTo(transformed touch: UITouch, with event: UIEvent?) {
    
    appendAndDraw(current: touch, with: event, drawIt: self.state.strokesTransform?.showsRawPreview ?? false)
    self.state.strokesTransform?.append(touch, in: self)
    
    if let event = event { 
      if let coalescedTouches = event.coalescedTouches(for: touch) {
        for ct in coalescedTouches {
          appendAndDraw(current: ct, with: event, drawIt: self.state.strokesTransform?.showsRawPreview ?? false)
          self.state.strokesTransform?.append(ct, in: self)
        }
      }
    }
    
  }
  func appendAs(finalTransformed lastTouch: UITouch, with event: UIEvent?) {
    self.appendTo(transformed: lastTouch, with: event) 
    guard let ra = state.strokesTransform else {
      print("Touch tracking missed a step somewhere...")
      self.strokeData_H.append(currentStroke) 
      return
    }
    
    let finalStroke = ra.final()
    
    
    rawStrokeLayers.forEach { $0.removeFromSuperlayer() }
    rawStrokeLayers.removeAll()
    
    finishTransformAndDrawStroke(finalStroke)
    strokeData_H.append(finalStroke) 
    currentStroke = PencilStroke()

    layer.setNeedsDisplay(finalStroke.boundingBox.rectangle.insetBy(dx: -5, dy: -5)) 
    
    
    
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesBegan(touches, with: event)
    
    switch appHyperMode.type {
    case .pen:
      print("pen")
    case .eraser:
      print("eraser")
    case .invert:
      print("invert")
    case .compass:
      print("compass")
    case .classify:
      print("classify")
    case .numCursor:
      
      state.strokesTransform = AnyTransform(RuledAlignment(position: appHyperMode.lastSqueezedPosition))
      self.state.isInputTransforming = true
    case .normStamp:
      print("norm stamp") 
    case .sineWave:
      state.strokesTransform = AnyTransform(StrokeToGaussian())
      self.state.isInputTransforming = true
    case .timeLapse:
      print("timeLapse")
    case .snapToTip:
      print("snapToTip")
    case .gauge:
      print("gauge")
    case .mean:
      print("mean")
    case .plus:
      print("plus")
    case .minus:
      print("minus")
    case .fitSize:
      print("fit size of last stroke")
      state.strokesTransform = AnyTransform(fitVariance(appNib: self.nib_H))
      state.isInputTransforming = true
    case .widthPlus:
      print("width increase")
    case .widthMinus:
      print("width decrease")
    case .equalizeColor:
      print("equalizer")
    }
    if !state.isInputTransforming && layerCount > layerLimit {
      flattenLayers()
    }
    
    for newTouch in touches { 
      if state.selecting.active {
        self.selectionPoint = newTouch.location(in: self) 
        
      }
      if !state.isDrawing { return }
      switch newTouch.type {
      case .pencil:
        if state.isInputTransforming { 
          self.appendTo(transformed: newTouch, with: event)
            
        } else {
          self.appendAndDraw(current: newTouch, with: event, drawIt: true) 
        }
      case .direct: 
        if state.fingerPosition == nil { 
          let newFingerPosition = newTouch.location(in: self)
          state.fingerPosition = newFingerPosition
          self.fingerViewOn?(true) 
          self.sendFingerPosition?(newFingerPosition) 
        } else {
          
        }
      case .indirect: 
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
  }
  
	override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesMoved(touches, with: event)
		
    for newTouch in touches { 
      if state.selecting.active { 
        return 
      }
      if !state.isDrawing { return }
      switch newTouch.type {
      case .pencil:
        if state.isInputTransforming {
          self.appendTo(transformed: newTouch, with: event) 
        } else {
          self.appendAndDraw(current: newTouch, with: event, drawIt: true) 
        }
      case .direct: 
        let newFingerPosition = newTouch.location(in: self)
        self.sendFingerPosition?(newFingerPosition) 
      case .indirect: 
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
	}
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    if self.state.selecting.active { 
      
      return
    }
    
    for newTouch in touches { 
      switch newTouch.type {
      case .pencil:
        
        if state.isInputTransforming { 
          
          self.appendAs(finalTransformed: newTouch, with: event) 
          if let _ = state.strokesTransform { 
            sendCursorBox?(state.strokesTransform!.feedbackRect)
            if state.strokesTransform!.shouldResetBetweenStrokes {
              state.strokesTransform!.reset()
            }
          }
          state.isInputTransforming = false 
        } else {
          self.appendAs(final: newTouch, with: event)
        }
      case .direct: 
        
        print("           avgs of \(nib_H.avgRed.interval.count) red map out \(nib_H.avgRed.interval)")
        print("           avgs of \(nib_H.avgGreen.interval.count) avgGreen  out \(nib_H.avgGreen.interval)")
        print("           avgs of \(nib_H.avgBlue.interval.count) avgBlue  out \(nib_H.avgBlue.interval)")
        print("           avgs of \(nib_H.avgAlpha.interval.count) avgAlpha  out \(nib_H.avgAlpha.interval)")
        print("           avgs of \(nib_H.avgSize.interval.count) avgSize  out \(nib_H.avgSize.interval)")
        print("\n---------")
        print("           avgs of \(nib_H.avgForce.interval.count) avgForce  out \(nib_H.avgForce.interval)")
        print("           avgs of \(nib_H.avgAzimuth.interval.count) avgAzimuth  out \(nib_H.avgAzimuth.interval)")
        print("           avgs of \(nib_H.avgAltitude.interval.count) avgAltitude  out \(nib_H.avgAltitude.interval)")
        print("           avgs of \(nib_H.avgRoll.interval.count) avgRoll  out \(nib_H.avgRoll.interval)")
        state.fingerPosition = nil 
        self.fingerViewOn?(false) 
        if newTouch.tapCount == 1 { 
          
          if state.isInputTransforming { 
            state.strokesTransform?.reset() 
            sendCursorBox?(nil) 
            state.isInputTransforming = false 
            
          }

        } else if newTouch.tapCount == 2 {
          
          if !state.isInputTransforming { 
            self.state.strokesTransform = AnyTransform(StrokeToGaussian())
            if let _ = state.strokesTransform {
              state.isInputTransforming = true
              let p = newTouch.location(in: self)
              let s = CGSize(width: state.strokesTransform!.feedbackRect.width, height: state.strokesTransform!.feedbackRect.height) 
              state.strokesTransform!.setFeedbackRect(to: CGRect(center: p, size: s))
              sendCursorBox?(state.strokesTransform!.feedbackRect)
              
            }
          }
        }
      case .indirect: 
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
    
    
    
    
    
    
    if self.layerCount > self.layerLimit {
      flattenLayers()
    }
    
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    if state.selecting.active { 
      
      return
    }
    
    
    
    for newTouch in touches { 
      switch newTouch.type {
      case .pencil: 
        self.appendAs(final: newTouch, with: event) 
      case .direct: 
        state.strokesTransform?.reset()
      case .indirect: 
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
  }
  
	
	func imageFlatten() {

			guard let image = self.captureViewImage() else {
				
				return
			}
			
				self.clearLayers()
				self.layerCount = 0
				self.restoreViewFromImage(image)
			
	}
  
  
  fileprivate func flattenLayers() {
    
    let now = Date()
    guard now.timeIntervalSince(lastFlattenTime) > 0.3 else { return } 
    
    guard Thread.isMainThread else {
      DispatchQueue.main.async {self.flattenLayers() }
      return
    }
    
    
    rasterizedImageView?.isHidden = true
    
    let selfSize = self.layer.bounds.size 
    let allStrokes = strokeData_H.value + [currentStroke]

    let _ = UIGraphicsImageRenderer(bounds: self.bounds).image { context in
      
      self.layer.render(in: context.cgContext)
    }
    
    
    
    
    let renderingQueue = DispatchQueue(
      label: "com.MoonStroke.strokeRendering",
      qos: .userInitiated,
      attributes: .concurrent)
    let group = DispatchGroup()
    
    for (index, stroke) in allStrokes.enumerated() {
      group.enter()
      renderingQueue.async { [weak self] in
        defer { group.leave() }
        self?.preRenderStroke(stroke, atIndex: index, size: selfSize)
      }
    }
    
    group.notify(queue: .main) { [weak self] in
      self?.finalizeFlattening()
    }
  }
  
  private func finalizeFlattening() {

    let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
      
      self.layer.render(in: context.cgContext)
    }
    
    
    let tempImageView = UIImageView(image: image)
    tempImageView.contentMode = .scaleToFill
    tempImageView.frame = bounds
    tempImageView.alpha = 0
    addSubview(tempImageView)
    
    
    
    UIView.transition(with: self, duration: 0.5, options: .transitionCrossDissolve) {
      self.rasterizedImageView?.removeFromSuperview()
      tempImageView.alpha = 1
      self.rasterizedImageView = tempImageView
    } completion: { _ in
      self.rasterizedImageView = nil
    }
    

    layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    rawStrokeLayers.removeAll()
    layerCount = 0

    
    
    
  }
  
  fileprivate func clearLayers() {
    
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    layer.displayIfNeeded()
    CATransaction.commit()
    
    self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    
    
    rawStrokeLayers.removeAll()
    
    self.layerCount = 0

    rasterizedImageView?.removeFromSuperview()
    rasterizedImageView = nil
    
  }
  
  func captureViewImage() -> UIImage? { 
    
    if !currentStroke.isEmpty {
      
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      
      
      
      layer.displayIfNeeded()
      CATransaction.commit()
    }
    
    let wasAsync = layer.drawsAsynchronously
    layer.drawsAsynchronously = false
    defer { layer.drawsAsynchronously = wasAsync }
    
    
    rasterizedImageView?.isHidden = true
    defer { rasterizedImageView?.isHidden = false }
      

    let renderer = UIGraphicsImageRenderer(bounds: bounds)
    return renderer.image { context in
      self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
      
    }
    

  }
  
  func restoreViewFromImage(_ image: UIImage) {
    
    rasterizedImageView?.removeFromSuperview()
    rasterizedImageView = nil
    let imageView = UIImageView(frame: self.bounds)
    imageView.image = image
    imageView.contentMode = .scaleAspectFit 
    self.addSubview(imageView)
    rasterizedImageView = imageView
  }
}

extension HyperView {
  func sendSampleToServer(_ sample: PencilSample, isStart: Bool = false) {
    let type = isStart ? "start" : "move"
    let body: [String: Any] = [
      "type": type,
      "x": sample.location.x,
      "y": sample.location.y
    ]
    
      
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
          let url = URL(string: "https://aswmac.com/strokes-stream/add-stroke") else {
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    
    URLSession.shared.dataTask(with: request).resume()
  }
}

