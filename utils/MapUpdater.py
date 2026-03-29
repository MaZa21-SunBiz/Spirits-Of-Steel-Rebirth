import os
import json
from PIL import Image, ImageDraw
from collections import Counter

def rgb_to_id(rgb):
    return (rgb[0] << 16) | (rgb[1] << 8) | rgb[2]

def id_to_rgb(id):
    return ((id >> 16) & 0xFF, (id >> 8) & 0xFF, id & 0xFF)

def update_map(map_data_path, regions_path, blank_map_path, output_dir):
    print(f"Loading data...")
    with open(map_data_path, "r") as f:
        old_map_data = json.load(f)
    
    old_regions = Image.open(regions_path).convert("RGB")
    old_pixels = old_regions.load()
    width, height = old_regions.size

    new_blank = Image.open(blank_map_path).convert("RGB")
    new_pixels = new_blank.load()
    
    # Create a working copy for flood-filling
    # We use a white background and will fill provinces with unique IDs
    # Borders are assumed to be (0, 0, 0)
    working_map = new_blank.copy()
    w_pixels = working_map.load()
    
    border_color = (0, 0, 0)
    # Background color might be white or something else, 
    # but we want to find everything that isn't a border.
    
    # To store mapping: new_id -> list of (x, y)
    new_provinces = {}
    
    print("Identifying new provinces...")
    province_counter = 1
    flood_blacklist = {border_color}
    
    # We'll use a unique color for each province to identify them
    for y in range(height):
        for x in range(width):
            c = w_pixels[x, y]
            if c in flood_blacklist:
                continue
            
            province_counter += 1
            new_color = id_to_rgb(province_counter)
            flood_blacklist.add(new_color)
            
            # Floodfill the region in working_map
            ImageDraw.floodfill(working_map, (x, y), new_color)
            
    # Reload pixels after floodfill
    w_pixels = working_map.load()
    
    # Group pixels by new province ID
    print("Gathering pixel data...")
    province_pixel_groups = {}
    for y in range(height):
        for x in range(width):
            c = w_pixels[x, y]
            if c == border_color:
                continue
            
            p_id = rgb_to_id(c)
            if p_id not in province_pixel_groups:
                province_pixel_groups[p_id] = []
            province_pixel_groups[p_id].append((x, y))
            
    print(f"Found {len(province_pixel_groups)} new provinces.")
    
    new_provinces_data = {}
    assigned_cities = set()
    
    print("Transferring metadata from old map data...")
    for p_id, pixels in province_pixel_groups.items():
        # Find which old province ID is most common in these pixels
        old_id_votes = []
        for x, y in pixels:
            old_c = old_pixels[x, y]
            old_p_id = rgb_to_id(old_c)
            # 0 or black might be borders, we should ignore them in votes if possible
            if old_c != (0, 0, 0):
                old_id_votes.append(str(old_p_id)) # map_data uses string keys for IDs
        
        if not old_id_votes:
            # New province with no overlap with old land? 
            # Default empty data
            new_provinces_data[str(p_id)] = {
                "type": 1,
                "name": "New Province",
                "polity": "Neutral",
                "biome": "0, 0, 0",
                "resources": [],
                "city": "",
                "buildings": [],
                "populations": [],
                "claims": [],
                "gdp": 0
            }
            continue
            
        # Get most common old ID
        most_common_old_id = Counter(old_id_votes).most_common(1)[0][0]
        
        if most_common_old_id in old_map_data["provinces"]:
            # Copy data
            prov_data = old_map_data["provinces"][most_common_old_id].copy()
            city_name = prov_data.get("city", "")
            if city_name:
                if city_name in assigned_cities:
                    prov_data["city"] = ""
                else:
                    assigned_cities.add(city_name)
            new_provinces_data[str(p_id)] = prov_data
        else:
            # Fallback if ID not in json (unlikely if regions.png is consistent)
            new_provinces_data[str(p_id)] = {
                "type": 1,
                "name": f"Unknown {most_common_old_id}",
                "polity": "Neutral",
                "biome": "0, 0, 0",
                "resources": [],
                "city": "",
                "buildings": [],
                "populations": [],
                "claims": [],
                "gdp": 0
            }

    # Prepare final map data
    final_map_data = old_map_data.copy()
    final_map_data["provinces"] = new_provinces_data
    
    # Save results
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
        
    print(f"Saving new regions.png to {output_dir}...")
    working_map.save(os.path.join(output_dir, "regions.png"))
    
    print(f"Saving new map_data.json to {output_dir}...")
    with open(os.path.join(output_dir, "map_data.json"), "w") as f:
        json.dump(final_map_data, f, indent=4, sort_keys=True)
        
    print("Done!")

if __name__ == "__main__":
    # Using paths relative to utils directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    
    map_data_path = os.path.join(script_dir, "input/map_data.json")
    if not os.path.exists(map_data_path):
        map_data_path = os.path.join(script_dir, "map_data.json")
        
    regions_path = os.path.join(script_dir, "input/regions.png")
    blank_map_path = os.path.join(script_dir, "input/blank.png")
    output_dir = os.path.join(script_dir, "output")
    
    update_map(map_data_path, regions_path, blank_map_path, output_dir)
