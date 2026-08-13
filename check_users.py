import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

conn = sqlite3.connect(r'c:\xampp\htdocs\Quran Center\QuranCircles.Api\QuranCircles.Api\quran.db')
cursor = conn.cursor()

cursor.execute('SELECT Id, Username, Role, PlainPassword, PasswordHash, FullName FROM Users LIMIT 15;')
users = cursor.fetchall()

print("Sample Users in Database:")
for u in users:
    print(f"ID: {u[0]} | Username: '{u[1]}' | Role: {u[2]} | PlainPass: '{u[3]}' | PassHash: '{u[4]}' | Name: '{u[5]}'")

conn.close()
