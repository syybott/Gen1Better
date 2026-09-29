#!/usr/bin/env python3
"""
BetterBattle 320x180 Backdrop Grid, Pixel-Art Integrity & 4K Parity Validator

Grades 2D battle and stage backdrop images across a 4-tier scale:
  - PERFECT : True pixel-art discipline (high flat clustering, low AA ramp rate,
              controlled palette, and lossless/near-lossless 4K counterpart parity
              when a counterpart is supplied).
  - PASS    : Clean, game-ready 320x180 pixel-art backdrop.
  - WARN    : Playable in-game, but exhibits low flat clustering (< 3.5%),
              elevated edge AA interpolation ramps (> 8.0%), high unique color
              count (> 20,000 / 57,600 pixels), or moderate counterpart drift.
  - FAIL    : Violates hard format/resolution/aspect/opacity contracts, or
              exhibits severe AA blur (> 13.5%), combined blur + low clustering
              (AA > 12.5% and flat < 3.5%), extreme color noise (> 35,000 colors),
              or severe 4K counterpart mismatch (MAE > 8.0).

Note:
  --counterpart-dir is completely optional. Native 320x180 artist assets receive
  a full standalone grade (PERFECT / PASS / WARN / FAIL) without requiring any
  high-resolution source image.

Usage:
  python verify_backdrop.py <image_path_or_directory> [...] [--counterpart-dir <dir>] [--json <out.json>]
"""

import argparse
import json
import os
import struct
import sys

EXPECTED_WIDTH = 320
EXPECTED_HEIGHT = 180
TOTAL_PIXELS = EXPECTED_WIDTH * EXPECTED_HEIGHT
SCALE_TARGETS = [
    ("720p", 4, 1280, 720),
    ("1080p", 6, 1920, 1080),
    ("1440p", 8, 2560, 1440),
    ("4K / 2160p", 12, 3840, 2160),
]

# Raw unrounded classification thresholds
FAIL_AA_RAMP_MAX = 13.5
FAIL_COMBO_AA_RAMP = 12.5
FAIL_COMBO_FLAT_MIN = 3.5
FAIL_UNIQUE_COLORS_MAX = 35000
FAIL_COUNTERPART_MAE_MAX = 8.0

WARN_FLAT_ADJ_MIN = 3.5
PASS_AA_RAMP_MAX = 8.0
PASS_UNIQUE_COLORS_MAX = 20000
PASS_COUNTERPART_MAE_MAX = 5.8

PERFECT_FLAT_ADJ_MIN = 9.0
PERFECT_AA_RAMP_MAX = 6.5
PERFECT_HIGH_FLAT_MIN = 10.0
PERFECT_HIGH_FLAT_AA_MAX = 7.5
PERFECT_UNIQUE_COLORS_MAX = 12500
PERFECT_COUNTERPART_MAE_MAX = 5.25


def read_png_dimensions(filepath):
    """Reads width and height from PNG IHDR chunk without external dependencies."""
    try:
        with open(filepath, "rb") as f:
            header = f.read(8)
            if header != b"\x89PNG\r\n\x1a\n":
                return None, "Not a valid PNG file (invalid magic signature)"
            chunk_len, chunk_type = struct.unpack(">I4s", f.read(8))
            if chunk_type != b"IHDR":
                return None, f"Expected IHDR chunk, got {chunk_type}"
            width, height = struct.unpack(">II", f.read(8))
            bit_depth, color_type = struct.unpack(">BB", f.read(2))
            return (width, height, bit_depth, color_type), None
    except Exception as exc:
        return None, f"Failed to read PNG header: {exc}"


