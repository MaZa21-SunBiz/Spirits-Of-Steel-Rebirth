import os
import random
from pathlib import Path
from PIL import Image
from typing import List, Dict, Tuple, Optional

class PortraitGeneratorEngine:
    """
    A procedural, data-driven portrait generation engine relying on layered alpha compositing
    and runtime color modulation.
    """
    
    def __init__(self, a_assetDirectory: str) -> None:
        self._assetDirectory: Path = Path(a_assetDirectory)
        self._rng: random.Random = random.Random()

        self._renderStack: List[str] = [
            "Background",
            "BodyBase",
            "HeadBase",
            "Eyes",
            "Nose",
            "Mouth",
            "HairBase",
        ]
        self._assetRegistry: Dict[str, List[Path]] = self._BuildAssetRegistry()

    def _BuildAssetRegistry(self) -> Dict[str, List[Path]]:
        """Scans the asset directory and indexes all available PNG layers."""
        l_registry: Dict[str, List[Path]] = {}
        for l_layerName in self._renderStack:
            l_layerPath: Path = self._assetDirectory / l_layerName
            if l_layerPath.exists() and l_layerPath.is_dir():
                l_registry[l_layerName] = [
                    l_file for l_file in l_layerPath.iterdir()
                    if l_file.suffix.lower() in ['.png']
                ]
            else:
                l_registry[l_layerName] = []
        return l_registry

    def _ApplyColorModulation(self, a_image: Image.Image, a_colorTint: Tuple[int, int, int]) -> Image.Image:
        """
        Applies a procedural color multiply to a grayscale asset to generate dynamic tones.
        Gives explicit control over the final pixel output.
        """
        l_image: Image.Image = a_image.convert("RGBA")
        l_pixels = l_image.load()

        if l_pixels is None:
             return a_image

        for l_y in range(l_image.height):
            for l_x in range(l_image.width):
                l_r, l_g, l_b, l_a = l_pixels[l_x, l_y]
                
                # Only tint visible pixels
                if l_a > 0:
                    l_newR: int = int(l_r * (a_colorTint[0] / 255.0))
                    l_newG: int = int(l_g * (a_colorTint[1] / 255.0))
                    l_newB: int = int(l_b * (a_colorTint[2] / 255.0))
                    l_pixels[l_x, l_y] = (l_newR, l_newG, l_newB, l_a)

        return l_image

    def GeneratePortrait(self, a_seed: Optional[str] = None, a_outputPath: str = "output_portrait.png") -> bool:
        """
        Composites the portrait and writes it to disk. 
        Returns True if successful, False if no assets were found.
        """
        if a_seed is not None:
            self._rng.seed(a_seed)

        l_compositeImage: Optional[Image.Image] = None

        l_skinTone: Tuple[int, int, int] = (
            self._rng.randint(120, 255),
            self._rng.randint(90, 200),
            self._rng.randint(50, 150)
        )
        l_hairTone: Tuple[int, int, int] = (
            self._rng.randint(20, 255),
            self._rng.randint(20, 255),
            self._rng.randint(20, 255)
        )

        for l_layer in self._renderStack:
            l_availableAssets: List[Path] = self._assetRegistry.get(l_layer, [])

            if not l_availableAssets:
                continue

            if l_layer in ["Accessories"] and self._rng.random() > 0.75:
                continue

            l_selectedAsset: Path = self._rng.choice(l_availableAssets)
            l_layerImage: Image.Image = Image.open(l_selectedAsset).convert("RGBA")

            if l_layer in ["BodyBase", "HeadBase", "Nose"]:
                l_layerImage = self._ApplyColorModulation(l_layerImage, l_skinTone)
            elif l_layer in ["HairBase", "HairDetail"]:
                l_layerImage = self._ApplyColorModulation(l_layerImage, l_hairTone)

            if l_compositeImage is None:
                l_compositeImage = Image.new("RGBA", l_layerImage.size)

            l_compositeImage = Image.alpha_composite(l_compositeImage, l_layerImage)

        if l_compositeImage is not None:
            l_compositeImage.save(a_outputPath)
            return True

        return False

if __name__ == "__main__":
    # Ensure your directory matches the rendering stack exactly:
    # ./Assets/Background/
    # ./Assets/HeadBase/
    # etc...
    # All PNGs within those folders must share the exact same resolution (e.g., 512x512).
    
    l_generator: PortraitGeneratorEngine = PortraitGeneratorEngine("./Assets")
    
    # Passing a specific string seed ensures this exact combination of assets and tints can be recalled later
    l_generator.GeneratePortrait(a_seed=random.random(), a_outputPath="character_portrait_01.png")