# Species shadow calibration

Track each species individually. Anchors are visually authored projections of
perceived body mass onto the ground plane. Anatomy and pose guide the decision;
these records are not an automatic anchor-detection algorithm. Front sprites are
canonical; player placement and tilt mirror horizontally.

All dimensions below are canonical sprite pixels. Layer sizes are full width
and height, not radii. Opacity retains the global 1.15 multiplier.

## Review ledger

| Species | Anchor | Outer / middle / inner dimensions | Inner offset | Enemy tilt | Review status |
| --- | --- | --- | --- | --- | --- |
| Bulbasaur | 28, 39 | 48x16 / 39.36x13.12 / 34.72x12.64 | +2, -1.2 | 0 degrees | Preview approved and applied; user advanced to Ivysaur |
| Ivysaur | 28, 45 | 50x16 / 41x13.12 / 39x14 | 0, -1 | 0 degrees | Preview approved and applied; user advanced to Venusaur |
| Venusaur, initial live version | 29.5, 46 | 62x24 / 55x20 / 48x16 | 0, 0 | -8 degrees | Preview approved; live size rejected as too small |
| Venusaur, enlarged | 29.5, 46 | 74.4x28.8 / 66x24 / 57.6x19.2 | 0, 0 | -8 degrees | 20% enlargement authorized and applied; new screenshot awaiting user visual review |

## Coverage observations and corrections

### Bulbasaur

- The front/rear leg relationship supplied by the user guides the perceived
  stance depth for this species. Near-symmetrical extension beyond the relevant
  visible legs and no exposed shadow behind the upper-left sprite were requested.
- Anchor (33,39) was rejected as too far rearward; (28,39) was retained after
  a proposed further shift was deferred in favor of enlargement alone.
- Outer ellipse grew from 44x14 to 48x16: two pixels farther on each horizontal
  side and one pixel farther in each vertical direction, before occlusion.
- Dark interior initially covered front feet but missed rear feet. Its right
  edge was extended four pixels and its upper edge 2.4 pixels, preserving its
  left and lower extents. This became the approved asymmetric inner ring.
- Live screenshot: C:/BACKUP/gen1recomp/worker-output/bulbasaur-inner-rear-extension-fixed-origin-20260915/battle.png

### Ivysaur

- Authored for its wider, more frontal stance. The inner ellipse is 39x14,
  centered at (28,44), to cover the stance rather than a small front contact.
- Live screenshot: C:/BACKUP/gen1recomp/worker-output/ivysaur-authored-shadow-20260915-220921/battle.png
- Separate beyond-leg margin measurements were not recorded during this review;
  do not invent retrospective measurements or treat these values as universal.

### Venusaur: 20% enlargement, 2026-09-15

- Preserve the approved anchor and -8-degree stance alignment. Enlarge every
  ring together, preserving their separation and opacity.
- Outer local-axis reach grows from +/-31 to +/-37.2 horizontally and +/-12
  to +/-14.4 vertically. Inner reach grows from +/-24 to +/-28.8 and from +/-8
  to +/-9.6. Those increases broaden dark coverage as well as the feathering.
- After rotation, outer horizontal extent is approximately [-7.39,66.39] in
  sprite coordinates, versus [-1.24,60.24] before: 6.15 extra pixels per side.
  Vertical extent is [30.83,61.17], versus [33.36,58.64]: 2.53 extra pixels each
  way. These are ellipse extrema, not distances measured from a leg.
- The 1920x1080 capture renders at five screen pixels per sprite pixel:
  outer dimensions 372x144 before rotation, with about 30.7 more screen pixels
  of horizontal reach per side than the previous version.
- Visual estimate from the enemy capture: outer lateral extent about x1465 to
  x1834, compared with the visible lower-body/leg silhouette about x1510 to
  x1775. Thus roughly 45 pixels of exposed lateral coverage on the left and
  60 on the right (about 9 and 12 canonical pixels). These are approximate
  horizontal silhouette-to-extrema margins, not same-row contact measurements;
  pose and tilt affect how much feathering is visible.
