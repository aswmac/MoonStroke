//
//  HyperView.swift
//  MoonStroke
//
//  Created on 9/23/24.
//
import UIKit
//import SwiftUI //for @Binding--NO because they work on the View life cycle of onAppear, onChange etc
import SwiftUI // for EnvironmentObject


// Do the pre-rendering of images from strokes off the main thread
actor StrokeCacheActor {
  private var strokeImageCache = [Int: UIImage]() // index to pre-rendered images
  //{ willSet { precondition(Thread.isMainThread, "stroke cache stay MAIN please!") }}
  private var cachedStrokeIndices = Set<Int>() // which strokes are cached
  //{ willSet { precondition(Thread.isMainThread, "cached stay MAIN please!") }}
  
  subscript(index: Int) -> UIImage? {
    return self.strokeImageCache[index]
  }
  
  func cache(_ image: UIImage, for index: Int) {
    strokeImageCache[index] = image
    cachedStrokeIndices.insert(index)
  }
  
  func contains(_ member: Int) -> Bool {
    return self.cachedStrokeIndices.contains(member)
  }
  
  func getIndices() -> Set<Int> {
    cachedStrokeIndices
  }
  
  func clear() {
    strokeImageCache.removeAll()
    cachedStrokeIndices.removeAll()
  }
}


//
enum InputEvent: Hashable {
  case fingerTap(postion: CGPoint)
  case doubleTap(position: CGPoint) // want to snap straight lines that I get ends close
  case keyDown(charCap: Character) // want "s" key held to select strokes, "h" key to show crosshairs etc
  case keyUp(charCap: Character)
}

// State Transition Rules, Current DrawingState with InputEvent returns new DrawingState
// use like:
// inputRules = InputRulesMap()
// inputRules.append(.fingerDown, from: .draw, to: .draw | .shapeHighlighting)
struct InputRulesMap {
  typealias Rule = (InputEvent, DrawingState) -> DrawingState?
  var rules: [Rule]
  
  init(rules: [Rule] = []) {
    self.rules = rules
  }
  
  mutating func append(_ rule: @escaping Rule) {
    rules.append(rule)
  }
//  // Convenience builder
//  mutating func append(_ input: InputEvent, from state: DrawingState, to newState: DrawingState) {
//    append { ev, st in ev == input && st == state ? newState : nil }
//  }
  
