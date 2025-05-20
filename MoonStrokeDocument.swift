import SwiftUI
import UniformTypeIdentifiers
import UIKit

extension UTType {
  static var moonstroke: UTType {
    UTType(exportedAs: "com.AdamMcGregor.moonstroke")
  }
}

struct MoonStrokeDocument: FileDocument {
  static var readableContentTypes: [UTType] { [.moonstroke] }
  var content = PencilStrokesArray()
	var nib = NibMatrix.standard
  
  init(content: PencilStrokesArray = PencilStrokesArray()) {
    self.content = content
		self.content.updateAll()
  }
  
  
  
  init(configuration: ReadConfiguration) throws {
    if let data = configuration.file.regularFileContents {
      let cdata = try JSONDecoder().decode(PencilStrokesArray.self, from: data)
      self.content = cdata
    }
		self.content.updateAll() // re-calculate the statistics for the strokes
  }
  
  func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
    let cdata = try JSONEncoder().encode(self.content)
    //
    return FileWrapper(regularFileWithContents: cdata)
  }
	
	static func generateDatedFilename() -> String {
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd-MMMM"
		let dateString = dateFormatter.string(from: Date())
		return "Tutoring\(dateString)"
	}
}
