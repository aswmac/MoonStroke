import SwiftUI
import Accelerate // vDSP_mmul
//import Foundation //

@Observable
final class NibMatrix {
  // c,x,y,t,force,azimuth,altitude,rollAngle ___c: Bias term, ___x:, ___y: position on screen, ___t: timestamp, ___force: pencil pressure (~0 to 4)
  static let rowSize = PencilSample.N + 1 // all inputs from pencil sample plus a bias term, rowSize === stride
  static let colSize = 5 // 4 (RGBA) colors then a size result
  static let N = rowSize*colSize // stride*outputCount -- input is 7 elements from PencilSample (plus one bias),
  static let biasColIndex = 0
  static let xColIndex = 1
  static let yColIndex = 2
  static let timeColIndex = 3
  static let forceColIndex = 4
  static let azimuthColIndex = 5
  static let altitudeColIndex = 6
  static let rollAngleColIndex = 7
  static let redRowStartIndex = rowSize*0 //
  static let redRowIndices = NibMatrix.redRowStartIndex..<NibMatrix.redRowStartIndex + NibMatrix.rowSize
  static let greenRowStartIndex = rowSize*1 //
  static let greenRowIndices = NibMatrix.greenRowStartIndex..<NibMatrix.greenRowStartIndex + NibMatrix.rowSize
  static let blueRowStartIndex = rowSize*2 //
  static let blueRowIndices = NibMatrix.blueRowStartIndex..<NibMatrix.blueRowStartIndex + NibMatrix.rowSize
  static let alphaRowStartIndex = rowSize*3 //
  static let alphaRowIndices = NibMatrix.alphaRowStartIndex..<NibMatrix.alphaRowStartIndex + NibMatrix.rowSize
  static let sizeRowStartIndex = rowSize*4 //
  static let sizeRowIndices = NibMatrix.sizeRowStartIndex..<NibMatrix.sizeRowStartIndex + NibMatrix.rowSize
  
  var selectedSize: Double = 1.5 //
  var selectedRed: Double = 0.3 //
  var selectedGreen: Double = 0.67 //
  var selectedBlue: Double = 0.75 //
  var selectedAlpha: Double = 1.0 //
  
  var weights: [Double] {
    didSet {
      //print("I see them \(self.weights)")
    }
  }
  let strideCount = NibMatrix.rowSize // each row has a constant first
  static let outputCount = NibMatrix.colSize // define in one place to keep all things consistent TODO: put the 5 static let at place that reads it
  // MARK: shape is one by two---pencil sample size and outputcount
  
  // and 5 outputs of RGBA-color and strokeSize
  private var complement: Bool = false
  //var shiftVector: [CGFloat]
  
  init(_ weights: [Double]) {
    assert(weights.count == NibMatrix.N) //
    //assert(constants.count == 5)
    
    //self.shiftVector = constants
    self.weights = weights
  }
  
  init(flat weights: [Double]) {
    assert(weights.count == NibMatrix.N)
    self.weights = Array(weights[0..<NibMatrix.N])
    //self.shiftVector = Array(weghts[20..<25])
  }
  
  func index(row: Int, column: Int) -> Int {
    row*strideCount + column
  }
  
  subscript(row: Int, column: Int) -> Double {
    self.weights[self.index(row: row, column: column)]
  }
  
  // basically a sanity check here, see the changes
  func invert() {
    self.complement.toggle()
    //		for i in 0..<NibMatrix.N {
    //			self.weights[i] = 1.0 - self.weights[i] // TODO: force would invert differently. This is like binary invert, or (0,1) range
    //		}
  }
  func unInvert() { // "or reset to normal"
    self.complement = false
  }
  
