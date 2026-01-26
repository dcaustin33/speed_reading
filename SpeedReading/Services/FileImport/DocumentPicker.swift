import SwiftUI
import UniformTypeIdentifiers

/// SwiftUI wrapper for UIDocumentPickerViewController
/// Allows selecting .txt, .md, and .epub files from the iOS Files app
struct DocumentPicker: UIViewControllerRepresentable {
    /// Callback when a file is selected successfully
    let onSelect: (URL) -> Void
    /// Callback when the picker is cancelled
    let onCancel: () -> Void

    // Supported file types
    private static let supportedTypes: [UTType] = [
        .plainText,                    // .txt
        UTType(filenameExtension: "md") ?? .plainText,  // .md
        .epub                          // .epub
    ]

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(
            forOpeningContentTypes: Self.supportedTypes,
            asCopy: true  // Copy file to app's sandbox
        )
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {
        // No updates needed
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onSelect: onSelect, onCancel: onCancel)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onSelect: (URL) -> Void
        let onCancel: () -> Void

        init(onSelect: @escaping (URL) -> Void, onCancel: @escaping () -> Void) {
            self.onSelect = onSelect
            self.onCancel = onCancel
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else {
                onCancel()
                return
            }
            onSelect(url)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onCancel()
        }
    }
}

/// Modifier to present the document picker as a sheet
extension View {
    func documentPicker(
        isPresented: Binding<Bool>,
        onSelect: @escaping (URL) -> Void,
        onCancel: @escaping () -> Void = {}
    ) -> some View {
        sheet(isPresented: isPresented) {
            DocumentPicker(
                onSelect: { url in
                    isPresented.wrappedValue = false
                    onSelect(url)
                },
                onCancel: {
                    isPresented.wrappedValue = false
                    onCancel()
                }
            )
        }
    }
}
