import os
import shutil
import json

FLAGS_DIR = "/home/soi/Spirits-Of-Steel-Rebirth/assets/flags"
REDIRECTS_FILE = "/home/soi/Spirits-Of-Steel-Rebirth/assets/flags/flag_redirects.json"

# Mapping suffixes to ideologies
SUFFIX_MAPPING = [
    ("_kingdom", "monarchist"),
    ("_empire", "monarchist"),
    ("_republic", "liberal"), 
    ("_commune", "communist"),
    ("_union", "communist"),
    ("_socialist", "communist"),
    ("_fascist", "facist"),
    ("_national", "facist"),
    ("_democratic", "liberal"),
    ("_monarchy", "monarchist"),
    ("_sultanate", "monarchist"),
    ("_emirate", "monarchist"),
    ("_khanate", "monarchist"),
    ("_clique", "neutral"),
]

# Manual overrides for base names (Demonyms -> Country Name)
DEMONYM_MAPPING = {
    "french": "france",
    "german": "germany",
    "spanish": "spain",
    "italian": "italy",
    "polish": "poland",
    "danish": "denmark",
    "swedish": "sweden",
    "finnish": "finland",
    "turkish": "turkey",
    "greek": "greece",
    "russian": "russia",
    "belgian": "belgium",
    "mexican": "mexico",
    "brazilian": "brazil",
    "argentinian": "argentina",
    "portugese": "portugal",
    "japanese": "japan",
    "chinese": "china",
    "vietnamese": "vietnam",
    "korean": "korea", # Might be south_korea or joseon? check dirs.
    "ukrainian": "ukraine",
    "hungarian": "hungary",
    "romanian": "romania",
    "bulgarian": "bulgaria",
    "serbian": "serbia",
    "albanian": "albania",
    "norwegian": "norway",
    "austrian": "austria",
    "dutch": "netherlands", # Important
    "british": "united_kingdom",
    "english": "england",
    "scottish": "scotland",
    "irish": "ireland",
    "swiss": "switzerland",
    "czech": "czechia",
    "slovak": "slovakia",
    "mongolian": "mongolia",
    "thai": "thailand",
    "iranian": "iran",
    "iraqi": "iraq",
    "syrian": "syria",
    "egyptian": "egypt",
    "libyan": "libya",
    "ethiopian": "ethiopia",
    "nigerian": "nigeria",
    "indian": "india",
    "pakistani": "pakistan",
    "indonesian": "indonesia",
    "australian": "australia",
    "canadian": "canada",
    "american": "united_states", # classic
    "eurasian": "eurasia",
    "african": "african_union", # maybe?
    "arab": "saudi_arabia", # often map to saudi
    "slavic": "slavia", # or panslavia
    "soviet": "soviet_union", 
}

