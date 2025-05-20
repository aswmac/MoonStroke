import SwiftUI

final class NibMatrix {
	var weights: [CGFloat]
	let colSize = PencilSample.N + 1 // each row has a constant first
	static let outputCount: Int = 5 // define in one place to keep all things consistent TODO: put the 5 static let at place that reads it
	// MARK: shape is one by two---pencil sample size and outputcount
	static let N = (1 + PencilSample.N)*outputCount	// input is 7 elements from PencilSample (plus one bias),
																									// and 5 outputs of RGBA-color and strokeSize
	private var complement: Bool = false
	//var shiftVector: [CGFloat]
	
	init(_ weights: [CGFloat]) {
		assert(weights.count == NibMatrix.N) //
		//assert(constants.count == 5)
		
		//self.shiftVector = constants
		self.weights = weights
	}
	
	func index(row: Int, column: Int) -> Int {
		row * colSize + column
	}
	
	subscript(row: Int, column: Int) -> CGFloat {
		self.weights[self.index(row: row, column: column)]
	}
//	var flatWeights: [CGFloat] {
//		get {
//			return self.tensorWeights // + self.shiftVector
//		}
//	}
	
	init(flat weghts: [CGFloat]) {
		assert(weghts.count == NibMatrix.N)
		self.weights = Array(weghts[0..<NibMatrix.N])
		//self.shiftVector = Array(weghts[20..<25])
	}
	
	init() {
		let randVector = (0..<NibMatrix.N).map { _ in
			CGFloat.random(in: 0...1)
		}
		self.weights = Array(randVector)
		//self.shiftVector = Array(randVector[20..<25])
	}
	
	// basically a sanity check here, see the changes
	func invert() {
		self.complement.toggle()
//		for i in 0..<NibMatrix.N {
//			self.weights[i] = 1.0 - self.weights[i] // TODO: force would invert differently. This is like binary invert, or (0,1) range
//		}
	}
	
	// just a reglar dot product
	private func dot(_ input: [CGFloat], _ input2: ArraySlice<CGFloat>) -> CGFloat {
		//return zip(input, self.tensorWeights).reduce(0) { $0 + $1.0.0 * $1.1.0 } // "autocomplete" suggested this
		return zip(input, input2).map(*).reduce(0, +) // GPT gave this 2024.09.27.084926
	}
	
	// MARK: just a matrix multiply: outputs = M*v + c where M and c is this NibMatrix Transform Function, c is index 0 on inputs
	private func predict(_ input: [CGFloat]) -> [CGFloat] { // call it predict just to match wording with nueral network terminology
		var outputs = [CGFloat](repeating: 0.0, count: NibMatrix.outputCount) // setup the output vector size
		// shape of the output --- colorRed, colorGreen, colorBlue, colorAlpha, strokeSize
		for i in 0..<NibMatrix.outputCount { // for each row
			let start = PencilSample.N*i // get the start index for i-th the row
			let w = self.weights[start..<(start + PencilSample.N)] // get the i-th row
			outputs[i] = dot([1.0] + input, w) // input first is always the 1 for bias
		}
		//let scale = outputs.prefix(4).max() ?? 0 // max of the first 4 elements
		for i in 0..<4 { // scale the RGBA outputs to keep them at range 0 to 1
			outputs[i] = max(0,min(outputs[i], 1.0)) // clip in range 0 to 1 for the colors
		}
		
		return outputs
		
	}
	
	
	func map(_ ps: PencilSample) -> (UIColor, CGFloat) {
		let parameters = self.predict(ps.flat_0_1)
		let cRed = parameters[0]
		let cGreen = parameters[1]
		let cBlue = parameters[2]
		let cAlpha = parameters[3]
		let cSize = parameters[4] // (1.0 - tvSize.dot(with: ps, and: -0.0625))*16 = 1 - 16*dot

		let color: UIColor
		if complement {
			color = UIColor(red: 1.0 - cRed, green: 1.0 - cGreen, blue: 1.0 - cBlue, alpha: cAlpha)
		} else {
			color = UIColor(red: cRed, green: cGreen, blue: cBlue, alpha: cAlpha)
		}

		//let sSize = CGSize(width: cSize, height: cSize)
		//var pointSquare = CGRect(origin: ps.location, size: sSize)
		//pointSquare.center = ps.location
		//let dLine = UIBezierPath(ovalIn: pointSquare)
		
		return (color, cSize)
	}
	
	func increase(row: Int, col: Int, del: CGFloat) {
		//let sizeRow = self.sizeIndex // TODO: set up names for indexing to get at them easier
		let index = self.index(row: row, column: col)
		debugPrint("increasing size weight[\(index)] from \(self.weights[index])", terminator: "")
		self.weights[index] += del // size row index is 4: 0,1,2,3 is RGBA then size, force is index 4: constant,x,y,t,force,az,alt,r
		debugPrint(" to \(self.weights[index])", terminator: "\n")
	}
	
	func reset() {
		self.weights = NibMatrix.vecRed + NibMatrix.vecGreen + NibMatrix.vecBlue + NibMatrix.vecAlpha + NibMatrix.vecSize
	}
	
}

// The constants to feed into matrix transform that gives a function from pencil-sample input to size and color output
extension NibMatrix {
	static let vecRed: [CGFloat] =   [0.0, 0.0, 0.0, 0.0, 0.75, 0.0, 0.0, 0.25] // c,x,y,t,force,azimuth,altitude,rollAngle
	static let vecGreen: [CGFloat] = [0.0, 0.0, 0.0, 0.0, 0.67, 0.0, 0.0, 0.33]
	static let vecBlue: [CGFloat] =  [0.0, 0.0, 0.0, 0.0, 0.3,  0.0, 0.0, 0.7]
	static let vecAlpha: [CGFloat] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0]
	static let vecSize: [CGFloat] =  [4.0, 0.0, 0.0, 0.0, 3.0,  2.0, -1.0, 1.0] // 1, x, y, t, f, azmth, alttd, roll
	
	static var standard: NibMatrix { // make it var to be able to alter the weights
		let nibMat = NibMatrix(vecRed + vecGreen + vecBlue + vecAlpha + vecSize)
		return nibMat
	}
	
	static var standard0: NibMatrix { // nice purple with reddish brights, thickness seems to max at only 2 or 3 points in size
		//let vecConstant: [CGFloat] = [0.0, 0.0, 0.0, 0.0, -1.0]
		
		let nibMat = NibMatrix(vecRed + vecGreen + vecBlue + vecAlpha + vecSize)
		
		return nibMat
	}
	
}
