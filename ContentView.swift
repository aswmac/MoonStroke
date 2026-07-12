import SwiftUI

struct ContentView: View {
  // The document's content array is passed as a binding
  @Binding var document_0000: PencilStrokesArray // struct PencilStrokesArray: Codable
//  @Bindable var appNib: NibMatrix // final class NibMatrix
//  @Bindable var appHyperMode: HyperMode
  var appNib = NibMatrix()
  @State var appHyperMode = HyperMode(type: .pen) // state because the onChange watches it to trigger handleTypeChange()
  @State private var showMenu: Bool = false // Control menu visibility
  @State private var contextualPaletteAnchor: PopoverAttachmentAnchor?
  @State private var hoverPosition: CGPoint = .zero // postion of the pencil hovering
  @State private var contactPosition: CGPoint = .zero // position of the finger/stylus touching
  @State private var isHovering = false
  @State private var isHoverPositioning: Bool = false
  @State private var isContactPositioning: Bool = false
  @State private var selectionBoxes: [CGRect] = [] // when non-empty they show dash-line boxes
  @State private var cursor: CGRect? // to show terminal like cursor
  @State private var lastSqueezedPosition: CGPoint = .zero
  
  @State private var showEqualizer = false
  @State private var redSliderInput: Double = 1.0
  @State private var greenSliderInput: Double = 1.0
  @State private var blueSliderInput: Double = 1.0
  
  @State private var colorPickerSelectedColor: Color = .white
  
  
  
  
  var body: some View {
    
    GeometryReader { geometry in // may need geometry...
      ZStack {
        MoonStrokesEditor(stroke_ER: $document_0000,
                          appHyperMode: appHyperMode,
                          appNib: appNib,
                          hoverPositioning: $isHoverPositioning,
                          selectionBoxes: $selectionBoxes,
                          fingerPosition: $contactPosition,
                          isFingerPositioning: $isContactPositioning,
                          cursor: $cursor
                          
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        //.background(Color.white)
        .onPencilSqueeze { squeeze in
          if case let .ended(value) = squeeze {
            //debugPrint("case ended")
            if showMenu { // dismiss also
              showMenu = false
              return
            }
            if let vloc = value.hoverPose?.anchor { // Cannot assign value of type 'UnitPoint' to type 'CGPoint'
              //if let vloc = value.hoverPose?.location {
              //menuPosition = vloc
              
              let size = geometry.size
              let point = CGPoint(x: vloc.x*size.width, y: vloc.y*size.height)
              lastSqueezedPosition = point
              contextualPaletteAnchor = .point(vloc)
              showMenu = true
            } else {
              print("no vloc")
            }
          } else {
            
          }
        }
        .onAppear {
          //appHyperMode = HyperMode(type: .pen, onTypeChanged: hook) // SUBSCRIBE or something like that
        }
        
        PlusSymbol()//Circle()
          .fill(isHoverPositioning && isHovering ? Color.green : Color.clear)
          .frame(width: 200, height: 200)
          .position(hoverPosition)
          .allowsHitTesting(false)
          .blendMode(.difference) // difference seems nothing (maybe alpha colors?) can try many here
        SelectionOfStrokesView(selectionBoxes: $selectionBoxes)
        CursorView(cursorRect: $cursor)
        CircleFocus() //contactInput view helper when wanting to "highlight" an area
          .stroke(isContactPositioning ? Color.green : Color.clear, lineWidth: 2)
          .frame(width: 100, height: 100)
          .position(contactPosition)
          .allowsHitTesting(false)
          .blendMode(.difference) // difference seems nothing (maybe alpha colors?) can try many here
      }
      .popover(
        isPresented: $showMenu,
        //attachmentAnchor: .point(.center),  // would be the center of whole view/screen
        attachmentAnchor: contextualPaletteAnchor ?? .point(.center),
        arrowEdge: .trailing, // trailing (for US-EN or whatever) is left
        content: {
          MenuView(
            lastSQPos: lastSqueezedPosition,
            selectedColor_Menu: $colorPickerSelectedColor,
            appNib: appNib, showMenu_Menu: $showMenu,
            appHyperMode: appHyperMode
          )
        }
      )
      .overlay(alignment: .leading) {
        if showEqualizer {
          EqualizerView(
            red: $redSliderInput,
            green: $greenSliderInput,
            blue: $blueSliderInput,
            appNib: appNib,
            onDismiss: { showEqualizer = false }
          )
          //.animation(.easeInOut(duration: 3), value: showEqualizer) // optional: for smoother transition DOES NADA
          .transition(.move(edge: .leading).combined(with: .opacity)) // It is fast but maybe does something
        }
      }

      .onContinuousHover { phase in //
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
    .onChange(of: appHyperMode.type) { // Triggers only on change, ie not when selecting same again...
      handleTypeChange()
    }
    
  }
  
  
  private func handleTypeChange() {
    
    switch appHyperMode.type {
    case .numCursor:
      self.appHyperMode.lastSqueezedPosition = lastSqueezedPosition
      cursor = CGRect(center: lastSqueezedPosition, size: CGSize(width: 10, height: 30))
    case .pen:
      self.appNib.unInvert() // or "reset to normal"
      cursor = nil
    case .eraser:
      cursor = nil
    case .invert:
      print("invert in handleTypeChange")
      self.appNib.invert()
      cursor = nil
    case .compass:
      cursor = nil
    case .classify:
      cursor = nil
    case .normStamp:
      cursor = nil
    case .sineWave:
      cursor = nil
    case .timeLapse:
      cursor = nil
    case .snapToTip:
      cursor = nil
    case .gauge:
      cursor = nil
    case .mean:
      cursor = nil
    case .plus:
      cursor = nil
    case .minus:
      cursor = nil
    case .fitSize:
      cursor = nil
    case .widthPlus:
      cursor = nil
    case .widthMinus:
      cursor = nil
    case .equalizeColor:
      showEqualizer = true
      cursor = nil
    }
    
    // Replace binding value *with hook preserved*
    //appHyperMode = HyperMode(type: appHyperMode.type, onTypeChanged: oldHook)
    
    showMenu = false // dismiss the menu
    
  }
}

struct SelectionOfStrokesView: View {
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
            .foregroundColor(Color(red: 0.5, green: 0.5, blue: 0.0, opacity: 1.0))
            .frame(width: selectionBoxes[index].width, height: selectionBoxes[index].height)
            .position(x: selectionBoxes[index].midX, y: selectionBoxes[index].midY)
        }
      }
    }
  }
}

