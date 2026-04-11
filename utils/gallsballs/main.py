#!/usr/bin/env python3
"""
Convert a PNG world map from Robinson projection to Gall's Stereographic projection
with optional output scaling. Nearest‑neighbor resampling keeps original colors intact.

Usage:
    python reproject_robinson_to_gall.py input.png output.png [--scale FACTOR]
    python reproject_robinson_to_gall.py input.png output.png --width W --height H

Examples:
    # Default size (preserves approximate pixel area)
    python reproject_robinson_to_gall.py world_robinson.png world_gall.png

    # Scale output by a factor of 2 (4× pixels)
    python reproject_robinson_to_gall.py world_robinson.png world_gall.png --scale 2

    # Explicit output dimensions
    python reproject_robinson_to_gall.py world_robinson.png world_gall.png --width 2000 --height 1200
"""

import sys
import argparse
import numpy as np
from PIL import Image
from scipy.ndimage import map_coordinates
from pyproj import Transformer

# ----------------------------------------------------------------------
# Projection definitions
# ----------------------------------------------------------------------
ROBINSON_PROJ = "+proj=robin +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"
GALL_PROJ = "+proj=gall +lon_0=0 +x_0=0 +y_0=0 +datum=WGS84 +units=m +no_defs"

# ----------------------------------------------------------------------
def get_geographic_extent(width, height, proj_str):
    """Compute the (x,y) bounding box of the full globe in a given projection."""
    transformer = Transformer.from_crs("EPSG:4326", proj_str, always_xy=True)

    lons = np.linspace(-180, 180, 100)
    lats = np.linspace(-90, 90, 100)
    lon_grid, lat_grid = np.meshgrid(lons, lats)
    x, y = transformer.transform(lon_grid, lat_grid)

    return np.nanmin(x), np.nanmax(x), np.nanmin(y), np.nanmax(y)

# ----------------------------------------------------------------------
def reproject_image(input_path, output_path, output_width=None, output_height=None):
    """Reproject with nearest‑neighbor resampling to preserve exact colors."""

    img = Image.open(input_path).convert("RGB")
    input_array = np.array(img)
    in_h, in_w = input_array.shape[:2]

    # Extent of Robinson map
    x_min, x_max, y_min, y_max = get_geographic_extent(in_w, in_h, ROBINSON_PROJ)
    to_robin = Transformer.from_crs("EPSG:4326", ROBINSON_PROJ, always_xy=True)

    # Default output size (approximate to keep similar pixel area)
    if output_width is None or output_height is None:
        width_ratio = 0.833
        output_width = int(in_w * width_ratio)
        output_height = int(in_h * 1.1)

    to_geo = Transformer.from_crs(GALL_PROJ, "EPSG:4326", always_xy=True)
    gall_x_min, gall_x_max, gall_y_min, gall_y_max = get_geographic_extent(
        output_width, output_height, GALL_PROJ
    )

    # Build output coordinate grids
    out_x = np.linspace(0, output_width - 1, output_width)
    out_y = np.linspace(0, output_height - 1, output_height)
    out_xx, out_yy = np.meshgrid(out_x, out_y)

    gall_x = gall_x_min + (out_xx / (output_width - 1)) * (gall_x_max - gall_x_min)
    gall_y = gall_y_min + (out_yy / (output_height - 1)) * (gall_y_max - gall_y_min)

    lon, lat = to_geo.transform(gall_x, gall_y)
    robin_x, robin_y = to_robin.transform(lon, lat)

    in_col = (robin_x - x_min) / (x_max - x_min) * (in_w - 1)
    in_row = (robin_y - y_min) / (y_max - y_min) * (in_h - 1)

    coords = np.array([in_row.flatten(), in_col.flatten()])

    # Nearest‑neighbor resampling (order=0) → no color interpolation
    output_array = np.zeros((output_height, output_width, input_array.shape[2]),
                            dtype=input_array.dtype)
    for c in range(input_array.shape[2]):
        channel = input_array[:, :, c]
        sampled = map_coordinates(channel, coords, order=0, mode='constant', cval=0)
        output_array[:, :, c] = sampled.reshape(output_height, output_width)

    out_img = Image.fromarray(output_array)
    out_img.save(output_path)
    print(f"Saved reprojected image to {output_path} ({output_width}×{output_height})")

# ----------------------------------------------------------------------
def parse_arguments():
    parser = argparse.ArgumentParser(
        description="Reproject a Robinson projection PNG to Gall's Stereographic."
    )
    parser.add_argument("input", help="Input PNG file (Robinson projection)")
    parser.add_argument("output", help="Output PNG file (Gall Stereographic)")
    parser.add_argument("--scale", type=float,
                        help="Scale factor for output size (relative to default)")
    parser.add_argument("--width", type=int, help="Explicit output width")
    parser.add_argument("--height", type=int, help="Explicit output height")
    return parser.parse_args()

# ----------------------------------------------------------------------
if __name__ == "__main__":
    args = parse_arguments()

    # Determine output dimensions based on user input
    if args.width is not None and args.height is not None:
        out_w, out_h = args.width, args.height
    elif args.scale is not None:
        # We need default dimensions to scale. Read input to get default size.
        img = Image.open(args.input)
        in_w, in_h = img.size
        width_ratio = 0.833
        default_w = int(in_w * width_ratio)
        default_h = int(in_h * 1.1)
        out_w = int(default_w * args.scale)
        out_h = int(default_h * args.scale)
    else:
        out_w, out_h = None, None  # Use defaults inside reproject_image

    reproject_image(args.input, args.output, out_w, out_h)
