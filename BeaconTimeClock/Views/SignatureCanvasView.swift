// FILE PURPOSE: PencilKit canvas and rendering of approval signatures.
import SwiftUI
import PencilKit
import UIKit

/// SwiftUI wrapper for Apple's PencilKit canvas.
///
/// Supervisors may sign with a finger or Apple Pencil.
// This type groups related state and behavior under a clear responsibility.
struct SignatureCanvasView:
    UIViewRepresentable
{
    @Binding
    var drawing: PKDrawing

    func makeCoordinator()
        -> Coordinator
    {
        Coordinator(
            drawing: $drawing
        )
    }

    func makeUIView(
        context: Context
    ) -> PKCanvasView {
        let canvas =
            PKCanvasView()

        canvas.delegate =
            context.coordinator

        canvas.backgroundColor =
            UIColor.systemBackground

        canvas.drawingPolicy =
            .anyInput

        canvas.tool =
            PKInkingTool(
                .pen,
                color: .label,
                width: 3
            )

        return canvas
    }

    func updateUIView(
        _ uiView: PKCanvasView,
        context: Context
    ) {
        if uiView.drawing.dataRepresentation() !=
            drawing.dataRepresentation()
        {
            uiView.drawing = drawing
        }
    }

    // This type groups related state and behavior under a clear responsibility.
    final class Coordinator:
        NSObject,
        PKCanvasViewDelegate
    {
        @Binding
        var drawing: PKDrawing

        // Create this object with the dependencies or state it needs; avoid hidden global services.
        init(
            drawing:
                Binding<PKDrawing>
        ) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(
            _ canvasView: PKCanvasView
        ) {
            drawing =
                canvasView.drawing
        }
    }
}

/// Converts the vector PencilKit drawing into PNG bytes for the API.
// This type groups related state and behavior under a clear responsibility.
enum SignatureRenderer {

    static func pngData(
        from drawing: PKDrawing
    ) -> Data? {
        let bounds = drawing.bounds

        guard !bounds.isEmpty else {
            return nil
        }

        let padded =
            bounds.insetBy(
                dx: -12,
                dy: -12
            )

        return drawing
            .image(
                from: padded,
                scale: 2
            )
            .pngData()
    }
}
