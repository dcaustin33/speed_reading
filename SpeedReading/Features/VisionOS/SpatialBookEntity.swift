#if os(visionOS)
import RealityKit
import UIKit

/// Custom component to identify book entities on tap
struct BookComponent: Component {
    var bookID: UUID
    var title: String
}

/// Factory for creating 3D book entities on the spatial bookshelf
enum SpatialBookEntity {
    // MARK: - Constants

    static let bookWidth: Float = 0.02
    static let bookHeight: Float = 0.15
    static let bookDepth: Float = 0.10
    private static let bookSize = SIMD3<Float>(bookWidth, bookHeight, bookDepth)

    /// Fixed color palette for fallback book covers
    private static let fallbackColorPalette: [UIColor] = [
        UIColor(red: 0.26, green: 0.52, blue: 0.96, alpha: 1),  // Blue
        UIColor(red: 0.85, green: 0.26, blue: 0.22, alpha: 1),  // Red
        UIColor(red: 0.20, green: 0.66, blue: 0.33, alpha: 1),  // Green
        UIColor(red: 0.61, green: 0.35, blue: 0.71, alpha: 1),  // Purple
        UIColor(red: 0.95, green: 0.61, blue: 0.07, alpha: 1),  // Orange
        UIColor(red: 0.00, green: 0.59, blue: 0.53, alpha: 1),  // Teal
        UIColor(red: 0.83, green: 0.18, blue: 0.55, alpha: 1),  // Pink
        UIColor(red: 0.40, green: 0.31, blue: 0.64, alpha: 1),  // Indigo
    ]

    // MARK: - Entity Creation

    /// Create a 3D book entity with optional cover image
    /// - Parameters:
    ///   - book: The book model
    ///   - coverImage: Optional UIImage for the cover texture
    /// - Returns: A configured ModelEntity with interaction components
    @MainActor
    static func create(for book: Book, coverImage: UIImage? = nil) async -> ModelEntity {
        let material = await makeMaterial(coverImage: coverImage, title: book.title)
        let mesh = MeshResource.generateBox(size: bookSize)
        let entity = ModelEntity(mesh: mesh, materials: [material])

        // Custom data for tap identification
        entity.components.set(BookComponent(bookID: book.id, title: book.title))

        // Interactive trio — all three required for gestures
        entity.components.set(InputTargetComponent())
        entity.components.set(CollisionComponent(shapes: [ShapeResource.generateBox(size: bookSize)]))
        entity.components.set(HoverEffectComponent())

        return entity
    }

    /// Animate a selection pulse on the entity
    @MainActor
    static func animateSelectionPulse(_ entity: Entity) {
        let scaledUp = Transform(
            scale: SIMD3<Float>(repeating: 1.1),
            rotation: entity.transform.rotation,
            translation: entity.transform.translation
        )
        entity.move(to: scaledUp, relativeTo: entity.parent, duration: 0.2, timingFunction: .easeOut)
    }

    /// Animate a new book appearing (scale from 0 to 1)
    @MainActor
    static func animateAppear(_ entity: Entity) {
        entity.scale = .zero
        let fullScale = Transform(
            scale: SIMD3<Float>(repeating: 1.0),
            rotation: entity.transform.rotation,
            translation: entity.transform.translation
        )
        entity.move(to: fullScale, relativeTo: entity.parent, duration: 0.3, timingFunction: .easeOut)
    }

    // MARK: - Private

    @MainActor
    private static func makeMaterial(coverImage: UIImage?, title: String) async -> SimpleMaterial {
        if let coverImage, let cgImage = coverImage.cgImage {
            if let texture = try? await TextureResource(image: cgImage, options: .init(semantic: .color)) {
                var material = SimpleMaterial()
                material.color = .init(texture: .init(texture))
                return material
            }
        }
        // Fallback: deterministic solid color from title hash
        let color = fallbackColor(for: title)
        return SimpleMaterial(color: color, isMetallic: false)
    }

    /// Deterministic color from title using djb2 hash
    static func fallbackColor(for title: String) -> UIColor {
        let index = fallbackColorIndex(for: title)
        return fallbackColorPalette[index]
    }

    static func fallbackColorIndex(for title: String) -> Int {
        var hash: UInt64 = 5381
        for char in title.utf8 {
            hash = ((hash &<< 5) &+ hash) &+ UInt64(char)
        }
        return Int(hash % UInt64(fallbackColorPalette.count))
    }
}
#endif
