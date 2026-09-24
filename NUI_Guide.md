# NUI Design Guide

Use this guide as the shared visual foundation for new NUI menus. Each NUI can have its own size, position, layout, content, and controls. The goal is consistent color, typography, borders, buttons, dividers, and sliders—not a fixed window template.

## Core rules

- Use **IM Fell English** for all visible NUI text.
- Do not place icons in menu titles or action buttons.
- The only button icon is `<i class="fa-solid fa-hand-point-left"></i>`, used to mark the currently selected choice in an option or setting group.
- Do not use the selection hand on buttons that immediately perform an action.
- Do not require a fixed window width, height, or screen position.
- Size and position each menu for its own content and gameplay purpose.
- Keep the shared colors, borders, gradients, shadows, dividers, sliders, and button states visually consistent.
- A window title is optional.
- When a window title is present, use the attached full-width curved top from Style 3 in `nt_western_ui_demo`.
- The curve belongs to the window shell itself and must run continuously from the upper-left corner to the upper-right corner.
- Keep the title inside the window. Never render it as a separate plaque, floating panel, overlaid box, or narrow arch above the window.
- When a window title is absent, remove the title element and use the window shell's normal top corners and padding.
- Keep every visible window element inset from the window border. Titles, dividers, lists, buttons, and other content must not touch or overlap either the outer border or the inner decorative border.
- Keep **Scale** and **Leave** at the bottom-right of every menu. Scale always opens the shared Scale window documented below.
- Always place the shared divider immediately above the bottom button row containing Back, Scale, and Leave.
- Add **Back** at the bottom-left only when the menu needs back navigation.

## Font

Load IM Fell English in the document head:

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=IM+Fell+English&display=swap" rel="stylesheet">
```

Load Font Awesome when the menu contains selectable option buttons:

```html
<link href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/7.3.1/css/all.min.css" rel="stylesheet">
```

Use it throughout the NUI:

```css
:root {
    --ui-font: "IM Fell English";
}

