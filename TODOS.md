# TODOS

## Phase 1B: Upgrade to Spatial Volumetric/Immersive
**What:** Convert the windowed visionOS app to use volumetric library (3D bookshelf) and mixed immersive reader space.
**Why:** The "teleprompter in space" experience — floating ORP word in the user's room — is the core value proposition of the visionOS port. Phase 1A validates the engine works on visionOS; 1B delivers the wow factor.
**Pros:** True only-on-Vision-Pro experience. 3D bookshelf with RealityKit entities. Immersive reading mode.
**Cons:** Significant RealityKit investment. 3D book entities, spatial positioning, immersive space management.
**Context:** Phase 1A ships a working windowed visionOS app with all features (library, reader, EPUB, search, settings). SpatialNavigationState and ImmersiveSpace scene are already scaffolded. 1B fills in the spatial content: SpatialLibraryView (volumetric bookshelf), SpatialReaderView (immersive reader), SpatialBookEntity (3D book models), SpatialORPView (floating word as SwiftUI attachment), SpatialControlBar, SpatialProgressRing.
**Depends on:** Phase 1A complete and tested on visionOS simulator.
**Added:** 2026-03-26 via /plan-eng-review

## v2: Eye Tracking Pause/Resume
**What:** Use visionOS eye tracking to pause playback when the user looks away from the ORP word, and resume when they look back.
**Why:** Truly hands-free reading that only makes sense on Vision Pro. The ultimate expression of the "just look at it" input model.
**Pros:** No buttons needed. Look to read, look away to pause. Natural and delightful.
**Cons:** Requires visionOS 3+ APIs (not yet released). Privacy permission required for ARKit eye tracking. May need careful calibration to avoid false triggers.
**Context:** visionOS 3 (expected WWDC 2025) is adding eye-scrolling APIs. Need to evaluate whether these provide sufficient gaze direction data for pause/resume, or whether full ARKit eye tracking (with privacy permission prompt) is needed. Alternative: use the system's hover/focus system as a proxy — detect when the ORP view loses focus.
**Depends on:** Phase 1B complete. visionOS 3+ SDK available.
**Added:** 2026-03-26 via /plan-eng-review

## Verify .fileImporter() Regression on iOS
**What:** After migrating from DocumentPicker.swift to .fileImporter(), verify file import still works correctly on iOS.
**Why:** The .fileImporter() migration touches iOS behavior (deletes DocumentPicker.swift). While .fileImporter() is a drop-in replacement, the interaction model is slightly different (SwiftUI modifier vs UIKit wrapper).
**Pros:** Catches any regression before shipping.
**Cons:** Quick manual test, minimal effort.
**Context:** DocumentPicker.swift uses UIViewControllerRepresentable wrapping UIDocumentPickerViewController. Replaced with SwiftUI's .fileImporter(isPresented:allowedContentTypes:onCompletion:) which supports .txt, .md, and .epub UTTypes. Test: import a .txt file, import an .epub file, cancel the picker.
**Depends on:** .fileImporter() migration implemented.
**Added:** 2026-03-26 via /plan-eng-review
