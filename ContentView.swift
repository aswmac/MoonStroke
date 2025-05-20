import SwiftUI

struct ContentView: View {
	// The document's content array is passed as a binding
	@Binding var document: PencilStrokesArray
	@Binding var nib: NibMatrix
	@State private var showMenu: Bool = false // Control menu visibility
	@State private var contextualPaletteAnchor: PopoverAttachmentAnchor?
	@State private var hoverPosition: CGPoint = .zero
	@State private var isHovering = false
	@State private var isHoverPositioning: Bool = false
	@State private var selectionBoxes: [CGRect] = [] // when non-empty they show dash-line boxes
	
	@State private var colorPickerSelectedColor: Color = .white
	
	
	
	
	var body: some View {
		
		GeometryReader { geometry in // may need geometry...
			ZStack {
				MoonStrokesEditor(stroke: $document, nibMat: $nib, hoverPositioning: $isHoverPositioning, selectionBoxes: $selectionBoxes)
				.frame(maxWidth: .infinity, maxHeight: .infinity)
			//.background(Color.white)
				.onPencilSqueeze { squeeze in
					//print("squeeze: \(squeeze)")
					if case let .ended(value) = squeeze {
						//debugPrint("case ended")
						if showMenu { // dismiss also
							showMenu = false
							return
						}
						if let vloc = value.hoverPose?.anchor { // Cannot assign value of type 'UnitPoint' to type 'CGPoint'
							//if let vloc = value.hoverPose?.location {
							//menuPosition = vloc
							contextualPaletteAnchor = .point(vloc)
							showMenu = true
							//print("vloc = \(vloc)")
						} else {
							print("no vloc")
						}
					} else {
						//print("not case ended")
					}
				}
				
				PlusSymbol()//Circle()
					.fill(isHoverPositioning && isHovering ? Color.green : Color.clear)
					.frame(width: 200, height: 200)
					.position(hoverPosition)
					.allowsHitTesting(false)
					.blendMode(.difference) // difference seems nothing (maybe alpha colors?) can try many here
				SelectionBoxesView(selectionBoxes: $selectionBoxes)
				
			}
			.popover(
				isPresented: $showMenu,
				//attachmentAnchor: .point(.center),  // would be the center of whole view/screen
				attachmentAnchor: contextualPaletteAnchor ?? .point(.center),
				arrowEdge: .trailing, // trailing (for US-EN or whatever) is left
				content: {
					MenuView(selectedColor: $colorPickerSelectedColor, nibMat: $nib)
				}
			)
			.onContinuousHover { phase in
				switch phase {
				case .active(let point):
					hoverPosition = point
					isHovering = true
				case .ended:
					hoverPosition = .zero
					isHovering = false
				}
			}
		}
		//		}
	}
}

struct SelectionBoxesView: View {
	@Binding var selectionBoxes: [CGRect]
	let dashOn: CGFloat = 5
	let dashOff: CGFloat = 3
	let dashSpeed: CGFloat = 16.0 // 2 is slow, 4 is almost, 8 is maybe good, I like 16 I think
	//@State private var dashPhase: CGFloat = 0.0
	
	var body: some View {
		let dashLength = dashOn + dashOff
		ZStack {
			ForEach(0..<selectionBoxes.count, id: \.self) { index in
				TimelineView(.animation) { timeline in
					let timeInterval = timeline.date.timeIntervalSinceReferenceDate
					let dashPhase = CGFloat(timeInterval*dashSpeed).truncatingRemainder(dividingBy: dashLength)
					Rectangle()
						.strokeBorder(style: StrokeStyle(
							lineWidth: 1,
							dash: [dashOn, dashOff], // dash pattern: 5 points on, 3 points off
							dashPhase: dashPhase))
					//.stroke(Color(red: 0.5, green: 0.5, blue: 0.0, opacity: 1.0))
						.foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.0, opacity: 1.0))
						.frame(width: selectionBoxes[index].width, height: selectionBoxes[index].height)
						.position(x: selectionBoxes[index].midX, y: selectionBoxes[index].midY)
				}
			}
		}
	}
}
// Plus symbol shape that shows when "h" is held down and tracks the hover position of the pencil
struct PlusSymbol: Shape {
	func path(in rect: CGRect) -> Path {
		var path = Path()
		let width = rect.width
		let height = rect.height
		let lineWidth: CGFloat = 1.0 //width * 0.1
		
		// Horizontal line
		path.addRect(CGRect(x: 0, y: (height - lineWidth) / 2, width: width, height: lineWidth))
		
		// Vertical line
		path.addRect(CGRect(x: (width - lineWidth) / 2, y: 0, width: lineWidth, height: height))
		
		return path
	}
}

struct MenuView: View {
	@Binding var selectedColor: Color
	@Binding var nibMat: NibMatrix
	private let selectionIndices = 0..<NibMatrix.N
	@State private var randomSelections: [Int] = [0,1,2,3]
	static private var tools: [Tool] = [.pen, .eraser,.compass, .classify]
	/// The squeeze-pop-up selection elements
	var body: some View {
		
		return VStack {
			ColorPicker("",selection: $selectedColor)
				.padding()
				.onChange(of: selectedColor) {
					//let random3 = selectionIndices.shuffled()[0..<4] // or .prefix(4) I think
					let rs = Array(selectionIndices.shuffled()[0..<4]) // grab a random set of 4 to let colorpicker play with using its RGBA
					self.randomSelections = rs
					var flatVec = nibMat.weights
					guard let components = selectedColor.cgColor?.components else { return }
					flatVec[rs[0]] = components[0]
					flatVec[rs[1]] = components[1]
					flatVec[rs[2]] = components[2]
					flatVec[rs[3]] = components[3]
					nibMat = NibMatrix(flat: flatVec)
					//setNeedsDisplay() // TODO: HOW do I get the view to refresh DURING the color selection!?!?!?!
					//comment("nib: \(nib.flatWeights)")
					//print("selectedColor: \(selectedColor)")
				}
			ForEach(MenuView.tools, id: \.self) { nibTool in
				Button(action: {
					//comment("tool selected is \(nib)")
					action(for: nibTool)
					
					//let toolNib =
					//let (sv, cc) = self.activeTool.
					//self.colors = generateRandomColors()
				}) {
					//let s = nib.descriptiveShape
					nibTool.descriptiveImage
					
				}.padding() // NECESSARY here, else the for each seems on top of eachother (when scale-3)
			}
			.scaleEffect(3)
		}
		//.scaleEffect(3)// scale underflows--view is clipped
	}
	
	func action(for tool: Tool) {
		switch tool {
		case .pen:
			()//activeTool = .pen(.random)
		case .eraser:
			()//activeTool = .eraser(.random)
		case .compass:
			//DispatchQueue.main.async { // want to see the change immediately---this does nothing to help that
			//DispatchQueue.main.async { // 2024.09.29.141925 GPT's #1 suggestion
				
				
				self.nibMat.invert() //right now effect does not show until dismissal of MenuView
			debugPrint("invert tapped")
			//}
				//setNeedsDisplay() // but do not have a refresh display option
			//}
		case .classify:
			()
		}
	}
	
}
