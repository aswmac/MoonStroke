import SwiftUI

@main
struct MoonStrokeDocumentApp: App {

  let appHyperMode = HyperMode(type: .pen) // there is only one app and one mode at a time
  let appNib = NibMatrix() // there is only one pencil and one nib at a time
  
  var body: some Scene {
    DocumentGroup(newDocument: MoonStrokeDocument()) { file in
      ContentView(document_0000: file.$document.content, appNib: appNib, appHyperMode: appHyperMode)
    }
  }
}
