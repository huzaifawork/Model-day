#!/usr/bin/env python3
"""
Simple script to create test images for OCR testing
Requires: pip install pillow
"""

from PIL import Image, ImageDraw, ImageFont
import os

def create_agent_test_image():
    # Create a white background image
    width, height = 600, 400
    image = Image.new('RGB', (width, height), 'white')
    draw = ImageDraw.Draw(image)
    
    # Try to use a system font, fallback to default
    try:
        font_large = ImageFont.truetype("arial.ttf", 24)
        font_medium = ImageFont.truetype("arial.ttf", 18)
        font_small = ImageFont.truetype("arial.ttf", 14)
    except:
        font_large = ImageFont.load_default()
        font_medium = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Draw border
    draw.rectangle([10, 10, width-10, height-10], outline='black', width=2)
    
    # Title
    draw.text((50, 30), "TALENT AGENT", fill='black', font=font_large)
    draw.text((50, 60), "Professional Representation", fill='gray', font=font_small)
    
    # Draw a line
    draw.line([50, 90, width-50, 90], fill='black', width=1)
    
    # Agent information
    y_pos = 120
    line_height = 25
    
    agent_info = [
        "Name: Sarah Johnson",
        "Agency: Elite Modeling Agency",
        "Phone: +1 (555) 123-4567",
        "Email: sarah.johnson@elitemodeling.com",
        "Office: 123 Fashion Ave, New York, NY 10001",
        "Website: www.elitemodeling.com",
        "",
        "Specialties: Fashion, Commercial, Editorial",
        "Commission: 15-20%",
        "Experience: 10+ years in industry"
    ]
    
    for line in agent_info:
        if line.strip():
            draw.text((50, y_pos), line, fill='black', font=font_medium)
        y_pos += line_height
    
    # Save the image
    image.save('agent_test_image.png')
    print("✅ Created agent_test_image.png")
    
    return 'agent_test_image.png'

def create_simple_text_image():
    # Create a simple text image for basic OCR testing
    width, height = 400, 200
    image = Image.new('RGB', (width, height), 'white')
    draw = ImageDraw.Draw(image)
    
    try:
        font = ImageFont.truetype("arial.ttf", 20)
    except:
        font = ImageFont.load_default()
    
    # Simple text
    text_lines = [
        "bookingAgent: John Smith",
        "agency: Premier Talent",
        "phone: +1-555-0123",
        "email: john@premier.com",
        "notes: Available weekdays"
    ]
    
    y_pos = 30
    for line in text_lines:
        draw.text((20, y_pos), line, fill='black', font=font)
        y_pos += 30
    
    image.save('simple_ocr_test.png')
    print("✅ Created simple_ocr_test.png")
    
    return 'simple_ocr_test.png'

if __name__ == "__main__":
    print("🖼️ Creating OCR test images...")
    
    try:
        agent_img = create_agent_test_image()
        simple_img = create_simple_text_image()
        
        print(f"\n📋 Test Images Created:")
        print(f"1. {agent_img} - Detailed agent card")
        print(f"2. {simple_img} - Simple text for basic testing")
        
        print(f"\n🧪 How to test:")
        print(f"1. Go to http://localhost:3000/#/new-agent")
        print(f"2. Click the OCR upload area")
        print(f"3. Select one of the created images")
        print(f"4. Check if the agent information is extracted correctly")
        
    except ImportError:
        print("❌ PIL (Pillow) not installed. Install with: pip install pillow")
    except Exception as e:
        print(f"❌ Error creating images: {e}")
