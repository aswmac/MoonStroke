import SwiftUI
import UIKit

// to use in SwiftUI with a regular view but still have keyboard input need
// original UIViewController from UIKit
struct MoonStrokesEditor: UIViewControllerRepresentable { // class --> wants final, BUT ALSO wants to initialize bindings
	@Binding var stroke: PencilStrokesArray
	@Binding var nibMat: NibMatrix
	@Binding var hoverPositioning: Bool // need a path to send the hover control from the keyboard up to ContentView
	//@Binding var menuVisible: Bool
	@Binding var selectionBoxes: [CGRect]
	
	func makeUIViewController(context: Context) -> MoonStrokesEditorController {
		let editorController =
		MoonStrokesEditorController(strokes: $stroke, nibMat: $nibMat)
		//editorController.coordinator = context.coordinator // trying to get a handle to publish redraw immediately
		editorController.requestHoverview = { s in // trying to get a handle to publish redraw immediately
			//debugPrint("MSE: requestHoverview()")
			hoverPositioning = s
		}
		editorController.requestBoxesView = { frmList in
			selectionBoxes = frmList
		}
		return editorController
	}
	
	func updateUIViewController(_ uiViewController: MoonStrokesEditorController, context: Context) {
		//uiViewController.nibMat = nibMat // Publishing changes from within view updates is not allowed, this will cause undefined behavior.
		//(uiViewController as! MoonStrokesEditorController).nibMat = nibMat//Publishing changes from within view updates is not allowed, this will cause undefined behavior.
	}
//	
//	func makeCoordinator() -> Coordinator {
//		return Coordinator(self)
//	}
	
//	class Coordinator: NSObject {
//			var parent: MoonStrokesEditor
//
//			init(_ parent: MoonStrokesEditor) {
//					self.parent = parent
//			}
//	}
}

/// Put keyboard up/down interface elements here
final class MoonStrokesEditorController: UIViewController {
	@Binding var strokes: PencilStrokesArray
	@Binding var nibMat: NibMatrix {
		didSet {
			updateView()
		}
	}
	
	func updateView() {
		
		view.setNeedsDisplay()
		view.setNeedsLayout()
	}
	private var editorView: HyperView!
	var requestHoverview: ((Bool) -> Void)?
	var requestMenuView: ((Bool) -> Void)?
	var requestBoxesView: (([CGRect]) -> Void)?
	//var refresh: (() -> Void)?
	
	init(strokes: Binding<PencilStrokesArray>, nibMat: Binding<NibMatrix>) {
		self._strokes = strokes
		self._nibMat = nibMat
		super.init(nibName: nil, bundle: nil)
	}
	
	required init?(coder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		//SetupSliders()
		
		editorView = HyperView(samples: $strokes, nibMat: $nibMat)
		editorView.frame = view.bounds
		editorView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
		editorView.hoverViewOn = { s in// don't need this I think
			//comment("MSE_C: callBack()") // don't need this I think
			self.requestHoverview?(s)
		}
		var fileString = "" // output to a file also to see on the documents on the iPad
		editorView.sendSelectedStrokes = { strokeList in
			debugPrint("MSEC: got selected strokes, \(strokeList.count)")
			var rectList: [CGRect] = [] // set of rectangles to request be printed/drawn on screen
			
			for stroke in strokeList {
				rectList.append(stroke.boundingBox.rectangle)
				// want to see someting from segmenting functions, do it here
				let test_edgeSorter = EdgeSorter(ps: stroke)
//				debugPrint("x-sorted: \(test_edgeSorter.horizontalSortedIndices)")
//				debugPrint("y-sorted: \(test_edgeSorter.verticalSortedIndices)")
//				debugPrint("LeftMost: \(test_edgeSorter.edgeList(for: .horizontal(type: .left)))")
//				debugPrint("RightMst: \(test_edgeSorter.edgeList(for: .horizontal(type: .right)))")
//				debugPrint("DownMost: \(test_edgeSorter.edgeList(for: .vertical(type: .down)))")
//				debugPrint("UpperMst: \(test_edgeSorter.edgeList(for: .vertical(type: .up)))")
				let pointTypes = test_edgeSorter.edgeMarks()
				//debugPrint("stroke.edgeSplit() returned \(pointTypes.count)")
				let runLengths = RunLengthBangSet(pointTypes)
//				for i in 0..<pointTypes.count {
//					debugPrint("\tpointTypes[\(i)] is \(pointTypes[i])")
//					fileString += "\n" + "pointTypes[\(i)] is \(pointTypes[i])"
//				}
				debugPrint("runLengths: \(runLengths)")
				fileString += "runLengths: \(runLengths)\n"
			}
			let url = URL.documentsDirectory.appending(path: "BangBangNumbers.txt")
			let data = fileString.data(using: .utf8)!
			do {
				try data.write(to: url, options: [.atomic, .completeFileProtection])
			} catch {
				debugPrint(error.localizedDescription)
			}
			debugPrint("MSEC: calling requestBoxesView, \(rectList.count)")
			// It is so annoying that calls beget calls, how to keep straight the path??...
			self.requestBoxesView?(rectList)
		}
		view.addSubview(editorView)
		//editorView.setNeedsDisplay() // Doesn't help for the M1 iPad Air because it does not show drawing at first until input
	}
	
	// Detect key press and adjust stroke color
	override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			//comment("Down press.key: \(press.key)")
			editorView.keyEvent(press, down: true)
		}
		super.pressesBegan(presses, with: event)
	}
	
	// Detect key release and keep stroke color green
	override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			//comment("Up press.key: \(press.key)")
			editorView.keyEvent(press, down: false)
			
		}
		super.pressesEnded(presses, with: event)
	}
	
	// Detect key changes during press
	override func pressesChanged(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
		for press in presses {
			if let key = press.key, key.charactersIgnoringModifiers == "f" {
				debugPrint("3")//strokeColor = .green
			} else {
				debugPrint("4")//strokeColor = .black
			}
		}
		super.pressesChanged(presses, with: event)
	}
	
}

