import os, sys, subprocess

SupportedFormats: set[str] = ["mp4"]

def main():
    properDir: str = os.curdir + "/../assets/cutscenes"
    for file in os.scandir(properDir):
        name, extension = file.name.rsplit(".", 1)
        if file.is_file() and extension in SupportedFormats:
            print(f"{file.path} | {name} : {extension}")
            subprocess.run(f"ffmpeg -i {file.path} -vf \"scale=-1:720\" -c:v libtheora -q:v 7 -c:a libvorbis -q:a 6 -g:v 64 {name}.ogv")
            pass

main()