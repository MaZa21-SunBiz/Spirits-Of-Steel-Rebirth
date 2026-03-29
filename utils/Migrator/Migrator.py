import json
import collections
from PIL import Image

def bgr_to_id(b, g, r):
    return (b << 16) | (g << 8) | r

def id_to_rgb(province_id):
    # Converts our BGR uint back to an RGB tuple for PIL saving
    b = (province_id >> 16) & 0xFF
    g = (province_id >> 8) & 0xFF
    r = province_id & 0xFF
    return (r, g, b)

def migrate_with_splits(old_map_path, new_bw_path, json_path):
    old_img = Image.open(old_map_path).convert("RGB")
    new_bw = Image.open(new_bw_path).convert("L")
    with open(json_path, 'r') as f:
        original_data = json.load(f)

    width, height = old_img.size
    old_pixels = old_img.load()
    bw_pixels = new_bw.load()
    
    # 1. Map out the Old Map's total area per ID for scaling
    old_province_total_pixels = collections.Counter()
    for y in range(height):
        for x in range(width):
            r, g, b = old_pixels[x, y]
            if r == g == b == 0: continue
            old_province_total_pixels[bgr_to_id(b, g, r)] += 1

    # 2. Identify New Blobs and their overlaps
    visited = set()
    new_provinces = [] # List of dicts: {"pixels": [], "overlaps": {old_id: count}}
    
    max_id = max([int(k) for k in original_data["provinces"].keys()] + [0])

    for y in range(height):
        for x in range(width):
            if bw_pixels[x, y] > 128 and (x, y) not in visited:
                # Flood fill
                q = [(x, y)]
                blob_pixels = []
                overlaps = collections.Counter()
                
                while q:
                    cx, cy = q.pop()
                    if (cx, cy) in visited or cx < 0 or cx >= width or cy < 0 or cy >= height or bw_pixels[cx, cy] <= 128:
                        continue
                    visited.add((cx, cy))
                    blob_pixels.append((cx, cy))
                    
                    # Check what was here on the old map
                    r, g, b = old_pixels[cx, cy]
                    if not (r == g == b == 0):
                        overlaps[bgr_to_id(b, g, r)] += 1
                    
                    q.extend([(cx+1, cy), (cx-1, cy), (cx, cy+1), (cx, cy-1)])
                
                new_provinces.append({"pixels": blob_pixels, "overlaps": overlaps})

    # 3. Create New Data and Render Image
    final_json_provinces = {}
    output_img = Image.new("RGB", (width, height), (0, 0, 0))
    out_pixels = output_img.load()

    for blob in new_provinces:
        # Decide ID: If it significantly overlaps an old ID, keep it. Otherwise, new ID.
        if not blob["overlaps"]:
            max_id += 1
            assigned_id = max_id
        else:
            # Pick the old ID with the most overlap as the "Primary" to inherit non-numeric metadata
            assigned_id = blob["overlaps"].most_common(1)[0][0]
            # If this ID is already taken by another new blob (a split), we give this one a new ID
            if str(assigned_id) in final_json_provinces:
                max_id += 1
                assigned_id = max_id

        # Paint the map
        color = id_to_rgb(assigned_id)
        for px, py in blob["pixels"]:
            out_pixels[px, py] = color

        # Generate Data
        new_entry = {"name": f"New Prov {assigned_id}", "populations": [], "gdp": 0, "resources": []}
        
        for old_id, overlap_count in blob["overlaps"].items():
            old_str = str(old_id)
            if old_str not in original_data["provinces"]: continue
            
            old_entry = original_data["provinces"][old_str]
            # Ratio of this new blob's share of the old province
            ratio = overlap_count / old_province_total_pixels[old_id]

            # Scale numeric stats
            new_entry["gdp"] += int(old_entry.get("gdp", 0) * ratio)
            
            # Scale Populations
            for pop in old_entry.get("populations", []):
                new_entry["populations"].append({
                    "ethnicity": pop["ethnicity"],
                    "amount": int(pop["amount"] * ratio)
                })
            
            # Inherit core metadata from the largest overlap
            if old_id == blob["overlaps"].most_common(1)[0][0]:
                new_entry.update({
                    "biome": old_entry.get("biome", ""),
                    "polity": old_entry.get("polity", ""),
                    "type": old_entry.get("type", 0)
                })

        final_json_provinces[str(assigned_id)] = new_entry

    # Save
    original_data["provinces"] = final_json_provinces
    with open("migrated_data.json", "w") as f:
        json.dump(original_data, f, indent=4)
    output_img.save("migrated_map.png")

migrate_with_splits("old_map.png", "new_bw_map.png", "data.json")