  /// Returns updated nib weights with the color output adjusted to match the given `selectedColor`,
  /// while preserving the mapping of non-color outputs (e.g., width).
  ///
  /// The current implementation extracts RGBA components from `selectedColor.cgColor`, compares
  /// them to the existing color outputs (the first four outputs in `self.weights`), and computes
  /// a 4×4 linear transform (embedded in a 5×5 identity matrix) that maps the current color
  /// vector to the target. This transform is applied by post-multiplying the 8×5 weight matrix,
  /// thus modifying only the color output subspace.
  ///
  /// This is a minimal, forward-compatible approach: as sensor inputs grow (e.g., delayed history),
  /// the same output-space transform strategy can be preserved, with richer color models added
  /// to the transform computation itself.
  ///
  /// ⚠️ **Work in progress**:
  /// The exact nature of the color transform (e.g., linear vs perceptual, RGB vs LAB, chroma/hue
  /// decomposition) is under active design. Future versions may use more sophisticated transforms
  /// informed by sensor fusion or temporal context.
  ///
  /// - Parameter selectedColor: The target RGBA color to adapt toward.
  /// - Returns: Updated weight matrix with transformed color outputs, all other mappings unchanged
  func getFlat(for selectedColor: Color) -> [Double] {
    /// take
    var flatVec = self.weights
    guard let components = selectedColor.cgColor?.components else { return []}
    let r = Double(components[0])
    let g = Double(components[1])
    let b = Double(components[2])
    flatVec[0] = r
    flatVec[strideCount] = g
    flatVec[2*strideCount] = b
    // keep whatever alpha was before
    
    return flatVec
  }
  
  func set(color: Color, reset: Bool = false) {
    guard let components = color.cgColor?.components else { return }
    if reset {
      self.weights = Array(repeating: 0.0, count: NibMatrix.N)
      self.weights[3*strideCount] = 1.0 // set the alpha
    }
    let r = Double(components[0])
    let g = Double(components[1])
    let b = Double(components[2])
    selectedRed = r
    selectedBlue = b
    selectedGreen = g
//    self.weights[0] = r
//    self.weights[strideCount] = g
//    self.weights[2*strideCount] = b
    
  }
  
  func setRow(_ r: Int, data: [Double]) {
    assert(data.count == NibMatrix.rowSize) // not counting for bias
    let rowStart = NibMatrix.rowSize*r
    for i in 0..<NibMatrix.rowSize {
      self.weights[rowStart + i] = data[i]
    }
  }
  
  var color: Color {
    let r = self.weights[0]
    let g = self.weights[strideCount]
    let b = self.weights[2*strideCount]
    //let a = self.weights[3*stride]
    
    return Color(red: r, green: g, blue: b)
  }
  
  enum WeightChange {
    case double
    case half
    case addEpsilon
    case subEpsilon
    case negate
    
    func apply(to value: Double) -> Double {
      switch self {
      case .double: return value*2.0
      case .half: return value/2.0
      case .addEpsilon: return value + 0.125
      case .subEpsilon: return value - 0.125
      case .negate: return -value
      }
    }
  }
  
  // do an increase for weights in the row
  func sizeUp(row: Range<Int>) { // "increase" as in result of sigmoid more
    var avg = 0.0 // get the average value
    for i in row { avg += self.weights[i] }
    avg = avg / Double(NibMatrix.rowSize)
    let operation: WeightChange
    if avg > 0 { operation = .double } // positive, make more positive
    else if avg == 0 { operation = .addEpsilon } // actual zero, shift up
    else if avg > -0.125 { operation = .negate } // small but negative, make positive
    else /*if avg > 0 */{ operation = .half } // negative bring towards zero
    for i in row {
      self.weights[i] = operation.apply(to: self.weights[i])
    }
  }
  
  // do an decrease for weights in the row
  func sizeDn(row: Range<Int>) { // "increase" as in result of sigmoid more
    var avg = 0.0 // get the average value
    for i in row { avg += self.weights[i] }
    avg = avg / Double(NibMatrix.rowSize)
    let operation: WeightChange
    if avg > 0.000125 { operation = .half } // bigger: bring down
    else if avg > 0.0 { operation = .negate }  // small but positive, make negative
    else if avg == 0.0 { operation = .subEpsilon } // actual zero,shift down
    else /*if avg > 0 */{ operation = .double } // negative make more negative
    for i in row {
      self.weights[i] = operation.apply(to: self.weights[i])
    }
  }
  
  // c,x,y,t,force,azimuth,altitude,rollAngle ___c: Bias term, ___x:, ___y: position on screen, ___t: timestamp, ___force: pencil pressure (~0 to 4)
  func zero(col sensorIndex: Int) {
    for i in stride(from: sensorIndex, to: NibMatrix.N, by: strideCount) {
      self.weights[i] = 0.0
    }
  }
  
  
  
