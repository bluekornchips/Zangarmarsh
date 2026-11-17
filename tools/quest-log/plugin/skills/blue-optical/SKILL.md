---
name: blue-optical
description: Apply and audit optical balance in UI, icons, and layout. Use for blue-optical, optical balance, visual weight, optical alignment, corner rounding, icon grids, or keylines.
disable-model-invocation: true
---

# Blue Optical

Make interfaces look balanced to the eye, not only to the geometry grid. Cover markup, CSS, components, icons, and design assets in scope for the request. Create when building. Audit when reviewing.

Geometric equality is not optical equality. Prefer the look that reads even when the numbers do not match. An icon grid is a shared starting point for a set, not a hard rule. Drop or revise a grid line when optics or in-context tests say otherwise.

## Mode

- Create: apply the rules below while writing or editing the surface.
- Audit: walk the named surface or the current diff, report each defect, stop for approval before edits.

Done when every peer set that should feel equal does feel equal under the checks below, and every icon that ships still reads in its real container.

## 1. Visual weight

The eye judges size by area, fill, and density, not by bounding-box width and height alone.

- Circles, diamonds, triangles, birds, and other non-square marks need extra size or less padding next to squares and rectangles.
- Squarish marks need more padding inside a shared frame so they do not dominate.
- Hollow or thin marks need more size than filled or dense marks of the same box.
- A round control beside a rectangular field needs a larger diameter than the field height when both are outlined. A filled round control can match the field height.
- Color and fill count as weight. Dark or solid fills read heavier than light or outlined ones.
- Dense detail adds weight. Simplify a busy mark, or shrink it, when it steals focus from peers.

Check: blur or greyscale peer icons or controls into blobs. Matched peers should share size and density. If one blob is smaller or thinner, grow that mark or shrink its padding. Also place the set side by side without labels; if one mark anchors the row without intent, fix its weight.

## 2. Icon grids and keylines

Use a grid when drawing or auditing an icon family. Keep one canvas size per family role, such as 24 for system UI marks. Draw at that size; scale in product only when the family allows it. Prefer fewer, clearer strokes at small sizes over one master path scaled down until it muddies.

### Parts

Keep only the parts the family needs:

- Pixel grid: snap to whole pixels, or half pixels when the stroke system needs them, so marks stay sharp at the target size.
- Keyshapes: start from a circle, square, portrait rectangle, and landscape rectangle sized for equal visual area, not equal bounding boxes. Circles run larger than squares. Rectangles run longer on one axis and sit inside the live area like the circle does.
- Orthogonals: center crosses at 90 and 45 degrees for slashes and diagonals. Step to 15 or 5 degrees only when the mark needs a finer angle.
- Mask: know the final container shape. App and launcher icons often get a rounded or OEM mask after draw time; keep critical mass inside the safe area.
- Safe area and trim area: put the readable silhouette in the safe or live area. Keep the trim clear so masks and neighboring chrome do not crop meaning.

Keyshapes are molds, not targets. Some icons fill a mold; others only borrow its scale. Never force every glyph onto a basic shape.

### Defaults when the repo has no grid

Start from Material-style system proportions on a 24 canvas unless the product already defines another grid:

- Square live area about 18
- Circle diameter about 20
- Vertical rectangle about 16 by 20
- Horizontal rectangle about 20 by 16

On larger canvases, keep the same area relationships and a clear trim. Prefer even measurements. Document the family's stroke width, end caps, angle steps, and keyshape sizes next to the grid so contributors share one trailhead.

### Optics over grids

When a keyshape fit looks wrong in the set, scale or nudge off the grid until the set balances. A mark that hits the circle keyline yet reads heavy next to peers is still wrong. Test icons in native contexts: home screen, folder, notification, settings row, store listing, or the product chrome that will show them. Use a test sheet of siblings at real sizes and colors before shipping a new mark.

## 3. Alignment

Align to optical edges, not only to bounding boxes.

- Sharp points, spikes, and arrow tips should overshoot the rectangle they sit with so both read the same length or width.
- Light backgrounds on highlighted text can share the text column edge. Dense or dark backgrounds should align their outer edge with the column, with padding inside for the text.
- Light input fills may extend past labels. Bordered inputs align outer edges with labels, with content inset.
- A darker or pointed button next to rectangular fields shifts outward so it does not look short or light.
- Text on a pointed or asymmetric button shifts toward the blunt side so the label looks centered.
- Prefer cap-height vertical centering for title-case or all-caps labels. Prefer x-height when the label has both ascenders and descenders and the cap-height seat looks high.
- Center icons by equal distance from silhouette extremes to the background edge, not by the asset's rectangular sheet. For a triangle on a round or rounded control, seat an imaginary circle around the triangle, then center that circle. Nudge opposite the heavy side of an asymmetric mark.
- Leave transparent margin in the asset when handoff needs optical centering without code offsets.

## 4. Corner rounding

Default editor or CSS corner radii snap from line to arc too early. The join stays visible.

- Prefer a curve that keeps a little extra mass past a pure quarter-circle so the straight-to-curve join disappears.
- For icons and system-like tiles, prefer a superellipse, continuous corner smoothing, or manually tightened handles over a plain rounded rectangle when smooth corners matter. iOS app-icon masks follow that family of curves.
- Acute corners on maps and schemes need the same optical easing; geometric fillets look kinked.
- Circles that must look round may need slight extra mass on the sides. Eyes read height more than width, so a true geometric circle can look thin.

Check: if the eye finds the exact pixel where the side becomes the corner, the radius is still geometric. Adjust until that join is hard to point at.

## 5. Squares and stems

A square that is slightly wider than it is tall often reads more square. Vertical strokes often need more thickness than horizontal strokes of the same role. Apply when drawing marks, letters, or frames that must feel even.

## Report

For audit findings use this shape:

```text
- Site: path:line or asset name
  Class: weight | keyline | alignment | rounding | proportion
  Defect: what the eye misreads
  Remedy: the smallest optical change
```

`keyline` covers wrong canvas, ignored trim, forced keyshape fit, missing family rules, or a grid that wins over optics.

For create work, apply the remedy in the change and name each optical choice in the reply only when it is not obvious from the diff.

## Sources

- https://medium.com/design-bridges/optical-effects-9fca82b4cd9a
- https://minoraxis.medium.com/icon-grids-keylines-demystified-5a228fe08cfd

