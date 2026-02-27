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
    with open("input/countries.json") as f:
        coloredata = {tuple(v["color"]): k for k, v in load(f).items()}
    with open("input/ethnicities.json") as f:
        eth_data = load(f)

    # with open("input/ethnicities.json", 'w') as f:
    #     for country in coloredata:
    #         if not eth_data.get(str(country), True):
    #             eth_data[str(country)] = coloredata[country]
    #     for ethnicity in eth_data:
    #         eth_data[ethnicity] = eth_data[ethnicity].capitalize().replace(' ', '-').replace('_', '-').replace('\n', '-')
    #     dump(eth_data, f, indent=4)

    with open("input/population_color_map.json") as f:
        pop_data = load(f)
    with open("input/gdp_data.json") as f:
        gdp_data = load(f)
    with open("input/city_colors.json") as f:
        city_data = load(f)
    # with open("input/claims.json") as f:
    #     claims_data = load(f)
    cmap = Image.open("input/polities.png").convert("RGB")
    eth_map = Image.open("input/ethnicities.png").convert("RGB")
    pop_map = Image.open("input/population_color_map.png").convert("RGB")
    gdp_map = Image.open("input/gdp_data.png").convert("RGB")
    city_map = Image.open("input/city_colors.png").convert("RGB")
    # claims_map = Image.open("input/claims.png").convert("RGB")
    industry_map = Image.open("input/industry.png").convert("RGB")
    biomes_map = Image.open("input/biomes.png").convert("RGB")
    pmap = Image.open("input/regions.png").convert("RGB")
    cpixels = cmap.load()
    eth_pixels = eth_map.load()
    pop_pixels = pop_map.load()
    gdp_pixels = gdp_map.load()
    city_pixels = city_map.load()
    # claims_pixels = claims_map.load()
    industry_pixels = industry_map.load()
    biomes_pixels = biomes_map.load()
    ppixels = pmap.load()

    width, height = cmap.size
    print(width, height)

    blacklist = {
            (0, 0, 0),
            (105, 118, 132),
            (126, 142, 158),
            # (255, 255, 255)
            }

    unknown_cultures = set() 

    for i in range(height * width):
        country_color = tuple(cpixels[i % width, i // width])
        eth_color = tuple(eth_pixels[i % width, i // width])
        pop_color = tuple(pop_pixels[i % width, i // width])
        gdp_color = tuple(gdp_pixels[i % width, i // width])
        city_color = tuple(city_pixels[i % width, i // width])


        # claims_color = tuple(claims_pixels[i % width, i // width])
        industry_color = tuple(industry_pixels[i % width, i // width])
        biomes_color = tuple(biomes_pixels[i % width, i // width])
        province_color = tuple(ppixels[i % width, i // width])
        if province_color in blacklist and country_color in blacklist: # I assume you can't just put BLACK in colors?
            continue
        id = (province_color[2] + province_color[1]*256 + province_color[0]*65536)
        if id not in sosr_time["provinces"] and country_color in coloredata:
            sosr_time["provinces"][str(id)] = {
                "type": "land",
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
                "city": city_data.get(f"({city_color[0]}, {city_color[1]}, {city_color[2]})", ""),
                "buildings": [
                    {
                        "type": "Factory",
                        "state": 1,
                        "durability": 1.0
                    }
                ] if industry_color == (255, 255, 0) else [],
                "population": [
                    {
                        "ethnicity": eth_data.get(f"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})", "Unknown"),
                        "amount": pop_data.get(f"({pop_color[0]}, {pop_color[1]}, {pop_color[2]})", 10000)
                    }
                ],
                "claims": [
                    # entryer.capitalize() for entryer in claims_data.get(f"({claims_color[0]},{claims_color[1]},{claims_color[2]})", [])
                    ],
                "gdp": gdp_data.get(f"({gdp_color[0]}, {gdp_color[1]}, {gdp_color[2]})", 1500000)
            }
            blacklist.add(province_color)
            count +=1

            if not eth_data[f"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})"]:
                unknown_cultures.add(f"{rgb_to_hex(*eth_color)} \"({eth_color[0]}, {eth_color[1]}, {eth_color[2]})\"            ")

        if country_color not in blacklist and country_color in coloredata:
            sosr_time["polities"].append(
                    {
                        "name": coloredata[country_color].capitalize(), 
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
            blacklist.add(country_color)


    # NOTE(soi): this is the worst code known to mankind
    for province in sosr_time["provinces"].values():
        province["name"]
        for country in sosr_time["polities"]:
            if country["name"] == province["polity"]:
                for population in province["population"]:
                    if population["ethnicity"] not in country["accepted_cultures"]:
                        country["accepted_cultures"].append(population["ethnicity"])

    # pprint(sosr_time)
    pprint(unknown_cultures)
    with open("output/map_data.json", "w") as f:
        dump(sosr_time, f, indent=4)
    print(count)


main()
