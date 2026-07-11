// TODO: this is for having different styles of display, accounting for
// TODO:    all data like position, azimuth, altitude, force, roll, timestamp (any others?)
/*
 ps sample = PencilSample(location: (581.0, 241.0), timestamp: 89719.04900216666, force: 0.5348827362060546, azimuth: 0.40463702281448216, altitude: 1.014628724255834, rollAngle: -0.659942626953125)"
 "
 
 location (values have*.0 or *.5 probably a ipad 1 vs "double" resolution type thing
 timestamp
 force, azimuth, altitude, rollAngle
 
 Basically want a dot product, or entire matrix transform, of these to give function
 of rgba color result, and size
 */

import SwiftUI // for Image type
import Observation // already in SwiftUI I think, for the @Observable


// shape, size, and color for the draw() method, variable down to the point
@Observable
final class HyperMode {
  static func == (lhs: HyperMode, rhs: HyperMode) -> Bool {
    return lhs.type == rhs.type
  }
  
  var type: HyperModeType = .pen
  // Hook for external observation
  var onTypeChanged: ((HyperModeType) -> Void)?
  
  var lastSqueezedPosition: CGPoint = .zero
  
  init(type: HyperModeType) {
    self.type = type
  }
  
  init(type: HyperModeType, onTypeChanged: ((HyperModeType) -> Void)? = nil) {
    self.type = type
    self.onTypeChanged = onTypeChanged
  }
  
  // when changing typ fire notification through hook onTypeChanged(_)
  func set(type newType: HyperModeType) {
    guard self.type != newType else { return }
    self.type = newType
    onTypeChanged?(newType) // NOTIFY the subscribers
  }
}


enum HyperModeType: Hashable {
  case pen // just the normal mode, could be "none", could be "normal"
  case eraser // could be whole vs portion
  case invert // invert the colors, r -> 1 -r etc rgb, not alpha
  case compass // thinking of getting distance measurements on the screeen
  case classify // more like select
  case numCursor //(position: CGPoint) // for the ruledAlignment transform, straight-line single stroke boxing/placing
  case normStamp // for the strokeToGaussian's generate gaussian (normal distribution curve) points from stroke
  case sineWave
  case timeLapse // replay the page's strokes
  case snapToTip // if close to a stroke start, snap to that point (probably want for only straight lines? maybe can put small shift for whatever input?)
  case gauge
  case mean
  case plus
  case minus
  case widthPlus
  case widthMinus
  case fitSize
  case equalizeColor
  
  var descriptiveImage: Image {
    switch self {
    case .pen:
      return Image(systemName: "pencil.circle")
    case .invert:
      return Image(systemName: "pencil.circle.fill")
    case .eraser:
      return Image(systemName: "eraser.fill")
    case .compass:
      return Image(systemName: "compass.drawing")
    case .classify:
      return Image(systemName: "plus.square.dashed")
    case .numCursor:
      return Image(systemName: "number")
    case .normStamp:
      return Image(systemName: "pencil.and.ruler")
    case .sineWave:
      return Image(systemName: "alternatingcurrent")
    case .timeLapse:
      return Image(systemName: "timelapse")
    case .snapToTip:
      return Image(systemName: "dot.circle.and.cursorarrow")
    case .gauge:
      return Image(systemName: "gauge.with.needle.fill")
    case .mean:
      return Image(systemName: "sum")
    case .plus:
      return Image(systemName: "plus")
    case .minus:
      return Image(systemName: "minus")
    case .widthPlus:
      return Image(systemName: "arrowshape.left.arrowshape.right.fill")
    case .widthMinus:
      return Image(systemName: "arrowshape.left.arrowshape.right")
    case .fitSize:
      return Image(systemName: "square.resize")
    case .equalizeColor:
      return Image(systemName: "equal")
    }
  }
}

// want to be able to use the list of complete types in the menu without forgetting to add cases
// cannot do any associated types if want all cases automatically accounted for...
extension HyperModeType: CaseIterable {
//  static var allCases: [HyperModeType] {
//    switch self {
//    case pen:
//      
//    }
//  }
  
  
}
