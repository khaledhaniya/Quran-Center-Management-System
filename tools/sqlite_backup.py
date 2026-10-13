from contextlib import closing
"""Verified SQLite backups; restore only while the application is stopped."""
import argparse
from datetime import datetime, timezone
from pathlib import Path
import os
import sqlite3


def validate(path):
    if not path.is_file():
        raise ValueError("Database file does not exist")
    with closing(sqlite3.connect(path.resolve().as_uri() + "?mode=ro", uri=True)) as db:
        if db.execute("PRAGMA quick_check").fetchone()[0] != "ok":
            raise ValueError("Database integrity check failed")


def backup(database, destination):
    database, destination = Path(database).resolve(), Path(destination).resolve()
    if database == destination or destination.exists():
        raise ValueError("Backup destination must be a new, distinct file")
    validate(database)
    destination.parent.mkdir(parents=True, exist_ok=True)
    partial = destination.with_suffix(destination.suffix + ".partial")
    if partial.exists():
        raise ValueError("An unfinished backup already exists")
    try:
        with closing(sqlite3.connect(database.as_uri() + "?mode=ro", uri=True)) as source:
            with closing(sqlite3.connect(partial)) as target:
                source.backup(target)
        validate(partial)
        os.replace(partial, destination)
    except Exception:
        if partial.exists():
            partial.unlink()
        raise
    return destination


def restore(database, source, backup_dir):
    database, source = Path(database).resolve(), Path(source).resolve()
    validate(source)
    if database == source:
        raise ValueError("Restore source must be distinct from the database")
    # Refuse sidecars rather than replacing a live or uncheckpointed database.
    if any(Path(str(database) + suffix).exists() for suffix in ("-wal", "-shm", "-journal")):
        raise ValueError("Stop the server and close/checkpoint SQLite before restoring")
    stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    previous = None
    if database.exists():
        previous = backup(database, Path(backup_dir) / f"before-restore-{stamp}.db")
    staged = database.with_name(database.name + f".restore-{stamp}")
    backup(source, staged)
    try:
        if database.exists():
            # An exclusive lock is a second check that no connection is active.
            with closing(sqlite3.connect(database, timeout=0)) as connection:
                connection.execute("BEGIN EXCLUSIVE")
                connection.rollback()
        os.replace(staged, database)
    except Exception:
        if staged.exists():
            staged.unlink()
        raise
    return previous


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", required=True, type=Path)
    parser.add_argument("--backup-dir", type=Path, default=Path("backups"))
    parser.add_argument("--restore-from", type=Path)
    args = parser.parse_args()
    if args.restore_from:
        previous = restore(args.database, args.restore_from, args.backup_dir)
        print(f"Restored verified backup. Previous database saved at: {previous}")
    else:
        stamp = datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
        print(backup(args.database, args.backup_dir / f"quran-{stamp}.db"))
