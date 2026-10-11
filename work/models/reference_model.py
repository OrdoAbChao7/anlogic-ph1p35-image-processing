"""Board-independent, 8-bit grayscale reference model for pre-board tests.

Input and output use plain-text PGM (P2), keeping the tool dependency-free.
This is an algorithm oracle, not a sensor, ISP, RTL, or timing model.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def validate_image(image: list[list[int]]) -> tuple[int, int]:
    if not image or not image[0]:
        raise ValueError("image must contain at least one pixel")
    width = len(image[0])
    if any(len(row) != width for row in image):
        raise ValueError("image rows must have equal width")
    if any(not isinstance(value, int) or not 0 <= value <= 255
           for row in image for value in row):
        raise ValueError("pixels must be integers in 0..255")
    return width, len(image)


def binary_image(image: list[list[int]], threshold: int) -> list[list[int]]:
    validate_image(image)
    if not 0 <= threshold <= 255:
        raise ValueError("threshold must be in 0..255")
    return [[255 if value >= threshold else 0 for value in row]
            for row in image]


def sobel_image(image: list[list[int]]) -> list[list[int]]:
    width, height = validate_image(image)
    result = [[0] * width for _ in range(height)]
    for y in range(1, height - 1):
        for x in range(1, width - 1):
            top = image[y - 1]
            mid = image[y]
            bottom = image[y + 1]
            gx = (top[x + 1] + 2 * mid[x + 1] + bottom[x + 1]
                  - top[x - 1] - 2 * mid[x - 1] - bottom[x - 1])
            gy = (bottom[x - 1] + 2 * bottom[x] + bottom[x + 1]
                  - top[x - 1] - 2 * top[x] - top[x + 1])
            result[y][x] = min(255, abs(gx) + abs(gy))
    return result


def target_stats(mask: list[list[int]]) -> dict[str, object]:
    """Count 255-valued target pixels; return inclusive BBox or None."""
    validate_image(mask)
    points = [(x, y) for y, row in enumerate(mask)
              for x, value in enumerate(row) if value == 255]
    if not points:
        return {"area_px": 0, "bbox": None, "width_px": 0, "height_px": 0}
    xmin = min(x for x, _ in points)
    xmax = max(x for x, _ in points)
    ymin = min(y for _, y in points)
    ymax = max(y for _, y in points)
    return {
        "area_px": len(points),
        "bbox": {"xmin": xmin, "ymin": ymin, "xmax": xmax, "ymax": ymax},
        "width_px": xmax - xmin + 1,
        "height_px": ymax - ymin + 1,
    }


def read_p2(path: Path) -> list[list[int]]:
    tokens: list[str] = []
    for line in path.read_text(encoding="ascii").splitlines():
        tokens.extend(line.partition("#")[0].split())
    if len(tokens) < 4 or tokens[0] != "P2":
        raise ValueError("input must be a plain-text PGM (P2) image")
    width, height, maxval = map(int, tokens[1:4])
    if width <= 0 or height <= 0 or maxval != 255:
        raise ValueError("PGM must have positive dimensions and maxval 255")
    pixels = list(map(int, tokens[4:]))
    if len(pixels) != width * height:
        raise ValueError("PGM pixel count does not match dimensions")
    image = [pixels[y * width:(y + 1) * width] for y in range(height)]
    validate_image(image)
    return image


def write_p2(path: Path, image: list[list[int]]) -> None:
    width, height = validate_image(image)
    lines = ["P2", f"{width} {height}", "255"]
    lines.extend(" ".join(map(str, row)) for row in image)
    path.write_text("\n".join(lines) + "\n", encoding="ascii")


def self_test() -> None:
    assert binary_image([[0, 127, 128, 255]], 128) == [[0, 0, 255, 255]]
    assert binary_image([[0, 255]], 0) == [[255, 255]]
    assert target_stats([[0, 0], [0, 0]]) == {
        "area_px": 0, "bbox": None, "width_px": 0, "height_px": 0}
    assert target_stats([[0, 255, 0], [0, 255, 255]]) == {
        "area_px": 3,
        "bbox": {"xmin": 1, "ymin": 0, "xmax": 2, "ymax": 1},
        "width_px": 2, "height_px": 2}
    step = [[0, 0, 0, 255, 255] for _ in range(5)]
    edge = sobel_image(step)
    assert edge[2][2] == 255 and edge[2][0] == 0 and edge[0][2] == 0
    assert sobel_image([[10]]) == [[0]]


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--input", type=Path, help="8-bit P2 PGM input")
    parser.add_argument("--out-dir", type=Path, help="output directory")
    parser.add_argument("--threshold", type=int, default=128)
    parser.add_argument("--edge-threshold", type=int, default=128)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        print("self-test passed")
        return
    if args.input is None or args.out_dir is None:
        parser.error("--input and --out-dir are required unless using --self-test")
    image = read_p2(args.input)
    binary = binary_image(image, args.threshold)
    edge = sobel_image(image)
    edge_binary = binary_image(edge, args.edge_threshold)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    write_p2(args.out_dir / "binary.pgm", binary)
    write_p2(args.out_dir / "sobel.pgm", edge)
    write_p2(args.out_dir / "edge_binary.pgm", edge_binary)
    (args.out_dir / "stats.json").write_text(
        json.dumps(target_stats(binary), indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
