#!/usr/bin/env python3

import argparse
import numpy as np
import nibabel as nib


def main():
    parser = argparse.ArgumentParser(
        description="Print unique label IDs from a NIfTI label map."
    )
    parser.add_argument("labels", type=str, help="Path to the label map (NIfTI file)")
    parser.add_argument("mask", type=str, help="Path to the mask NIfTI file")

    args = parser.parse_args()

    labels = nib.load(args.labels).get_fdata().astype(np.int32)
    mask = nib.load(args.mask).get_fdata().astype(bool)

    overlap = labels * mask
    unique_labels = np.unique(overlap[overlap != 0])

    for val in unique_labels:
        volume_in_labels = np.sum(labels == val)
        volume_in_mask = np.sum(overlap == val)
        percentage = (volume_in_mask / volume_in_labels) * 100
        if percentage > 5:
            print(val)


if __name__ == "__main__":
    main()
