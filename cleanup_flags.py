import os

FLAGS_DIR = "/home/soi/Spirits-Of-Steel-Rebirth/assets/flags"

def cleanup():
    countries = [d for d in os.listdir(FLAGS_DIR) if os.path.isdir(os.path.join(FLAGS_DIR, d))]
    
    removed_count = 0
    for country in countries:
        dir_path = os.path.join(FLAGS_DIR, country)
        if not os.listdir(dir_path):
            os.rmdir(dir_path)
            print(f"Removed empty directory: {country}")
            removed_count += 1
            
    print(f"Cleanup complete. Removed {removed_count} empty directories.")

if __name__ == "__main__":
    cleanup()
