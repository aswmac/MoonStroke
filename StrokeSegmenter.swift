//
//  StrokeSegmenter.swift
//  MoonStroke
//
//  Created by Adam Mcgregor on 10/14/24.
//

import Foundation // for CGFloat


/// Just keep track of the corners of the stroke to have the box
struct StrokeBoxer {
	var count: Int = 0 // keep count of how many elements have been seen
	var minX: CGFloat? // the minimum x value of all, ie the left bounding box coordinate
	var maxX: CGFloat? // right coordinate of the bounding box
	var minY: CGFloat? // bottom coordinate of the bounding box
	var maxY: CGFloat? // top coordinate of the bounding box
	
	private var left: CGFloat { minX ?? .infinity }
	private var right: CGFloat { maxX ?? -.infinity }
	private var bottom: CGFloat { minY ?? .infinity }
	private var top: CGFloat { maxY ?? -.infinity }
	
	mutating func update(with ps: PencilSample, at index: Int) {
		if minX == nil || ps.location.x < minX! { minX = ps.location.x }
		if maxX == nil || ps.location.x > maxX! { maxX = ps.location.x }
		if minY == nil || ps.location.y < minY! { minY = ps.location.y }
		if maxY == nil || ps.location.y > maxY! { maxY = ps.location.y }
		count += 1 // count the count adding this one more
	}
	
	init() {
		// the initial values were there, why compiler need this...?
	}
	
	init(_ pstroke: PencilStroke) {
		self.count = 0
		for ps in pstroke {
			update(with: ps, at: count)
		}
	}
	
	init(_ strokeList: [PencilSample] ) {
		self.count = 0
		for ps in strokeList {
			update(with: ps, at: count)
		}
	}
	
	/// if the point is inside the box, returns false if self has no points
	func contains(_ point: CGPoint) -> Bool {
		if left <= point.x && right >= point.x {
			if bottom <= point.y && top >= point.y {
				return true
			}
		}
		return false
	}
	
	var rectangle: CGRect {
		get {
				let strokeOrigin = CGPoint(x: left, y: bottom) // the top left of the bounding box
				let strokeSize = CGSize(width: right - left, height: top - bottom) // the size of the bounding box
				return CGRect(origin: strokeOrigin, size: strokeSize) // the actual bounding box as a CGRect
		}
	}
}

import SwiftUI

enum hbang {
	case left
	case right
}
enum vbang {
	case down
	case up
}

/// vertical, horizontal, none
enum bangbang {
	case vertical(type: vbang)
	case horizontal(type: hbang)
	case none
}

struct Edge {
	var indices: [Int]
	var type: bangbang
}
/// Which edge (left | right | down | up) or rawValue = 0 if not an edge
struct BangFlags: OptionSet {
	var rawValue: UInt8 // only need left, right, down, up, or none/middle
	static let leftFlag = BangFlags(rawValue: 1 << 0)
	static let rightFlag = BangFlags(rawValue: 1 << 1)
	static let downFlag = BangFlags(rawValue: 1 << 2)
	static let upFlag = BangFlags(rawValue: 1 << 3)
	
}

extension BangFlags: CustomStringConvertible {
	var description: String {
		return "\(self.rawValue)"
	}
}

/// Each stroke point can be considered an edge of the stroke or not an edge, usually if an edge there is a run of them
struct RunLengthBang {
	var runSet: BangFlags // the single type, edges only, corners taken as last edge
	var length: Int // the length
	
	init() {
		self.runSet = .rightFlag // like to start with right
		self.length = 0 // but no input means a run of zero
	}
	
	init(_ runSet: BangFlags) {
		// keep self as pure up | left | down | right only, with preference in that order
		if runSet.rawValue&BangFlags.rightFlag.rawValue == BangFlags.rightFlag.rawValue {
			self.runSet = .rightFlag
		} else if runSet.rawValue&BangFlags.upFlag.rawValue == BangFlags.upFlag.rawValue {
			self.runSet = .upFlag
		} else if runSet.rawValue&BangFlags.leftFlag.rawValue == BangFlags.leftFlag.rawValue {
			self.runSet = .leftFlag
		} else if runSet.rawValue&BangFlags.downFlag.rawValue == BangFlags.downFlag.rawValue {
			self.runSet = .downFlag
		} else {
			self.runSet = BangFlags(rawValue: 0)
		}
		self.length = 1
	}
	
