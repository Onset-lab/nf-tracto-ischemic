#!/usr/bin/env python3

import argparse
import numpy as np
import nibabel as nib
import sys


def get_unique_labels(nifti_path):
    try:
        img = nib.load(nifti_path)
        data = img.get_fdata()

        unique_vals = np.unique(data[data != 0])

        unique_vals = unique_vals.astype(int)  # if it's a label map

        return unique_vals

    except Exception as e:
        sys.stderr.write(f"Error: {e}\n")
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Print unique label IDs from a NIfTI label map."
    )
    parser.add_argument(
        "nifti_file", type=str, help="Path to the label map (NIfTI file)"
    )

    args = parser.parse_args()

    labels = get_unique_labels(args.nifti_file)

    for val in labels:
        print(val)


if __name__ == "__main__":
    main()