body,
button,
input,
textarea,
select {
    font-family: var(--ui-font), Georgia, serif;
}
```

Do not add alternate font selectors to individual menus.

## Shared colors

Use these variables as the common palette. A menu may use only the colors it needs, but should not replace them with a different theme.

```css
:root {
    --rdr-black: #000000;
    --rdr-panel: #0a0a0a;
    --rdr-panel-2: #141414;
    --rdr-leather: #1c1c1c;
    --rdr-text: #f2f2f2;
    --rdr-muted: #9a9a9a;

    --silver: #aeb5bc;
    --silver-bright: #e1e5e9;
    --silver-dim: #626970;

    --selection: #dedede;
    --selection-bg: #252525;
    --shadow: rgba(0, 0, 0, 0.88);
}
```

## Window shell

The shell should retain the dark western presentation, but its dimensions and placement belong to the individual NUI.

```css
.menu {
    position: relative;
    padding: 24px 28px 26px;
    color: var(--rdr-text);
    background: linear-gradient(180deg, #141414, #090909 58%, #000000);
    border: 2px solid var(--silver);
    border-radius: 24px;
    box-shadow:
        0 22px 60px var(--shadow),
        inset 0 0 0 5px rgba(255, 255, 255, 0.01);
}

.menu::before {
    content: "";
    position: absolute;
    inset: 9px;
    border: 1px solid rgba(215, 221, 227, 0.18);
    border-radius: 16px;
    pointer-events: none;
}
```

Set width, height, positioning, overflow, columns, and spacing in the individual resource. Do not copy a fixed demo width or screen position into every NUI.

Keep the menu's content inside the inner decorative border. Use enough menu padding for that window's controls so no title, divider, list, button, or other visible element touches the shell border.

## Optional window title and attached arch

The required title treatment is Style 3 from `resources/[test]/nt_western_ui_demo`: one continuous window whose outer top border arches from corner to corner. The title sits inside that curved part of the window.

The arch is made by changing the border radius of the complete `.menu` shell and its inner decorative border. It is **not** made by styling `.title-sign` as another bordered or filled shape.

Use this structure when the window has a title. Keep `.title-sign` as the first child inside `.menu`:

```html
<section class="menu has-title">
    <header class="title-sign">
        <div class="title">Window Title</div>
    </header>

    <!-- The rest of the window content follows here. -->
</section>
```

Use this attached, corner-to-corner arch:

```css
.menu.has-title {
    padding-top: 30px;
    border-radius: 48% 48% 24px 24px / 72px 72px 24px 24px;
}

.menu.has-title::before {
    border-radius: 48% 48% 16px 16px / 62px 62px 16px 16px;
}

.title-sign {
    position: relative;
    z-index: 2;
    width: auto;
    min-height: 0;
    margin: 0 4px 24px;
    padding: 0;
    background: none;
    border: 0;
    border-radius: 0;
    box-shadow: none;
}

.title {
    margin: 0;
    color: #ffffff;
    font-size: 36px;
    line-height: 1;
    letter-spacing: 0.06em;
    text-align: center;
    text-shadow: 0 2px 0 #000000;
}
```

Required visual behavior:

- The outer window border and inner decorative border both arch across the full window width.
- Both arches begin at their respective upper-left corner and end at their respective upper-right corner.
- The title remains centered inside the window's curved top area.
- Window content begins below the title with normal internal spacing.
- Do not position the title with negative `top`, reserve space above the window, give the title its own background or border, or place a horizontal window edge behind it.

When there is no title, omit `.title-sign`, remove `.has-title`, and do not retain the curved title area or its extra top padding.

## Divider

Keep this divider design and use it to separate major groups of content:

```html
<div class="divider">
    <span>◇ ◆ ◇</span>
</div>
```

```css
.divider {
    position: relative;
    z-index: 2;
    height: 18px;
    display: flex;
    align-items: center;
    gap: 12px;
}

.divider::before,
.divider::after {
    content: "";
    flex: 1;
    height: 1px;
    background: linear-gradient(90deg, transparent, var(--silver));
}

.divider::after {
    background: linear-gradient(90deg, var(--silver), transparent);
}

.divider span {
    color: #e4e8eb;
    font-size: 13px;
    letter-spacing: 0.16em;
    white-space: nowrap;
}
```

The divider width and margins may change to suit the menu.

## Buttons

Action buttons contain text only. Do not add icons before or after their labels. Selectable option buttons use the left-pointing hand described below.

```css
.menu-button,
.footer-button {
    border: 1px solid var(--silver-dim);
    border-radius: 3px;
    color: var(--rdr-text);
    background: linear-gradient(180deg, #252525, #101010);
    cursor: pointer;
    transition:
        border-color 0.15s ease,
        filter 0.15s ease,
        transform 0.15s ease,
        background 0.15s ease;
}

.menu-button:hover,
.footer-button:hover {
    border-color: var(--silver-bright);
    filter: brightness(1.18);
}

.menu-button.active {
    border-color: var(--silver-bright);
    background: linear-gradient(180deg, #3b3b3b, #1c1c1c);
    box-shadow: inset 0 -3px 0 #d8dde1;
}

.footer-button {
    min-width: 126px;
    min-height: 45px;
    padding: 9px 18px;
    font-size: 15px;
    letter-spacing: 0.06em;
}

.footer-button.secondary {
    color: #d2d7dc;
    background: linear-gradient(180deg, #1c1c1c, #090909);
}
```

## Selectable option buttons

When the player chooses one setting from a group, display `<i class="fa-solid fa-hand-point-left"></i>` on the currently selected option. For example, a player may select one of three available settings.

The hand communicates selection only. Do not use it on Back, Scale, Leave, Save, Buy, Confirm, or any other button that performs an immediate action.

```html
<div class="option-group" role="group" aria-label="Example setting">
    <button class="option-button" type="button" aria-pressed="false">
        <span>Option 1</span>
        <i class="fa-solid fa-hand-point-left" aria-hidden="true"></i>
    </button>

    <button class="option-button selected" type="button" aria-pressed="true">
        <span>Option 2</span>
        <i class="fa-solid fa-hand-point-left" aria-hidden="true"></i>
    </button>

    <button class="option-button" type="button" aria-pressed="false">
        <span>Option 3</span>
        <i class="fa-solid fa-hand-point-left" aria-hidden="true"></i>
    </button>
</div>
```

```css
.option-group {
    display: grid;
    gap: 9px;
}

.option-button {
    min-height: 45px;
    padding: 9px 16px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 14px;
    border: 1px solid rgba(202, 209, 216, 0.22);
    border-radius: 4px;
    color: var(--rdr-text);
    background: linear-gradient(180deg, rgba(255, 255, 255, 0.035), rgba(0, 0, 0, 0.16));
    cursor: pointer;
}

.option-button i {
    display: none;
    color: var(--silver-bright);
}

.option-button.selected {
    border-color: var(--silver-bright);
    background: linear-gradient(90deg, #303030 0%, #1c1c1c 56%, #101010 100%);
}

.option-button.selected i {
    display: block;
}
```

When selection changes, move both the `.selected` class and `aria-pressed="true"` to the newly selected option:

```js
const optionButtons = [...document.querySelectorAll('.option-button')];

optionButtons.forEach(button => {
    button.addEventListener('click', () => {
        optionButtons.forEach(option => {
            const selected = option === button;
            option.classList.toggle('selected', selected);
            option.setAttribute('aria-pressed', selected);
        });
    });
});
```

## Bottom controls

Use two groups so navigation stays on the left and the universal controls stay on the right:

```html
<div class="divider" aria-hidden="true">
    <span>◇ ◆ ◇</span>
</div>

<footer class="bottom-controls">
    <div class="bottom-left">
        <!-- Include Back only when needed. -->
        <button class="footer-button secondary" type="button">Back</button>
    </div>

    <div class="bottom-right">
        <button class="footer-button secondary" type="button">Scale</button>
        <button class="footer-button" type="button">Leave</button>
    </div>
</footer>
```

```css
.bottom-controls {
    position: relative;
    z-index: 2;
    margin-top: 20px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 20px;
}

.bottom-left,
.bottom-right {
    display: flex;
    align-items: center;
    gap: 10px;
}

.bottom-right {
    margin-left: auto;
}
```

When Back is not needed, omit its button. Scale and Leave remain aligned on the right.

## Standard slider

Preserve the current slider track, thumb, label, value display, and behavior:

```html
<div class="slider-control">
    <div class="slider-header">
        <span>Example Slider</span>
        <span id="exampleSliderValue">50</span>
    </div>

    <input id="exampleSlider" type="range" min="0" max="100" value="50">
</div>
```

```css
.slider-control {
    min-width: 0;
    padding: 9px 12px 7px;
    border: 1px solid rgba(174, 181, 188, 0.45);
    border-radius: 4px;
    background: linear-gradient(180deg, #141414, #080808);
}

.slider-header {
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    color: #d8dde1;
    font-size: 14px;
    letter-spacing: 0.04em;
}

input[type="range"] {
    width: 100%;
    height: 16px;
    appearance: none;
    -webkit-appearance: none;
    background: transparent;
    cursor: pointer;
}

input[type="range"]::-webkit-slider-runnable-track {
    height: 4px;
    border: 1px solid #555c62;
    border-radius: 4px;
    background: linear-gradient(90deg, #31363a, #111111);
    box-shadow: inset 0 1px 2px rgba(0, 0, 0, 0.8);
}

input[type="range"]::-webkit-slider-thumb {
    width: 14px;
    height: 14px;
    margin-top: -6px;
    appearance: none;
    -webkit-appearance: none;
    border: 1px solid #f1f3f5;
    border-radius: 50%;
    background: linear-gradient(180deg, #e8ecef, #888f96);
    box-shadow: 0 1px 4px #000000;
}

input[type="range"]:focus {
    outline: none;
}
```

Keep the visible value synchronized while the slider moves:

```js
const exampleSlider = document.getElementById('exampleSlider');
const exampleSliderValue = document.getElementById('exampleSliderValue');

exampleSlider.addEventListener('input', () => {
    exampleSliderValue.textContent = exampleSlider.value;
});
```

## Slider with range marks

Use the same slider design with range marks when the minimum, middle, and maximum values help the player understand the setting:

```html
<div class="slider-control">
    <div class="slider-header">
        <span>Menu Scale</span>
        <span id="scaleValue">100%</span>
    </div>

    <input id="scaleSlider" type="range" min="75" max="125" value="100">

    <div class="slider-marks">
        <span>75%</span>
        <span>100%</span>
        <span>125%</span>
    </div>
</div>
```

```css
.slider-marks {
    margin-top: 3px;
    display: flex;
    justify-content: space-between;
    color: #747b82;
    font-size: 10px;
}
```

The displayed value should include its unit when a unit is relevant, such as `%`, `$`, or a measurement.

## Scale menu behavior

The Scale button must always open the same separate Scale window shown below. Copy this window into every NUI rather than placing scale sliders inside the main menu or designing different scale controls for each script.

The Scale window must:

- Open only when the player clicks **Scale**.
- Include both **Menu Scale** and **Text Size** sliders.
- Remain fixed-size and unscaled while either slider changes the main NUI.
- Cap Menu Scale at the largest value that keeps the complete main NUI inside the screen. No menu edge may scale beyond the viewport.
- Design the menu so it fits inside the viewport at the slider's minimum scale, including the required screen inset.
- Recalculate the Menu Scale cap when the NUI opens, when its layout changes, and when the viewport size changes.
- Update both percentage labels while the sliders move.
- Close independently without closing the main NUI.
- Close automatically when the main NUI closes.
- Keep the player's selected scale values when it is closed and reopened.

Wrap all scalable menu content in `#scaleRoot`. Place `#scaleMenu` beside it, not inside it, so the Scale window is never affected by the menu transform or text-size changes:

```html
<main id="ui" class="hidden">
    <div id="scaleRoot" class="scale-root">
        <!-- The complete main menu belongs here. -->
    </div>

    <section id="scaleMenu" class="scale-menu hidden" aria-label="Scale controls">
        <div class="scale-control">
            <div class="scale-header">
                <span>Menu Scale</span>
                <span id="scaleValue">100%</span>
            </div>

            <input id="scaleSlider" type="range" min="75" max="125" value="100">

            <div class="scale-marks">
                <span>75%</span>
                <span>100%</span>
                <span>125%</span>
            </div>
        </div>

        <div class="scale-control">
            <div class="scale-header">
                <span>Text Size</span>
                <span id="textScaleValue">100%</span>
            </div>

            <input id="textScaleSlider" type="range" min="75" max="150" value="100">

            <div class="scale-marks">
                <span>75%</span>
                <span>100%</span>
                <span>150%</span>
            </div>
        </div>

        <button id="closeScaleBtn" class="footer-button" type="button">Close</button>
    </section>
</main>
```

Use `id="openScaleBtn"` on the standard Scale button in the main menu:

```html
<button id="openScaleBtn" class="footer-button secondary" type="button">Scale</button>
```

Use this shared Scale window styling in every NUI:

```css
.scale-root {
    transform: scale(1);
    transform-origin: center center;
}

.scale-menu {
    position: fixed;
    z-index: 10;
    left: 50%;
    bottom: 24px;
    transform: translateX(-50%);
    width: min(1000px, calc(100vw - 48px));
    padding: 14px;
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr) auto;
    align-items: end;
    gap: 12px;
    color: var(--rdr-text);
    background: linear-gradient(180deg, #141414, #090909 58%, #000000);
    border: 2px solid var(--silver);
    border-radius: 10px;
    box-shadow:
        0 12px 36px var(--shadow),
        inset 0 0 0 4px rgba(255, 255, 255, 0.018);
}

.scale-control {
    min-width: 0;
    padding: 9px 12px 7px;
    border: 1px solid rgba(174, 181, 188, 0.45);
    border-radius: 4px;
    background: linear-gradient(180deg, #141414, #080808);
}

.scale-header {
    margin-bottom: 5px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    color: #d8dde1;
    font-size: 14px;
    letter-spacing: 0.04em;
}

.scale-marks {
    margin-top: 3px;
    display: flex;
    justify-content: space-between;
    color: #747b82;
    font-size: 10px;
}

.hidden {
    display: none;
}

@media (max-width: 760px) {
    .scale-menu {
        grid-template-columns: 1fr;
    }
}
```

The standard slider CSS from this guide is also required.

Use this JavaScript behavior in every NUI. Capturing the original computed font sizes allows text to scale independently without requiring every script to rewrite its font-size declarations:

```js
const scaleRoot = document.getElementById('scaleRoot');
const scaleMenu = document.getElementById('scaleMenu');
const scaleSlider = document.getElementById('scaleSlider');
const scaleValue = document.getElementById('scaleValue');
const textScaleSlider = document.getElementById('textScaleSlider');
const textScaleValue = document.getElementById('textScaleValue');
const scaledText = [...scaleRoot.querySelectorAll('*')].map(element => ({
    element,
    fontSize: Number.parseFloat(getComputedStyle(element).fontSize)
}));
const viewportInset = 24;
const configuredScaleMaximum = Number(scaleSlider.max) / 100;

const getViewportScaleMaximum = () => {
    const previousTransform = scaleRoot.style.transform;
    scaleRoot.style.transform = 'scale(1)';

    const rect = scaleRoot.getBoundingClientRect();
    const transformOrigin = getComputedStyle(scaleRoot).transformOrigin
        .split(' ')
        .map(Number.parseFloat);
    const originX = transformOrigin[0];
    const originY = transformOrigin[1];
    const rightWidth = rect.width - originX;
    const bottomHeight = rect.height - originY;
    const maximums = [configuredScaleMaximum];

    if (originX > 0) maximums.push((rect.left + originX - viewportInset) / originX);
    if (rightWidth > 0) maximums.push((window.innerWidth - viewportInset - rect.left - originX) / rightWidth);
    if (originY > 0) maximums.push((rect.top + originY - viewportInset) / originY);
    if (bottomHeight > 0) maximums.push((window.innerHeight - viewportInset - rect.top - originY) / bottomHeight);

    scaleRoot.style.transform = previousTransform;
    return Math.max(Number(scaleSlider.min) / 100, Math.min(...maximums));
};

const applyMenuScale = () => {
    const requestedScale = Number(scaleSlider.value) / 100;
    const scale = Math.min(requestedScale, getViewportScaleMaximum());
    const percentage = Math.floor(scale * 100);

    scaleRoot.style.transform = `scale(${scale})`;
    scaleSlider.value = percentage;
    scaleValue.textContent = `${percentage}%`;
};

scaleSlider.addEventListener('input', () => {
    applyMenuScale();
});

textScaleSlider.addEventListener('input', () => {
    const textScale = Number(textScaleSlider.value) / 100;

    scaledText.forEach(text => {
        text.element.style.fontSize = `${text.fontSize * textScale}px`;
    });

    textScaleValue.textContent = `${textScaleSlider.value}%`;
});

document.getElementById('openScaleBtn').addEventListener('click', () => {
    applyMenuScale();
    scaleMenu.classList.remove('hidden');
});

document.getElementById('closeScaleBtn').addEventListener('click', () => {
    scaleMenu.classList.add('hidden');
});

window.addEventListener('resize', applyMenuScale);
```

When the script handles its main NUI close message, also hide the Scale window:

```js
if (event.data.action === 'close') {
    ui.classList.add('hidden');
    scaleMenu.classList.add('hidden');
}
```

Call `applyMenuScale()` after the main NUI becomes visible and after a layout change that alters its dimensions. The cap must be calculated while `#scaleRoot` is visible so its bounds are accurate.

Set only `transform-origin` for the individual menu based on where its main window is positioned. Do not move, resize, restyle, or place the shared Scale window inside `#scaleRoot`.

## Per-menu decisions

Each NUI should define these for itself:

- Window width and height
- Screen position and transform origin
- Whether a window title and attached full-width curved top are present
- Whether Back is present
- Content layout, columns, scrolling, and information panels
- Which additional controls and sliders are needed outside the shared Scale window
- Responsive behavior for its content

These differences should not change the shared font, palette, button treatment, selected-option indicator, divider design, slider design, or bottom-control placement rules.
