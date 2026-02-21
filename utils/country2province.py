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
    with open("countries.json") as f:
        uhh = load(f)
        coloredata = {tuple(v["color"]): k for k, v in uhh.items()}
    cmap = Image.open("polities.png").convert("RGB")
    pmap = Image.open("regions.png").convert("RGB")
    cpixels = cmap.load()
    ppixels = pmap.load()

    width, height = cmap.size
    print(width, height)

    blacklist = {
            (0, 0, 0),
            (105, 118, 132),
            (126, 142, 158),
            # (255, 255, 255)
            }

    for i in range(height * width):
        country_color = tuple(cpixels[i % width, i // width])
        province_color = tuple(ppixels[i % width, i // width])
        if province_color in blacklist and country_color in blacklist: # I assume you can't just put BLACK in colors?
            continue
        id = (province_color[2] + province_color[1]*256 + province_color[0]*65536)
        if id not in sosr_time["provinces"] and country_color in coloredata:
            sosr_time["provinces"][str(id)] = {
                    "type": "land",
                    "name": "",
                    "polity": coloredata[country_color].capitalize()
                    }
            blacklist.add(province_color)
            count +=1


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
                        "puppets": []
                    }
                    )
            blacklist.add(country_color)

    pprint(sosr_time)
    with open("map_data.json", "w") as f:
        dump(sosr_time, f)
    print(count)


main()
