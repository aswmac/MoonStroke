//
//  HyperKeys.swift
//  MoonStroke
//
//  Created by Adam Mcgregor on 10/7/24.
//

import UIKit

extension HyperView {
	
	
//	// this was auto-suggested:
//	public func hyper(_ body: () -> HyperView) -> HyperView {
//		body()
//	}
	func keyEvent(_ press: UIPress, down: Bool) {
		guard let key = press.key else { return }
		switch key.charactersIgnoringModifiers { // do the down and up here
		case "h":
			if down {
				self.hoverViewOn?(true) // want to activate the hover display up at ContentView
			} else {
				self.hoverViewOn?(false)
			}
			return // do not fall into other switch possibilities from here
//		case "s":
//			if down {
//				self.sendSelectedStrokes?(self.selectedStrokes)// want to activate the hover display up at ContentView
//				//comment("s-DOWN")
//			} else {
//				self.sendSelectedStrokes?([])
//				//comment("s-UP")
//			}
//			return // do not fall into other switch possibilities from here
		default:
			()
		}
		if down { return } // do action on the up portion of the keypress
		//switch key.charactersIgnoringModifiers { // ignores capitol letters, and...
		switch key.characters {
		case "f": debugPrint("f")
		case "s": self.isSelecting.toggle()
		case "=": // the plus key without the shift being held down
			self.nib.increase(row: 4, col: 0, del: 1)
			setNeedsDisplay()
			//comment("+ (via the '=' key)")
		case "-":
			self.nib.increase(row: 4, col: 0, del:-1)
			//self.nib.weights.forEach { $0 -= 0.1 } // Left side of mutating operator isn't mutable: '$0' is immutable
			setNeedsDisplay()
			//comment("-")
		case "\u{08}": // the backspace key
			self.nib.reset()
			setNeedsDisplay()
		case "p": // print weights to the console TODO: put this in the default print called what again... __repl__ no...
			for i in 0..<NibMatrix.outputCount {
				for j in 0..<self.nib.colSize {
					print("\(self.nib[i, j])", terminator: " ")
				}
				print("")
			}
			//comment("\(self.nib.weights)")
			//pdebugPrint("\(self.nib.weights)")
		case "r":
			//comment("KEYBOARD r")
			self.nib.increase(row: 0, col: 0, del: 0.1) // TODO: define a simpler hook like rBias-->index like 0,0
			setNeedsDisplay()
		case "R":
			//comment("KEYBOARD R")
			self.nib.increase(row: 0, col: 0, del: -0.1)
			setNeedsDisplay()
		case "g":
			self.nib.increase(row: 1, col: 0, del: 0.1)
			setNeedsDisplay()
		case "G":
			self.nib.increase(row: 1, col: 0, del: -0.1)
			setNeedsDisplay()
		case "b":
			self.nib.increase(row: 2, col: 0, del: 0.1)
			setNeedsDisplay()
		case "B":
			self.nib.increase(row: 2, col: 0, del: -0.1)
			setNeedsDisplay()
		case "a":
			self.nib.increase(row: 3, col: 0, del: 0.1)
			setNeedsDisplay()
		case "A":
			self.nib.increase(row: 3, col: 0, del: -0.1)
			setNeedsDisplay()
		case " ":
			self.nib.reset()
			setNeedsDisplay()
		case "x":
			self.imageFlatten()
		default:
			debugPrint("Not f: it is \(key.charactersIgnoringModifiers)")
		}
//		if s {
//			let randVector = (0..<NibMatrix.N).map { _ in
//				CGFloat.random(in: 0...1)
//			}
//			let randNib = NibMatrix(flat: randVector)
//			self.tempVec = self.nib.weights
//			self.nib = randNib
//		} else {
//			self.nib = NibMatrix(flat: self.tempVec)
//		}
//		setNeedsDisplay()
	}
}
