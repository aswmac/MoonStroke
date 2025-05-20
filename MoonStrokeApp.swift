import SwiftUI

@main
struct MoonStrokeDocumentApp: App {
    var body: some Scene {
        DocumentGroup(newDocument: MoonStrokeDocument()) { file in
					ContentView(document: file.$document.content, nib: file.$document.nib)
        }
    }
}
