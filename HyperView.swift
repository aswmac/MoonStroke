import UIKit
import SwiftUI 


final class HyperView: UIView {
  var nib_H: NibMatrix
  @Binding var strokeData_H: PencilStrokesArray 
  
  
  
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

  init(samples: Binding<PencilStrokesArray>, nibMat: NibMatrix, appHyperMode: HyperMode) {
    
    
    self.state.strokesTransform = AnyTransform(StrokeToGaussian())
    self._strokeData_H = samples
    self.state.isDrawing = true
    self.currentStroke = PencilStroke() 
    self.nib_H = nibMat
    self.appHyperMode = appHyperMode
    
    super.init(frame: .zero)
    layer.drawsAsynchronously = true
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = true 
    
      drawFromStrokesData()
      loadDataNeedsDisplay = false
    
    layer.setNeedsDisplay() 
  }
  
  var currentStroke: PencilStroke
  var rawStrokeLayers: [CALayer] = [] 
  
  var drawingLayer: CAShapeLayer? 
  
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
    
    
    DispatchQueue.main.async { [weak self] in
      self?.drawFromStrokesData()
    }
    
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
    
    
    drawSinglePoint(stroke[0], layer) 
    
    for i in 1..<stroke.count {
      let prev = stroke[i - 1]
      let curr = stroke[i]
      let prevPrev = i >= 2 ? stroke[i - 2] : nil
      let next = i + 1 < stroke.count ? stroke[i + 1] : nil
      
      addCurveLayer(from: prev, to: curr, prevPrev: prevPrev, next: next)
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
  
  
  private func addCurveLayer(from prev: PencilSample, to curr: PencilSample, prevPrev: PencilSample? = nil, next: PencilSample? = nil){
    let (fillColor, fillSize) = nib_H.map(curr)
    
    
    let path = UIBezierPath()
    let layer = CAShapeLayer()
    
    layer.strokeColor = fillColor.cgColor
    layer.lineWidth = fillSize
    layer.lineCap = .round
    layer.lineJoin = .round
    
    
    let p0 = prev.location
    let p1 = curr.location
    
    let v1 = prevPrev.map { ($0.location - p0) } ?? (p1 - p0)
    let v2 = next.map { _ in (next!.location - p1) } ?? (p1 - p0)
    
    let d1 = CGVector(dx: v1.x / 6, dy: v1.y / 6)
    let d2 = CGVector(dx: v2.x / 6, dy: v2.y / 6)
    
    let c1 = p0 + d1
    let c2 = p1 - d2
    
    path.move(to: p0)
    path.addCurve(to: p1, controlPoint1: c1, controlPoint2: c2)
    
    layer.path = path.cgPath
    addSublayerAndCount(layer)
  }
  
  private func drawCurveInContext(from prev: PencilSample, to curr: PencilSample, prevPrev: PencilSample?, next: PencilSample?, context: CGContext) {
    let (color, size) = nib_H.map(curr)
    context.setStrokeColor(color.cgColor)
    context.setLineWidth(size)
    context.setLineCap(.round)
    context.setLineJoin(.round)
    
    
    let p0 = prev.location
    let p1 = curr.location
    
    let v1 = prevPrev.map { ($0.location - p0) } ?? (p1 - p0)
    let v2 = next.map { _ in (next!.location - p1) } ?? (p1 - p0)
    
    let d1 = CGVector(dx: v1.x / 6, dy: v1.y / 6)
    let d2 = CGVector(dx: v2.x / 6, dy: v2.y / 6)
    
    let c1 = p0 + d1
    let c2 = p1 - d2
    
    context.move(to: p0)
    context.addCurve(to: p1, control1: c1, control2: c2)
    context.strokePath()
  }
  
  fileprivate func addSublayerAndCount(_ newLayer: CALayer) {
    
    layer.addSublayer(newLayer)
    if state.isInputTransforming { 
      rawStrokeLayers.append(newLayer)
    }
    
  }
  
  fileprivate func finishTransformAndDrawStroke(_ stroke: PencilStroke) {
    guard !stroke.isEmpty else { return }
    guard var _ = state.strokesTransform else { return }
    
    drawSinglePoint(stroke[0], layer)

    for i in 1..<stroke.count {
      let prev = stroke[i - 1]
      let curr = stroke[i]
      let prevPrev = i >= 2 ? stroke[i - 2] : nil
      let next = i + 1 < stroke.count ? stroke[i + 1] : nil
      
      addCurveLayer(from: prev, to: curr, prevPrev: prevPrev, next: next)
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
          if drawIt {
            if currentStroke.count >= 2 {
              let prev = currentStroke[currentStroke.count - 2]
              let curr = currentStroke.last!
              addSegmentLayer(from: prev, to: curr)
            } else if currentStroke.count == 1 {
              drawSinglePoint(currentStroke[0], layer)
            }
          }
        }
      }
    }
    
    self.currentStroke.append(touch, in: self)
    if drawIt {
      if currentStroke.count >= 2 {
        let prev = currentStroke[currentStroke.count - 2]
        let curr = currentStroke.last!
        addSegmentLayer(from: prev, to: curr)
      } else if currentStroke.count == 1 {
        drawSinglePoint(currentStroke[0], layer)
      }
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
      context.setLineJoin(.round)
      
      var prevPrev: PencilSample? = nil
      var prev = stroke[0]
      drawSinglePointLayerInContext(prev, context: context)
      
      for i in 1..<stroke.count {
        let curr = stroke[i]
        drawCurveInContext(from: prev, to: curr, prevPrev: prevPrev, next: i + 1 < stroke.count ? stroke[i + 1] : nil, context: context)
        prevPrev = prev
        prev = curr
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
        
        state.strokesTransform?.reset()
        state.isInputTransforming = false
        sendCursorBox?(nil)
        
        
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
        
      case .indirect: 
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
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
        if state.isInputTransforming {
          state.strokesTransform?.reset()
          state.isInputTransforming = false
        }
      case .direct: 
        state.strokesTransform?.reset()
        state.isInputTransforming = false
      case .indirect: 
        state.strokesTransform?.reset()
        state.isInputTransforming = false
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        state.strokesTransform?.reset()
        state.isInputTransforming = false
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        state.strokesTransform?.reset()
        state.isInputTransforming = false
        debugPrint("Unknown input type -- fatal error...")
      }
    }
    
    if state.isInputTransforming {
      state.strokesTransform?.reset()
      state.isInputTransforming = false
      sendCursorBox?(nil)
    }
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
    
    
    let wasHidden = rasterizedImageView?.isHidden ?? false
    rasterizedImageView?.isHidden = true
    defer { rasterizedImageView?.isHidden = wasHidden }
      

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