  func asFunc(_ x: Double) -> Double {
    // x,y,t,force,azimuth,altitude,rollAngle
    return self.weights[NibMatrix.sizeRowStartIndex]*x
  }
  
  // iterate a scale value to fit to output value
  func getXFor(pressure v: Double) -> Double { // pressure about (0, 4) in samples
    if let x = iterate(function: self.asFunc, for: v) {
      return x
    } else {
      return 0
    }
    
    
  }
  
  // just a reglar dot product
  private func dot(_ input: [Double], _ input2: ArraySlice<Double>) -> Double {
    //return zip(input, self.tensorWeights).reduce(0) { $0 + $1.0.0 * $1.1.0 } // "autocomplete" suggested this
    return zip(input, input2).map(*).reduce(0, +) // GPT gave this 2024.09.27.084926
  }
  
  // MARK: just a matrix multiply: outputs = M*v + c where M and c is this NibMatrix Transform Function, c is index 0 on inputs
  private func predict_sigmoid(_ input: [Double]) -> [CGFloat] { // call it predict just to match wording with nueral network terminology
    assert(input.count == NibMatrix.rowSize - 1, "count is \(input.count) and is not \(NibMatrix.rowSize - 1)")
    //print("inputs pre-bias \(input)")
    var outputs = [Double](repeating: 0.0, count: NibMatrix.outputCount) // setup the output vector size
    let biasedInput = [1] + input // var so that can pass & to vDSP
    //print("predict with \(biasedInput)")
    // helper function to constrain output to (0,1)
    func sigmoid(_ x: Double) -> Double {
      let z = (x - 0.75) / 3.25
      let k = 2.0 // shift-scale for good range
      return 1.0/(1.0 + exp(-k*z))
    }
    
    // last three vDSP_Length thingies are input rows, output cols, middle (erased) dimension
    //vDSP_mmulD(&weights, 1, &biasedInput, 1, &outputs, 1, vDSP_Length(NibMatrix.outputCount), vDSP_Length(1), vDSP_Length(stride))
    
    for i in 0..<NibMatrix.colSize {
      for j in 0..<NibMatrix.rowSize {
        outputs[i] += self.weights[i*strideCount + j]*biasedInput[j]
        //print("outputs[\(i)] = \(outputs[i])")
      }
      //print("                   prescaled \(i): \(outputs[i])")
      //print("                   ")
      //      outputs[i] = CGFloat(max(0,min(outputs[i], 1.0))) // clip in range 0 to 1 for the colors
      if i < 4 { // scale the RGBA outputs to keep them at range 0 to 1
        outputs[i] = sigmoid(outputs[i])
        //print("                    ----> sigmoid: \(outputs[i])")
      } else { // the size is (0,1) --> (1,8)
        outputs[i] = 7*sigmoid(outputs[i]) + 1
      }
    }
    //outputs[4] = 1 + 5*outputs[4] // let the size output be (1,5)
    let castOutput: [CGFloat] = outputs.map {CGFloat($0)}
    
    //print("--------------> 🟢\(castOutput)")
    return castOutput
    
  }
  
  var avgForce = IntervalStrapped()
  var avgAzimuth = IntervalStrapped()
  var avgAltitude = IntervalStrapped()
  var avgRoll = IntervalStrapped()
  
  var avgRed = IntervalStrapped()
  var avgGreen = IntervalStrapped()
  var avgBlue = IntervalStrapped()
  var avgAlpha = IntervalStrapped()
  var avgSize = IntervalStrapped()
  
