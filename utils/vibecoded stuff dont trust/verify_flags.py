import os

FLAGS_DIR = "/home/soi/Spirits-Of-Steel-Rebirth/assets/flags"

def verify_flags():
    countries = [d for d in os.listdir(FLAGS_DIR) if os.path.isdir(os.path.join(FLAGS_DIR, d))]
    
    missing_neutral = []
    
    print(f"Checking {len(countries)} country directories...")
    
    for country in countries:
        neutral_path = os.path.join(FLAGS_DIR, country, "neutral_flag.png")
        if not os.path.exists(neutral_path):
            missing_neutral.append(country)
            
    if missing_neutral:
        print(f"ERROR: The following {len(missing_neutral)} countries are missing 'neutral_flag.png':")
        for c in missing_neutral:
            print(f" - {c}")
    else:
        print("SUCCESS: All country directories contain 'neutral_flag.png'.")

    # Check for loose files
    loose_files = [f for f in os.listdir(FLAGS_DIR) if os.path.isfile(os.path.join(FLAGS_DIR, f)) and f.endswith("_flag.png")]
    if loose_files:
        print(f"WARNING: Found {len(loose_files)} loose flag files in root (should be moved):")
        for f in loose_files:
            print(f" - {f}")
    else:
        print("SUCCESS: No loose flag files found in root.")

if __name__ == "__main__":
    verify_flags()