struct CursorView: View {
  @Binding var cursorRect: CGRect?
  let dashOn: CGFloat = 5
  let dashOff: CGFloat = 3
  let dashSpeed: CGFloat = 16.0 // 2 is slow, 4 is almost, 8 is maybe good, I like 16 I think
  //@State private var dashPhase: CGFloat = 0.0
  
  var body: some View {
    TimelineView(.animation) { timeline in
      Group {
        if let rect = cursorRect {
          Rectangle()
          //.stroke(Color(red: 0.5, green: 0.5, blue: 0.0, opacity: 1.0))
            .fill(Color(red: 0.2, green: 0.5, blue: 0.1, opacity: 1.0))
            .frame(width: rect.width, height: rect.height)
            .position(x: rect.midX, y: rect.midY)
            .opacity(timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0)
        } else {
          EmptyView()
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

// Circle shape to show/focus
struct CircleFocus: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    let size = min(rect.width, rect.height)
    let center = CGPoint(x: rect.midX, y: rect.midY)
    let radius = size / 2.0
    
    path.addEllipse(in: CGRect(
      x: center.x - radius,
      y: center.y - radius,
      width: size,
      height: size
    ))
    
    return path
  }
}
struct MenuView: View { // TODO: allow drag to reorder tools in menu
  let lastSQPos: CGPoint // need this to trigger the action, otherwise didSet fires twice for one thing
  @Binding var selectedColor_Menu: Color
  @Bindable var appNib: NibMatrix { // handle to change color (refactor: put color request or something
    didSet {
      print("the new nibMat")
    }
  }
  @Binding var showMenu_Menu: Bool
  @Bindable var appHyperMode: HyperMode // Handle to alter mode type
  static private var tools: [HyperModeType] = HyperModeType.allCases
  private let itemsPerColumn: Int = 9
  private var columns: [[HyperMode]] {
    stride(from: 0, to: MenuView.tools.count, by: itemsPerColumn).map { start in
      let end = min(start + itemsPerColumn, MenuView.tools.count)
      return Array(MenuView.tools[start..<end].map{ HyperMode(type: $0)})
    }
  }
  
  // when the mode type is selected from the menu, act on it here
  func action(for tool: HyperModeType) { // TODO: decide--if same is selected then menu does not dismiss (because no change in mode value)
    appHyperMode.set(type: tool) // side effects (notifications) on the set function, will call onTypeChanged which is defined on ContentView's onappear
    showMenu_Menu = false // dismiss on any selection-tap not just the n - 1 "changing" selections
    switch tool {
    case .compass:
      () //
    case .plus:
      appNib.sizeUp(row: NibMatrix.sizeRowIndices)
    case .minus:
      appNib.sizeDn(row: NibMatrix.sizeRowIndices)
    case .widthPlus:
      appNib.sizeUp(row: NibMatrix.blueRowIndices)
    case .widthMinus:
      appNib.sizeDn(row: NibMatrix.blueRowIndices)
    case .fitSize:
      appNib.color.scaledToFit()
    case .equalizeColor:
      ()//appNib.set(color: Color(red: redSliderInput, green: greenSliderInput, blue: blueSliderInput))
    default:
      ()
    }
  }
  /// The squeeze-pop-up selection elements
  var body: some View {
    
    return VStack {
      VStack(alignment: .center, spacing: 12) {
        ColorPicker("", selection: $selectedColor_Menu)
          .pickerStyle(.menu)
          .padding()
          .onChange(of: selectedColor_Menu) { // infinite loop danger--do not let nibMat affect colors showing here!
            appNib.set(color: selectedColor_Menu)
          }
        // ScrollView(.vertical, showsIndicators: true)
        // LazyVGrid(columns: columns, alignment: .leading, spacing: 12)
        HStack(spacing: 24) {
          ForEach(columns.indices, id: \.self) { index in
            let columnTools = columns[index].map { $0.type }
            VStack(alignment: .leading, spacing: 12) {
              ForEach(columnTools, id: \.self) { nibTool in
                Button(action: {
                  action(for: nibTool)
                }) {
                  nibTool.descriptiveImage
                    .frame(width: 20, height: 20) // size it
                    .contentShape(Rectangle()) // make it tappable
                  }
                }
                
            }
            //.padding()
            //.scaleEffect(2)
          }
        }
        .padding(.horizontal)
        .background(Color.secondary.opacity(0.2))
        .cornerRadius(12)
        .shadow(radius: 8)
      }
      .padding()
      .background(Color.primary.opacity(0.1))
      .cornerRadius(16)
      .shadow(radius: 10)
      .onAppear {
        // Optional: ensure color picker updates nibMat if needed
      }
      //.scaleEffect(3)// scale underflows--view is clipped
    }
  }
}
