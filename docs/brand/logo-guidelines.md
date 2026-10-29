# Luma Industrial Marketplace - SL Logo Standard

**Status:** Approved brand standard  
**Source of truth:** The two user-approved logo images supplied for this project  
**Applies to:** Web, Flutter mobile apps, app icons, browser icons, documents, marketing, and future platform surfaces

## 1. Approved logo variants

### Primary logo — full lockup

Use the approved wide logo containing all of the following elements together:

- The market-stall emblem on the left
- The wordmark **Luma**
- The green-and-gold leaf accent above the final letter
- The gold horizontal divider
- The exact tagline **Industrial Marketplace - SL**

Use this variant where there is enough horizontal space, including website headers, desktop navigation, formal documents, presentations, marketing banners, and business-facing materials.

### Secondary logo — stall emblem only

Use the approved standalone market-stall emblem without the wordmark or tagline. Preserve the canopy, red/yellow panels, green supports, and green-and-gold geometric stall pattern.

Use this variant for app icons, favicons, compact mobile navigation, avatars where appropriate, loading indicators, and other small or square placements.

## 2. Non-negotiable consistency rules

- Treat the supplied approved images as the visual source of truth. Do not redraw, regenerate, approximate, or substitute the artwork.
- Do not alter the canopy colors, pattern geometry, supports, proportions, wordmark lettering, leaf accent, divider, or tagline wording.
- Do not stretch, skew, crop, rotate, recolor, add effects to, or rearrange the logo.
- Preserve the full primary lockup when using the primary logo. Do not remove the tagline from the primary lockup and call it the primary version.
- The secondary mark is the stall emblem only. Do not add replacement text or decorative elements to it.
- Keep sufficient clear space around each variant. Never place text or UI controls over the artwork.
- Use a background that provides clear contrast. Prefer a transparent asset over placing a white-background image on a colored surface.
- Do not recreate the logo using live text or emoji.

## 3. Placement matrix

| Surface | Required variant | Notes |
|---|---|---|
| Website / web app header | Primary | Use the full lockup when it remains legible at the available width. |
| Narrow mobile header | Secondary, or primary if legible | Never squeeze or distort the full lockup. |
| Android / iOS launcher icon | Secondary | Use a square icon canvas with safe padding; do not put the full tagline in the icon. |
| Browser favicon / pinned shortcut | Secondary | Use a simplified-size export of the exact stall artwork, not a new design. |
| Splash / loading screen | Secondary; primary if space allows | Keep the mark centered and preserve its proportions. |
| Login, registration, and onboarding | Primary where space allows | Use the same approved asset across all auth screens. |
| Admin / supplier / buyer dashboards | Primary in shared branding areas; secondary in compact navigation | All roles and modules must use the same assets. |
| Emails, PDFs, proposals, and official documents | Primary | Maintain consistent placement and clear space. |
| Social and promotional graphics | Primary or secondary according to format | Do not create a variant with changed colors or lettering. |

## 4. Asset handling and implementation

- Keep canonical brand assets in one shared location in the repository, rather than duplicating hand-edited copies across features.
- Recommended asset names:
  - `assets/branding/luma-primary.png`
  - `assets/branding/luma-stall.png`
  - `assets/branding/luma-primary.svg` (only if a faithful vector master is available)
  - `assets/branding/luma-stall.svg` (only if a faithful vector master is available)
- Use the same canonical files in every platform and feature. Reference shared asset constants or a single branding component where the stack supports it.
- Export transparent PNGs from the approved source for UI use. SVG files must be genuine, faithful vector assets—not an SVG wrapper around an unrelated or recreated logo.
- Generate platform-specific icon sizes from the approved stall-only master. Do not manually redraw the icon separately for Android, iOS, web, or desktop.
- Do not claim an asset is transparent or vector until that property has been checked.
- If an approved source asset is unavailable in a build environment, do not substitute an AI-generated approximation. Flag the missing asset and request or restore the canonical file.

## 5. Flutter and web integration checklist

- [ ] Add the approved primary and secondary source images to the shared branding asset directory.
- [ ] Declare assets in `pubspec.yaml` and centralize their paths in a shared branding helper/theme.
- [ ] Replace ad-hoc or inconsistent logos in app headers, authentication screens, onboarding, dashboards, and navigation with the approved shared asset.
- [ ] Use the secondary mark for launcher icons and favicon assets.
- [ ] Configure web manifest / favicon and native launcher assets from the same stall-only master, with appropriate sizes and padding.
- [ ] Check light and dark surfaces without recoloring the logo artwork.
- [ ] Check small-screen legibility, image scaling, safe area, and accessibility labels.
- [ ] Search the repository for old logo files, text-based substitutes, and duplicate branding implementations.
- [ ] Run formatting, analysis, tests, and platform builds after integration.
- [ ] Verify visually on web and supported mobile targets before release.

## 6. Accessibility

- For meaningful logo images, use an accessible label such as **“Luma Industrial Marketplace - SL”** for the primary logo and **“Luma market stall”** for the secondary mark.
- If the logo is purely decorative beside an equivalent visible brand name, avoid announcing duplicate text to screen-reader users.
- Do not rely on color alone to identify interactive controls; the logo itself is branding, not a control.

## 7. Change control

Any proposed logo change must be explicitly approved by the project owner and then updated in the canonical source assets and this document together. Until then, the two supplied images remain the approved masters.

## 8. Important implementation status

This document defines the required standard. It does **not** by itself mean all app screens, manifests, favicons, or native launcher icons have already been updated. Mark each implementation checklist item complete only after the code and resulting builds have been inspected and verified.
