from PIL import Image
from json import dump, load
from pprint import pprint


def wrap(value, max):
    return value % max

def rgb_to_hex(r, g, b): 
    return '#{:02x}{:02x}{:02x}'.format(r, g, b).upper()

def main():
    biomes = {}
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
        uhh = load(f)
        coloredata = {tuple(v["color"]): k for k, v in uhh.items()}

    with open("input/city_colors.json") as f:
        uhh = load(f)
        city_colors = {eval(k): v for k, v in uhh.items()}

    with open("input/gdp_data.json") as f:
        uhh = load(f)
        gdp_data = {eval(k): v for k, v in uhh.items()}

    with open("input/population_color_map.json") as f:
        uhh = load(f)
        pop_data = {eval(k): v for k, v in uhh.items()}

    with open("input/cultures.json") as f:
        uhh = load(f)
        cult_data = {tuple(v): k for k, v in uhh.items()}

    cmap = Image.open("input/polities.png").convert("RGB")
    pmap = Image.open("input/regions.png").convert("RGB")
    city_map = Image.open("input/city_colors.png").convert("RGB")
    gdp_map = Image.open("input/gdp_data.png").convert("RGB")
    pop_map = Image.open("input/population_color_map.png").convert("RGB")
    cult_map = Image.open("input/cultures.png").convert("RGB")

    cpixels = cmap.load()
    ppixels = pmap.load()
    city_pixels = city_map.load()
    gdp_pixels = gdp_map.load()
    pop_pixels = pop_map.load()
    cult_pixels = cult_map.load()

    width, height = cmap.size
    print(width, height)

    blacklist = {
            (0, 0, 0),
            (105, 118, 132),
            (126, 142, 158),
            (255, 255, 255)
            }

    for i in range(height * width):
        country_color = tuple(cpixels[i % width, i // width])
        province_color = tuple(ppixels[i % width, i // width])
        city_color = tuple(city_pixels[i % width, i // width])
        gdp_color = tuple(gdp_pixels[i % width, i // width])
        pop_color = tuple(pop_pixels[i % width, i // width])
        cult_color = tuple(cult_pixels[i % width, i // width])

        if province_color in blacklist and country_color in blacklist: # I assume you can't just put BLACK in colors?
            continue

        if country_color in coloredata:
            country = coloredata[country_color].capitalize()
            culture = cult_data.get(cult_color, "brazilians").capitalize()

            if country_color not in blacklist and country_color in coloredata:
                sosr_time["polities"].append(
                        {
                            "name": country, 
                            "color": rgb_to_hex(*country_color),
                            "flag": "",
                            "money": 100000,
                            "ideology": [0, 0],
                            "political_power": 500,
                            "stability": 1.0,
                            "war_support": 1.0,
                            "acceptedCultures": [culture],
                            "puppets": []
                        }
                )
                blacklist.add(country_color)

            id = (province_color[2] + province_color[1]*256 + province_color[0]*65536)
            if id not in sosr_time["provinces"]:
                sosr_time["provinces"][id] = {
                        "type": "land",
                        "name": "",
                        "polity": country,
                        "biome": "",
                        "resources": [],
                        "buildings": [],
                        "population": [{"ethnicity": culture,
                                         "amount": pop_data.get(pop_color, 0)}],
                        "claims": [],
                        "gdp": gdp_data.get(gdp_color, 0),
                        }


                blacklist.add(province_color)
                if city_color not in blacklist:
                    sosr_time["provinces"][id]["city"] = city_colors[city_color]
                    blacklist.add(city_color)

                count +=1

    # NOTE(soi): this is the worst code known to mankind
    for province in sosr_time["provinces"].values():
        province["name"]
        for country in sosr_time["polities"]:
            if country["name"] == province["polity"]:
                for population in province["population"]:
                    if population["ethnicity"] not in country["acceptedCultures"]:
                        country["acceptedCultures"].append(population["ethnicity"])

    pprint(sosr_time)
    with open("map_data.json", "w") as f:
        dump(sosr_time, f, indent=4, sort_keys=True)
    print(count)


main()
