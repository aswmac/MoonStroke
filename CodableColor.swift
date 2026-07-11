//
//  CodableColor.swift
//  MoonStroke
//
//  Created by exo:mlx-community/Qwen3-coder-Next-6bit on 6/29/26.
//

import SwiftUI


// Define a Codable representation of Color
struct CodableColor: Codable, Equatable {
    private let r: Double, g: Double, b: Double, a: Double

    init(_ color: Color) {
        let components = color.cgColor?.components
        if let comps = components, comps.count >= 3 {
            r = comps[0]
            g = comps[1]
            b = comps[2]
            a = comps.count >= 4 ? comps[3] : 1.0
        } else {
            // Fallback to black if color components can't be extracted
            r = 0; g = 0; b = 0; a = 1
        }
    }

    init?(from colorString: String) {
        // Example: "#000000" → black
        guard colorString.hasPrefix("#"), colorString.count == 7 else { return nil }
        let scanner = Scanner(string: colorString)
        //scanner.scanLocation = 1 // skip #
        var rgb: UInt64 = 0
        guard scanner.scanHexInt64(&rgb) else { return nil }

        r = Double((rgb >> 16) & 0xFF) / 255.0
        g = Double((rgb >> 8) & 0xFF) / 255.0
        b = Double(rgb & 0xFF) / 255.0
        a = 1.0
    }

    var uiColor: Color {
        Color(red: r, green: g, blue: b, opacity: a)
    }

    // Custom Codable conformance
    enum CodingKeys: String, CodingKey {
        case value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let hexString = try container.decode(String.self, forKey: .value)
        guard let color = CodableColor(from: hexString) else {
            throw DecodingError.dataCorruptedError(forKey: .value, in: container, debugDescription: "Invalid hex color string")
        }
        self = color
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        let hexString = String(format: "#%02X%02X%02X",
                               Int(r * 255), Int(g * 255), Int(b * 255))
        try container.encode(hexString, forKey: .value)
    }
}
