//
//  StatsGraphics.swift
//  MoonStroke
//
//  Created on 7/1/26.
//
import UIKit

/// Generates a vector of `CGPoint`s forming a Gaussian curve within the same bounding box as input stroke
/// changing the location of the points to represent a normal curve
/// preserving the count and other properties of the sample input points
/// - Parameters:
///   - stroke: Original pencil stroke
/// - Returns: `PencilStroke of x-uniform samples of the normal distribution, scaled to fit the box.
func generateGaussianPoints(_ stroke: PencilStroke) -> PencilStroke {
  let count = stroke.count
  let box = stroke.boundingBox.rectangle
  var newStroke = PencilStroke()
  
  precondition(count >= 2, "At least 2 points required to form a curve.")
  
  // Use default sigma = 1/6 width → so [-2.5σ, 2.5σ] spans ~5/6 of width (leaving margins)
  let σ = box.width / 6.0
  
  let meanX = box.origin.x + box.width / 2.0  // center of box
  
  let startX = meanX - 2.5 * σ
  let endX = meanX + 2.5 * σ
  let stepX = (endX - startX) / CGFloat(count - 1)
  
  // Gaussian peak height (y = 1 at mean), scaled to fit box height from bottom
  // We map y=0 → bottom of box, y=1 → top of box (inverted for UIKit coords)
  let boxBottom = box.maxY
  //let boxTop = box.minY
  let boxHeight = box.height
  
  newStroke.reserveCapacity(count)// prepare memory for the following
  
//  return (0 ..< count).map { i in
  for i in 0 ..< count {
    let x = startX + CGFloat(i) * stepX
    // Standard normal PDF: (1/(σ√(2π))) * exp(-0.5 * ((x-μ)/σ)^2)
    let z = (x - meanX) / σ
    let gaussianY = exp(-0.5 * z * z) / (σ * sqrt(2 * .pi)) // raw PDF height at x
    // Normalize to fit: scale max to box height, then offset to start from bottom
    // Since PDF peaks at (μ) = 1/(σ√(2π)), use that to scale:
    let peakValue = 1.0 / (σ * sqrt(2 * .pi))
    let normalizedY = gaussianY / peakValue  // now in [0, 1]
    let y = boxBottom - normalizedY * boxHeight  // UIKit: y=0 at top, so subtract from bottom
    
    var point:PencilSample = stroke[i]
    point.location.x = x
    point.location.y = y
    newStroke.append(sample: point)
  }
  
  return newStroke
}

struct IntervalStrapped {
  var interval = Interval(left: 0,right: 0, closedLeft: false, closedRight: false)
  var data: [Double] = []
  
  var binCount: Int = 10
  
  mutating func append(_ x: Double) {
    self.interval.append(x) // append on interval just extends bounds if necessary
    self.data.append(x)
  }
  
}

// MARK: Interval
// TODO: add some bins to count new points appended and end up with a frequency chart
// TODO: dare (?) to consider multi-dimensional numbers (probably 
struct Interval {
  var left: Double // left bound ::::-- cases: defined (number/infinity) and nil
  var right: Double // right bound
  var closedLeft: Bool // inclusive(or not) for left bound
  var closedRight: Bool // inclusive(or not) for right bound
  var midpoint: Double {
    return (left + right) / 2
  }
  var count = 0
  
  
  init(left: Double, right:Double, closedLeft: Bool = true, closedRight: Bool = true) {
    count = 2
    assert(right >= left)
    self.left = left
    self.right = right
    self.closedLeft = closedLeft
    self.closedRight = closedRight
  }
  
  // extend interval to include a new point
  mutating func append(_ new: Double) {
    if !closedLeft && !closedRight { // we are starting new here
      left = new
      right = new
      closedLeft = true
      closedRight = true
      count = 2
      return
    }
    if new < left {
      left = new
      closedLeft = true // redundant here if used initial of both ends open
      count = count + 1
    }
    else if new > right {
      right = new
      closedRight = true
      count = count + 1
    }
  }
  
  mutating func extendLeft(factor: Double = 2.0, hop: Bool = false) {
    let newLeft = factor*(left - right) + right // shift right to zero, scale new left, shift back
    guard newLeft <= right else { return } // preserve left <= right
    if hop {
      let newRight = left
      if newLeft <= newRight {
        left = newLeft
        right = newRight
        return
      }
      // let a bad hop (never happen but just do it) be no hop
    }
    left = newLeft
    return
  }
  
  mutating func extendRight(factor: Double = 2.0, hop: Bool = false) {
    let newRight = factor*(right - left) + left // shift left to zero, scale new right, shift back
    guard left <= newRight else { return }
    if hop {
      let newLeft = right
      if newLeft <= newRight {
        left = newLeft
        right = newRight
        return
      }
      // let a bad hop (never happen but just do it) be no hop
    }
    right = newRight
    return
  }
  
  mutating func trimNew(right: Double) {
    if right >= left { self.right = right }
  }
  
  mutating func trimNew(left: Double) {
    if left <= right { self.left = left }
  }
  
}
