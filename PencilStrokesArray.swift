//
//  PencilStrokeArray.swift
//  MoonStroke
//
//  Created by Adam Mcgregor on 9/23/24.
//
// TODO: add nib-tip, gradient, whatever I come up with (as of after 2024.09.23.101106)

import SwiftUI

struct PencilStrokesArray: Codable {
	
	
  var value: [PencilStroke]
	
	//var sortedByX: [(index: Int, value: PencilStroke)]
  
  init() { self.value = [] }
	init(_ list: [PencilStroke]) {
		var newList: [PencilStroke] = []
		for newStroke in list {
			var bs = newStroke
			bs.update()
			newList.append(bs) // refresh the bounding box statistics
		}
		self.value = newList
	}
  mutating func append(_ a: PencilStroke) { self.value.append(a) }
	mutating func updateAll() {
		for i in 0..<self.value.count {
			var x = self.value[i]
			x.update()
			self.value[i] = x // update the stats for each one
		}
	}
  func enumerated() -> EnumeratedSequence<[PencilStroke]> { return self.value.enumerated() }
  
  mutating func erase(_ index: Int) { // TODO: todo here
    guard index >= 0 && index < self.value.count else { return }
    
  }
	/// look through the strokes to see if this point is contained within it
	func indices(boxing near: CGPoint) -> [Int] {
		//comment("\(#function)")
		//comment("\(near)")
		//comment("\(self)")
		//comment("\(self.enumerated())")
		var indices: [Int] = []
		for (index, value) in self.enumerated() {
			if value.boundingBox.contains(near) {
				indices.append(index)
			}
		}
		//comment("returning: \(indices)")
		return indices
	}
}

extension PencilStrokesArray: Sequence {
	func makeIterator() -> AnyIterator<PencilStroke> {
		var iteratorCount = 0
		return AnyIterator{
			if iteratorCount < value.count {
				iteratorCount += 1
				return value[iteratorCount - 1]
			}
			return nil
		}
	}
	
}
