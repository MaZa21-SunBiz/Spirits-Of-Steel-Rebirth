from PIL import Image, ImageDraw

def main():
    image = Image.open("input/polities.png").convert("RGB")
    pixels = image.load()
    if not pixels:
        return

    width, height = image.size

    blacklist = {
            (0, 0, 0),
            # (126, 142, 158),
            # (105, 118, 132)
            }

    counter = 1

    for i in range(height * width):
        c = pixels[i % width, i // width]
        if c in blacklist: # I assume you can't just put BLACK in colors?
            continue
        counter += 1
        new_color = ((counter // 65536) % 256, (counter // 256) % 256, counter % 256)
        if c == (105, 118, 132):
            new_color = (0, 0, 0)
        blacklist.add(new_color)

        ImageDraw.floodfill(image, (i % width, i // width), new_color)

        # If you want just check for black here for validation or something.
 
    print("Saved image to 'provinces.png'")
    image.save("regions.png")
    print(counter)

if __name__ == "__main__":
    main()
