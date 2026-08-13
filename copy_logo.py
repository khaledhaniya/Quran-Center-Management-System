import shutil
import os
import base64

src = r'C:\Users\w11\.gemini\antigravity-ide\brain\a4c3ace2-1677-4748-b346-106819ded615\media__1786185391239.png'
dest_dir = r'c:\xampp\htdocs\Quran Center\QuranCircles.Web\assets'
os.makedirs(dest_dir, exist_ok=True)
dest_png = os.path.join(dest_dir, 'logo.png')
shutil.copy(src, dest_png)
print('Copied logo to:', dest_png)

with open(src, 'rb') as f:
    b64_data = base64.b64encode(f.read()).decode('utf-8')
    data_url = 'data:image/png;base64,' + b64_data

with open(os.path.join(dest_dir, 'logo_base64.js'), 'w', encoding='utf-8') as js_file:
    js_file.write(f'const CENTER_LOGO_BASE64 = "{data_url}";\n')

print('Base64 logo saved to logo_base64.js!')