  // MARK: just a matrix multiply: outputs = M*v + c where M and c is this NibMatrix Transform Function, c is index 0 on inputs
  private func predict(_ input: [Double]) -> [CGFloat] { // call it predict just to match wording with nueral network terminology
    // make note of the input stats
    avgForce.append(input[3]) // force (0,1,2 are x, y, t) 0.00--1.07    0.00---2.905
    avgAzimuth.append(input[4]) // etc                     0.53--0.73    0.00---0.998
    avgAltitude.append(input[5]) //                        0.48--0.70    0.33---1.000
    avgRoll.append(input[6]) //                            0.54--0.77    0.00---1.000
    var outputs = [CGFloat](repeating: 0.0, count: NibMatrix.outputCount) // setup the output vector size
    // shape of the output --- colorRed, colorGreen, colorBlue, colorAlpha, strokeSize
    for i in 0..<NibMatrix.outputCount { // for each row
      let start = PencilSample.N*i + i // get the start index for i-th the row, remember  + i for bias
      let w = self.weights[start..<(start + PencilSample.N + 1)] // get the i-th row, remember +1 for bias
      
      outputs[i] = dot([1.0] + input, w) // input first is always the 1 for bias
//      if outputs[i] > 20000 { print("BIG AT \(i) with w \(w)")}
//      else { print("NOT----\(i) with w \(w)")}
    }
    // make note of the weight's output stats before clipping
    avgRed.append(outputs[0]) //  0.00---1.446
    avgGreen.append(outputs[1])// 0.25---0.919
    avgBlue.append(outputs[2]) // 38.2---371.5
    avgAlpha.append(outputs[3])// 64e3---649e3  ??? why here so big... not sure yet
    avgSize.append(outputs[4]) // 0.00---7.710
    //let scale = outputs.prefix(4).max() ?? 0 // max of the first 4 elements
    for i in 0..<4 { // scale the RGBA outputs to keep them at range 0 to 1
      outputs[i] = max(0,min(outputs[i], 1.0)) // clip in range 0 to 1 for the colors
    }
    
    return outputs
    
  }
  
  
  
  func map(_ ps: PencilSample) -> (UIColor, CGFloat) {
    //print("Pensilly samp.force is \(ps.force)")
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
    //print("nib map size \(cSize) color \(color)")
    return (color, cSize)
  }
  
  // find the scale value for which scaling input
  // will give midpoint output ( output of 0.5) for zero
  //
  // so not zero scale, but scale such that the max value
  // of something like 0.93 on the curve with limit = 1.0
  func kFor(input ps: [Double]) -> Double { // 1/(1+e^-x) = y = e^x/(1+e^x) --> e^x = y/(1-y)
    let y = 0.75 // desired y
    let k_x = Darwin.log(y/(1-y))
    print("k_x is \(k_x)")
    let parameters = self.predict(ps) //
    return 256.0*k_x / Double(parameters[4]) // for the size result, times 20 for now for adjusting/testing
  }
  
  
  func increase(row: Int, col: Int, del: Double) {
    //let sizeRow = self.sizeIndex // TODO: set up names for indexing to get at them easier
    let index = self.index(row: row, column: col)
    debugPrint("increasing size weight[\(index)] from \(self.weights[index])", terminator: "")
    self.weights[index] += del // size row index is 4: 0,1,2,3 is RGBA then size, force is index 4: constant,x,y,t,force,az,alt,r
    debugPrint(" to \(self.weights[index])", terminator: "\n")
  }
  
  func reset() {
    self.weights = NibMatrix.vecRed + NibMatrix.vecGreen + NibMatrix.vecBlue + NibMatrix.vecAlpha + NibMatrix.vecSize
  }
  
  static let vecRed: [Double] =   [0.0, 0.0, 0.0, 0.0, 0.75, 0.0, 0.0, 0.25] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  static let vecGreen: [Double] = [0.0, 0.0, 0.0, 0.0, 0.67, 0.0, 0.0, 0.33] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  static let vecBlue: [Double] =  [0.0, 0.0, 0.0, 0.0, 0.3,  0.0, 0.0, 0.7] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  static let vecAlpha: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  static let vecSize: [Double] =  [2.0, 0.0, 0.0, 0.0, 1.0,  1.0, -0.5, 0.5] // 1, x, y, t, f, azmth, alttd, roll
  
  static var standard: NibMatrix { // make it var to be able to alter the weights
    
    // Row major build:
    let nibMat = NibMatrix(vecRed + vecGreen + vecBlue + vecAlpha + vecSize)
    //print("nibMat standard weights:\n********  \(nibMat.weights)")
    return nibMat
  }
  
