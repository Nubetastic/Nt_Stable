# Nt UI Guide

Shared front-end style notes for Nt script NUI screens. Use the current `Nt_Trader` UI as the reference when building or restyling another resource.

The goal is a readable Old West interface that feels consistent across scripts without becoming too decorative or hard to scan.

## Basics

- Show the actual tool or information screen first. Do not add a landing page.
- Use one main framed panel per screen.
- Keep controls in the upper-right header.
- Use inventory pictures whenever they help players recognize items.
- Use additional screens for guides, details, or settings, with clear buttons to move back and forth.
- Keep text readable at smaller resolutions.
- Let players adjust scale, but default to `100%`.

## Font

Use Special Elite for all visible UI text.

```css
@import url('https://fonts.googleapis.com/css2?family=Special+Elite&display=swap');

:root {
  font-family: "Special Elite", Georgia, "Times New Roman", serif;
}
```

Suggested sizes:

| Text | Size |
| --- | --- |
| Main title | `24px` |
| Buttons | `14px` |
| Header subtitle | `15px` |
| Table data | `16px` |
| Table headers | `14px` |
| Guide card title | `18px` |
| Guide text | `15px` |
| Compact labels | `13px` or `14px` |

Avoid decorative display fonts in shared Nt UI. Special Elite gives the western feel while staying easy to read.

## Colors

Use the shared dark panel, gold trim, warm text, green positive values, and red warning colors.

```css
:root {
  --gold: #d9bd7d;
  --gold-soft: #ead7ac;
  --text: #eee2c5;
  --muted: #bdb29c;
  --panel: rgba(28, 24, 18, 0.97);
  --panel-deep: rgba(13, 12, 10, 0.97);
  --line: rgba(220, 194, 139, 0.72);
  --line-soft: rgba(220, 194, 139, 0.3);
  --control: #2b251c;
  --control-hover: #453824;
  --danger: #e77a66;
  --danger-bg: rgba(91, 30, 19, 0.32);
  --success: #7de18a;
}
```

Use `--gold` for titles, active controls, headings, and important labels. Use `--text` for normal text and `--muted` for secondary text. Do not make everything gold.

## Panel Size

The standard large panel can use the trader default:

```css
.nt-panel {
  width: min(1416px, 92vw);
  max-height: 84vh;
  min-height: min(810px, 78vh);
  border: 1px solid var(--line);
  border-radius: 5px;
  background: linear-gradient(180deg, var(--panel), var(--panel-deep));
  box-shadow: 0 8px 30px rgba(0, 0, 0, 0.68);
  transform: scale(var(--ui-scale));
  transform-origin: center center;
}
```

Smaller scripts may use a smaller panel, but should keep the same border, colors, radius, shadow, and header style.

Keep the page transparent:

```css
html,
body {
  width: 100%;
  height: 100%;
  margin: 0;
  overflow: hidden;
  background: transparent !important;
}
```

## Header And Buttons

Every screen should have a header with the title/subtitle on the left and controls on the right.

Common controls:

- `Scale`
- `How To`
- `Back`
- `Close`

Buttons should be simple, square, and readable:

```css
.panel-action,
.panel-close {
  min-height: 38px;
  border: 1px solid #776a50;
  border-radius: 3px;
  color: var(--gold-soft);
  background: var(--control);
  cursor: pointer;
  font-size: 14px;
  font-weight: 700;
  letter-spacing: 0.05em;
}
```

Use `How To` to open a guide screen. Use `Back` to return from that screen without closing the NUI. Keep a close button available on every screen, and keep Escape working.

## Additional Screens

If a UI needs help, details, settings, previews, or a second mode, make it another screen inside the same NUI.

Expected behavior:

1. The main screen opens first.
2. A header button opens the extra screen.
3. The extra screen keeps the same panel, header, scale control, and close button.
4. A `Back` button returns to the previous/main screen.
5. Escape closes the NUI from any screen.

Guide screens can use short steps, small cards, inventory images, galleries, and warning bands.

## Inventory Pictures

Use real inventory PNGs when possible. They help players recognize goods, tools, weapons, ingredients, or rewards faster than text alone.

Rules:

- Prefer resource inventory PNGs over generic symbols.
- Use `object-fit: contain`.
- Keep item pictures consistently sized.
- Add a subtle drop shadow for transparent PNGs.
- Use meaningful `alt` text in guide content.
- Use empty `alt=""` only when the adjacent text already names the item.
- Include image paths in `fxmanifest.lua`, usually with `imgs/*.png`.

Reference sizes:

| Use | Size |
| --- | --- |
| Table item icon | `38px x 38px` |
| Guide step image | `58px x 58px` inside a `74px` frame |
| Gallery image | `64px x 64px` |

## Scale

Scale controls should default to `100%`, have a configured range from `50%` to `200%`, and move in `5%` steps. The effective maximum must be reduced when necessary so the scaled panel stays slightly inside both the viewport width and height.

```html
<label class="scale-control">
  <span>Scale</span>
  <input class="scale-slider" type="range"
         min="0.50" max="2.00" step="0.05" value="1.00"
         aria-label="Scale interface">
  <output class="scale-value">100%</output>
</label>
```

```js
const scaleStorageKey = 'nt_resource_ui_scale';
const defaultUiScale = 1;
```

Use a unique local storage key per resource, such as `nt_trader_ui_scale`. If multiple screens have scale sliders, update all sliders and percentage outputs together.

### Viewport-aware maximum

Never allow scaling to make the NUI larger than the player's screen. Leave a small safety margin around every edge so the scale control and close button remain reachable. The current Nt standard uses `94%` of the viewport, leaving a `3%` margin on each side.

Calculate the maximum from the active panel's unscaled dimensions:

```js
const widthScale = (window.innerWidth * 0.94) / panel.offsetWidth;
const heightScale = (window.innerHeight * 0.94) / panel.offsetHeight;
const viewportMax = Math.min(2, widthScale, heightScale);
const maxScale = Math.max(0.5, Math.floor((viewportMax + Number.EPSILON) / 0.05) * 0.05);
```

Apply `maxScale` to every scale slider's `max` attribute and clamp the selected value to it. This clamp also applies to values restored from local storage.

Recalculate the maximum:

- After the NUI becomes visible, so the panel has measurable dimensions.
- When switching between NUI screens.
- Whenever the browser viewport is resized.

Use `offsetWidth` and `offsetHeight` for the calculation because they report the panel's layout dimensions without its CSS scale transform.

## Responsive Rules

At smaller widths:

- Reduce outer padding.
- Allow the panel to use most of the viewport.
- Stack the header vertically if needed.
- Wrap header controls.
- Give the scale control its own row.
- Collapse guide grids to one column.
- Check that button text, item names, and percentage text do not overflow.

## Checklist

- Special Elite is used for all text.
- Shared colors are used.
- Page background is transparent.
- Main panel uses the standard dark panel style.
- Header controls are in the upper-right.
- Additional screens use `How To`, `Back`, close, and Escape behavior.
- Inventory pictures are used when helpful.
- Image files are included in `fxmanifest.lua`.
- Scale defaults to `100%`.
- Scale supports `50%` through `200%` when the panel fits within the viewport.
- The effective maximum is clamped against both viewport width and height with a safety margin.
- The slider maximum and selected or restored scale are clamped when the viewport limit changes.
- Scale is cached with a resource-specific local storage key.
- Text and controls do not overlap at smaller widths.

## Reference

Current reference files:

- `html/Trader.html`
- `html/Trader.css`
- `html/Trader.js`

When the reference UI and this guide differ, update the guide intentionally after deciding which behavior should become the shared Nt standard.