  func resolve(_ input: InputEvent, with state: DrawingState) -> DrawingState {
    // Try all rules; fail bac to current state if no match
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
  
  private let strokeCacheActor = StrokeCacheActor()
  
  @MainActor private var strokeCache = [Int: UIImage]()
  @MainActor private var strokeCacheIndices = Set<Int>()
  @MainActor private func hasCachedStroke(_ index: Int) -> Bool {
    strokeCacheIndices.contains(index)
  }
  
  @MainActor private func getCachedStroke(_ index: Int) -> UIImage? {
    strokeCache[index]
  }
  
  var appHyperMode: HyperMode
  private var rasterizedImageView: UIImageView? // track for removals
  
  private func handleTypeChange(_ type: HyperModeType ) {
    print("handled")
  }

  init(samples: PencilStrokesArray, nibMat: NibMatrix, appHyperMode: HyperMode) {
    
    //self.state.strokesTransform = AnyTransform(RuledAlignment(position: CGPoint()))
    self.state.strokesTransform = AnyTransform(StrokeToGaussian())
    self.strokeData_H = samples
    self.state.isDrawing = true
    self.currentStroke = PencilStroke() // allot memory for the next/current stroke drawn
    self.nib_H = nibMat
    self.appHyperMode = appHyperMode
    
    super.init(frame: .zero)
    isUserInteractionEnabled = true
    isMultipleTouchEnabled = true // Want to do touch and pencil simultaneously
    if loadDataNeedsDisplay { // maybe not even need the Bool, since always do it on load, but later..
      drawFromStrokesData()
      loadDataNeedsDisplay = false
    }
    layer.setNeedsDisplay() // need to show the loaded data, otherwise wont show until a stroke drawn
  }
  
  var currentStroke: PencilStroke
  var rawStrokeLayers: [CALayer] = [] // when erasing the view of raw strokes that get transformed
  
  var drawingLayer: CAShapeLayer? // many get created anyway, maybe do not need this handle
  var layerCount = 0 // keep the number of draw rendered layers limited, TODO: can use layer.sublayers?.count maybe
  let layerLimit: Int = 2<<12 // flatten the rest to an image layer at a threshold
  var loadDataNeedsDisplay: Bool = true // need to grab the load data and view it but only once
  var state: DrawingState = DrawingState()
  //var fingerSelection: CGPoint = .zero
  
  
  var fingerViewOn: ((Bool) -> Void)? // handle to send for finger touch selection
  //private var touchedStrokes: Int = 0 // Let finger touch affect the strokes! Can straighten thier view based on thier bbox!
  
  var hoverViewOn: ((Bool) -> Void)? // handle to send messages up to turn on hover view, since pencil hover is SwiftUI not UIKit
  // Selected strokes will have a dashed line aound them (their bounding box)
  var sendSelectedStrokes: (([PencilStroke]) -> Void)? // send [] to erase them
  // Selected cursor will be drawn with box
  var sendCursorBox: ((CGRect?) -> Void)? // Defined in parent (MoonStrokeEditor) with instance of self
  // so I use showSelecting to send the task up the chain hierarchy
  var sendFingerPosition: ((CGPoint) -> Void)? // To show a circle or whatever
  var selectionPoint: CGPoint? {// to allow selection of areas
    didSet { // selecting a stroke or strokes happens here (at least all such route through here)
      if let sp = selectionPoint {  // indicesList only ever looked at when 's' key is pressed/held
        //comment("selectionPoint: didSet")
        indicesList = self.strokeData_H.indices(boxing: sp)
      } else {
        indicesList = []
      }
      //comment("selectionPoint: sending selected strokes up the hierarchy chain")
      self.sendSelectedStrokes?(self.selectedStrokes) // alert/callback the changes up the hierarchy chain
    }
  }
  var selectedStrokes: [PencilStroke] { // observer--keep list of selected strokes
    guard let indices = indicesList else { return [] }
    return indices.compactMap { index in
      guard index >= 0 && index < self.strokeData_H.count else { return nil }
      return self.strokeData_H.value[index]
    }
  }
  var indicesList: [Int]? // set when selectionPoint is set
  private var tempVec: [CGFloat] = Array(repeating: 0, count: NibMatrix.N) // For randomly changing nib
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func didMoveToWindow() {
    super.didMoveToWindow()
    
    guard window != nil, loadDataNeedsDisplay else { return }
    
    drawFromStrokesData()
    loadDataNeedsDisplay = false
    
//    // MARK: svd
//    // Test the svd, of all the pencil samples
//    // The following gives [[Double]] where each row is a sample
//    var allSamples = strokeData_H.value.map { $0.samples.map { $0.flat } }.flatMap { $0 }
//    // PencilSample --- x,y,t,force,azimuth,altitude,rollAngle ___c: Bias term, ___x:, ___y: position on screen, ___t: timestamp, ___force: pencil pressure (~0 to 4)
//    for i in 0..<allSamples.count {
//      allSamples[i][0] = 0 // x pos
//      allSamples[i][1] = 0 // y pos
//      allSamples[i][2] = 0 // time
//    }
//    //print("all----\n\n\(allSamples)")
//    
//    let svd = svdRows(allSamples) // The "most variance" comes from the first row
//    guard !svd.isEmpty else { return } // empty file has no data
//    let scaled = svd[0].map { $0 / svd[0][5] } // quick easy scale to unit-like
//    //print("svd \(svd)") // svd is [[Double]] with each row
//    //print("\n\nscaledeed \n\(scaled)\n")
//    let firstRow = Array(svd.prefix(NibMatrix.rowSize))
//    
//    let k = nib_H.kFor(input: scaled)
//    nib_H.setRow(4, data: ([k] + scaled).map { $0 / k })
//    //print("new nib row ")
    
  }
  
  
  // set drawsAsynchronously
  override func layoutSubviews() {
    super.layoutSubviews()
    layer.drawsAsynchronously = true
  }
  
  // TODO: maybe do an array of layers for each color maybe, or for a single possibly long stroke
  fileprivate func drawSinglePoint(_ sample: PencilSample, _ layer: CALayer) {
    // store for the (possibly) continuing stroke
    let circleLayer = CAShapeLayer()
    let (fillColor, fillSize) = nib_H.map(sample)
    //print("filel le size \(fillSize) wz \(nib_H.weights[NibMatrix.sizeIndex])")
    let rect = CGRect(center: sample.location, size: CGSize(width: fillSize, height: fillSize))
    let circlePath = UIBezierPath(ovalIn: rect)
    //let circlePath = UIBezierPath(arcCenter: sample.location, radius: fillSize, startAngle: 0, endAngle: 1.9 * .pi, clockwise: false) // change this to just ellipse in later
    circleLayer.fillColor = fillColor.cgColor
    circleLayer.path = circlePath.cgPath
    addSublayerAndCount(circleLayer)
  }
  
  
  // MARK: the chung/grouping draw
  //  override func draw(_ layer: CALayer, in ctx: CGContext) { // do not use ctx if want GPU over CPU
  //    // TODO: this uses two points at a time. Can maybe use 3 or 4 to get bezier curvature
  //    guard !self.currentStroke.isEmpty else { return }
  //    renderStroke(self.currentStroke, in: layer)
  //  }
  override func draw(_ layer: CALayer, in ctx: CGContext) { // do not use ctx if want GPU over CPU
    // TODO: this uses two points at a time. Can maybe use 3 or 4 to get bezier curvature
    //var previousSample = PencilSample()
    //let lineLayer = CAShapeLayer()
    //drawingLayer = CAShapeLayer() // just reuse the same variable, is that where the slowdown came?
    //guard let lineLayer = drawingLayer else { return }
    for stroke in strokeData_H {
      renderStroke(stroke, in: layer)
    }
    renderStroke(self.currentStroke, in: layer)
//    for ( index ,sample) in self.currentStroke.enumerated() {
//      if index == 0 {
//        previousSample = sample
//        drawSinglePoint(sample, layer)
//        continue
//      } // make sure there are two points to make the line
//      drawingLayer = CAShapeLayer() // just reuse the same variable, is that where the slowdown came?
//      guard let lineLayer = drawingLayer else { continue }
//      layerCount += 1
//      drawLinePath(from: previousSample, to: sample, lineLayer,  layer)
//      previousSample = sample
//    }
    
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
    // render live layers
    var previousSample = stroke[0]
    drawSinglePoint(previousSample, layer) // make sure there are two points to make the line
    
    for i in 1..<stroke.count {
      let sample = stroke[i]
      addSegmentLayer(from: previousSample, to: sample) // segment count is a bit weird maybe
      
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
    if state.isInputTransforming { // if tracking for later removal of rawstrokes (before a transform)
      rawStrokeLayers.append(newLayer)
    } else {// else only trigger flatten if not still tracking transform layers
      if self.layerCount > self.layerLimit {
        self.imageFlatten()
      }
    }
    
  }
  
  fileprivate func finishTransformAndDrawStroke(_ stroke: PencilStroke) {
    guard !stroke.isEmpty else { return }
    guard var _ = state.strokesTransform else { return }
    
  
    //print("Final Stroke incoming!\n\(String(describing: stroke.count))")
    
    var lastSample = stroke[0] // the first sample will be the next's last sample
    //currentTouchedStroke[0]
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
    
//    nib_H.weights = w // restore them
    
  }
}

// get strokes and append them to the self data (the append function checks quadrature distance
extension HyperView {
  func appendAndDraw(current touch: UITouch, with event: UIEvent?, drawIt: Bool) { // drawit false for hiding some transforms
    // COALESCED points can be 20+ points per frame with apple pencil
    if let event = event { // also append coalesded touches
      if let coalescedTouches = event.coalescedTouches(for: touch) {
        for ct in coalescedTouches {
          self.currentStroke.append(ct, in: self)
          if drawIt {
            //let frame = CGRect(origin: ct.location(in: self), size: .zero)
            //layer.setNeedsDisplay(frame.insetBy(dx: -20, dy: -20))
          }
        }
      }
    }
    // NOT COALESCED
    self.currentStroke.append(touch, in: self)
    if drawIt {
      let frame = CGRect(origin: touch.location(in: self), size: .zero)
//      DispatchQueue.main.async { [weak self] in // delay slight for less blocking
//        guard let self = self else { return }
        self.layer.setNeedsDisplay(frame.insetBy(dx: -20, dy: -20))
      //}
    }
  }
  func appendAs(final lastTouch: UITouch, with event: UIEvent?) {
    self.appendAndDraw(current: lastTouch, with: event, drawIt: true) // handles drawing the last coalesced touches and appends sample points
    self.strokeData_H.append(self.currentStroke) // append the full stroke of sample points to self data
    self.currentStroke = PencilStroke() // currentStroke will now be the one not yet appended so now it is empty
  }
  
  private func preRenderStroke(_ stroke: PencilStroke, atIndex index: Int, size: CGSize) {
    guard !stroke.isEmpty else { return }
    
    
    // Render stroke to image using UIGraphicsRenderer // MARK: can pass self.bounds in on main thread if needed ...
    let renderer = UIGraphicsImageRenderer(size: size) // UIView.bounds must be used from main thread only
    let image = renderer.image { ctx in
      // Set up context for stroke rendering
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
//    Task {
//      // Non-blocking, async write to actor
//      await strokeCacheActor.cache(image, for: index)
//    }
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
  
  // Does not draw until the stroke is finished since it gets aligned to the cursorBox
  func appendTo(transformed touch: UITouch, with event: UIEvent?) {
    
    appendAndDraw(current: touch, with: event, drawIt: self.state.strokesTransform?.showsRawPreview ?? false)
    self.state.strokesTransform?.append(touch, in: self)
    
    if let event = event { // also append coalesded touches
      if let coalescedTouches = event.coalescedTouches(for: touch) {
        for ct in coalescedTouches {
          appendAndDraw(current: ct, with: event, drawIt: self.state.strokesTransform?.showsRawPreview ?? false)
          self.state.strokesTransform?.append(ct, in: self)
        }
      }
    }
    
  }
  func appendAs(finalTransformed lastTouch: UITouch, with event: UIEvent?) {
    self.appendTo(transformed: lastTouch, with: event) // If stroke is still being built, the bounding box is not ready
    guard let ra = state.strokesTransform else {
      print("Touch tracking missed a step somewhere...")
      self.strokeData_H.append(currentStroke) // grab data that apparently was missed here just in case
      return
    }
    
    let finalStroke = ra.final()
    
    // ERASE the raw strokes
    rawStrokeLayers.forEach { $0.removeFromSuperlayer() }
    rawStrokeLayers.removeAll()
    
    finishTransformAndDrawStroke(finalStroke)
    strokeData_H.append(finalStroke) // append the transformed data
    currentStroke = PencilStroke()

    layer.setNeedsDisplay(finalStroke.boundingBox.rectangle.insetBy(dx: -5, dy: -5)) // TODO: this should ERASE the raw stroke!...
    //state.strokesTransform?.reset() // reset the transformer!
    
    
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
      //print("numCursor")
      state.strokesTransform = AnyTransform(RuledAlignment(position: appHyperMode.lastSqueezedPosition))
      self.state.isInputTransforming = true
    case .normStamp:
      print("norm stamp") // printContent("yay6")
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
    
    for newTouch in touches { // want to deal with multiple concurrent touch inputs--finger and pencil same time
      if state.selecting.active {
        self.selectionPoint = newTouch.location(in: self) // if the "s" key is indicating selection
        //return // then get the point of touch and just return as no drawing is taking place here
      }
//      if let _ = state.ruledAlignment {
//        self.appendTo(touched: newTouch, with: event)
//      }
      if !state.isDrawing { return }
      switch newTouch.type {
      case .pencil:
        if state.isInputTransforming { // if in transforming-stroke mode and a new pencil stroke is coming in
          self.appendTo(transformed: newTouch, with: event)
            // Don't append/display yet! Will do a cool shift-scale of the stroke!
        } else {
          self.appendAndDraw(current: newTouch, with: event, drawIt: true) // pencil draws, append it
        }
      case .direct: // Finger does not draw---"Finger Touch" began, set finger is touching and give the position
        if state.fingerPosition == nil { // only set fingerposition once
          let newFingerPosition = newTouch.location(in: self)
          state.fingerPosition = newFingerPosition
          self.fingerViewOn?(true) // Turn on the circle "highlighter/pointer"
          self.sendFingerPosition?(newFingerPosition) // send the updated position
        } else {
          
        }
      case .indirect: // "Mouse Touch"
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
		//guard let newTouch = touches.first else { return } // pencil is first one, rest is multi-touch
    for newTouch in touches { // want to deal with multiple concurrent touch inputs--finger and pencil same time
      if state.selecting.active { // selection index is nil unless the "s" key is held down
        return // then get the point of touch and just return as no drawing is taking place here
      }
      if !state.isDrawing { return }
      switch newTouch.type {
      case .pencil:
        if state.isInputTransforming {
          self.appendTo(transformed: newTouch, with: event) // pencil draws not yet, append to buffer
        } else {
          self.appendAndDraw(current: newTouch, with: event, drawIt: true) // pencil draws, append it
        }
      case .direct: // touch with finger/stylus
        let newFingerPosition = newTouch.location(in: self)
        self.sendFingerPosition?(newFingerPosition) // send the updated position
      case .indirect: // click/drag with mouse
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
    if self.state.selecting.active { // selection index is nil unless the "s" key is held down
      // "s" key do not want to draw self.selectionPoint = newTouch.location(in: self) // if the "s" key is indicating selection
      return
    }
    
    for newTouch in touches { // want to deal with multiple concurrent touch inputs--finger and pencil same time
      switch newTouch.type {
      case .pencil:
        // if relevant, get bbox before last append erases currentStroke
        if state.isInputTransforming { // if in a transforming-state stroke
          // get the bounding box of the first stroke to affect the next touched strokes...
          self.appendAs(finalTransformed: newTouch, with: event) // will draw now at the end in append function
          if let _ = state.strokesTransform { // TODO: probably want this optional unwrapping to happen in the sendCursorBox function
            sendCursorBox?(state.strokesTransform!.feedbackRect)
            if state.strokesTransform!.shouldResetBetweenStrokes {
              state.strokesTransform!.reset()
            }
          }
          state.isInputTransforming = false // turn off at end of touch...?
        } else {
          self.appendAs(final: newTouch, with: event)
        }
      case .direct: // touch with finger/stylus
        //print("TOUCH ENDED here are appNib weights: \n\n\(nib_H.weights)")
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
        state.fingerPosition = nil // turn off... should bind/wrap these together...
        self.fingerViewOn?(false) // turn off the highlighting if doing cursor strokes, regardless of which touch/finger
        if newTouch.tapCount == 1 { // single tap toggles ruledAlignment, has to be at the end not beginning (like requireToFail...)
          //print("ENDED direct start and single-tap")
//          clearLayers()
//          drawFromStrokesData() // want to refresh the screen here, to put elsewhere later maybe
          if state.isInputTransforming { // Use single tap to end a transform input, no matter how it started
            state.strokesTransform?.reset() // reset the transform
            sendCursorBox?(nil) // make sure none of its display is on
            state.isInputTransforming = false // and turn off the state
            //print("----> OFF")
          }
//          let fingerPosition = newTouch.location(in: self) // touch ended, just turn off finger position/highlighting
//          self.state.fingerPosition = fingerPosition

        } else if newTouch.tapCount == 2 {
          //print("          DOUBLE-tap")
          if !state.isInputTransforming { // if there is not a transform already
            self.state.strokesTransform = AnyTransform(StrokeToGaussian())
            if let _ = state.strokesTransform {
              state.isInputTransforming = true
              let p = newTouch.location(in: self)
              let s = CGSize(width: state.strokesTransform!.feedbackRect.width, height: state.strokesTransform!.feedbackRect.height) // use initial from transform
              state.strokesTransform!.setFeedbackRect(to: CGRect(center: p, size: s))
              sendCursorBox?(state.strokesTransform!.feedbackRect)
              //print("---->ON")
            }
          }
        }
      case .indirect: // click/drag with mouse
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
    
    // TODO: can use the further out point as a velocity measure maybe, like a tapering of the stroke
    //		if let flattenedDrawing = flattenedLayer() {
    //			self.layer.addSublayer(flattenedDrawing)
    //			debugPrint("flattened drawing")
    //		}
    if self.layerCount > self.layerLimit {
      flattenLayers()
    }
    
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    super.touchesEnded(touches, with: event)
    if state.selecting.active { // selection index is nil unless the "s" key is held down
      // "s" key do not want to draw self.selectionPoint = newTouch.location(in: self) // if the "s" key is indicating selection
      return
    }
    // TODO: here is the last point that can show some "velocity" like ....  . where the last is a bit further, use that also
    // TODO: maybe check if current stroke is empty, but that may be extra unneccessarry
    //guard let newTouch = touches.first else { return }// pencil is first one, rest is multi-touch
    for newTouch in touches { // want to deal with multiple concurrent touch inputs--finger and pencil same time
      switch newTouch.type {
      case .pencil: // Be sure to save data if cancel event
        self.appendAs(final: newTouch, with: event) // this is possibly a point further out
      case .direct: // touch with finger/stylus
        state.strokesTransform?.reset()
      case .indirect: // click/drag with mouse
        debugPrint("indirect", newTouch)
      case .indirectPointer:
        debugPrint("indirectPointer", newTouch)
      @unknown default:
        debugPrint("Unknown input type -- fatal error...")
      }
    }
  }
  
	
	func imageFlatten() {
		//comment("Saving an image...")
		// 2024.10.12.182612---Originally I thought this was necessary to do on alternate thread
		// because there seemed to be some strokes getting missed. Maybe they still are when doing
		// cursive as that maybe makes too many layers per point of long cursive strokes, but it
		// seems that at least with single stroke decimal digits that it has little problem, it
		// has some noticeable lag during fast stroke input, but nothing gets dropped. It does
		// crash after some time if actually do the global queue so that is out I guess, keep it MAIN
		//DispatchQueue.main.async { //DispatchQueue.global(qos: .userInitiated).async { //
			guard let image = self.captureViewImage() else {
				//comment("Failed to capture view image!")
				return
			}
			//DispatchQueue.main.async {
				self.clearLayers()//self.layer.sublayers?.forEach({ $0.removeFromSuperlayer() })
				self.layerCount = 0
				self.restoreViewFromImage(image)
			//}
		//}
		/*
		// to clear coule also do this:
		//self.layer.sublayers?.removeAll() // maybe this, AI ass suggested
		// or possibly this:
		//self.layer.sublayers?.forEach({ $0.removeFromSuperlayer() })
		*/
	}
  
//  func imageFlatten() {
//    guard layerCount > layerLimit else { return }
//    
//    let layersToFlatten = layer.sublayers ?? []
//    //var image: UIImage
//    
//    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
//      guard let self = self else { return }
//      
//      let renderer = UIGraphicsImageRenderer(bounds: self.bounds) //Thread 60: EXC_BAD_ACCESS (code=1, address=0x55b4ca20c084a0)
//      let image = renderer.image { ctx in
//        self.layer.render(in: ctx.cgContext)Thread 60: EXC_BAD_ACCESS (code=1, address=0x55b4ca20c084a0)
//      }
//      
//      DispatchQueue.main.async {
//        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
//        self.layerCount = 0
//        self.restoreViewFromImage(image)
//      }
//    }
//  }
  func clearStrokeCache() { // clear cache when needed
//    strokeImageCache.removeAll()
//    cachedStrokeIndices.removeAll()
    Task {
      await strokeCacheActor.clear()
    }
  }
  
  fileprivate func flattenLayers() {
    guard Thread.isMainThread else {
      DispatchQueue.main.async {self.flattenLayers() }
      return
    }
    
    //let wasHidden = rasterizedImageView?.isHidden ?? false // *main thread* as required
    rasterizedImageView?.isHidden = true
    
    let selfSize = self.layer.bounds.size // get this before sending it off main thread
    let allStrokes = strokeData_H.value + [currentStroke]

    let _ = UIGraphicsImageRenderer(bounds: self.bounds).image { context in
      
      self.layer.render(in: context.cgContext)
    }
    
    
    
    // Use a private queue for rendering
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
//    renderingQueue.async { [weak self] in
//      guard let self = self else { return }
//      
//      // BEFORE clearing layers, pre-render ALL strokes (including current stroke)
//      for (index, stroke) in allStrokes.enumerated() {
//        preRenderStroke(stroke, atIndex: index, size: selfSize)
//      }
//      
////      // 1. Ensure we actually have layers to flatten
////      guard layerCount > layerLimit else { return }
////      
////      // Ensure async draws are flushed before capture
////      CATransaction.begin()
////      CATransaction.setDisableActions(true)
////      layer.displayIfNeeded() // wait for async draw to finish
////      CATransaction.commit()
////      
//      // Use UIGraphicsImageRenderer — thread-safe for bounds-based rendering
//      
//      //Cleanup
//      
//      DispatchQueue.main.async { [weak self] in
//        guard let self = self else { return }
//        
//        
//        
//        self.rasterizedImageView?.isHidden = wasHidden
//        
//        self.rasterizedImageView?.removeFromSuperview()///////////////////////////
//        self.rasterizedImageView = nil
//        self.restoreViewFromImage(image)
//        
//        self.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
//        self.rawStrokeLayers.removeAll()
//        self.layerCount = 0
//      }
//    }
  }
  
  private func finalizeFlattening() {

//    let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
//      self.drawHierarchy(in: self.bounds, afterScreenUpdates: true)
//    }
    let image = UIGraphicsImageRenderer(bounds: bounds).image { context in
      self.layer.render(in: context.cgContext)
    }
    
    layer.sublayers?.forEach { $0.removeFromSuperlayer() }
    rawStrokeLayers.removeAll()
    layerCount = 0
    //rasterizedImageView?.removeFromSuperview()
    rasterizedImageView = nil
    //clearLayers()
    
    //CATransaction.commit()
    
    restoreViewFromImage(image)
    
  }
  
  fileprivate func clearLayers() {
    // Flush Async draw
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
  
  func captureViewImage() -> UIImage? { // was self.bounds.self.size with an extra 'self'...?
    
    if !currentStroke.isEmpty {
      // Ensure no pending async draws are in flight
      CATransaction.begin()
      CATransaction.setDisableActions(true)
      
      // Force flush of any pending async draws
      // layer.displayIfNeeded() blocks until all pending async draws complete
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
      //self.layer.render(in: context.cgContext)
    }
    

  }
  
  func restoreViewFromImage(_ image: UIImage) {
    
    rasterizedImageView?.removeFromSuperview()
    rasterizedImageView = nil
//
//    // or subviews.filter{ $0 is UIImageView }.forEach{ $0.removeFromSuperView() }
//    for view in subviews where view is UIImageView {
//      view.removeFromSuperview()
//    }
    let imageView = UIImageView(frame: self.bounds)
    imageView.image = image
    imageView.contentMode = .scaleAspectFit // or .scaleAspectFill
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
    
      // STREAM it to website for live viewing
    
    guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
          let url = URL(string: "https://aswmac.com/strokes-stream/add-stroke") else {
//          let url = URL(string: "http://192.168.0.235/strokes-stream/add-stroke") else {
      return
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = jsonData
    
    // Use a background session (or shared) - ATS disabled in Info.plist, so HTTPS works "--insecure"
    URLSession.shared.dataTask(with: request).resume()
  }
}