- The darker region visibly extends beneath the front and rear stance; three
  bands remain visible. User acceptance of this enlargement is still pending.
- Player-side lower feathering meets the status panel and is partly occluded;
  use the enemy side to judge full ground coverage in this layout.
- Before: C:/BACKUP/gen1recomp/worker-output/venusaur-approved-stance-20260915-221815/battle.png
- After: C:/BACKUP/gen1recomp/worker-output/venusaur-coverage-plus20-20260915-222059/battle.png

### Charmander: first preview, pending review

- Authored anchor (26,43) beneath the torso/pelvis of the upright pose. The
  raised tail and flame do not pull the center away from the body's stance.
- Three concentric, unrotated layers: outer 44x18, middle 37x14, inner 30x11.
  Global opacity remains 1.15. Game settings have not been changed.
- Outer horizontal extent [4,48], vertical [34,52]; inner horizontal extent
  [11,41], vertical [37.5,48.5], all in canonical sprite coordinates.
- In the 12x preview, the visible foot silhouette spans approximately x15 to
  x36 in canonical coordinates. Outer lateral reach therefore extends about
  11 pixels left and 12 right beyond that span. These compare horizontal
  extrema, not ellipse intersections at the individual foot rows.
- Visually, both feet fall within the dark interior, with three separate
  feather bands exposed below and beside them. Tail-base coverage is partial;
  the raised flame is not treated as a ground contact. Live appearance and
  animation have not yet been reviewed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmander-shadow-preview.png

### Charmander: second preview, pending review

- User feedback: first preview was a tiny bit large and needed to move forward.
- Reduce every layer dimension by 5%; move anchor one pixel toward the head
  (left in the canonical front view), from (26,43) to (25,43).
- Layers: 41.8x17.1 / 35.15x13.3 / 28.5x10.45. Rotation remains zero;
  opacity is unchanged. Both visible feet still sit within the dark interior.
- Outer horizontal extent is now [4.1,45.9]. Relative to the approximate
  foot span [15,36], lateral margins are 10.9 left and 9.9 right. Compared
  with the first preview, left reach retreats 0.1 pixel and right reach
  retreats 2.1 pixels. This is a deliberate forward shift, not a new
  automatically measured anchor. Game settings remain unchanged.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmander-shadow-preview-v2.png

### Charmander: third preview approved and applied

- User clarified that forward means DOWN toward the viewer, not toward the
  head or horizontally right. The second preview's leftward shift was rejected;
  the subsequent suggestion to shift right was also rejected and never rendered.
- Restore original X=26 and shift original Y=43 down to 44. Keep the 5%
  reduction: layers 41.8x17.1 / 35.15x13.3 / 28.5x10.45, zero tilt.
- Outer extent is X [5.1,46.9], Y [35.45,52.55]. Compared with the original,
  the upper edge moves down 1.45 pixels and lower edge moves down 0.55 pixels
  because the one-pixel translation combines with the size reduction.
- Approximate lateral margins relative to the previously recorded foot span
  are 9.9 left and 10.9 right. Both feet remain within the dark interior.
- User approved implementation of this preview. Applied to both battle sides
  through shared species settings, with the existing player-side mirroring.
  Lua syntax check passed. No live driver, screenshot capture, or visual
  validation was performed for this implementation, as explicitly requested.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmander-shadow-preview-v3.png

### Charmeleon: first preview, pending review

- User requested the same concept with a slightly larger shadow. All three
  dimensions are 10% larger than approved Charmander, preserving layer ratios
  and opacity: 45.98x18.81 / 38.665x14.63 / 31.35x11.495.
- Authored anchor (27,46), zero tilt, beneath the pelvis and upright stance of
  Charmeleon's own sprite. The raised tail/flame does not determine its center.
- Outer extent X [4.01,49.99], Y [36.595,55.405]. Compared with Charmander's
  outer ellipse, local-axis reach grows 2.09 pixels horizontally per side and
  0.855 vertically per side. Anchor differences are pose-specific placement.