def resolve_stem(filename):
    """Extracts canonical scene stem from *_320x180.png, *_320.png, or *.png."""
    name = os.path.splitext(os.path.basename(filename))[0]
    for suffix in ("_320x180", "_320"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def find_counterpart(filepath, counterpart_dir):
    """Finds optional high-res / 4K counterpart image for a 320x180 backdrop."""
    if not counterpart_dir or not os.path.isdir(counterpart_dir):
        return None
    stem = resolve_stem(filepath)
    candidates = [
        f"{stem}_320x180_nearest_4k.png",
        f"{stem}_4k.png",
        f"{stem}_3840x2160.png",
        f"{stem}.png",
    ]
    for cand in candidates:
        cand_path = os.path.join(counterpart_dir, cand)
        if os.path.isfile(cand_path) and os.path.abspath(cand_path) != os.path.abspath(filepath):
            return cand_path
    return None


def compute_pixel_metrics(filepath, counterpart_path=None):
    """
    Computes unrounded raw pixel-art integrity metrics and optional 4K counterpart
    parity metrics using Pillow + NumPy.
    """
    from PIL import Image
    import numpy as np

    im = Image.open(filepath)
    min_alpha = 255
    if im.mode in ("RGBA", "LA") or (im.mode == "P" and "transparency" in im.info):
        alpha = im.convert("RGBA").split()[-1]
        min_alpha = alpha.getextrema()[0]

    rgb_im = im.convert("RGB")
    arr = np.array(rgb_im, dtype=np.float64)

    # 1. Flat-run neighbor adjacency (% of 4-connected neighbors with identical RGB)
    same_h = float(np.all(arr[:, :-1] == arr[:, 1:], axis=-1).mean() * 100.0)
    same_v = float(np.all(arr[:-1, :] == arr[1:, :], axis=-1).mean() * 100.0)
    flat_adj_pct = 0.5 * (same_h + same_v)

    # 2. 1px linear interpolation / antialiasing ramp rate (% of interior triplets
    #    where center pixel sits strictly between left/right or top/bottom neighbors
    #    across all 3 RGB channels by at least 2 intensity levels)
    h_min = np.minimum(arr[:, :-2], arr[:, 2:]) + 2.0
    h_max = np.maximum(arr[:, :-2], arr[:, 2:]) - 2.0
    mid_h = float(np.all((arr[:, 1:-1] >= h_min) & (arr[:, 1:-1] <= h_max), axis=-1).mean() * 100.0)

    v_min = np.minimum(arr[:-2, :], arr[2:, :]) + 2.0
    v_max = np.maximum(arr[:-2, :], arr[2:, :]) - 2.0
    mid_v = float(np.all((arr[1:-1, :] >= v_min) & (arr[1:-1, :] <= v_max), axis=-1).mean() * 100.0)
    aa_ramp_pct = 0.5 * (mid_h + mid_v)

    # 3. Unique RGB color count (out of 57,600 pixels for 320x180)
    unique_colors = int(len(np.unique(arr.reshape(-1, 3), axis=0)))
    unique_color_pct = (unique_colors / float(arr.shape[0] * arr.shape[1])) * 100.0

    # 4. Optional 4K / High-Res Counterpart Comparison
    #    Simulates the in-game nearest-neighbor upscale (12x -> 3840x2160 4K,
    #    plus direct comparison at the counterpart's native resolution)
    counterpart_mae = None
    counterpart_4k_mae = None
    counterpart_size = None
    counterpart_block_std = None

    if counterpart_path and os.path.isfile(counterpart_path):
        cp_im = Image.open(counterpart_path).convert("RGB")
        cp_w, cp_h = cp_im.size
        counterpart_size = (cp_w, cp_h)
        cp_arr = np.array(cp_im, dtype=np.float64)

        # Upscale 320x180 via NEAREST to counterpart resolution
        up_native = np.array(
            rgb_im.resize((cp_w, cp_h), resample=Image.Resampling.NEAREST),
            dtype=np.float64,
        )
        counterpart_mae = float(np.abs(cp_arr - up_native).mean())

        # Also compare both at 4K (3840x2160) as rendered in-game on a 4K display
        render_4k = np.array(
            rgb_im.resize((3840, 2160), resample=Image.Resampling.NEAREST),
            dtype=np.float64,
        )
        cp_4k = (
            cp_arr
            if (cp_w, cp_h) == (3840, 2160)
            else np.array(
                cp_im.resize((3840, 2160), resample=Image.Resampling.NEAREST),
                dtype=np.float64,
            )
        )
        counterpart_4k_mae = float(np.abs(cp_4k - render_4k).mean())

        if cp_w % EXPECTED_WIDTH == 0 and cp_h % EXPECTED_HEIGHT == 0:
            fx = cp_w // EXPECTED_WIDTH
            fy = cp_h // EXPECTED_HEIGHT
            blocks = cp_arr.reshape(EXPECTED_HEIGHT, fy, EXPECTED_WIDTH, fx, 3)
            counterpart_block_std = float(blocks.std(axis=(1, 3)).mean())

    return {
        "mode": im.mode,
        "min_alpha": int(min_alpha),
        "flat_adj_pct": flat_adj_pct,
        "same_h_pct": same_h,
        "same_v_pct": same_v,
        "aa_ramp_pct": aa_ramp_pct,
        "mid_h_pct": mid_h,
        "mid_v_pct": mid_v,
        "unique_colors": unique_colors,
        "unique_color_pct": unique_color_pct,
        "counterpart_path": counterpart_path,
        "counterpart_size": counterpart_size,
        "counterpart_mae": counterpart_mae,
        "counterpart_4k_mae": counterpart_4k_mae,
        "counterpart_block_std": counterpart_block_std,
    }


def classify_backdrop(width, height, metrics):
    """
    Classifies a backdrop using unrounded raw metric values.
    Precedence:
      1. Hard contract / severe-quality FAIL
      2. PERFECT
      3. PASS
      4. WARN
    Returns (tier, fail_reasons, warn_reasons)
    """
    fail_reasons = []
    warn_reasons = []

    # --- Hard contract checks ---
    if (width, height) != (EXPECTED_WIDTH, EXPECTED_HEIGHT):
        fail_reasons.append(
            f"dimensions={width}x{height} (must be strictly {EXPECTED_WIDTH}x{EXPECTED_HEIGHT})"
        )

    ratio = (width / float(height)) if height else 0.0
    if abs(ratio - (16.0 / 9.0)) >= 1e-5:
        fail_reasons.append(f"aspect_ratio={ratio:.6f} (must be 16:9 / 1.777778)")

    for name, factor, target_w, target_h in SCALE_TARGETS:
        if width * factor != target_w or height * factor != target_h:
            fail_reasons.append(f"scale_mismatch_{name}={width * factor}x{height * factor}")

    if metrics is None:
        fail_reasons.append("pixel_inspection_unavailable")
        return "FAIL", fail_reasons, warn_reasons

    min_alpha = metrics["min_alpha"]
    flat_adj = metrics["flat_adj_pct"]
    aa_ramp = metrics["aa_ramp_pct"]
    unique_colors = metrics["unique_colors"]
    cp_mae = metrics["counterpart_mae"]

    if min_alpha < 255:
        fail_reasons.append(
            f"alpha_transparency_detected (min_alpha={min_alpha} < 255; backdrops must be 100% opaque)"
        )

    # --- Severe pixel-quality FAIL rules (unrounded raw comparisons) ---
    if aa_ramp > FAIL_AA_RAMP_MAX:
        fail_reasons.append(
            f"severe_aa_interpolation_blur (aa_ramp_pct={aa_ramp:.6f}% > {FAIL_AA_RAMP_MAX}%)"
        )

    if aa_ramp > FAIL_COMBO_AA_RAMP and flat_adj < FAIL_COMBO_FLAT_MIN:
        fail_reasons.append(
            f"combined_aa_blur_and_low_clustering (aa_ramp_pct={aa_ramp:.6f}% > {FAIL_COMBO_AA_RAMP}% "
            f"and flat_adj_pct={flat_adj:.6f}% < {FAIL_COMBO_FLAT_MIN}%)"
        )

    if unique_colors > FAIL_UNIQUE_COLORS_MAX:
        fail_reasons.append(
            f"excessive_color_noise (unique_colors={unique_colors} > {FAIL_UNIQUE_COLORS_MAX} / {TOTAL_PIXELS})"
        )

    if cp_mae is not None and cp_mae > FAIL_COUNTERPART_MAE_MAX:
        fail_reasons.append(
            f"severe_4k_counterpart_mismatch (counterpart_mae={cp_mae:.6f} > {FAIL_COUNTERPART_MAE_MAX})"
        )

    # Precedence 1: FAIL
    if fail_reasons:
        return "FAIL", fail_reasons, warn_reasons

    # Collect any WARN conditions (using unrounded raw values)
    if flat_adj < WARN_FLAT_ADJ_MIN:
        warn_reasons.append(
            f"low_flat_adjacency (flat_adj_pct={flat_adj:.6f}% < {WARN_FLAT_ADJ_MIN}%)"
        )

    if aa_ramp > PASS_AA_RAMP_MAX:
        warn_reasons.append(
            f"elevated_aa_ramp_rate (aa_ramp_pct={aa_ramp:.6f}% > {PASS_AA_RAMP_MAX}%)"
        )

    if unique_colors > PASS_UNIQUE_COLORS_MAX:
        warn_reasons.append(
            f"high_unique_color_count (unique_colors={unique_colors} > {PASS_UNIQUE_COLORS_MAX})"
        )

    if cp_mae is not None and cp_mae > PASS_COUNTERPART_MAE_MAX:
        warn_reasons.append(
            f"moderate_4k_counterpart_drift (counterpart_mae={cp_mae:.6f} > {PASS_COUNTERPART_MAE_MAX})"
        )

    # Precedence 2: PERFECT
    is_perfect_aa = (aa_ramp <= PERFECT_AA_RAMP_MAX) or (
        flat_adj >= PERFECT_HIGH_FLAT_MIN and aa_ramp <= PERFECT_HIGH_FLAT_AA_MAX
    )
    is_perfect_cp = (cp_mae is None) or (cp_mae <= PERFECT_COUNTERPART_MAE_MAX)
    if (
        not warn_reasons
        and flat_adj >= PERFECT_FLAT_ADJ_MIN
        and is_perfect_aa
        and unique_colors <= PERFECT_UNIQUE_COLORS_MAX
        and is_perfect_cp
    ):
        return "PERFECT", fail_reasons, warn_reasons

    # Precedence 3: PASS
    if not warn_reasons:
        return "PASS", fail_reasons, warn_reasons

    # Precedence 4: WARN
    return "WARN", fail_reasons, warn_reasons


def verify_image(filepath, counterpart_dir=None, quiet=False):
    """Runs full 4-tier verification on a backdrop image file."""
    if not os.path.exists(filepath):
        if not quiet:
            print(f"\n[FAIL] File does not exist: {filepath}")
        return {
            "filepath": filepath,
            "tier": "FAIL",
            "passed": False,
            "fail_reasons": [f"file_not_found ({filepath})"],
            "warn_reasons": [],
            "metrics": None,
        }

    info, err = read_png_dimensions(filepath)
    if err:
        if not quiet:
            print(f"\n========================================================")
            print(f"Verifying: {filepath}")
            print(f"========================================================")
            print(f"  [FAIL] {err}")
            print(f"  >>> TIER: FAIL")
        return {
            "filepath": filepath,
            "tier": "FAIL",
            "passed": False,
            "fail_reasons": [err],
            "warn_reasons": [],
            "metrics": None,
        }

    width, height, bit_depth, color_type = info
    counterpart_path = find_counterpart(filepath, counterpart_dir)
    metrics = compute_pixel_metrics(filepath, counterpart_path=counterpart_path)
    tier, fail_reasons, warn_reasons = classify_backdrop(width, height, metrics)

    if not quiet:
        print(f"\n========================================================")
        print(f"Verifying: {filepath}")
        print(f"========================================================")
        print(f"  Dimensions       : {width}x{height} (Aspect: {width / height:.4f}, Bit depth: {bit_depth})")
        print(
            f"  Raw Pixel Metrics: flat_adj={metrics['flat_adj_pct']:.4f}% "
            f"(H={metrics['same_h_pct']:.4f}%, V={metrics['same_v_pct']:.4f}%) | "
            f"aa_ramp={metrics['aa_ramp_pct']:.4f}% "
            f"(H={metrics['mid_h_pct']:.4f}%, V={metrics['mid_v_pct']:.4f}%) | "
            f"unique_colors={metrics['unique_colors']} ({metrics['unique_color_pct']:.2f}%)"
        )
        if metrics["counterpart_path"]:
            cp_w, cp_h = metrics["counterpart_size"]
            std_str = (
                f", block_std={metrics['counterpart_block_std']:.4f}"
                if metrics["counterpart_block_std"] is not None
                else ""
            )
            print(
                f"  4K Counterpart   : {metrics['counterpart_path']} ({cp_w}x{cp_h}) | "
                f"native_MAE={metrics['counterpart_mae']:.4f} | "
                f"4K_3840x2160_MAE={metrics['counterpart_4k_mae']:.4f}{std_str}"
            )
        else:
            print("  4K Counterpart   : None (standalone 320x180 evaluation)")

        if fail_reasons:
            print("  FAIL Reasons:")
            for r in fail_reasons:
                print(f"    - [FAIL] {r}")
        if warn_reasons:
            print("  WARN Reasons:")
            for r in warn_reasons:
                print(f"    - [WARN] {r}")

        print(f"  >>> TIER: {tier}")

    return {
        "filepath": filepath,
        "filename": os.path.basename(filepath),
        "width": width,
        "height": height,
        "tier": tier,
        "passed": tier in ("PERFECT", "PASS", "WARN"),
        "strict_passed": tier in ("PERFECT", "PASS"),
        "fail_reasons": fail_reasons,
        "warn_reasons": warn_reasons,
        "metrics": metrics,
    }


def main():
    parser = argparse.ArgumentParser(
        description="BetterBattle 320x180 Backdrop 4-Tier (PERFECT / PASS / WARN / FAIL) Validator"
    )
    parser.add_argument(
        "targets",
        nargs="+",
        help="Backdrop PNG file(s) or directory(ies) to validate",
    )
    parser.add_argument(
        "--counterpart-dir",
        default=None,
        help="Optional directory containing 4K / high-resolution counterpart images",
    )
    parser.add_argument(
        "--json",
        default=None,
        help="Optional path to write full JSON validation report",
    )
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit non-zero on WARN as well as FAIL",
    )
    args = parser.parse_args()

    files_to_check = []
    for target in args.targets:
        if os.path.isdir(target):
            for entry in sorted(os.listdir(target)):
                full = os.path.join(target, entry)
                if os.path.isfile(full) and entry.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                    files_to_check.append(full)
        elif os.path.isfile(target):
            files_to_check.append(target)
        else:
            print(f"Warning: '{target}' not found, skipping.")

    if not files_to_check:
        print("No image files found to verify.")
        sys.exit(1)

    results = []
    counts = {"PERFECT": 0, "PASS": 0, "WARN": 0, "FAIL": 0}

    for fpath in files_to_check:
        res = verify_image(fpath, counterpart_dir=args.counterpart_dir)
        results.append(res)
        counts[res["tier"]] += 1

    print("\n================================================================================")
    print(
        f"SUMMARY ({len(results)} files): "
        f"PERFECT={counts['PERFECT']} | PASS={counts['PASS']} | "
        f"WARN={counts['WARN']} | FAIL={counts['FAIL']}"
    )
    print("================================================================================")

    for tier in ("PERFECT", "PASS", "WARN", "FAIL"):
        tier_items = [r for r in results if r["tier"] == tier]
        if not tier_items:
            continue
        print(f"\n--- {tier} ({len(tier_items)}) ---")
        for r in tier_items:
            m = r["metrics"]
            if m:
                cp_str = (
                    f"4K_MAE={m['counterpart_4k_mae']:.2f}"
                    if m["counterpart_4k_mae"] is not None
                    else "standalone"
                )
                reasons = "; ".join(r["fail_reasons"] + r["warn_reasons"])
                reason_suffix = f" -> {reasons}" if reasons else ""
                print(
                    f"  [{r['tier']:7s}] {r['filename']:38s} | "
                    f"flat={m['flat_adj_pct']:5.2f}% | AA={m['aa_ramp_pct']:5.2f}% | "
                    f"colors={m['unique_colors']:5d} | {cp_str}{reason_suffix}"
                )
            else:
                reasons = "; ".join(r["fail_reasons"])
                print(f"  [{r['tier']:7s}] {os.path.basename(r['filepath']):38s} | {reasons}")

    if args.json:
        os.makedirs(os.path.dirname(os.path.abspath(args.json)), exist_ok=True)
        with open(args.json, "w", encoding="utf-8") as jf:
            json.dump(
                {
                    "total": len(results),
                    "counts": counts,
                    "results": results,
                },
                jf,
                indent=2,
            )
        print(f"\nReport written to: {args.json}")

    if counts["FAIL"] > 0 or (args.strict and counts["WARN"] > 0):
        sys.exit(1)
    sys.exit(0)


if __name__ == "__main__":
    main()
