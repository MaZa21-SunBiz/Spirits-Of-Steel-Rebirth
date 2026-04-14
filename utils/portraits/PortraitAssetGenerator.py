import numpy as np
import random
import math
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ASSET_SIZE = 512

class AssetFactory:
    def __init__(self, output_dir="Assets", seed=None):
        self.base = Path(output_dir)
        self.rng = np.random.RandomState(seed)

        self.layers = [
            "Background",
            "BodyBase",
            "HeadBase",
            "Eyes",
            "Nose",
            "Mouth",
            "HairBase",
            "HairDetail",
            "Accessories"
        ]

        self._create_dirs()

    def _create_dirs(self):
        for layer in self.layers:
            (self.base / layer).mkdir(parents=True, exist_ok=True)

    def _save(self, img, layer, name):
        img.save(self.base / layer / f"{name}.png")

    def _blank(self):
        return Image.new("RGBA", (ASSET_SIZE, ASSET_SIZE), (0, 0, 0, 0))
    
    def radial_shading(self, center, radius, strength=0.8):
        y, x = np.ogrid[:ASSET_SIZE, :ASSET_SIZE]
        cx, cy = center
        dist = np.sqrt((x - cx)**2 + (y - cy)**2)
        mask = np.clip(1 - (dist / radius), 0, 1)
        return (mask * 255 * strength).astype(np.uint8)

    def skin_texture(self):
        noise = self.rng.normal(0, 8, (ASSET_SIZE, ASSET_SIZE))
        noise = np.clip(noise + 128, 0, 255).astype(np.uint8)
        return Image.fromarray(noise).filter(ImageFilter.GaussianBlur(1.2))

    def generate_background(self, count=20):
        for i in range(count):
            base = np.zeros((ASSET_SIZE, ASSET_SIZE), dtype=np.uint8)

            gradient = np.linspace(80, 180, ASSET_SIZE)
            base[:] = gradient[:, None]

            noise = self.rng.normal(0, 10, base.shape)
            base = np.clip(base + noise, 0, 255)

            img = Image.fromarray(base).convert("RGBA")
            img = img.filter(ImageFilter.GaussianBlur(4))

            self._save(img, "Background", f"bg_{i}")

    def generate_head(self, count=30):
        for i in range(count):
            # Canvas setup
            arr = np.zeros((ASSET_SIZE, ASSET_SIZE), dtype=np.float32)
            y, x = np.ogrid[:ASSET_SIZE, :ASSET_SIZE]
            
            # Shifted slightly up to account for chin space
            cx, cy = 256, 220 
            
            # 1. RIGID GEOMETRY (The "Bones")
            # Cranium: Larger and slightly wider to prevent the "small head" look
            cranium = ((x - cx)**2) / (155**2) + ((y - cy)**2) / (165**2)
            
            # Jaw: Tapered trapezoid logic
            # We increase the base width to 130 to keep it beefy
            jaw_taper = np.clip((y - cy) / 180, 0, 1)
            dynamic_width = 130 * (1.0 - 0.3 * jaw_taper) 
            jaw = (np.abs(x - cx) / dynamic_width)**2.2 + ((y - cy) / 190)**2
            
            # Combine: 0.0 is center, 1.0 is edge
            head_sdf = np.minimum(cranium, jaw)

            # 2. SOLID ALPHA MASK
            # Instead of a linear fade, we use a sharp step with a tiny margin for AA
            # This prevents the "ghostly" transparent look.
            mask_softness = 0.02
            mask = 1.0 - np.clip((head_sdf - 1.0) / mask_softness, 0, 1)
            
            # 3. ANATOMICAL SHADING (The "Clay")
            light_dir = np.array([-0.6, -0.7])
            # Normalized coordinates for lighting calculations
            nx = (x - cx) / 155
            ny = (y - cy) / 165
            dot = nx * light_dir[0] + ny * light_dir[1]
            
            # Base skin tone range (100-200 for headroom)
            shading = (dot * 60 + 140)

            # Sculpting the features:
            # Brow Ridge (Shadow under the brow)
            shading -= np.exp(-((y - (cy - 15))**2) / 900) * 20
            
            # Cheekbone Highlights (Zygomatic process)
            cheek_x_dist = np.abs(x - cx) - 75
            cheek_y_dist = y - (cy + 25)
            cheek_spots = np.exp(-(cheek_x_dist**2 / 1000 + cheek_y_dist**2 / 800))
            shading += cheek_spots * 25
            
            # Chin Definition
            chin_spot = np.exp(-((x - cx)**2 / 800 + (y - (cy + 160))**2 / 600))
            shading += chin_spot * 20

            # Apply shading to the masked area
            arr = shading * mask

            # 4. FINALIZATION
            arr = np.clip(arr, 0, 255).astype(np.uint8)
            img = Image.fromarray(arr).convert("RGBA")
            
            # Create a sharp, solid Alpha channel
            alpha_channel = (mask * 255).astype(np.uint8)
            img.putalpha(Image.fromarray(alpha_channel, "L"))
            
            # Light blur to simulate skin texture/diffuse light
            img = img.filter(ImageFilter.GaussianBlur(0.6))
            
            self._save(img, "HeadBase", f"head_{i}")

    def generate_body(self, count=5):
        for i in range(count):
            img = self._blank()
            draw = ImageDraw.Draw(img)

            w = random.randint(280, 340)
            h = random.randint(220, 280)

            x0 = (512 - w) // 2
            y0 = 300

            draw.rounded_rectangle(
                [x0, y0, x0 + w, y0 + h],
                radius=40,
                fill=(200, 200, 200, 255)
            )

            img = img.filter(ImageFilter.GaussianBlur(1.2))
            self._save(img, "BodyBase", f"body_{i}")

    def generate_eyes(self, count=40):
        for i in range(count):
            # Initialize RGBA canvas
            arr = np.zeros((ASSET_SIZE, ASSET_SIZE, 4), dtype=np.float32)
            y_grid, x_grid = np.ogrid[:ASSET_SIZE, :ASSET_SIZE]
            
            spacing = self.rng.randint(110, 145)
            base_y = 235 
            
            for side in [-1, 1]:
                cx = 256 + side * (spacing // 2)
                
                # 1. THE EYELID MASK (The "Slit")
                # We intersect two shifted circles to create an almond/vesica piscis shape
                eye_width = 45
                eye_height = 22
                # Upper lid curve
                upper_lid = ((x_grid - cx)**2) / (eye_width**2) + ((y_grid - (base_y + 10))**2) / (eye_height**2)
                # Lower lid curve (shallower)
                lower_lid = ((x_grid - cx)**2) / (eye_width**2) + ((y_grid - (base_y - 12))**2) / (eye_height**2)
                
                eye_mask = (upper_lid <= 1.0) & (lower_lid <= 1.0)
                
                # 2. THE SCLERA (Eyeball Sphere)
                # Subtle radial shading to make the white look spherical
                dist_sq = ((x_grid - cx)**2 + (y_grid - base_y)**2)
                sclera_shading = 245 - np.sqrt(dist_sq) * 0.8 
                
                # 3. THE IRIS & PUPIL
                iris_radius = self.rng.randint(16, 22)
                iris_dist_sq = ((x_grid - cx)**2 + (y_grid - base_y)**2)
                iris_mask = iris_dist_sq <= iris_radius**2
                
                # Iris color with radial gradient (lighter near pupil)
                iris_val = 60 + (np.sqrt(iris_dist_sq) / iris_radius) * 40
                
                # Pupil (Deep black)
                pupil_mask = iris_dist_sq <= 7**2
                
                # 4. COMPOSITING THE LAYERS
                # Start with sclera
                chan_rgb = np.full((ASSET_SIZE, ASSET_SIZE, 3), 255.0)
                for c in range(3):
                    chan_rgb[..., c] = sclera_shading
                    
                # Overwrite with Iris
                for c in range(3):
                    chan_rgb[iris_mask, c] = iris_val[iris_mask]
                    
                # Overwrite with Pupil
                chan_rgb[pupil_mask, :] = 20
                
                # Specular Highlight (The "Glint")
                highlight_mask = ((x_grid - (cx - 6))**2 + (y_grid - (base_y - 6))**2) <= 4**2
                chan_rgb[highlight_mask, :] = 255
                
                # 5. APPLY TO MAIN ARRAY
                # We only apply the RGB where the eye_mask is True
                arr[eye_mask, :3] = chan_rgb[eye_mask]
                arr[eye_mask, 3] = 255  # Solid Alpha

            # Final Processing
            arr = np.clip(arr, 0, 255).astype(np.uint8)
            img = Image.fromarray(arr, mode="RGBA")
            
            # Soften edges and simulate eye moisture
            img = img.filter(ImageFilter.GaussianBlur(0.6))
            self._save(img, "Eyes", f"eyes_{i}")

    def generate_nose(self, count=25):
        for i in range(count):
            cx, cy = 256, 290

            arr = np.zeros((ASSET_SIZE, ASSET_SIZE), dtype=np.float32)

            # Vertical ridge (bridge of nose)
            for y in range(240, 340):
                for x in range(cx - 20, cx + 20):
                    dist = abs(x - cx)
                    falloff = max(0, 1 - dist / 20)
                    arr[y, x] += falloff * 120

            # Soft bulb at tip
            y, x = np.ogrid[:ASSET_SIZE, :ASSET_SIZE]
            dist = np.sqrt((x - cx)**2 + (y - (cy + 20))**2)
            bulb = np.clip(1 - dist / 30, 0, 1)
            arr += bulb * 80

            arr = np.clip(arr, 0, 255).astype(np.uint8)

            img = Image.fromarray(arr).convert("RGBA")

            alpha_img = Image.fromarray(arr, mode="L")
            img.putalpha(alpha_img)

            img = img.filter(ImageFilter.GaussianBlur(1.2))

            self._save(img, "Nose", f"nose_{i}")

    def generate_mouth(self, count=30):
        for i in range(count):
            arr = np.zeros((ASSET_SIZE, ASSET_SIZE, 4), dtype=np.float32)
            y_grid, x_grid = np.ogrid[:ASSET_SIZE, :ASSET_SIZE]
            
            # Move center up slightly to fix "Too tall" placement
            cx, cy = 256, 365 
            
            # Thinner profile: Reduced width and tighter thickness ranges
            width = self.rng.randint(25, 45) 
            upper_thickness = self.rng.uniform(8, 12)
            lower_thickness = self.rng.uniform(12, 16)
            
            # Coordinate mapping
            dx = (x_grid - cx) / width
            dy = (y_grid - cy)
            
            # 1. THE SHAPE (Fixing "Wonk")
            # Sharper Cupid's Bow with a steeper falloff
            cupid_bow = 0.2 * np.cos(dx * np.pi) * np.exp(-dx**2 * 2)
            upper_mask = (dx**2 + ((dy + 6) / upper_thickness + cupid_bow)**2) <= 1.0
            lower_mask = (dx**2 + ((dy - 4) / lower_thickness)**2) <= 1.0
            mouth_mask = upper_mask | lower_mask

            # 2. VERTICAL LINES (Patterning)
            # High frequency vertical strips modulated by the mouth mask
            line_pattern = 1.0 - (0.15 * np.abs(np.sin(dx * width * 0.5)))
            
            # 3. ENHANCED LIGHTING & SHADING
            # Stronger top-down gradient for volume
            shading = (150 - (dy * 3.5)).astype(np.float32)
            
            # Apply the vertical lines pattern to the shading
            #shading *= line_pattern

            # Specular "Wet" Lighting (Lower lip pout)
            # Using a higher power for a tighter, more intense highlight
            pout_highlight = np.exp(-((dy - 6)**2 / 15 + (dx * 1.5)**2)) * 50
            shading = shading + pout_highlight

            # The "Part Line" (Stomion) - Darker and sharper
            part_line = np.exp(-(dy**2) / 4) * np.exp(-(dx**2) / 0.8)
            shading = shading * (1.0 - part_line * 0.85)

            # 4. COMPOSITING
            # Tinting: Greyscale base with a slight bias towards mid-tones
            chan_rgb = np.stack([shading] * 3, axis=-1)
            arr[mouth_mask, :3] = chan_rgb[mouth_mask]
            
            # Alpha with a tighter falloff to make it look "thinner" and less blurry
            dist_field = np.minimum(
                (dx**2 + ((dy + 6) / upper_thickness + cupid_bow)**2),
                (dx**2 + ((dy - 4) / lower_thickness)**2)
            )
            alpha = np.clip((1.02 - dist_field) * 15, 0, 1)
            arr[..., 3] = alpha * 255

            # 5. FINALIZATION
            arr = np.clip(arr, 0, 255).astype(np.uint8)
            img = Image.fromarray(arr, mode="RGBA")
            
            # Subtle blur to integrate with skin, but keeping the lines visible
            img = img.filter(ImageFilter.GaussianBlur(0.6))
            self._save(img, "Mouth", f"mouth_{i}")

    def generate_hair(self, count=40):
        for i in range(count):
            final_rgb = np.zeros((ASSET_SIZE, ASSET_SIZE, 3), dtype=np.float32)
            final_alpha = np.zeros((ASSET_SIZE, ASSET_SIZE), dtype=np.float32)
            
            y_grid, x_grid = np.mgrid[:ASSET_SIZE, :ASSET_SIZE]
            cx, cy = 256, 170 

            # 1. DEFINE THE SMOOTH FACE CUTOUT
            # We use an oval that narrows at the top to clear the forehead/eyes
            # and tapers down for the jaw.
            dx_face = (x_grid - cx) / 125
            dy_face = (y_grid - (cy + 140)) / 160 # Centered lower on the face
            face_sdf = (dx_face**2 + dy_face**2)
            
            # Create a soft mask: 0 inside the face, 1 outside the face
            # We use a smooth transition to avoid the rectangular "cut"
            face_cutout_mask = np.clip((face_sdf - 0.7) / 0.3, 0, 1)

            # 2. FLOW FIELD
            dx = (x_grid - cx) / 160
            dy = (y_grid - cy) / 200
            flow_x_base = dx * 0.7  
            flow_y_base = 1.0 + np.abs(dx) * 0.3
            
            num_layers = 4
            for layer in range(1, num_layers + 1):
                is_outer = (layer > 2)
                seed_threshold = 1.6 + (layer - 1) * 0.2
                steps = 15 + (layer - 1) * 3
                layer_brightness = 80 + (layer - 1) * 27
                layer_wobble = 0.2 + (layer - 1) * (0.2 if is_outer else 0.1)

                layer_canvas = np.zeros((ASSET_SIZE, ASSET_SIZE), dtype=np.float32)
                noise = self.rng.standard_normal((ASSET_SIZE, ASSET_SIZE)).astype(np.float32)
                strands = np.where(noise > seed_threshold, 1.0, 0.0).astype(np.float32)
                
                curr_x = x_grid.astype(np.float32)
                curr_y = y_grid.astype(np.float32)

                for step in range(steps):
                    curl_wobble = np.sin(step * 0.6) * layer_wobble
                    curr_x += (flow_x_base + curl_wobble) * 1.3
                    curr_y += flow_y_base * 1.1
                    
                    ix = np.clip(curr_x, 0, ASSET_SIZE-1).astype(np.int32)
                    iy = np.clip(curr_y, 0, ASSET_SIZE-1).astype(np.int32)
                    
                    fade = np.cos((step / steps) * (np.pi / 2.1)) 
                    layer_canvas[iy, ix] += strands * fade

                # 3. COMPOSITE MASKING
                scale_adj = 1.0 + (layer - 1) * 0.01 
                scalp_mask = ((x_grid - cx)**2 / (185*scale_adj)**2 + (y_grid - (cy+20))**2 / (165*scale_adj)**2) <= 1.0
                hanging_mask = (np.abs(x_grid - cx) < 190) & (y_grid >= cy) & (y_grid < cy + (steps * 8.5))
                
                # Combine general shape and subtract the smooth face zone
                final_mask = (scalp_mask | hanging_mask).astype(np.float32) * face_cutout_mask
                
                # 4. SHADING & ACCUMULATION
                ao = np.clip((y_grid - cy + 80) / 200, 0.15, 1.0)
                layer_intensity = (layer_canvas * layer_brightness * 0.4 * ao) * final_mask
                
                final_rgb += layer_intensity[..., np.newaxis] 
                final_alpha += (layer_canvas * 255 * final_mask)

            # 5. GLOBAL POLISH
            global_shine = np.exp(-((y_grid - (cy + 30))**2) / 1000) * 50
            hair_exists = (final_alpha > 50).astype(np.float32)
            
            final_rgb = (final_rgb * (1.0 + global_shine[..., np.newaxis] / 255)) + (global_shine[..., np.newaxis] * hair_exists[..., np.newaxis])

            # Final Assembly
            arr = np.zeros((ASSET_SIZE, ASSET_SIZE, 4), dtype=np.uint8)
            arr[..., 0:3] = np.clip(final_rgb, 0, 255).astype(np.uint8)
            arr[..., 3] = np.clip(final_alpha, 0, 255).astype(np.uint8)

            img = Image.fromarray(arr, mode="RGBA")
            img = img.filter(ImageFilter.GaussianBlur(0.35))

            self._save(img, "HairBase", f"hair_{i}")

    def generate_hair_detail(self, count=30):
        for i in range(count):
            img = self._blank()
            draw = ImageDraw.Draw(img)

            cx, cy = 256, 180

            draw.ellipse(
                [cx-160, cy-120, cx+160, cy+140],
                fill=(180,180,180,255)
            )

            img = img.filter(ImageFilter.GaussianBlur(8))

            self._save(img, "HairDetail", f"hair_vol_{i}")

    def generate_accessories(self, count=5):
        for i in range(count):
            img = self._blank()
            draw = ImageDraw.Draw(img)

            # Glasses
            y = 240
            for side in [-1, 1]:
                cx = 256 + side * 70
                draw.rectangle(
                    [cx - 35, y - 20, cx + 35, y + 20],
                    outline=(255, 255, 255, 255),
                    width=3
                )

            draw.line([(221, y), (291, y)], fill=(255, 255, 255, 255), width=3)

            self._save(img, "Accessories", f"acc_{i}")

    def generate_all(self):
        self.generate_background()
        self.generate_body()
        self.generate_head()
        self.generate_eyes()
        self.generate_nose()
        self.generate_mouth()
        self.generate_hair()
        self.generate_hair_detail()
        self.generate_accessories()


if __name__ == "__main__":
    factory = AssetFactory(seed=42)
    factory.generate_all()
    print("Asset generation complete.")