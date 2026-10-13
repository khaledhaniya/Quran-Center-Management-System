from contextlib import closing
import sqlite3
import tempfile
import unittest
from pathlib import Path
from sqlite_backup import backup, restore


class BackupTests(unittest.TestCase):
    def test_restore_preserves_previous_database(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            db = root / "source.db"
            with closing(sqlite3.connect(db)) as conn:
                conn.execute("CREATE TABLE items (name TEXT)")
                conn.execute("INSERT INTO items VALUES ('original')")
                conn.commit()
            saved = backup(db, root / "saved.db")
            with closing(sqlite3.connect(db)) as conn:
                conn.execute("UPDATE items SET name='changed'")
                conn.commit()
            previous = restore(db, saved, root / "backups")
            with closing(sqlite3.connect(db)) as conn:
                self.assertEqual(conn.execute("SELECT name FROM items").fetchone()[0], "original")
            with closing(sqlite3.connect(previous)) as conn:
                self.assertEqual(conn.execute("SELECT name FROM items").fetchone()[0], "changed")

    def test_refuses_corrupt_source_without_touching_database(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            db = root / "current.db"
            with closing(sqlite3.connect(db)) as conn:
                conn.execute("CREATE TABLE items (name TEXT)")
            original = db.read_bytes()
            bad = root / "bad.db"
            bad.write_text("not a database")
            with self.assertRaises(sqlite3.DatabaseError):
                restore(db, bad, root / "backups")
            self.assertEqual(db.read_bytes(), original)

    def test_refuses_restore_with_wal(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            db = root / "current.db"
            with closing(sqlite3.connect(db)) as conn:
                conn.execute("CREATE TABLE items (name TEXT)")
            saved = backup(db, root / "saved.db")
            Path(str(db) + "-wal").touch()
            with self.assertRaises(ValueError):
                restore(db, saved, root / "backups")


if __name__ == "__main__":
    unittest.main()
