
import sys
import os
import struct

EXPECTED_WIDTH = 320
EXPECTED_HEIGHT = 180
SCALE_TARGETS = [
    ("720p", 4, 1280, 720),
    ("1080p", 6, 1920, 1080),
    ("1440p", 8, 2560, 1440),
    ("4K / 2160p", 12, 3840, 2160),
]

def read_png_dimensions(filepath):
    
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

def verify_image(filepath):
    
    print(f"\n========================================================")
    print(f"Verifying: {filepath}")
    print(f"========================================================")

    if not os.path.exists(filepath):
        print(f"  [FAIL] File does not exist: {filepath}")
        return False

    info, err = read_png_dimensions(filepath)
    if err:
        print(f"  [FAIL] {err}")
        return False

    width, height, bit_depth, color_type = info
    passed = True

    if width == EXPECTED_WIDTH and height == EXPECTED_HEIGHT:
        print(f"  [PASS] Dimensions: {width}x{height} (matches expected 320x180)")
    else:
        print(f"  [FAIL] Dimensions: {width}x{height} (MUST be exactly {EXPECTED_WIDTH}x{EXPECTED_HEIGHT})")
        passed = False

    ratio = width / height
    expected_ratio = 16.0 / 9.0
    if abs(ratio - expected_ratio) < 1e-5:
        print(f"  [PASS] Aspect Ratio: 16:9 ({ratio:.4f})")
    else:
        print(f"  [FAIL] Aspect Ratio: {ratio:.4f} (MUST be 16:9 / ~1.7778)")
        passed = False

    print(f"\n  Integer Scaling Multipliers:")
    for name, factor, target_w, target_h in SCALE_TARGETS:
        calc_w = width * factor
        calc_h = height * factor
        if calc_w == target_w and calc_h == target_h:
            print(f"    - {name:12s}: {factor}x -> {calc_w}x{calc_h} (exact integer pixel block {factor}x{factor})")
        else:
            print(f"    - {name:12s}: MISMATCH (computed {calc_w}x{calc_h}, expected {target_w}x{target_h})")
            passed = False

    try:
        from PIL import Image

        img = Image.open(filepath)
        print(f"\n  Deep Pixel Inspection (Pillow):")
        print(f"    - Color Mode: {img.mode} (Bit depth: {bit_depth})")

        if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
            alpha = img.convert("RGBA").split()[-1]
            min_alpha, max_alpha = alpha.getextrema()
            if min_alpha < 255:
                alpha_pixels = getattr(alpha, "get_flattened_data", None)
                data_iter = alpha_pixels() if callable(alpha_pixels) else alpha.getdata()
                has_semitransparent = any(0 < p < 255 for p in data_iter)
                has_fully_transparent = min_alpha == 0
                if has_fully_transparent or has_semitransparent:
                    print(f"    - [WARN] Backdrop contains transparent/translucent pixels (min alpha: {min_alpha}).")
                    print(f"             BetterBattle backdrops are full-color base layers; transparent pixels will")
                    print(f"             reveal the black clear canvas behind the scene.")
            else:
                print(f"    - [PASS] Fully opaque (no accidental alpha holes)")
        else:
            print(f"    - [PASS] Fully opaque {img.mode} image")

        for name, factor, tw, th in [("1080p", 6, 1920, 1080), ("4K", 12, 3840, 2160)]:
            upscaled = img.resize((tw, th), resample=Image.Resampling.NEAREST)
            sample_passed = True
            for sx in range(0, min(10, width)):
                for sy in range(0, min(10, height)):
                    base_pixel = img.getpixel((sx, sy))
                    block_x = sx * factor
                    block_y = sy * factor
                    for dx in (0, factor - 1):
                        for dy in (0, factor - 1):
                            if upscaled.getpixel((block_x + dx, block_y + dy)) != base_pixel:
                                sample_passed = False
                                break
            if sample_passed:
                print(f"    - [PASS] {name} Nearest Grid: Verified {factor}x{factor} uniform texel alignment")
            else:
                print(f"    - [WARN] {name} Nearest Grid: Unexpected pixel block variation")

    except ImportError:
        print(f"\n  [NOTE] Install Pillow (pip install pillow) for deep alpha and texel grid inspection.")

    if passed:
        print(f"\n  >>> RESULT: PASS - Ready for BetterBattle 2D backdrops!")
    else:
        print(f"\n  >>> RESULT: FAIL - Resolve the issues above before using in BetterBattle.")

    return passed

def main():
    if len(sys.argv) < 2:
        print("Usage: python verify_backdrop.py <image_or_directory> [...]")
        sys.exit(1)

    targets = []
    for arg in sys.argv[1:]:
        if os.path.isdir(arg):
            for root, _, files in os.walk(arg):
                for f in files:
                    if f.lower().endswith(".png"):
                        targets.append(os.path.join(root, f))
        elif os.path.isfile(arg):
            targets.append(arg)
        else:
            print(f"Warning: '{arg}' not found, skipping.")

    if not targets:
        print("No PNG files found to verify.")
        sys.exit(1)

    all_passed = True
    for target in targets:
        ok = verify_image(target)
        if not ok:
            all_passed = False

    sys.exit(0 if all_passed else 1)

if __name__ == "__main__":
    main()
