"""Bit-exact RGB888 cartoon reference; OpenCV uses a trailing 3x3 anchor.

No bilateral filter or learned stylization is claimed. See the RTL contract.
"""
from pathlib import Path
import argparse
import cv2
import numpy as np


def filter_rgb(rgb: np.ndarray, threshold: int = 160):
    if rgb.dtype != np.uint8 or rgb.ndim != 3 or rgb.shape[2] != 3:
        raise ValueError('Expected HxWx3 uint8 RGB')
    if not 0 <= threshold <= 2047:
        raise ValueError('Threshold must be 0..2047')
    kernel = np.array([[1, 2, 1], [2, 4, 2], [1, 2, 1]], np.float32)
    smooth_sum = cv2.filter2D(rgb, cv2.CV_16U, kernel, anchor=(2, 2),
                             borderType=cv2.BORDER_REPLICATE)
    level = (smooth_sum >> 4) >> 5
    quant = ((level << 5) | (level << 2) | (level >> 1)).astype(np.uint8)
    gray = (rgb[:, :, 0] >> 2) + (rgb[:, :, 1] >> 1) + (rgb[:, :, 2] >> 2)
    kx = np.array([[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]], np.float32)
    ky = kx.T
    gx = cv2.filter2D(gray, cv2.CV_16S, kx, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
    gy = cv2.filter2D(gray, cv2.CV_16S, ky, anchor=(2, 2), borderType=cv2.BORDER_REPLICATE)
    mask = (np.abs(gx) + np.abs(gy)) >= threshold
    quant[mask] = 0
    return quant, (mask.astype(np.uint8) * 255)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('image', type=Path)
    p.add_argument('--out-dir', type=Path, default=Path('work/output/cartoon-preview'))
    p.add_argument('--threshold', type=int, default=160)
    args = p.parse_args()
    bgr = cv2.imdecode(np.fromfile(args.image, dtype=np.uint8), cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError(f'Cannot decode image: {args.image}')
    rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
    toon, edge = filter_rgb(rgb, args.threshold)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    cv2.imwrite(str(args.out_dir / 'cartoon.png'), cv2.cvtColor(toon, cv2.COLOR_RGB2BGR))
    cv2.imwrite(str(args.out_dir / 'edge.png'), edge)
    cv2.imwrite(str(args.out_dir / 'comparison.png'),
                cv2.cvtColor(np.concatenate([rgb, toon], axis=1), cv2.COLOR_RGB2BGR))


if __name__ == '__main__':
    main()
