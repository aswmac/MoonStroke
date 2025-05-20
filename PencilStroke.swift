import SwiftUI

/// The pencil samples that were created together with a single stroke input of the pencil
struct PencilStroke {
  //var nib: Nib = Nib.default
	static let qDist: CGFloat = 2.0 // the quadrance distance for determining unique point
  var samples:[PencilSample] // the array to hold all the samples in the stroke
  //var date: Date
	var boundingBox = StrokeBoxer() // make it optional so that when loading can see it is needed to update
	
  //var lastPredictedSample: PencilSample? // want to hold only the latest prediction value
  //var mutablePath: CGMutablePath?
  subscript(index: Int) -> PencilSample {
    get {
      return samples[index]
    }
    set {
      if index >= 0 && index < samples.count {
        samples[index] = newValue
      }
    }
  }
  func enumerated() -> EnumeratedSequence<[PencilSample]> { return self.samples.enumerated() }
  var count: Int { return samples.count }
  var last: PencilSample? { return samples.last }
  
	mutating func update() {
		self.boundingBox = StrokeBoxer(samples)
	}
	
  init() {
    samples = []
		boundingBox = StrokeBoxer()
  }
  init(sample: PencilSample) {
    samples = [sample]
		boundingBox = StrokeBoxer(samples) // build/get the statistics for the samples
  }
	// keep track of bounding box as new samples are appended
  mutating func append(sample: PencilSample) {
    if let last = samples.last {
			if (last.location - sample.location).quadrance < PencilStroke.qDist {
				// TODO: add and replace if force or angle(width)is greater
				// TODO: or add a time duration element to the struct strokePoint
        return
      }
			
    }
		boundingBox.update(with: sample, at: samples.count) // update the bounding box properties
    samples.append(sample)
  }
  mutating func append(_ newTouch: UITouch, in view: UIView) {
		let newSample = PencilSample(newTouch, in: view)
    
		self.append(sample: newSample)
    //dataToDrawIndex.append(touchesData.count - 1) // mark it as not drawn
//    if let touchIndex = newTouch.estimationUpdateIndex {
//      dataToUpdate[touchIndex] = touchesData.count - 1
//    }
//    let frame = CGRect(origin: newTouch.location(in: self), size: .zero)
//    setNeedsDisplay(frame.insetBy(dx: -40, dy: -40)) // negative number on an inset works?
  }

  /// x coordinate is stroke angle of change, y coordinate is the sum of the distance changes
  func diffieTheta() -> PencilStroke {
    var diffieT = PencilStroke()
    if self.count <= 1 { return diffieT } // need at least two to make a difference result
    var distanceCount: CGFloat = 0.0
    for i in 1..<self.count {
      let s = self[i]
      let sPrevious = self[i - 1]
      let diffX = s.location.x - sPrevious.location.x
      let diffY = s.location.y - sPrevious.location.y
      var diffData = PencilSample(s) // copy, to be altered next
      diffData.location.x = atan2(diffY, diffX) // let x hold the angle between each point
      distanceCount += hypot(diffX, diffY)
      diffData.location.y = distanceCount // y will hold the arclength
      // the rest of the data just keep from copy directly
      //if i == 1 { diffData.previousLocation = CGPoint() } // TODO: decide if use previous location
      //else { diffData.previousLocation = diffieT.last!.location } // TODO: need to do this?
      diffieT.append(sample: diffData)
    }
    return diffieT
  }
  
  func recognize() -> Character {
    return "0"
  }
  func integralTheta() -> PencilStroke { // TODO: move this to StrokeBounds--rename maybe StrokeStats
    var diffieT = PencilStroke()
    if self.count == 0 { return diffieT } // need at least two to make a difference result
    //var distanceCount: CGFloat = 0.0
    let firstSample = PencilSample()
    //firstSample.location.y = self.first!.location.y // going to be zero anywayy
    diffieT.append(sample: firstSample)
    for i in 0..<self.count {
      let s = self[i]
      let r: CGFloat
      if i > 0 {
        let sPrevious = self[i - 1]
        r = s.location.y - sPrevious.location.y
      } else {
        r = s.location.y
      }
      let diffX: CGFloat = r*cos(s.location.x)
      let diffY: CGFloat = r*sin(s.location.x)
      var diffData = PencilSample(s) // copy, to be altered next
      diffData.location.x = diffieT.last!.location.x + diffX
      diffData.location.y = diffieT.last!.location.y + diffY
      // the rest of the data just keep from copy directly
      //diffData.previousLocation = diffieT.last!.location
      diffieT.append(sample: diffData)
    }
    return diffieT
  }
}

extension PencilStroke: Codable {
	enum CodingKeys: String, CodingKey { // Specify which elements to encode
		case samples
		// do not encode bb as it is mostly a computed property really
	}
}

extension PencilStroke: Sequence {
	func makeIterator() -> AnyIterator<PencilSample> {
		var iteratorCount = 0
		return AnyIterator{
			if iteratorCount < samples.count {
				iteratorCount += 1
				return samples[iteratorCount - 1]
			}
			return nil
		}
	}
}
