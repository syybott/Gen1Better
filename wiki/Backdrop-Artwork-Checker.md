# Backdrop Artwork Checker

The artwork checker helps you prepare a backdrop for Gen1Better's 320×180 stage. It checks the export, measures pixel patterns, and gives you a **PERFECT**, **PASS**, **WARN**, or **FAIL** result with reasons.

Use the result to find things to inspect in your artwork. The grade measures the checker's pixel-art targets; your composition, storytelling, and art direction remain yours. A grade does not prove how the artwork will look in-game.

The script is [tools/verify_backdrop.py](https://github.com/syybott/Gen1Better/blob/main/tools/verify_backdrop.py). This guide describes its current behavior.

## Prepare and run

Supply a **320×180 PNG with a fully opaque background**. This checker is for backdrops; transparent character and prop images belong to a different workflow.

From your Gen1Better folder, install Pillow and NumPy, then check your image:

```bash
python -m pip install Pillow NumPy
python tools/verify_backdrop.py "path/to/my_scene_320.png"
```

You can check several files or a folder:

```bash
python tools/verify_backdrop.py "path/to/forest_320.png" "path/to/cave_320.png"
python tools/verify_backdrop.py "path/to/backdrops"
```

A folder scan checks its immediate files. It does not descend into subfolders. PNG, JPG, JPEG, and WebP filenames are collected; a non-PNG file fails the PNG signature check.

Missing target paths print a warning and are skipped. If no files are found, the command exits with an error. If other files are found, the skipped path does not itself count as a graded failure.

## Understand the grades

| Grade | What it means for your next step |
| --- | --- |
| **PERFECT** | Meets the checker's strongest pixel-art targets. Inspect the artwork and try it in your scene. |
| **PASS** | Meets the ordinary pixel-art targets and format requirements. Continue with scene integration. |
| **WARN** | Meets the hard export requirements but one or more measurements deserve a closer look. Read the reasons before deciding whether to adjust the artwork. |
| **FAIL** | Breaks an export requirement or exceeds a severe pixel-quality or comparison threshold. Read the reasons to distinguish an export problem from a style or comparison issue. |

A WARN is accepted in an ordinary run. **Strict mode** treats WARN as a command failure as well.

A FAIL caused by a pixel-quality measurement does not mean the image is technically unreadable. It means that measurement is outside the checker's intended pixel-art targets.

### What the measurements mean

| Measurement | What the checker measures | How to read it |
| --- | --- | --- |
| `flat_adj` | The average percentage of identical neighboring RGB pixels horizontally and vertically | Higher values indicate more repeated, flat-color areas. Texture and small details can lower it. |
| `aa_ramp` | The average rate of horizontal and vertical three-pixel patterns whose center color lies at least two intensity levels inside the neighbors' range in every RGB channel | It looks for patterns associated with interpolation and smoothing. It is a heuristic, not a complete blur detector. |
| `unique_colors` | The number of distinct RGB colors in the image's 57,600 pixels | A large count can indicate smoothing, gradients, or color noise. It does not explain why the colors are there. |
| Minimum alpha | The smallest alpha value found by the supported transparency inspection | Fully opaque alpha is 255. Detected values below 255 cause FAIL. |
| `native_MAE` | Optional mean absolute RGB difference between the supplied counterpart and your backdrop enlarged to that counterpart's resolution with nearest-neighbor sampling | Zero means identical RGB values at that resolution. Smaller values mean a closer match. This comparison affects the grade. |
| `4K_3840x2160_MAE` | The difference after both images are compared at 3840×2160. The summary labels this `4K_MAE`. | A separate inspection value; it does not determine the grade |
| `block_std` | Average color variation inside counterpart blocks corresponding to source pixels, when the counterpart's width and height are divisible by 320 and 180 | Zero means each such block is uniform. This value does not determine the grade. |

MAE uses color intensity levels from 0 to 255. It is not a percentage.

The horizontal and vertical components are printed separately so you can see whether a pattern is stronger in one direction

### Exact grading thresholds

The checker uses raw measurements for grading, before rounding them for display

**Hard requirements:** a readable PNG, exactly 320×180, a 16:9 aspect ratio, the expected integer dimensions at the listed display sizes, and fully opaque alpha as detected by the checker

The classifier checks FAIL first. Any of these severe conditions produces FAIL:

| Measurement | FAIL condition |
| --- | --- |
| AA ramp rate | Greater than **13.5%** |
| Combined AA and low flat adjacency | AA greater than **12.5%**, together with flat adjacency below **3.5%** |
| Unique RGB colors | More than **35,000** |
| Counterpart native MAE, when available | Greater than **8.0** |

If no failure applies, the ordinary PASS targets are:

| Measurement | PASS target |
| --- | --- |
| Flat adjacency | At least **3.5%** |
| AA ramp rate | At most **8.0%** |
| Unique RGB colors | At most **20,000** |
| Counterpart native MAE, when available | At most **5.8** |

Missing a PASS target produces WARN unless an earlier FAIL condition applies

PERFECT requires all of the following:

- Flat adjacency of at least **9.0%**
- AA ramp rate of at most **6.5%**, or at most **7.5%** when flat adjacency is at least **10.0%**
- At most **12,500** unique RGB colors
- Counterpart native MAE of at most **5.25**, if a counterpart is available
- No warning or failure conditions

For example, an AA value of exactly 8.0% is within the PASS target. A value just above it is WARN, even if the rounded display still reads 8.0000%.

## Optional high-resolution comparison

You can grade native 320×180 art without supplying a larger original. It is eligible for all four grades, including PERFECT.

To compare a high-resolution version of the same artwork:

```bash
python tools/verify_backdrop.py "path/to/forest_320.png" --counterpart-dir "path/to/high-resolution"
```

For `forest_320.png` or `forest_320x180.png`, the checker searches the supplied directory in this order:

1. `forest_320x180_nearest_4k.png`
2. `forest_4k.png`
3. `forest_3840x2160.png`
4. `forest.png`

It uses the first matching file and avoids comparing the target to itself. The `_320` and `_320x180` suffixes are removed exactly as written when forming the candidate names.

A counterpart does not have to be 4K. The first comparison enlarges the backdrop to the counterpart's actual width and height. Use matching composition and canvas proportions so the comparison is meaningful.

If no matching file is found, or the counterpart directory is unavailable, the image receives a standalone grade. Check the output for **None (standalone 320x180 evaluation)** when you expected a comparison.

## Strict mode and reports

### Strict mode

```bash
python tools/verify_backdrop.py "path/to/backdrops" --strict
```

Strict mode changes the command's exit status. It does not relabel a WARN image as FAIL.

| Run | Exit 0 | Exit 1 |
| --- | --- | --- |
| Ordinary | All graded images are PERFECT, PASS, or WARN | At least one graded image is FAIL, or no images are found |
| Strict | All graded images are PERFECT or PASS | At least one graded image is WARN or FAIL, or no images are found |

### JSON report

```bash
python tools/verify_backdrop.py "path/to/backdrops" --strict --json "reports/backdrop-review.json"
```

The report contains `total`, grade `counts`, and per-image `results` with the grade, reasons, and measurements when available. Decoded image results also contain:

- `passed`: true for PERFECT, PASS, and WARN
- `strict_passed`: true for PERFECT and PASS

Early file/header failures have shorter result records. Read the `tier` and reasons, and allow for absent measurements.

The report is written before the final graded exit status, so an ordinary graded failure can still produce a report

## What to inspect after a warning or failure

- **Wrong format or size:** export an opaque PNG at exactly 320×180
- **Detected transparency:** flatten the background against the color you intend to show
- **High AA ramp rate:** inspect edges and any resizing or smoothing used during export. Nearest-neighbor resizing preserves existing pixel blocks.
- **Low flat adjacency:** look at noisy textures and very fine detail. Keep deliberate detail when it serves the scene.
- **High color count:** inspect gradients, antialiasing, and compression artifacts; decide whether they fit your intended pixel-art style
- **Counterpart drift:** confirm that the matched image is the same artwork, crop, and revision

Adjust the export or artwork with your intended result in mind. You do not need to erase a deliberate artistic choice merely to pursue PERFECT.

### Current inspection limits

A solid-color image can receive PERFECT, and some gradients or smoothing patterns escape the ramp heuristic. Grades do not measure composition, readability, or artistic quality.

The current alpha check handles RGBA, LA, and transparent palette images, but can miss RGB PNGs that use a transparent color key. Export a fully opaque background and inspect transparency independently if your editor uses that feature.

Image-decoding errors, unreadable counterparts, or missing dependencies can stop the command before a summary or JSON report. Read the terminal error, correct the input or setup, and rerun.

The checker computes image measurements. It does not run Gen1Recomp, capture screenshots, or verify runtime integration.

## Display sizes

A 320×180 image has exact integer scaling at these full 16:9 viewport sizes:

| Viewport | Scale |
| --- | --- |
| 1280×720 | 4× |
| 1920×1080 | 6× |
| 2560×1440 | 8× |
| 3840×2160 | 12× |

Other window sizes may use fractional scaling. Check the actual scene at the sizes you want to support.

Ready to put the image into a mod? Continue with [Artist Backdrop Packs](https://github.com/syybott/Gen1Better/wiki/Artist-Backdrop-Packs) or [BetterScenes](https://github.com/syybott/Gen1Better/wiki/BetterScenes).