  init() {
    // c,x,y,t,force,azimuth,altitude,rollAngle ___c: Bias term, ___x:, ___y: position on screen, ___t: timestamp, ___force: pencil pressure (~0 to 4)
    self.weights = NibMatrix.vecRed + NibMatrix.vecGreen + NibMatrix.vecBlue + NibMatrix.vecAlpha + NibMatrix.vecSize
//    self.weights = [0.4952531545, 0.0, 0.0, 0.0, 1.715735028, 1.2,  0.9941837000, -0.22707642218830593,
//                    0.2898942674, 0.0, 0.0, 0.0, 0.1726457773, 1.08, 0.18448510979, -0.08,
//                    0.3324880933, 0.0, 0.0, 0.0, 0.7996673331, 0.367719, 0.156428, -0.0639919142,
//                    5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
//                    0.3, 0.0, 0.0, 0.0, 1.584617, 0.315726, 0.73579, 0.837472798]
    
    
//    let randVector = (0..<NibMatrix.N).map { _ in
//      0.1*Double.random(in: 0...1)
//    }
//    self.weights = Array(randVector)
//    self.zero(col: NibMatrix.xColIndex)
//    self.zero(col: NibMatrix.yColIndex)
//    self.zero(col: NibMatrix.timeColIndex)
    //self.shiftVector = Array(randVector[20..<25])
  }
}

// The constants to feed into matrix transform that gives a function from pencil-sample input to size and color output
extension NibMatrix {

  // row major gives purple-ish that workd for years tutoring, so keep track of it ( not sigmoid but hard threshhold using
  //	static let vecRed: [Double] =   [0.0, 0.0, 0.0, 0.0, 0.75, 0.0, 0.0, 0.25] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //	static let vecGreen: [Double] = [0.0, 0.0, 0.0, 0.0, 0.67, 0.0, 0.0, 0.33] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //	static let vecBlue: [Double] =  [0.0, 0.0, 0.0, 0.0, 0.3,  0.0, 0.0, 0.7] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //	static let vecAlpha: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //	static let vecSize: [Double] =  [4.0, 0.0, 0.0, 0.0, 3.0,  2.0, -1.0, 1.0] // 1, x, y, t, f, azmth, alttd, roll
  
  //  // after trying col-major and vDSP ops, it turned red, keep this as  that for a starting point:
  //  static let vecRed: [Double] =   [0.0, 0.0, 0.0, 0.0, 0.75, 0.0, 0.0, 0.25] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecGreen: [Double] = [0.0, 0.0, 0.0, 0.0, 0.67, 0.0, 0.0, 0.33] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecBlue: [Double] =  [0.0, 0.0, 0.0, 0.0, 0.3,  0.0, 0.0, 0.7] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecAlpha: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecSize: [Double] =  [4.0, 0.0, 0.0, 0.0, 3.0,  2.0, -1.0, 1.0] // 1, x, y, t, f, azmth, alttd, roll
  
  
  //  //
  //  static let vecRed: [Double] =   [0.0, 0.0, 0.0, 0.0, 0.3, 0.0, 0.0, 0.1] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecGreen: [Double] = [0.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.33] // c,x,y,t,force,azimuth,altitude,rollAngle -> green
  //  static let vecBlue: [Double] =  [0.0, 0.0, 0.0, 0.0, 0.5,  0.0, 0.0, 0.5] // c,x,y,t,force,azimuth,altitude,rollAngle -> blue
  //  static let vecAlpha: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> alpha
  //  static let vecSize: [Double] =  [0.05, 0.0, 0.0, 0.0, 0.10,  0.05, -0.05, 0.05] // 1, x, y, t, f, azmth, alttd, roll
  
  //  // Testing pure color only, col-major and vDSP ops
  //  //                               c     x    y    t    f  .alpha .beta .gamma
  //  static let vecRed: [Double] =   [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> red
  //  static let vecGreen: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> green
  //  static let vecBlue: [Double] =  [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> blue
  //  static let vecAlpha: [Double] = [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // c,x,y,t,force,azimuth,altitude,rollAngle -> alpha
  //  static let vecSize: [Double] =  [1.0, 0.0, 0.0, 0.0, 0.0,  0.0, 0.0, 0.0] // 1, x, y, t, f, azmth, alttd, roll
  
  
  //	static var standard0: NibMatrix { // nice purple with reddish brights, thickness seems to max at only 2 or 3 points in size
  //		//let vecConstant: [CGFloat] = [0.0, 0.0, 0.0, 0.0, -1.0]
  //
  //		let nibMat = NibMatrix(vecRed + vecGreen + vecBlue + vecAlpha + vecSize)
  //
  //		return nibMat
  //	}
  
}
