import sqlite3

conn = sqlite3.connect(r'c:\xampp\htdocs\Quran Center\QuranCircles.Api\QuranCircles.Api\quran.db')
cursor = conn.cursor()
cursor.execute("SELECT name FROM sqlite_master WHERE type='table';")
tables = [row[0] for row in cursor.fetchall()]
print('Tables in quran.db:', tables)

for t in tables:
    cursor.execute(f"PRAGMA table_info('{t}');")
    cols = [f"{c[1]} ({c[2]})" for c in cursor.fetchall()]
    print(f"Table '{t}':", cols)