- Visible foot span in this preview is approximately X [14,43], giving about
  10 pixels of outer lateral margin to the left and 7 to the right. These are
  horizontal-extrema comparisons, not same-row ellipse/foot measurements.
  Both feet have dark coverage; three feather bands are visible below them.
- Preview only; no game settings changed or live validation performed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmeleon-shadow-preview.png

### Charmeleon: second preview, pending review

- User requested moving forward: down toward the viewer, as previously clarified.
- Move anchor from (27,46) to (27,47). Retain all three layer dimensions,
  horizontal position, zero tilt and opacity from the first preview.
- Outer vertical extent moves from [36.595,55.405] to [37.595,56.405]; horizontal
  extent and lateral margins are unchanged. All three rings move down together.
- Both feet retain dark coverage in the preview. Added two pixels of canvas
  below the 56x56 sprite to avoid clipping the feathering; sprite scale is unchanged.
- Preview only; no game settings changed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmeleon-shadow-preview-v2.png

### Charmeleon: third preview approved and applied

- User requested exactly one pixel right. Anchor moves from (27,47) to (28,47).
  All ring dimensions, Y placement, tilt and opacity remain unchanged.
- Outer X extent is now [5.01,50.99]; approximate lateral margins relative to
  the previously recorded foot span [14,43] are 8.99 left and 7.99 right.
- User approved implementation and requested a pause. Applied shared species
  settings for both battle sides: anchor (28,47), layers 45.98x18.81 /
  38.665x14.63 / 31.35x11.495, zero tilt and unchanged opacity.
- Lua syntax check passed. No live driver or visual validation performed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charmeleon-shadow-preview-v3.png

### Charizard: first preview, pending review

- Authored anchor (30,51) beneath the perceived pelvis/body mass of this
  grounded front pose. Raised wings and tail inform the pose but do not set
  the anchor or force a hovering shadow.
- Three concentric layers: 54x20 / 46x16 / 38x12; zero tilt and unchanged
  opacity. Outer width is about 17% larger than approved Charmeleon.
- Outer extent X [3,57], Y [41,61]; inner extent X [11,49], Y [45,57].
- Visible foot span is approximately X [12,45] in the preview: outer lateral
  margins are about 9 pixels left and 12 right when comparing horizontal
  extrema. Both feet sit within the dark interior; three bands remain visible
  below the body. These are visual estimates, not automatic anchor inputs.
- Canvas has eight pixels of padding on every side to display the full shadow.
- Preview only; game settings unchanged, live appearance not yet reviewed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charizard-shadow-preview.png

### Charizard: second preview, pending review

- User feedback: first shadow was too small and needed to move forward/down.
- Enlarge all three layer dimensions 15% and move anchor two pixels down,
  from (30,51) to (30,53). Layers: 62.1x23 / 52.9x18.4 / 43.7x13.8.
  Horizontal placement, zero tilt and opacity remain unchanged.
- Outer extent X [-1.05,61.05], Y [41.5,64.5]. Each lateral edge extends
  4.05 pixels farther; the lower edge extends 3.5 pixels downward versus v1.
- Using the previously estimated foot span [12,45], outer lateral margins
  are about 13.05 left and 16.05 right (horizontal extrema, not contact-row
  measurements). The darker interior also expands, not just outer feathering.
- Recurring feedback on upright species: initial ground projection has been
  too high; Charmander, Charmeleon and Charizard all needed movement DOWN
  toward the viewer. Consider this visual evidence in subsequent previews,
  while continuing to author each species independently.
- Preview only; game settings unchanged.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0a833-18d5-7131-9981-bbfd84c5f5fe/charizard-shadow-preview-v2.png

### Charizard: third preview approved and applied

- User rejected the previous visual section separation and requires three
  clearly visible sections when resizing or repositioning the shadow.
- Keep anchor (30,53), outer size 62.1x23, zero tilt and existing opacity.
  Restore original concentric 100% / 82% / 64% dimensions: 62.1x23 /
  50.922x18.86 / 39.744x14.72. This changes ring spacing only; do not label it
  as a uniform resize of v2. Outer coverage is unchanged.
