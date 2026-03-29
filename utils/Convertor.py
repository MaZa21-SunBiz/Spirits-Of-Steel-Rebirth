import os
from PIL import Image, ImageDraw
from json import dump, load
from pprint import pprint


def wrap(value, max):
    return value % max

def rgb_to_hex(r, g, b): 
    return '#{:02x}{:02x}{:02x}'.format(r, g, b).upper()

def main():
    count = 0
    sosr_time = {
            "factions": [],
            "provinces": {},
            "polities": [],
            "ideologies": {
                "neutral": {
                  "region": [
                    [ -25,  -25],
                    [  25,   25]
                  ]
                },
                "communist": {
                  "region": [
                    [-100, -100],
                    [   0,    0]
                  ]
                },
                "fascist": {
                  "region": [
                    [   0, -100],
                    [ 100,    0]
                  ]
                },
                "liberal": {
                  "region": [
                    [-100,    0],
                    [   0,  100]
                  ]
                },
                "conservative": {
                  "region": [
                    [   0,    0],
                    [ 100,  100]
                  ]
                },
                "monarchist": {
                  "region": [
                    [  50,   50],
                    [ 150,  150] 
                  ]
                }
            },
            "info": {
              "name": "Mesianic Bilgecon",
              "description": "A world in chaos as great powers fight.",
              "time": 0
            }
        }
    
    # Paths (relative to script location)
    input_dir = "input"
    output_dir = "output"
    blank_map_path = "input/blank.png"
    
    with open(os.path.join(input_dir, "countries.json")) as f:
        coloredata = {tuple(v["color"]): k for k, v in load(f).items()}
    with open(os.path.join(input_dir, "ethnicities.json")) as f:
        eth_data = load(f)

    with open(os.path.join(input_dir, "population_color_map.json")) as f:
        pop_data = load(f)
    with open(os.path.join(input_dir, "gdp_data.json")) as f:
        gdp_data = load(f)
    with open(os.path.join(input_dir, "city_colors.json")) as f:
        city_data = load(f)

    print(f"Loading blank map from {blank_map_path}...")
    pmap = Image.open(blank_map_path).convert("RGB")
    width, height = pmap.size
    ppixels = pmap.load()

    print("Generating province IDs (floodfilling)...")
    flood_blacklist = {(0, 0, 0)}
    province_counter = 1
    
    # We use a copy of the blank map to avoid modifying the original if we need it later, 
    # but since we are redefining ppixels from it, we'll just use pmap.
    for i in range(height * width):
        x, y = i % width, i // width
        c = ppixels[x, y]
        if c in flood_blacklist:
            continue
            
        province_counter += 1
        # Create a unique color for the province ID
        new_color = ((province_counter // 65536) % 256, (province_counter // 256) % 256, province_counter % 256)
        
        # Specific rule from color.py
        if c == (105, 118, 132):
            new_color = (0, 0, 0)
            
        flood_blacklist.add(new_color)
        ImageDraw.floodfill(pmap, (x, y), new_color)

    # After floodfilling, reload pixels to get the new colors
    ppixels = pmap.load()
    print(f"Detected {province_counter} potential provinces (including black regions).")

    print("Loading other map layers...")
    cmap = Image.open(os.path.join(input_dir, "polities.png")).convert("RGB")
    eth_map = Image.open(os.path.join(input_dir, "ethnicities.png")).convert("RGB")
    pop_map = Image.open(os.path.join(input_dir, "population_color_map.png")).convert("RGB")
    gdp_map = Image.open(os.path.join(input_dir, "gdp_data.png")).convert("RGB")
    city_map = Image.open(os.path.join(input_dir, "city_colors.png")).convert("RGB")
    industry_map = Image.open(os.path.join(input_dir, "industry.png")).convert("RGB")
    biomes_map = Image.open(os.path.join(input_dir, "biomes.png")).convert("RGB")
    
    cpixels = cmap.load()
    eth_pixels = eth_map.load()
    pop_pixels = pop_map.load()
    gdp_pixels = gdp_map.load()
    city_pixels = city_map.load()
    industry_pixels = industry_map.load()
    biomes_pixels = biomes_map.load()

    blacklist = {
            (0, 0, 0),
            (105, 118, 132),
            (126, 142, 158),
            }

    unknown_cultures = set() 
    assigned_cities = set()
    
    print("Extracting data for each province...")
    for i in range(height * width):
        x, y = i % width, i // width
        country_color = tuple(cpixels[x, y])
        eth_color = tuple(eth_pixels[x, y])
        pop_color = tuple(pop_pixels[x, y])
        gdp_color = tuple(gdp_pixels[x, y])
        city_color = tuple(city_pixels[x, y])
        industry_color = tuple(industry_pixels[x, y])
        biomes_color = tuple(biomes_pixels[x, y])
        province_color = tuple(ppixels[x, y])

        if province_color in blacklist and country_color in blacklist:
            continue
            
        id = (province_color[2] + province_color[1]*256 + province_color[0]*65536)
        
        if id not in sosr_time["provinces"] and country_color in coloredata:
            city_name = city_data.get(f"({city_color[0]}, {city_color[1]}, {city_color[2]})", "")
            if city_name:
                if city_name in assigned_cities:
                    city_name = ""
                else:
                    assigned_cities.add(city_name)
                    
            sosr_time["provinces"][id] = {
                "type": 1,
                "name": "",
                "polity": coloredata[country_color].capitalize(),
                "biome": f"{biomes_color[0]}, {biomes_color[1]}, {biomes_color[2]}",
                "resources": [
                    {
                        "type": "Iron",
                        "amount": 2,
                        "quality": 0.5
                    }
                ],
                "city": city_name,
                "buildings": [
                    {
                        "type": "Factory",
                        "state": 1,
                        "durability": 1.0
                    }
                ] if industry_color == (255, 255, 0) else [],
                "populations": [
                    {
                        "ethnicity": eth_data.get(f"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})", "Unknown"),
                        "amount": pop_data.get(f"({pop_color[0]}, {pop_color[1]}, {pop_color[2]})", 10000)
                    }
                ],
                "claims": [],
                "gdp": gdp_data.get(f"({gdp_color[0]}, {gdp_color[1]}, {gdp_color[2]})", 1500000)
            }
            count +=1

            if not eth_data.get(f"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})", False):
                unknown_cultures.add(f"{rgb_to_hex(*eth_color)} \"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})\"            ")

        if country_color not in blacklist and country_color in coloredata:
            # Check if polity already added
            polity_name = coloredata[country_color].capitalize()
            if not any(p["name"] == polity_name for p in sosr_time["polities"]):
                sosr_time["polities"].append(
                        {
                            "name": polity_name, 
                            "color": rgb_to_hex(*country_color),
                            "flag": "",
                            "money": 100000,
                            "ideology": [0, 0],
                            "political_power": 500,
                            "stability": 1.0,
                            "war_support": 1.0,
                            "accepted_cultures": [],
                            "puppets": []
                        }
                        )

    print("Post-processing accepted cultures...")
    for province in sosr_time["provinces"].values():
        for country in sosr_time["polities"]:
            if country["name"] == province["polity"]:
                for population in province["populations"]:
                    if population["ethnicity"] not in country["accepted_cultures"]:
                        country["accepted_cultures"].append(population["ethnicity"])

    print(f"Saving regions map to {os.path.join(output_dir, 'regions.png')}...")
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    pmap.save(os.path.join(output_dir, "regions.png"))

    print(f"Saving map data to {os.path.join(output_dir, 'map_data.json')}...")
    with open(os.path.join(output_dir, "map_data.json"), "w") as f:
        dump(sosr_time, f, indent=4, sort_keys=True)
        
    print(f"Execution complete. Total provinces: {count}")
    if unknown_cultures:
        print("Unknown cultures detected:")
        pprint(unknown_cultures)


if __name__ == "__main__":
    main()
