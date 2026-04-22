import os
import json
import random
import numpy as np
from PIL import Image, ImageDraw

def generate_world(output_dir, width=1024, height=1024, num_provinces=200, num_countries=10):
    os.makedirs(output_dir, exist_ok=True)
    os.makedirs(os.path.join(output_dir, "decisions"), exist_ok=True)
    
    print(f"Generating world: {width}x{height}, {num_provinces} provinces, {num_countries} countries")
    
    # 1. Generate Land Mask (Improved blob noise)
    mask = np.zeros((height, width), dtype=np.uint8)
    num_blobs = random.randint(20, 40)
    for _ in range(num_blobs):
        cx, cy = random.randint(0, width), random.randint(0, height)
        radius_x = random.randint(width // 20, width // 5)
        radius_y = random.randint(height // 20, height // 5)
        # Add some "noise" by using multiple smaller blobs around the center
        for _ in range(5):
            ocx = cx + random.randint(-radius_x//2, radius_x//2)
            ocy = cy + random.randint(-radius_y//2, radius_y//2)
            or_x = random.randint(radius_x//4, radius_x)
            or_y = random.randint(radius_y//4, radius_y)
            y, x = np.ogrid[-ocy:height-ocy, -ocx:width-ocx]
            blob_mask = (x*x)/(or_x*or_x) + (y*y)/(or_y*or_y) <= 1
            mask[blob_mask] = 1
                    
    # 2. Generate Province Seeds on Land
    land_pixels = np.argwhere(mask == 1)
    if len(land_pixels) < num_provinces:
        num_provinces = len(land_pixels)
    
    indices = np.random.choice(len(land_pixels), num_provinces, replace=False)
    seeds = land_pixels[indices]
    
    # 3. Voronoi Province Generation
    print("Calculating province boundaries...")
    province_colors = []
    used_colors = set()
    used_colors.add(0) # Black for borders/sea
    
    def get_unique_color():
        while True:
            r = random.randint(1, 255)
            g = random.randint(1, 255)
            b = random.randint(1, 255)
            color_int = (r << 16) | (g << 8) | b
            if color_int not in used_colors:
                used_colors.add(color_int)
                return (r, g, b), color_int

    province_id_to_color_int = {}
    for i in range(num_provinces):
        rgb, color_int = get_unique_color()
        province_colors.append(rgb)
        province_id_to_color_int[i+1] = color_int
        
    y_coords, x_coords = np.where(mask == 1)
    points = np.column_stack((y_coords, x_coords))
    
    chunk_size = 5000
    min_indices = []
    for i in range(0, len(points), chunk_size):
        chunk = points[i:i+chunk_size]
        dists = np.sum((chunk[:, np.newaxis, :] - seeds[np.newaxis, :, :])**2, axis=2)
        min_indices.append(np.argmin(dists, axis=1))
    
    min_indices = np.concatenate(min_indices)
    
    regions_img = Image.new("RGB", (width, height), (0, 0, 0))
    pixels = regions_img.load()
    for idx, (y, x) in enumerate(points):
        province_idx = min_indices[idx]
        pixels[int(x), int(y)] = province_colors[province_idx]
        
    regions_img.save(os.path.join(output_dir, "regions.png"))
    
    # 4. Generate Countries
    prefixes = ["United", "Democratic", "Holy", "Imperial", "Peoples", "Federal", "Great"]
    bases = ["Soveria", "Aethel", "Orodreth", "Valoria", "Kaldor", "Zandalar", "Eridu", "Numinor", "Gondor", "Arnor"]
    suffixes = ["Republic", "Empire", "Kingdom", "Union", "State", "Federation", "Domain"]
    
    country_names = []
    while len(country_names) < num_countries:
        name = f"{random.choice(prefixes)}_{random.choice(bases)}_{random.choice(suffixes)}"
        if name not in country_names:
            country_names.append(name)
            
    countries = []
    for name in country_names:
        countries.append({
            "name": name,
            "color": "#"+''.join([random.choice('0123456789ABCDEF') for _ in range(6)]),
            "money": 10000.0,
            "ideology": [random.randint(-100, 100), random.randint(-100, 100)],
            "political_power": 150.0,
            "stability": random.uniform(0.4, 0.8),
            "war_support": random.uniform(0.2, 0.6),
            "manpower": random.randint(50000, 500000),
            "puppets": [],
            "accepted_cultures": ["Commoner"],
            "figures": []
        })
    
    # Assign provinces to countries
    country_list = [c["name"] for c in countries]
    map_data_provinces = {}
    for i in range(num_provinces):
        color_int = province_id_to_color_int[i+1]
        country = random.choice(country_list)
        map_data_provinces[str(color_int)] = {
            "type": 1,
            "name": f"Province {i+1}",
            "polity": country,
            "biome": "140, 204, 189",
            "resources": [{"type": "Iron", "amount": random.randint(1, 5), "quality": 0.5}],
            "city": f"Capital City" if random.random() < 0.1 else "",
            "buildings": [],
            "population": [{"ethnicity": "Commoner", "amount": random.randint(100000, 1000000)}],
            "claims": [],
            "gdp": random.randint(10000, 100000)
        }
        
    # 5. Save Data Files
    with open(os.path.join(output_dir, "map_data.json"), "w") as f:
        json.dump({"provinces": map_data_provinces, "factions": [], "polities": countries}, f, indent=4)
    with open(os.path.join(output_dir, "building_functions.json"), "w") as f:
        json.dump({
            "Factory": {"build_cost": {"money": "500.0"}, "requirements": "true", "input": [], "output": []},
            "Port": {"build_cost": {"money": "400.0"}, "requirements": "true", "input": [], "output": []}
        }, f, indent=4)
    with open(os.path.join(output_dir, "superevents.json"), "w") as f:
        json.dump({}, f, indent=4)

    # 6. Generate Focuses
    for country in country_list:
        dec_id = country.replace(" ", "_").lower()
        decisions = {
            "categories": {
                "National Focus": [
                    {
                        "id": f"focus_{dec_id}_start",
                        "title": f"The Destiny of {country}",
                        "desc": "A new era begins.",
                        "cost_pp": 50.0,
                        "days": 70.0,
                        "pos": [500, 100],
                        "action": [{"func": "add_country_attr", "args": ["stability", 0.05]}]
                    },
                    {
                        "id": f"focus_{dec_id}_expansion",
                        "title": "Territorial Expansion",
                        "desc": "Our borders must grow.",
                        "cost_pp": 50.0,
                        "days": 70.0,
                        "pos": [300, 300],
                        "prereq": f"focus_{dec_id}_start",
                        "action": [{"func": "add_country_attr", "args": ["war_support", 0.1]}]
                    },
                    {
                        "id": f"focus_{dec_id}_economy",
                        "title": "Economic Miracle",
                        "desc": "Building a better future.",
                        "cost_pp": 50.0,
                        "days": 70.0,
                        "pos": [700, 300],
                        "prereq": f"focus_{dec_id}_start",
                        "action": [{"func": "add_country_attr", "args": ["money", 5000.0]}]
                    }
                ]
            }
        }
        with open(os.path.join(output_dir, "decisions", f"{country}.json"), "w") as f:
            json.dump(decisions, f, indent=4)

    # 7. Other textures
    polities_img = Image.new("RGB", (width, height), (105, 142, 158))
    pol_pixels = polities_img.load()
    def hex_to_rgb(h): return tuple(int(h.lstrip('#')[i:i+2], 16) for i in (0, 2, 4))
    country_colors_rgb = {c["name"]: hex_to_rgb(c["color"]) for c in countries}
    reg_pixels = regions_img.load()
    for y in range(height):
        for x in range(width):
            reg_rgb = reg_pixels[x, y]
            if reg_rgb == (0, 0, 0): continue
            c_int = (reg_rgb[0] << 16) | (reg_rgb[1] << 8) | reg_rgb[2]
            p_data = map_data_provinces.get(str(c_int))
            if p_data: pol_pixels[x, y] = country_colors_rgb[p_data["polity"]]
    polities_img.save(os.path.join(output_dir, "polities.png"))
    regions_img.save(os.path.join(output_dir, "worldRegions.png"))
    regions_img.save(os.path.join(output_dir, "culture.png"))
    regions_img.save(os.path.join(output_dir, "biomes.png"))
    regions_img.save(os.path.join(output_dir, "blank.png"))
    print(f"Successfully generated world in {output_dir}")

if __name__ == "__main__":
    import sys
    # Default parameters or from CLI
    width = 1024
    height = 1024
    num_provinces = 200
    num_countries = 10
    
    target_dir = os.path.join("starts", "RandomWorld")
    generate_world(target_dir, width, height, num_provinces, num_countries)
