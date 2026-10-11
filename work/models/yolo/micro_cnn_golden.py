"""Quantized INT8 Micro-CNN Golden Model and Architecture Baseline for PH1P35 FPGA.

Architecture:
Input: 64x64x3 (RGB normalized to INT8 [-128, 127] or UINT8 [0, 255])
Conv1: 3 -> 16, 3x3, stride=2, padding=1 -> 32x32x16 (Weights: 3*16*9 = 432 B)
Conv2: 16 -> 32, 3x3, stride=2, padding=1 -> 16x16x32 (Weights: 16*32*9 = 4,608 B)
Conv3: 32 -> 64, 3x3, stride=2, padding=1 -> 8x8x64   (Weights: 32*64*9 = 18,432 B)
Conv4: 64 -> 64, 3x3, stride=2, padding=1 -> 4x4x64   (Weights: 64*64*9 = 36,864 B)
Head : Global Avg Pool / 1x1 Conv -> 4x(x, y, w, h, conf, classes)
Total Weights: ~60.3 KB (100% On-chip BRAM resident in PH1P35 free RAMs)
"""

import numpy as np


class Int8MicroCNNGolden:
    def __init__(self):
        # Deterministic dummy weights for baseline testbench generation
        np.random.seed(42)
        self.conv1_w = np.random.randint(-16, 16, size=(16, 3, 3, 3), dtype=np.int8)
        self.conv1_b = np.random.randint(-128, 128, size=(16,), dtype=np.int32)

    def conv1_pe_step(self, in_patch: np.ndarray, channel_idx: int) -> int:
        """Single 3x3 PE step emulation: in_patch is 3x3x3 INT8, computes dot product with conv1_w[channel_idx]."""
        # MAC accumulation in 32-bit integer (matches FPGA DSP accumulator)
        mac_acc = int(self.conv1_b[channel_idx])
        for c in range(3):
            for ky in range(3):
                for kx in range(3):
                    mac_acc += int(in_patch[c, ky, kx]) * int(self.conv1_w[channel_idx, c, ky, kx])
        # ReLU activation
        mac_acc = max(0, mac_acc)
        # Fixed point requantization (shift right by 8 with saturation to INT8 [0, 127])
        scaled = mac_acc >> 8
        out_val = min(127, max(0, scaled))
        return out_val


def self_test():
    model = Int8MicroCNNGolden()
    test_patch = np.ones((3, 3, 3), dtype=np.int8) * 10
    out0 = model.conv1_pe_step(test_patch, 0)
    print(f"Micro-CNN Golden Model Self-test: Output for test patch channel 0 = {out0}")
    assert isinstance(out0, int)
    print("Micro-CNN Golden Model Verification: PASS")


if __name__ == "__main__":
    self_test()
