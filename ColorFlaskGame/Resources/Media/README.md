# Media Resources

Use this folder for source and reference media files. Files here are not part of
the app bundle unless they are also exported into `Resources/Assets.xcassets`.

## Runtime Assets

Runtime images, colors, and app icons must live in `Assets.xcassets`.

Current runtime exports:
- `GameBackground.imageset/Background.png` comes from `Images/Background.png`.
- `ResetButton.imageset/preview.png` comes from `Images/Button reset.pxo`.
- `FlaskBottle.imageset/FlaskBottle.png` comes from `Images/Flask.pxo`.

## Source Assets

- `Images/`: source `.pxo` files, reference images, exported PNG/JPG/WebP files,
  backgrounds, textures, and UI element drafts.
- `Music/`: longer audio tracks such as menu music or gameplay loops.
- `Sounds/`: short effects such as taps, pours, wins, errors, and transitions.

Keep editable source files here, then export optimized runtime assets into
`Assets.xcassets`. Prefer short, lowercase runtime file names with hyphens, for
example `pour-loop.wav`.
