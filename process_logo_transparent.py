from PIL import Image, ImageDraw
import os
import base64

logo_path = r'c:\xampp\htdocs\Quran Center\QuranCircles.Web\assets\logo.png'
img = Image.open(logo_path).convert("RGBA")

width, height = img.size

# Create a circular mask
mask = Image.new('L', (width, height), 0)
draw = ImageDraw.Draw(mask)
# Smooth anti-aliased circle
draw.ellipse((2, 2, width - 2, height - 2), fill=255)

# Put alpha mask on image
result = Image.new('RGBA', (width, height), (0, 0, 0, 0))
result.paste(img, (0, 0), mask=mask)

output_path = r'c:\xampp\htdocs\Quran Center\QuranCircles.Web\assets\logo.png'
result.save(output_path, "PNG")
print("Saved transparent circular logo.png!")

# Generate updated Base64
with open(output_path, "rb") as f:
    b64_data = base64.b64encode(f.read()).decode('utf-8')
    data_url = 'data:image/png;base64,' + b64_data

js_path = r'c:\xampp\htdocs\Quran Center\QuranCircles.Web\assets\logo_base64.js'
with open(js_path, 'w', encoding='utf-8') as js_file:
    js_file.write(f'const CENTER_LOGO_BASE64 = "{data_url}";\n')

print("Saved transparent logo Base64 to logo_base64.js!")
