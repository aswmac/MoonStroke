//
//  Transforms.swift
//  MoonStroke
//
//  Created on 7/5/26.
//

import UIKit

protocol TransformPointsProtocol {
  
  var showsRawPreview: Bool { get }
  var shouldResetBetweenStrokes: Bool { get }
  var feedbackRect: CGRect { get }
  mutating func append(_ : UITouch, in: UIView)
  mutating func final() -> PencilStroke
  mutating func reset()
  
  mutating func setFeedbackRect(to newRect: CGRect)
}

// type-erased wrapper to use "Any..."
class AnyTransform: TransformPointsProtocol {
  
  
  private var _base: TransformPointsProtocol
  
  var showsRawPreview: Bool { _base.showsRawPreview }
  var shouldResetBetweenStrokes: Bool { _base.shouldResetBetweenStrokes }
  var feedbackRect: CGRect { _base.feedbackRect }
  
  init<T: TransformPointsProtocol>(_ base: T) {
    _base = base
    
  }
  //mutating
  func append(_ touch: UITouch, in w: UIView) {
    _base.append(touch, in: w)
  }
  
  //mutating
  func setFeedbackRect(to rect: CGRect) {
    var baseCopy = _base
    baseCopy.setFeedbackRect(to: rect)
    _base = baseCopy
  }
  
  //mutating
  func final() -> PencilStroke {
    var baseCopy = _base
    let result = baseCopy.final()
    _base = baseCopy
    return result
  }
  //mutating
  func reset() {
    var baseCopy = _base
    baseCopy.reset()
    _base = baseCopy
  }
  
}

struct DrawingState {
  var isHovering: Bool = false
  var isDrawing: Bool = true
  struct Selecting {
    var active: Bool = false
  }
  var selecting = Selecting()
  
  var isInputTransforming: Bool = false // is the strokesTransform taking input
  var strokesTransform: AnyTransform? = nil
  
  var fingerPosition: CGPoint? = nil
}

struct StrokeToGaussian: TransformPointsProtocol {
  let shouldResetBetweenStrokes: Bool = true
  
  mutating func setFeedbackRect(to newRect: CGRect) {
    self.feedbackRect = newRect
  }
  
  var showsRawPreview: Bool { true }
  
  var feedbackRect: CGRect = CGRect(x: 250, y: 250, width: 30, height: 10) // initialize
  
  var stroke: PencilStroke = PencilStroke() // to store
  
  mutating func append(_ touch: UITouch, in yo: UIView) {
    stroke.append(touch, in: yo)
  }
  
  mutating func final() -> PencilStroke {
    return generateGaussianPoints(stroke)
  }
  
  mutating func reset() {
    //print("Gausses resets")
    stroke = PencilStroke()
  }
  
}

struct fitVariance: TransformPointsProtocol {
  let shouldResetBetweenStrokes: Bool = true
  
  var appNib: NibMatrix
  let showsRawPreview: Bool = false
  
  let feedbackRect: CGRect = .zero
  
  var samples: [PencilSample] = [] // store pencilsamples to iterate
  var results: [Double] = [] // iterate space here
  
  mutating func append(_ touch: UITouch, in yo: UIView) {
    let sample = PencilSample(touch, in: yo)
    self.samples.append(sample)
    let (_, s) = appNib.map(sample)
    self.results.append(s)
  }
  
  // function on scale to iterate (looking for the middle output of the sigmoid iterating only on input to it)
  func scaledOutput(_ x: Double) -> Double {
    var s: Double = 0.0
    for i in 0..<self.samples.count {
      s += appNib.map(self.samples[i].scaled(by: x)).1 // the width result of map
    }
    return s/Double(self.samples.count)
  }
  
  mutating func final() -> PencilStroke {
    
    if let bestScale = iterate(function: scaledOutput, for: 4.5) { // size range is (1,8) so mid is 4.5
      print("Best scale \(bestScale)")
      return PencilStroke(samples.map{ $0.scaled(by: bestScale)})
    } else {
      print("No besty")
      return PencilStroke(samples)
    }
  }
  
  mutating func reset() {
    print("RESETTEDED")
    self.samples = []
    self.results = []
  }
  
  mutating func setFeedbackRect(to newRect: CGRect) {
    return
  }
  
  
}

struct RuledAlignment: TransformPointsProtocol {
  let shouldResetBetweenStrokes: Bool = false
  
  
  var inputStroke: PencilStroke = PencilStroke()
  
  var position: CGPoint // = CGPoint(x: 200.0, y: 250.0)
  
  var cursorWidth: CGFloat = 25.0
  var cursorHeight: CGFloat = 40.0
  var boundingBox: CGRect {
    return CGRect(center: position, size: CGSize(width: cursorWidth, height: cursorHeight))
  }
  var lineHeight: CGFloat = 50.0
  var interStrokeSpacing: CGFloat = 5.0 // 0.25 times width
  //var touchBase: UITouch // set alignment based on only the particular finger-touch
  struct CursorCount {
    var x: Int = 0
    var y: Int = 0
  }
  
  var cursorCount = CursorCount(x: 0, y: 0)
  var xCount: Int = 0
  
  var cursorBox: CGRect {
    //print("Cursor width \(cursorWidth)")
    //print("    Interstroke spacing \(interStrokeSpacing)")
    //print("               cursor count x \(cursorCount.x)")
    let x_offset = CGFloat(xCount)*(cursorWidth + interStrokeSpacing)
    let y_offset = CGFloat(cursorCount.y)*lineHeight
    //print("           Offset (\(x_offset), \(y_offset))")
    return boundingBox.offsetBy(dx: x_offset, dy: y_offset)
  }
  
  var showsRawPreview: Bool { return false }
  
  var feedbackRect: CGRect {
    //print("Getter----------------\(cursorBox)")
    return cursorBox
  }
  
  mutating func setFeedbackRect(to newRect: CGRect) {
    position = newRect.center
    cursorWidth = newRect.width
    cursorHeight = newRect.height
  }
  
  // Append the sample to the stroke
  mutating func append(_ touch: UITouch, in w: UIView) {
    let newSample = PencilSample(touch, in: w)
    inputStroke.append(sample: newSample)
  }
  
  
  // finalize the stroke
  mutating func final() -> PencilStroke {

    var newStroke = PencilStroke()
    //print("input \(inputStroke.boundingBox.rectangle)")
    //print("fitting---\(cursorBox)")
    for i in 0..<inputStroke.count {
      var sample = inputStroke[i]
      sample.location = sample.location.fit(from: inputStroke.boundingBox.rectangle, to: cursorBox)
      newStroke.append(sample: sample) // the
      //addSegmentLayer(from: lastSample, to: sample, segmentCount: 0)
    }
    xCount += 1 // increment for the next stroke
    inputStroke = PencilStroke() // Reset the input!
    //print("                                                ccx \(cursorCount.x)")
    //print("output \(newStroke.boundingBox.rectangle)")
    return newStroke
  }
  
  mutating func reset() {
    //cursorCount.x = 0
    //cursorCount.y = 0
    inputStroke = PencilStroke()
    // keep touchbase and position since they are used for the starting point of the count
  }
  
  

}