- Inner horizontal radius is 19.872; middle radius 25.461; outer radius 31.05.
  Each exposed lateral band is 5.589 pixels wide at the horizontal centerline.
- User approved implementation. Applied shared species settings for both battle
  sides: anchor (30,53), outer 62.1x23, middle 50.922x18.86, inner
  39.744x14.72, zero tilt and unchanged opacity. The three sections retain
  the 100% / 82% / 64% spacing requested by the user.
- Lua syntax check passed. No live driver or screenshot validation was run at
  the time of implementation.
- Live validation capture completed after implementation with the targeted
  Yellow driver and active settings: driver PASS, both sides CHARIZARD,
  shadowCount=2, alphaScale=1.15, screenshot:
  C:/BACKUP/gen1recomp/worker-output/charizard-approved-validation-20260916-083212/battle.png
- Enemy-side visual acceptance remains pending. The player-side lower feathering
  is partly occluded by the status panel in this battle layout.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0aa5f-ed31-7a42-b437-b9fcedeb93c7/charizard-three-sections-v3.png

### Charizard: re-authored independent-sections preview, pending review

- The prior Charizard geometry is superseded and must not be used as a template.
  This preview was reevaluated from the front sprite under the hard constraint
  that each section is authored independently.
- Authored ground projection: anchor (30,53), beneath the grounded leg/body
  stance. The wings and tail inform body volume but do not pull the anchor.
- Three sections are independently placed: outer center (30,53), size 64x22;
  middle center (30.5,52.6), size 53x18; inner center (30.5,52), size 45x14.
  No inherited section ratio was used. Opacity retains the global 1.15 multiplier.
- Canonical extents: outer [-2,62] x [42,64], middle [4,57] x [43.6,61.6],
  inner [8,53] x [45,59]. These are ellipse bounds, not detected anchor data.
- The inner section spans the grounded foot area while the outer sections extend
  beyond the full perceived body depth. The three boundaries remain visibly
  separated; no upper-left shadow spill is introduced.
- Preview only. Charizard settings were not changed and live validation was not
  run. Visual acceptance is pending.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0aa63-9beb-7483-92e8-ff82423ea074/charizard-shadow-independent-sections-preview.png

### Charizard: fresh independent preview rejected

- This attempt was drawn from the raw Crystal front sprite, but the resulting
  section proportions recreated the previously discarded visual relationship.
  The preview is rejected and is not valid calibration data.
- Authored ground projection: anchor (29,53), beneath the grounded leg/body
  stance. The wings and tail inform the silhouette but do not determine the
  ground point.
- Three sections were rendered, but their proportions were not sufficiently
  independent. Do not reuse their dimensions, centers, or coverage as input.
- Canonical ellipse bounds: outer [-5,63] x [41.5,64.5], middle [2,56] x
  [44.3,61.3], inner [7.5,50.5] x [45.85,59.35]. These are authored bounds,
  not automatic anchor measurements.
- Preview rejected by the user. No game settings or renderer files were changed.
- Preview: C:/Users/James/.codex/visualizations/2026/09/16/01a0aa63-9beb-7483-92e8-ff82423ea074/charizard-shadow-fresh-independent-preview.png

## What to record for the next species

1. Manually identify the body volume and pose evidence used to place its anchor.
2. Record anchor, tilt, dimensions and offsets of each of the three rings.
3. Inspect dark coverage beneath the relevant supports, exposed margins toward
   the front/rear, unwanted upper-left spill, and separation of all three rings.
4. Record approximate visible margins with units and screenshot/frame context;
   keep geometric ellipse extents distinct from observed beyond-body coverage.
5. Record the user's correction, resulting change, screenshot and review status.
   A successful driver run does not establish visual approval or animation stability.

Lesson so far: a large isolated preview can still look too small in battle.
Track live coverage before choosing the next species' initial size. Use prior
species as visual references, never as a universal anchor or feet rule.
