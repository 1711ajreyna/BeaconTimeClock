import SwiftUI
import PencilKit
import UIKit

/// SwiftUI wrapper for Apple's PencilKit canvas.
///
/// Supervisors may sign with a finger or Apple Pencil.
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

    final class Coordinator:
        NSObject,
        PKCanvasViewDelegate
    {
        @Binding
        var drawing: PKDrawing

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
