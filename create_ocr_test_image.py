#!/usr/bin/env python3
"""
Create a high-quality PNG image for OCR testing with ModelDay data
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_ocr_test_image():
    # Image dimensions
    width = 800
    height = 1000
    
    # Create white background
    image = Image.new('RGB', (width, height), 'white')
    draw = ImageDraw.Draw(image)
    
    # Try to use a better font, fallback to default
    try:
        # Try to load a system font
        title_font = ImageFont.truetype("arial.ttf", 24)
        header_font = ImageFont.truetype("arial.ttf", 18)
        text_font = ImageFont.truetype("arial.ttf", 16)
        small_font = ImageFont.truetype("arial.ttf", 14)
    except:
        try:
            # Fallback for different systems
            title_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 24)
            header_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 18)
            text_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 16)
            small_font = ImageFont.truetype("/System/Library/Fonts/Arial.ttf", 14)
        except:
            # Use default font
            title_font = ImageFont.load_default()
            header_font = ImageFont.load_default()
            text_font = ImageFont.load_default()
            small_font = ImageFont.load_default()
    
    # Colors
    black = (0, 0, 0)
    gray = (100, 100, 100)
    
    # Starting position
    y = 50
    margin = 50
    
    # Title
    draw.text((margin, y), "MODEL BOOKING CONFIRMATION", font=title_font, fill=black)
    y += 60
    
    # Draw a line
    draw.line([(margin, y), (width - margin, y)], fill=black, width=2)
    y += 30
    
    # Client information
    draw.text((margin, y), "Client: SAMSUNG", font=header_font, fill=black)
    y += 35
    
    draw.text((margin, y), "Contact: Adrien Gras | IMM BELGIUM", font=text_font, fill=black)
    y += 30
    
    draw.text((margin, y), "Agent: Sarah Johnson", font=text_font, fill=black)
    y += 50
    
    # Job details section
    draw.text((margin, y), "Job Details:", font=header_font, fill=black)
    y += 35
    
    job_details = [
        "Title: Samsung Galaxy Book 5",
        "Media: All electronic, digital, All print, Online",
        "Usage Period: 1 year",
        "Release Country: Global",
        "Exclusivity: Non-exclusive",
        "Shooting Schedule: 2nd week of May 2025",
        "Shooting Location: TBC",
        "Budget: 6000 euros gross"
    ]
    
    for detail in job_details:
        draw.text((margin + 20, y), detail, font=text_font, fill=black)
        y += 25
    
    y += 30
    
    # Payment information
    draw.text((margin, y), "Payment Terms:", font=header_font, fill=black)
    y += 35
    
    payment_info = [
        "Day Rate: 500 EUR",
        "Usage Rate: 5500 EUR", 
        "Total: 6000 EUR",
        "Payment: Net 30 days",
        "Currency: EUR"
    ]
    
    for info in payment_info:
        draw.text((margin + 20, y), info, font=text_font, fill=black)
        y += 25
    
    y += 40
    
    # Contact section
    draw.line([(margin, y), (width - margin, y)], fill=gray, width=1)
    y += 30
    
    draw.text((margin, y), "Agent Contact Information:", font=header_font, fill=black)
    y += 35
    
    contact_info = [
        "Sarah Johnson",
        "Model Agent",
        "+48 794 939 555",
        "sarah@uncovermodels.com",
        "",
        "Uncover Models",
        "Raclawicka 99/03",
        "Warsaw, Poland"
    ]
    
    for info in contact_info:
        if info:  # Skip empty lines
            draw.text((margin, y), info, font=text_font, fill=black)
        y += 22
    
    y += 30
    
    # Additional requirements
    draw.text((margin, y), "Requirements:", font=header_font, fill=black)
    y += 35
    
    requirements = [
        "• Model must be available for full day",
        "• Professional portfolio required",
        "• Previous tech campaign experience preferred",
        "• Wardrobe: Business casual provided"
    ]
    
    for req in requirements:
        draw.text((margin, y), req, font=small_font, fill=black)
        y += 22
    
    # Save the image
    filename = "ocr_test_document.png"
    image.save(filename, "PNG", quality=95)
    print(f"✅ OCR test image created: {filename}")
    print(f"📏 Image size: {width}x{height} pixels")
    print(f"📍 Location: {os.path.abspath(filename)}")
    
    return filename

if __name__ == "__main__":
    create_ocr_test_image()