	mutating func append(_ bang: BangFlags) -> Bool {
		var retBool: Bool
		defer {
			//debugPrint("Try append \(bang) to self \(self) --- returned \(retBool)")
		}
		// if a zero set run, input also has to be zero
		if self.runSet.rawValue == 0 && bang.rawValue == 0 {
			self.length += 1
			//debugPrint("RLB: Appended zero")
			retBool = true
			return retBool
		}
		if self.length == 0 { // or if the self is already empty, start with that
			self = .init(bang)
			//debugPrint("RLB: Initialized with \(bang)")
			retBool = true
			return retBool
		}
		// otherwise it has to match self to count
		if self.runSet.rawValue&bang.rawValue == 0 {
			retBool = false
			return retBool
		} else {
			self.length += 1
			//debugPrint("RLB: Appended \(bang) which matches self? \(self.runSet)")
			retBool = true
			return retBool
		}
	}
}

extension RunLengthBang: CustomStringConvertible {
	var description: String {
		return "\(runSet.rawValue)>>>[\(length)]"
	}
}

/// The array of the values and thier run-length
struct RunLengthBangSet {
	var runArray: [RunLengthBang]
	//var lastBang: RunLengthBang
	
	init() {
		runArray = []
	}
	
	init(_ bangArray: [BangFlags]) {
		//debugPrint("Initializing RunLengthBangSet with \(bangArray)")
		self.runArray = []
		for bs in bangArray {
			append(bs)
		}
	}
	
	mutating func append(_ bang: BangFlags) {
		if runArray.isEmpty { // if the self is empty (not yet started) then input is plain
			let newElement = RunLengthBang(bang)
			runArray.append(newElement)
		} else { // otherwise input has to be compared, and a new run started if necessary
			var lastElement = runArray.popLast()! // hopefully the compiler is smart enough here----
			//debugPrint("RunLengthBangSet.append(\(bang)) looking a lastElement: \(lastElement)")
			if lastElement.append(bang) { // ----because nothing gets permanently popped ever
				runArray.append(lastElement) // if it continues the run on the last element
			} else {
				runArray.append(lastElement) // ----it gets altered or a new element is appended
				runArray.append(RunLengthBang(bang)) // else start a nuw run at the end
			}
		}
	}
}

extension RunLengthBangSet: CustomStringConvertible {
	var description: String {
		var retString = ""
		for rl in runArray {
			retString += "\(rl); "
		}
		return retString
	}
}

/// Since no modifications of the inputs are made, SUPOSSEDLY the compiler is smart and does not copy things, just reads things
/// ie the reference pencil stroke does not waste time copying, nor memory, and the let keyword ensures that behavior wont change
class EdgeSorter {
	static let epsilon: CGFloat = 2.0 // the buffer of the edge
	let reference: PencilStroke // let constant to only look at the source without a copy
	var horizontalSortedIndices: [Int]
	var verticalSortedIndices: [Int]
	
	static let compareHorizontal: (PencilSample, PencilSample) -> Bool  = {
		$0.location.x < $1.location.x
	}
	
	static let compareVertical: (PencilSample, PencilSample) -> Bool  = {
		$0.location.y < $1.location.y
	}
	
	init( ps: PencilStroke) { // self.reference is a let constant so that the array is not copied
		reference = ps
		let indices = Array(ps.samples.indices)
		horizontalSortedIndices = indices.sorted { // the indices sorted by horizontal
			EdgeSorter.compareHorizontal(ps[$0], ps[$1])
		}
		verticalSortedIndices = indices.sorted { // the indices sorted by vertical
			EdgeSorter.compareVertical(ps[$0], ps[$1])
		}
	}
	
