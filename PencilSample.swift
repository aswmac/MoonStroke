import SwiftUI

struct PencilSample: Codable {
	
	static let N = 7 // the size of the flat_0_1, or other full dimension array
	
  var location: CGPoint // x and y
  var timestamp: TimeInterval // t
  var force: CGFloat // 0,0,0,force, asimuth, altitude, rollAngle weights
  var azimuth: CGFloat  // -.pi -> .pi where
  var altitude: CGFloat // 0 -> .pi/2 -- realistically 0.25 -> 1.5
  var rollAngle: CGFloat // -.pi -> .pi where zero has pencil-flat up top
	
//	enum CodingKeys: String, CodingKey { // do not need to explicitly do this for Codable, but here it is for reference
//		case location
//		case timestamp
//		case force
//		case azimuth
//		case altitude
//		case rollAngle
//	}
	
	
	var flat_0_1: [CGFloat] {
		return [location.x, // TODO: to norm position to 0-1 would require at least the full stroke bounding box...
						location.y,
						timestamp,
						force,
						norm_0_1_azimuth(azimuth),
						norm_0_1_altitude(altitude),
						norm_0_1_rollAngle(rollAngle)]
	}
  
//  var zero: PencilSample { // TODO: where would this go, do I want it? Is this how it would be done to have .zero return what I want
//    return PencilSample() // maybe @inlinable public static var zero
//  }
  
  
  init() {
    self.location = .zero
    self.timestamp = TimeInterval()
    self.force = .zero
    self.azimuth = .zero
    self.altitude = .zero
    self.rollAngle = .zero
  }
  
  init( _ newTouch: UITouch, in view: UIView) {
    location = newTouch.location(in: view)
    timestamp = newTouch.timestamp
    force = newTouch.force
    azimuth = newTouch.azimuthAngle(in: view)
    altitude = newTouch.altitudeAngle
    rollAngle = newTouch.rollAngle
  }
  // copy constructor
  init(_ copy: PencilSample) {
    location = copy.location
    timestamp = copy.timestamp
    force = copy.force
    azimuth = copy.azimuth
    altitude = copy.altitude
    rollAngle = copy.rollAngle
  }
	
	// function to map roll angle to the range (0,1)
	func norm_0_1_azimuth(_ x: CGFloat) -> CGFloat {
		let zo = (x + .pi) / (2 * .pi)
		if zo < 0 || zo > 1 {
			debugPrint("norm_0_1_azimuth(\(x)) -> \(zo)")
		}
		return zo
	}
	
	// function to map altitude to the range (0,1)
	func norm_0_1_altitude(_ x: CGFloat) -> CGFloat {
		let zo = x*2.0 / .pi // .truncatingRemainder(dividingBy: .pi) // Instance member 'truncatingRemainder' cannot be used on type 'CGFloat'
		if zo < 0 || zo > 1 {
			debugPrint("norm_0_1_altitude(\(x)) -> \(zo)")
		}
		return zo
	}
	
	// function to map roll angle to the range (0,1)
	func norm_0_1_rollAngle(_ x: CGFloat) -> CGFloat {
		let zo = (x + .pi) / (2 * .pi)
		if zo < 0 || zo > 1 {
			debugPrint("norm_0_1_rollAngle(\(x)) -> \(zo)")
		}
		return zo
	}
	
	
}
