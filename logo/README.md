# svyexpo logo

## The idea

A grid of raster cells forms a disc. Each cell is scaled by how much of the
buffer circle covers it: full cells at the centre, shrinking cells at the
edge. This is coverage-weighted extraction, the step svyexpo performs when it
summarises a raster inside a cluster buffer. In the colour versions, fully
covered cells are the main colour and partly covered cells are amber.

## Files

| File | Use |
|---|---|
| `sticker.svg`, `png/sticker-1040.png` | Hex sticker (colour). README, site, slides, posters |
| `sticker-mono.svg` | One-colour sticker, black on transparent |
| `symbol-colour.svg` | Symbol on light backgrounds |
| `symbol-colour-on-dark.svg` | Symbol on dark backgrounds |
| `symbol-black.svg`, `symbol-white.svg` | One-colour symbol |
| `symbol-small.svg` | Simplified cut for 16 to 32 px (favicons, tiny icons) |
| `lockup-colour.svg`, `lockup-black.svg`, `lockup-white.svg` | Symbol and wordmark side by side |
| `favicon-tile.svg`, `app-icon.svg` | Rounded favicon tile and square app icon |
| `avatar.svg`, `png/avatar-500.png` | GitHub avatar (survives a circular crop) |
| `png/social-preview-1280x640.png` | GitHub repository social preview |
| `build_kit.py` | Script that generates the SVGs from one definition |

The sticker used by the package is `man/figures/logo.png`, and the website
favicons are in `pkgdown/favicon/`.

## Colour

| Name | HEX | RGB | Use |
|---|---|---|---|
| Teal | `#0F3D4C` | 15, 61, 76 | Background, symbol on light |
| Amber | `#F2B544` | 242, 181, 68 | Partial cells and border on dark |
| Amber (dark) | `#C47F00` | 196, 127, 0 | Partial cells on light |
| White | `#FFFFFF` | 255, 255, 255 | Full cells on dark |

Contrast (WCAG): white on teal 11.7:1; amber on teal 6.4:1; teal on white
11.7:1; dark amber on white 3.3:1. Dark amber is suitable for graphic marks
only, not for text.

## Use

- **Minimum size.** Use the full symbol at 32 px or larger. Below that, use
  `symbol-small.svg` (down to 16 px). The sticker should not be printed
  smaller than 20 mm wide.
- **Clear space.** Keep at least one full-size cell of empty space around the
  symbol, and half the sticker's border width around the sticker.
- **One colour.** Use the black or white versions on photographs or when
  printing in one colour.
- **Do not** recolour the cells, change the number of cells, stretch or rotate
  the mark, add shadows or outlines, or place it on a background with low
  contrast.

## Notes

- The wordmark is set in Inter Bold (SIL Open Font License) and is converted
  to outlines, so the SVG files contain no live text.
- No trademark or reverse-image search has been done. Check before using the
  mark commercially.
- To change the mark, edit `build_kit.py` and rerun it. The script expects the
  Inter font at the path set at the top of the file.
