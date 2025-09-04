#!/usr/bin/env python3
"""
Create a simple ModelDay logo placeholder image
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_logo():
    # Create a 512x512 image with a transparent background
    width, height = 512, 512
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Draw a golden circle background
    circle_margin = 50
    circle_coords = [circle_margin, circle_margin, width - circle_margin, height - circle_margin]
    draw.ellipse(circle_coords, fill=(255, 215, 0, 255))  # Gold color
    
    # Try to use a default font, fallback to basic if not available
    try:
        font_size = 60
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        try:
            font = ImageFont.load_default()
        except:
            font = None
    
    # Draw text
    text = "ModelDay"
    if font:
        # Get text bounding box
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        # Center the text
        x = (width - text_width) // 2
        y = (height - text_height) // 2
        
        # Draw text with black color
        draw.text((x, y), text, fill=(0, 0, 0, 255), font=font)
    else:
        # Fallback without font
        draw.text((width//2 - 50, height//2 - 10), text, fill=(0, 0, 0, 255))
    
    return image

def create_hero_image():
    # Create a 1200x600 hero image
    width, height = 1200, 600
    image = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    
    # Create a gradient-like background
    for y in range(height):
        # Gradient from dark blue to light blue
        color_value = int(50 + (y / height) * 100)
        draw.line([(0, y), (width, y)], fill=(color_value, color_value, 255, 255))
    
    # Try to use a default font
    try:
        font_size = 80
        font = ImageFont.truetype("arial.ttf", font_size)
    except:
        try:
            font = ImageFont.load_default()
        except:
            font = None
    
    # Draw hero text
    text = "ModelDay"
    if font:
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        x = (width - text_width) // 2
        y = (height - text_height) // 2
        
        draw.text((x, y), text, fill=(255, 255, 255, 255), font=font)
    else:
        draw.text((width//2 - 100, height//2 - 20), text, fill=(255, 255, 255, 255))
    
    return image

if __name__ == "__main__":
    # Create assets/images directory if it doesn't exist
    os.makedirs("assets/images", exist_ok=True)
    
    # Create and save logo
    logo = create_logo()
    logo.save("assets/images/model_day_logo.png", "PNG")
    print("Created assets/images/model_day_logo.png")
    
    # Create and save hero image
    hero = create_hero_image()
    hero.save("assets/images/hero_sec.png", "PNG")
    print("Created assets/images/hero_sec.png")
    
    print("Logo and hero images created successfully!")
