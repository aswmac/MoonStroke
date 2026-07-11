//
//  EqualizerView.swift
//  MoonStroke
//
//  Created on 7/6/26.
//
import SwiftUI

struct EqualizerView: View {
  @Binding var red: Double
  @Binding var green: Double
  @Binding var blue: Double
  @Bindable var appNib: NibMatrix
  
  @State private var lastRed: Double = 0.5
  @State private var lastGreen: Double = 0.5
  @State private var lastBlue: Double = 0.5
  
  let onDismiss: () -> Void
  
  private let sliderMin: Double = 0.0
  private let sliderMax: Double = 1.0
  
  var body: some View {
    HStack(spacing: 0) {
      Spacer().frame(width: 24) // minimal padding
      
      VStack(spacing: 24) {
        // Red Slider
        VStack {
          Text("Red")
            .font(.footnote)
            .foregroundColor(.secondary)
          Slider(
            value: $red,
            in: sliderMin...sliderMax,
            step: 0.01
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 200)
          .controlSize(.large)
        }
        .frame(width: 40, height: 200)
        
        // Green Slider
        VStack {
          Text("Green")
            .font(.footnote)
            .foregroundColor(.secondary)
          Slider(
            value: $green,
            in: sliderMin...sliderMax,
            step: 0.01
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 200)
          .controlSize(.large)
        }
        .frame(width: 40, height: 200)
        
        // Blue Slider
        VStack {
          Text("Blue")
            .font(.footnote)
            .foregroundColor(.secondary)
          Slider(
            value: $blue,
            in: sliderMin...sliderMax,
            step: 0.01
          )
          .rotationEffect(.degrees(-90))
          .frame(width: 200)
          .controlSize(.large)
        }
        .frame(width: 40, height: 200)
        
        Spacer()
        
        Button(action: onDismiss) {
          Text("Done")
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color.accentColor)
            .foregroundStyle(.white)
            .cornerRadius(8)
        }
        .padding(.top, 16)
      }
      .padding(16)
      .background(
        Color.primary.opacity(0.2)
          .cornerRadius(16)
          .shadow(radius: 8)
      )
    }
    
  }
}

