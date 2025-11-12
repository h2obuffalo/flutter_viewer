#!/usr/bin/env python3
"""
Generate iOS app icons from bftv_eye.png
"""
from PIL import Image
import os

# Source image
source_path = 'assets/images/bftv_eye.png'
output_dir = 'ios/Runner/Assets.xcassets/AppIcon.appiconset'

# iOS icon sizes needed (from Contents.json)
icon_sizes = [
    # iPhone
    ('20x20', 20, 20, 'Icon-App-20x20@2x.png', 2),
    ('20x20', 20, 20, 'Icon-App-20x20@3x.png', 3),
    ('29x29', 29, 29, 'Icon-App-29x29@1x.png', 1),
    ('29x29', 29, 29, 'Icon-App-29x29@2x.png', 2),
    ('29x29', 29, 29, 'Icon-App-29x29@3x.png', 3),
    ('40x40', 40, 40, 'Icon-App-40x40@2x.png', 2),
    ('40x40', 40, 40, 'Icon-App-40x40@3x.png', 3),
    ('60x60', 60, 60, 'Icon-App-60x60@2x.png', 2),
    ('60x60', 60, 60, 'Icon-App-60x60@3x.png', 3),
    # iPad
    ('20x20', 20, 20, 'Icon-App-20x20@1x.png', 1),
    ('20x20', 20, 20, 'Icon-App-20x20@2x.png', 2),  # Already done above
    ('29x29', 29, 29, 'Icon-App-29x29@1x.png', 1),  # Already done above
    ('29x29', 29, 29, 'Icon-App-29x29@2x.png', 2),  # Already done above
    ('40x40', 40, 40, 'Icon-App-40x40@1x.png', 1),
    ('40x40', 40, 40, 'Icon-App-40x40@2x.png', 2),  # Already done above
    ('76x76', 76, 76, 'Icon-App-76x76@1x.png', 1),
    ('76x76', 76, 76, 'Icon-App-76x76@2x.png', 2),
    ('83.5x83.5', 83.5, 83.5, 'Icon-App-83.5x83.5@2x.png', 2),
    # iOS Marketing (App Store)
    ('1024x1024', 1024, 1024, 'Icon-App-1024x1024@1x.png', 1),
]

def generate_icons():
    # Load source image
    print(f"Loading source image: {source_path}")
    source = Image.open(source_path)
    
    # Convert to RGBA if needed
    if source.mode != 'RGBA':
        source = source.convert('RGBA')
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Track which files we've already generated
    generated = set()
    
    # Generate each icon size
    for size_name, width, height, filename, scale in icon_sizes:
        if filename in generated:
            continue
            
        # Calculate actual pixel size
        actual_width = int(width * scale)
        actual_height = int(height * scale)
        
        # Resize image with high-quality resampling
        icon = source.resize((actual_width, actual_height), Image.Resampling.LANCZOS)
        
        # Save icon
        output_path = os.path.join(output_dir, filename)
        icon.save(output_path, 'PNG', optimize=True)
        generated.add(filename)
        
        print(f"Generated: {filename} ({actual_width}x{actual_height})")
    
    print(f"\n✅ Generated {len(generated)} icon files in {output_dir}")

if __name__ == '__main__':
    generate_icons()


