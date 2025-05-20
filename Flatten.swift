
// from https://medium.com/@almalehdev/high-performance-drawing-on-ios-part-1-f3a24a0dcb31

/*
var flattenedImage: UIImage?
var line = [CGPoint]() {
		didSet {
				checkIfTooManyPointsIn(&line)
		}
}

override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
		super.touchesBegan(touches, with: event)
		flattenImage()
}

// called when adding new points
func checkIfTooManyPointsIn(_ line: inout [CGPoint]) {
		let maxPoints = 200
		if line.count > maxPoints {
				flattenedImage = self.getImageRepresentation()

				// we leave one point to ensure no gaps in drawing
				_ = line.removeFirst(maxPoints - 1)
		}
}

// called from touches ended
func flattenImage() {
		flattenedImage = self.getImageRepresentation()
		line.removeAll()
}

// convert view to bitmap
func getImageRepresentation() -> UIImage? {
		UIGraphicsBeginImageContextWithOptions(self.bounds.size, self.isOpaque, 0.0)
		defer { UIGraphicsEndImageContext() }
		if let context = UIGraphicsGetCurrentContext() {
				self.layer.render(in: context)
				let image = UIGraphicsGetImageFromCurrentImageContext()
				return image
		}
		return nil
}

 
 override func draw(_ rect: CGRect) {
				 super.draw(rect)
				 guard let context = UIGraphicsGetCurrentContext() else { return }
				 
				 // draw the flattened image if it exists
				 if let image = flattenedImage {
						 image.draw(in: self.bounds)
				 }
				 
				 context.setStrokeColor(lineColor.cgColor)
				 context.setLineWidth(lineWidth)
				 context.setLineCap(.round)
				 
				 for (index, point) in line.enumerated() {
						 if index == 0 {
								 context.move(to: point)
						 } else {
								 context.addLine(to: point)
						 }
				 }
				 context.strokePath()
		 }
 https://medium.com/@almalehdev/high-performance-drawing-on-ios-part-2-2cb2bc957f6
 
 override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
			 guard let newTouchPoint = touches.first?.location(in: self) else { return }
			 guard let previousTouchPoint = currentTouchPosition else { return }
			 drawBezier(from: previousTouchPoint, to: newTouchPoint)
			 currentTouchPosition = newTouchPoint
	 }
 
 func drawBezier(from start: CGPoint, to end: CGPoint) {
			 // 1
			 setupDrawingLayerIfNeeded()
			 // 2
			 let line = CAShapeLayer()
			 let linePath = UIBezierPath()
			 // 3
			 line.contentsScale = UIScreen.main.scale
			 linePath.move(to: start)
			 linePath.addLine(to: end)
			 line.path = linePath.cgPath
			 line.fillColor = lineColor.cgColor
			 line.opacity = 1
			 line.lineWidth = lineWidth
			 line.lineCap = .round
			 line.strokeColor = lineColor.cgColor

			 drawingLayer?.addSublayer(line)
			 
			 // 4
			 if let count = drawingLayer?.sublayers?.count, count > 400 {
					 flattenToImage()
			 }
	 }
 
 func setupDrawingLayerIfNeeded() {
			 guard drawingLayer == nil else { return }
			 let sublayer = CALayer()
			 sublayer.contentsScale = UIScreen.main.scale
			 layer.addSublayer(sublayer)
			 self.drawingLayer = sublayer
	 }
 
 
 func flattenToImage() {
			 UIGraphicsBeginImageContextWithOptions(bounds.size, false, Display.scale)
			 if let context = UIGraphicsGetCurrentContext() {

					 // keep old drawings
					 if let image = self.image {
							 image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
					 }

					 // add new drawings
					 drawingLayer?.render(in: context)

					 let output = UIGraphicsGetImageFromCurrentImageContext()
					 self.image = output
			 }
			 clearSublayers()
			 UIGraphicsEndImageContext()
	 }
 
 
 // MARK: now it is the GPU full (previous uses CPU when flattening the image)
 
 
*/