	/// indices to the epsilon neghborhood of the (left | right | bottom | top) extrema points
	/// Split up the stroke into segments where the segment edges are defined by the bounds of the stroke
	func edgeList(for type: bangbang) -> [Int] {
		var extremaIndices: [Int] = [] // the indices to the (left|right|bottom|top)most points
		let strider: StrideTo<Int> // stride forward or reverse
		let indices: [Int] // the indices to get the testpoints location x or y values
		let discriminant: (PencilSample) -> Bool // the comparison to make
		switch type {
		case .none:
			return [] // could I suppose do ALL the others and return the complement
		case .horizontal(let type):
			indices = horizontalSortedIndices
			switch type {
			case .left: // left most would be x least
				discriminant = { testpoint in
					let lmx = self.reference[indices[0]].location.x
					return testpoint.location.x - lmx < EdgeSorter.epsilon
				}
				strider = stride(from: 0, to: indices.count, by: 1) // 0 element is the extremum
			case .right: // right most would be x most
				discriminant = { testpoint in
					let rmx = self.reference[indices[indices.count - 1]].location.x
					return  rmx - testpoint.location.x < EdgeSorter.epsilon
				}
				strider = stride(from: indices.count - 1, to: -1, by: -1) // count-1 element is extremum
			}
		case .vertical(let type):
			indices = verticalSortedIndices
			switch type {
			case .down: // down most would be y most
				discriminant = { testpoint in
					let dmy = self.reference[indices[indices.count - 1]].location.y
					return dmy - testpoint.location.y < EdgeSorter.epsilon
				}
				strider = stride(from: indices.count - 1, to: -1, by: -1) // count-1 element is extremum
			case .up: // up most would be y least
				discriminant = { testpoint in
					let umy = self.reference[indices[0]].location.y
					return testpoint.location.y - umy < EdgeSorter.epsilon
				}
				strider = stride(from: 0, to: indices.count, by: 1) // 0 element is the extremum
			}
		}
		if indices.isEmpty {
			debugPrint("DID AN EMPTY ARRAY FIND ITS WAY INTO INIT HERE?!?!?")
			return [] // should never happen
		}
		for i in strider { // MARK: check if point is (left|right|bottom|top)most or not
			let testPoint = reference[indices[i]]
			if discriminant(testPoint) {
				extremaIndices.append(indices[i])
			} else {
				break // stop early if found one outside the epsilon-nieghborhood in the sorted values
			}
		}
		return extremaIndices.sorted()
	}

	/// Denote each element as bangSet meaning is left|right|bottom|top or corner(s) or none
	func edgeMarks() -> [BangFlags] {
		var pTypes: [BangFlags] = []
		let top = self.edgeList(for: .vertical(type: .up))
		let bottom = self.edgeList(for: .vertical(type: .down))
		let left = self.edgeList(for: .horizontal(type: .left))
		let right = self.edgeList(for: .horizontal(type: .right))
		for i in 0..<self.reference.count {
			var bs = BangFlags()
			if top.contains(i) {
				bs.insert(.upFlag)
			}
			if bottom.contains(i) {
				bs.insert(.downFlag)
			}
			if left.contains(i) {
				bs.insert(.leftFlag)
			}
			if right.contains(i) {
				bs.insert(.rightFlag)
			}
			pTypes.append(bs)
		}
		return pTypes
	}
	
	/// Runs of BangFlag zero may have shape as well, edge mark them also, want all parts determined to 8ths of the circle, curvature
	func fullMarks() {
		let firstMarks = self.edgeMarks()
		// 1. For all known segments, mark them with angle, cuvature, endpoints (new struct type)
		// 2. For all zero segments, drill into them further to get the segments
	}
	
	// new struct type to quantify the segments
	struct JotTerm {
		//let angle: CGFloat // angle is computed: can come from endpoints
		let curvature: CGFloat
		let endpoints: [Double]
		
	}
//	func edgeSplit() -> Int {
//		
//	}
}


func strokeSegmenter(_ input: PencilStroke) {
	
}