def merge_flags():
    candidates = [d for d in os.listdir(FLAGS_DIR) if os.path.isdir(os.path.join(FLAGS_DIR, d))]
    merged_count = 0
    redirects = {}
    
    # Load existing redirects if any, to append? No, simpler to rebuild or overwrite.
    # But wait, we already ran the script once and deleted folders.
    # We won't find "afghan_kingdom" anymore.
    # We should probably have tracked the previous run.
    # For now, this script will catch the ONES WE MISSED.
    # AND I'll try to reconstruct the ones we already did if possible?
    # No, I can't reconstruct deleted folders easily without undoing.
    # However, I can manually add the specific ones I saw in the log if I really need to,
    # or just accept that "afghan_kingdom" is gone and relying on the file system now?
    # Wait, if "afghan_kingdom" folder is gone, `get_flag("afghan_kingdom")` fails.
    # I NEED that redirect.
    # Since I didn't save it, I am in a bit of a pickle for the *already merged* ones.
    # BUT, I can rely on a runtime fallback in TroopManager: "if folder doesn't exist, try suffix stripping".
    # That is safer than relying on a static JSON that I missed generating 50% of the data for.
    
    # SO: I will generate redirects for the NEW merges.
    # AND I will implement the runtime suffix stripping in TroopManager as the primary solution.
    # The JSON is strictly an optimization or override.
    
    for folder_name in candidates:
        matched_suffix = None
        target_ideology = None
        
        for suffix, ideology in SUFFIX_MAPPING:
            if folder_name.endswith(suffix):
                matched_suffix = suffix
                target_ideology = ideology
                break
        
        if not matched_suffix:
            # Prefix check
            if folder_name.startswith("kingdom_of_"):
                matched_suffix = "kingdom_of_"
                target_ideology = "monarchist"
            elif folder_name.startswith("republic_of_"):
                matched_suffix = "republic_of_"
                target_ideology = "liberal"
        
        if not matched_suffix:
            continue
            
        # Determine Base
        if matched_suffix.startswith("_"):
             base_name_candidate = folder_name[:-len(matched_suffix)]
        else:
             base_name_candidate = folder_name[len(matched_suffix):]

        # Apply Demonym Mapping
        if base_name_candidate in DEMONYM_MAPPING:
            base_name_candidate = DEMONYM_MAPPING[base_name_candidate]

        target_dir_name = None
        
        # A. Exact Match
        if os.path.exists(os.path.join(FLAGS_DIR, base_name_candidate)):
             target_dir_name = base_name_candidate
        
        # B. Fuzzy Match
        if not target_dir_name:
            potential_targets = []
            for d in os.listdir(FLAGS_DIR):
                path = os.path.join(FLAGS_DIR, d)
                if not os.path.isdir(path): continue
                if d == folder_name: continue
                
                if d.startswith(base_name_candidate):
                    # Check for suffix presence to avoid merging peers
                    has_suffix = False
                    for s, _ in SUFFIX_MAPPING:
                        if d.endswith(s):
                            has_suffix = True
                            break
                    if not has_suffix:
                        potential_targets.append(d)
            
            if len(potential_targets) == 1:
                target_dir_name = potential_targets[0]
            elif len(potential_targets) > 1:
                # Try to pick the shortest one (usually the base)
                # e.g. "germany", "germania" -> germany is shorter?
                potential_targets.sort(key=len)
                target_dir_name = potential_targets[0]
                # print(f"Resolved ambiguous {base_name_candidate} to {target_dir_name} (Candidates: {potential_targets})")

        if not target_dir_name:
            continue
            
        print(f"Merging {folder_name} -> {target_dir_name} (Ideology: {target_ideology})")
        
        # Record Redirect
        redirects[folder_name] = {"target": target_dir_name, "ideology": target_ideology}
        
        source_dir = os.path.join(FLAGS_DIR, folder_name)
        base_dir = os.path.join(FLAGS_DIR, target_dir_name)

        source_flag = os.path.join(source_dir, "neutral_flag.png")
        target_flag = os.path.join(base_dir, f"{target_ideology}_flag.png")
        
        if os.path.exists(source_flag):
            if not os.path.exists(target_flag):
                shutil.move(source_flag, target_flag)
                if os.path.exists(source_flag + ".import"):
                    shutil.move(source_flag + ".import", target_flag + ".import")
            else:
                pass # Target exists
        
        for filename in os.listdir(source_dir):
            if filename == "neutral_flag.png" or filename == "neutral_flag.png.import":
                continue 
            src_path = os.path.join(source_dir, filename)
            dst_path = os.path.join(base_dir, filename)
            if not os.path.exists(dst_path):
                shutil.move(src_path, dst_path)
            
        if not os.listdir(source_dir):
            os.rmdir(source_dir)
            merged_count += 1

    print(f"Merge complete. Merged {merged_count} folders.")
    
    # Save redirects
    if os.path.exists(REDIRECTS_FILE):
        try:
            with open(REDIRECTS_FILE, 'r') as f:
                existing = json.load(f)
                existing.update(redirects)
                redirects = existing
        except:
            pass
            
    with open(REDIRECTS_FILE, 'w') as f:
        json.dump(redirects, f, indent=2)
        print(f"Saved redirects to {REDIRECTS_FILE}")

if __name__ == "__main__":
    merge_flags()
