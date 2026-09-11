---
name: Aura Acoustic
colors:
  surface: '#0b1326'
  surface-dim: '#0b1326'
  surface-bright: '#31394d'
  surface-container-lowest: '#060e20'
  surface-container-low: '#131b2e'
  surface-container: '#171f32'
  surface-container-high: '#222a3d'
  surface-container-highest: '#2d3449'
  on-surface: '#dae2fc'
  on-surface-variant: '#c6c6cc'
  inverse-surface: '#dae2fc'
  inverse-on-surface: '#283044'
  outline: '#909096'
  outline-variant: '#46464c'
  surface-tint: '#c2c6da'
  primary: '#c2c6da'
  on-primary: '#2b303f'
  primary-container: '#0a0f1d'
  on-primary-container: '#777b8d'
  inverse-primary: '#595e6f'
  secondary: '#bdf4ff'
  on-secondary: '#00363d'
  secondary-container: '#00e3fd'
  on-secondary-container: '#00616d'
  tertiary: '#ffb3b3'
  on-tertiary: '#680016'
  tertiary-container: '#2a0004'
  on-tertiary-container: '#f21d45'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#dee2f6'
  primary-fixed-dim: '#c2c6da'
  on-primary-fixed: '#161b2a'
  on-primary-fixed-variant: '#424657'
  secondary-fixed: '#9cf0ff'
  secondary-fixed-dim: '#00daf3'
  on-secondary-fixed: '#001f24'
  on-secondary-fixed-variant: '#004f58'
  tertiary-fixed: '#ffdad9'
  tertiary-fixed-dim: '#ffb3b3'
  on-tertiary-fixed: '#40000a'
  on-tertiary-fixed-variant: '#920023'
  background: '#0b1326'
  on-background: '#dae2fc'
  surface-variant: '#2d3449'
typography:
  display-lg:
    fontFamily: Inter
    fontSize: 48px
    fontWeight: '700'
    lineHeight: 56px
    letterSpacing: -0.02em
  headline-lg:
    fontFamily: Inter
    fontSize: 32px
    fontWeight: '600'
    lineHeight: 40px
    letterSpacing: -0.01em
  headline-md:
    fontFamily: Inter
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  body-lg:
    fontFamily: Inter
    fontSize: 18px
    fontWeight: '400'
    lineHeight: 28px
  body-md:
    fontFamily: Inter
    fontSize: 16px
    fontWeight: '400'
    lineHeight: 24px
  label-caps:
    fontFamily: Inter
    fontSize: 12px
    fontWeight: '600'
    lineHeight: 16px
    letterSpacing: 0.1em
  headline-lg-mobile:
    fontFamily: Inter
    fontSize: 28px
    fontWeight: '600'
    lineHeight: 36px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  base: 8px
  container-padding: 20px
  gutter: 16px
  stack-sm: 4px
  stack-md: 12px
  stack-lg: 24px
---

## Brand & Style

The design system is centered on the concept of "Protective Intelligence." It targets a high-stakes user base requiring reliable, real-time acoustic monitoring for personal safety. The aesthetic is a fusion of **Glassmorphism** and **High-Fidelity Dark Mode**, creating a UI that feels like a premium surveillance instrument rather than a standard consumer app.

The personality balances two states:
1.  **Passive Monitoring:** Calm, unobtrusive, and reassuring. It utilizes deep midnight tones and subtle cyan glows to signal health and connectivity.
2.  **Active Alert:** Urgent, authoritative, and high-contrast. When a threat is detected, the UI shifts to obsidian black with vibrant crimson accents to command immediate attention and action.

Visual depth is achieved through translucent layers, background blurs, and hairline-thin borders that mimic advanced sensor technology interfaces.

## Colors

The palette is divided into functional states to ensure cognitive clarity during emergencies.

