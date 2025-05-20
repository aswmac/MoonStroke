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


// shape, size, and color for the draw() method, variable down to the point
enum Tool: Hashable {
  case pen
  case eraser
  case compass
	case classify
  
  var descriptiveImage: Image {
    switch self {
    case .pen:
      return Image(systemName: "pencil")
    case .eraser:
      return Image(systemName: "eraser.fill")
    case .compass:
      return Image(systemName: "compass.drawing")
		case .classify:
			return Image(systemName: "plus.square.dashed")
		}
  }
  
  var descriptiveShape: any Shape {
    switch self {
    case .pen:
      return Circle()
    case .eraser:
      return Circle()
    case .compass:
      return Circle()
		case .classify:
			return Circle()
		}
  }
}
