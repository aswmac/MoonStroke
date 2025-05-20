//
//  CGMathExtensions.swift
//  draw line fit
//
//  Created by Adam McGregor on 2/23/18.
//  Copyright © 2018 Adam. All rights reserved.
//

/*
 Copyright (C) 2016 Apple Inc. All Rights Reserved.
 See LICENSE.txt for this sample’s licensing information
 
 Abstract:
 Math extensions to Core Graphics structs.
 */

import Foundation
import CoreGraphics

infix operator &<: MultiplicationPrecedence // floor division, custom operators begin with one of / = - + ! * % < > & | ^ ? ~
infix operator &>: MultiplicationPrecedence // floor division, custom operators begin with one of / = - + ! * % < > & | ^ ? ~
infix operator <>: MultiplicationPrecedence // floor division, custom operators begin with one of / = - + ! * % < > & | ^ ? ~

func &<(left: CGFloat, right: CGFloat) -> CGFloat {
  return min(left, right)
}

func &>(left: CGFloat, right: CGFloat) -> CGFloat {
  return max(left, right)
}

/// map (0,1) to the range given
func &<(left: CGFloat, right: (CGFloat, CGFloat)) -> CGFloat {
  let scale = right.1 - right.0
  return left*scale + right.0
}

// MARK: CGRect and Size
extension CGRect {
  var center: CGPoint {
    get {
      return origin + CGVector(dx: width, dy: height) / 2.0
    }
    set {
      origin = newValue - CGVector(dx: width, dy: height) / 2
    }
  }
}

func +(left: CGSize, right: CGFloat) -> CGSize {
  return CGSize(width: left.width + right, height: left.height + right)
}

func -(left: CGSize, right: CGFloat) -> CGSize {
  return left + (-1.0 * right)
}

func *(left: CGSize, right: CGFloat) -> CGSize {
  return CGSize(width: left.width*right, height: left.height*right)
}

// MARK: CGPoint and CGFloat math
func *(left: CGPoint, right: CGFloat) -> CGPoint {
  return CGPoint(x: left.x*right, y: left.y*right)
}

func /(left: CGPoint, right: CGFloat) -> CGPoint {
  return CGPoint(x: left.x/right, y: left.y/right)
}

// MARK: CGPoint and CGPoint math
func +(left: CGPoint, right:CGPoint) -> CGPoint {
  return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

// MARK: CGPoint and CGVector math
func -(left: CGPoint, right:CGPoint) -> CGVector {
  return CGVector(dx: left.x - right.x, dy: left.y - right.y)
}

/// Determinant or area of vectors
func <>(left: CGPoint, right:CGPoint) -> CGFloat {
  return left.x*right.y - left.y*right.x
}

func /(left: CGVector, right: CGFloat) -> CGVector {
  return CGVector(dx: left.dx/right, dy: left.dy/right)
}

func *(left: CGVector, right: CGFloat) -> CGVector {
  return CGVector(dx: left.dx*right, dy: left.dy*right)
}

func *(left: CGFloat, right: CGVector) -> CGVector {
  return CGVector(dx: left*right.dx, dy: left*right.dy)
}

func +(left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x + right.dx, y: left.y + right.dy)
}

func +(left: CGVector, right: CGPoint) -> CGPoint {
  return CGPoint(x: left.dx + right.x, y: left.dy + right.y)
}

func +(left: CGVector, right: CGVector) -> CGVector {
  return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
}

func +(left: CGVector?, right: CGVector?) -> CGVector? {
  if let left = left, let right = right {
    return CGVector(dx: left.dx + right.dx, dy: left.dy + right.dy)
  } else {
    return nil
  }
}


func -(left: CGPoint, right: CGVector) -> CGPoint {
  return CGPoint(x: left.x - right.dx, y: left.y - right.dy)
}

extension CGPoint {
  init(_ vector: CGVector) {
    self.init()
    x = vector.dx
    y = vector.dy
  }
  
  /// scale and translate from bounding box into the target box
  func fit(from b1: CGRect, to b2: CGRect) -> CGPoint {
    let scale1 = b2.width/b1.width
    let scale2 = b2.height/b1.height
    let newX = (x - b1.origin.x)*scale1 + b2.origin.x
    let newY = (y - b1.origin.y)*scale2 + b2.origin.y
    return CGPoint(x: newX, y: newY)
  }
  
  static func getAspectScale(from b1: CGRect, to b2: CGRect, maxAspectScale: CGFloat? = 2.0)
    -> (scaling: CGPoint, shifting: CGPoint, origin: CGPoint) {
      let scaleFactorX = b2.width/b1.width // ex: b1.width = 10, b1.height = 1 ---> b2.width = 10, b2.height = 10  ===> scaleFactorX = 1
      let scaleFactorY = b2.height/b1.height // scaleFactorY = 10
      var scale = CGPoint()
      var shift = CGPoint()
      if let maxScale = maxAspectScale {
        if scaleFactorX/scaleFactorY > maxScale { // limit the extremety of the scaling (default 2)
          scale.x = scaleFactorY*maxScale
          scale.y = scaleFactorY
          shift.x = (b1.width*scaleFactorX - b1.width*scale.x)/maxScale
          shift.y = 0
        } else if scaleFactorY/scaleFactorX > maxScale {
          scale.x = scaleFactorX
          scale.y = scaleFactorX*maxScale
          shift.x = 0
          shift.y = (b1.height*scaleFactorY - b1.height*scale.y)/maxScale
        } else {
          scale.x = scaleFactorX
          scale.y = scaleFactorY
          shift.x = 0
          shift.y = 0
        }
      } else {
        scale.x = scaleFactorX
        scale.y = scaleFactorY
        shift.x = 0
        shift.y = 0
      }
      return (scaling: scale, shifting: shift, origin: b2.origin)
  }
  /// scale and translate from bounding box into the target box, preserving some of the aspect ratio
  func fittingAspect(using:(scaling: CGPoint, shifting: CGPoint, origin: CGPoint)) -> CGPoint {
    let newX = (x - using.origin.x)*using.scaling.x + using.shifting.x
    let newY = (y - using.origin.y)*using.scaling.y + using.shifting.y
    return CGPoint(x: newX, y: newY)
  }
}

extension CGVector {
  init(_ point: CGPoint) {
    self.init()
    dx = point.x
    dy = point.y
  }
  
  func apply(transform:CGAffineTransform) -> CGVector {
    return CGVector(CGPoint(self).applying(transform))
  }
  
  func round(toScale scale: CGFloat) -> CGVector {
    return CGVector(dx: CoreGraphics.round(dx * scale) / scale,
                    dy: CoreGraphics.round(dy * scale) / scale)
  }
  
  var quadrance: CGFloat {
    return dx*dx + dy*dy;
  }
  
  var magnitude: CGFloat {
    return sqrt(dx*dx + dy*dy)
  }
  
  var normal: CGVector? {
    if !(dx.isZero && dy.isZero) {
      return CGVector(dx: -dy, dy: dx)
    } else {
      return nil
    }
  }
  
  /// CGVector pointing in the same direction as self, with a length of 1.0 - or nil if the length is zero.
  var normalize: CGVector? {
    let quadrance = self.quadrance
    if quadrance > 0.0 {
      return self / sqrt(quadrance)
    } else {
      return nil
    }
  }
}