**Passive State (Standard):**
- **Background (Deep Midnight):** `#0A0F1D` — The foundational canvas.
- **Surface (Dark Slate):** `#131B2E` — Used for cards and secondary layers.
- **Accent (Electric Cyan):** `#00E5FF` — Signals "Safe" status, active audio waves, and connectivity.

**Triggered State (Alert):**
- **Background (Obsidian):** `#05070B` — Deepened contrast to make alerts pop.
- **Accent (Vivid Crimson):** `#FF2A4D` — High-urgency alert color for detected threats.
- **Secondary Alert (Neon Red):** `#FF0000` — Used for critical pulse animations.

**Gradients & Glows:**
- Use radial gradients of Electric Cyan (15% opacity) behind monitoring icons to simulate a "sensor aura."
- Use Crimson blurs (20% opacity) at the screen edges during active alerts.

## Typography

This design system uses **Inter** exclusively to maintain a clean, technical, and highly legible appearance. The weight distribution favors Medium and Semi-Bold to ensure text remains sharp against dark, blurred backgrounds.

- **Display & Headlines:** Use tighter letter-spacing and heavier weights to create an authoritative "command center" feel.
- **Labels:** Small labels use uppercase with increased tracking (letter-spacing) to mimic technical readouts on a digital dashboard.
- **Readability:** All body text should maintain a minimum of 4.5:1 contrast ratio against the glassmorphic backgrounds.

## Layout & Spacing

This design system follows a **Dynamic Fluid Grid** optimized for one-handed mobile use. The interface prioritizes a central "Acoustic Aura" visualization, with supplementary data appearing in floating glassmorphic cards.

- **Margins:** 20px horizontal page margins.
- **Rhythm:** An 8px linear scale. Most vertical gaps between related items should be 12px or 24px.
- **Safe Areas:** Ensure interactive elements (buttons) are at least 48px from the bottom edge to avoid conflict with OS-level home indicators.
- **Reflow:** On tablets, the layout transitions from a single stack to a two-column dashboard, keeping the primary acoustic monitor on the left and the event log on the right.

## Elevation & Depth

Hierarchy is established through **translucency and backdrop blurs** rather than traditional drop shadows.

1.  **Level 0 (Base):** Deep Midnight (#0A0F1D).
2.  **Level 1 (Cards):** Dark Slate (#131B2E) at 60% opacity with a 20px backdrop blur and a 1px solid border (#FFFFFF, 10% opacity).
3.  **Level 2 (Active Elements):** Glass layers with a subtle internal glow effect (inner shadow) to simulate depth.
4.  **Hairline Borders:** Use 0.5px to 1px borders on all floating cards. In passive state, the border is white at 10% opacity. In alert state, the border shifts to Crimson at 40% opacity.

## Shapes

The shape language is smooth and modern.
- **Primary Cards:** 24px corner radius (`rounded-xl` equivalent). This provides a friendly, approachable feel to counter the intensity of the safety subject matter.
- **Interactive Controls:** Buttons and input fields use a 16px radius for a slightly sharper, more functional look.
- **Acoustic Waveforms:** Lines and shapes in visualizations should be rounded/anti-aliased to feel fluid and organic.

## Components

**Buttons:**
- **Primary:** Glassmorphic fill with an Electric Cyan glow. Text is white.
- **Emergency:** Solid Vivid Crimson (#FF2A4D) with a pulsing outer glow.
- **Ghost:** Hairline border only (10% white) with no fill.

**Acoustic Visualizer:**
- A central, circular element using multiple concentric rings of varying opacities.
- Waves pulse outward from the center based on decibel input.

**Alert Cards:**
- High-contrast black backgrounds.
- Iconography in Crimson.
- Integrated "Haptic Feedback" trigger instructions.

**Chips/Indicators:**
- Small, pill-shaped badges with 50% opacity backgrounds.
- Used for "Status: Monitoring" or "Environment: High Noise" labels.

**Input Fields:**
- Minimalist design. Only a bottom 1px border that glows Cyan when focused.
- Placeholder text in Slate grey.