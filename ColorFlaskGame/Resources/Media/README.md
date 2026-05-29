# Media Resources

Use this folder for source and reference media files. Files here are not part of
the app bundle unless they are also exported into `Resources/Assets.xcassets`.

## Runtime Assets

Runtime images, colors, and app icons must live in `Assets.xcassets`.

Current runtime exports:
- `GameBackground.imageset/Background.png` comes from `Images/Background.png`.

Current SwiftUI-generated components:
- Reset, Hint, Undo, and Menu controls are rendered in SwiftUI for a shared
  visual language.
- Gameplay flasks are rendered in SwiftUI from procedural bottle shapes.

## Source Assets

- `Images/`: source `.pxo` files, reference images, exported PNG/JPG/WebP files,
  backgrounds, textures, and UI element drafts.
- `Music/`: longer audio tracks such as menu music or gameplay loops.
- `Sounds/`: short effects such as taps, pours, wins, errors, and transitions.

Keep editable source files here, then export optimized runtime assets into
`Assets.xcassets`. Prefer short, lowercase runtime file names with hyphens, for
example `pour-loop.wav`.
