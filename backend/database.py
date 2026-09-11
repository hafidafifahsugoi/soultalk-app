import sqlite3
import os

if os.environ.get("VERCEL"):
    DB_FILE = "/tmp/soultalk_server.db"
else:
    DB_FILE = os.path.join(os.path.dirname(__file__), "soultalk_server.db")

_initialized = False

def init_db(existing_conn=None):
    should_close = False
    if existing_conn is None:
        conn = sqlite3.connect(DB_FILE)
        conn.execute("PRAGMA foreign_keys = ON")
        should_close = True
    else:
        conn = existing_conn

    cursor = conn.cursor()
    
    # Create users table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            email TEXT UNIQUE NOT NULL,
            password_hash TEXT NOT NULL,
            phone TEXT,
            bio TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
        )
    ''')
    
    # Create sessions table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sessions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            title TEXT NOT NULL,
            time TEXT NOT NULL,
            duration TEXT NOT NULL,
            moodAbbr TEXT NOT NULL,
            primaryMood TEXT NOT NULL,
            emoji TEXT NOT NULL,
            accuracy TEXT NOT NULL,
            observations TEXT NOT NULL,
            message_count INTEGER NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')
    
    # Create quota limits table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS quota_limits (
            user_id INTEGER PRIMARY KEY,
            message_count INTEGER DEFAULT 0,
            vc_duration_seconds INTEGER DEFAULT 0,
            last_reset_date TEXT NOT NULL,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')

    # Create memories table
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS memories (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id INTEGER NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )
    ''')

    # Migration: Add memory_enabled column to users if it doesn't exist
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN memory_enabled INTEGER DEFAULT 1")
    except sqlite3.OperationalError:
        # Column already exists
        pass
    
    conn.commit()
    if should_close:
        conn.close()

def get_db_connection():
    global _initialized
    conn = sqlite3.connect(DB_FILE)
    conn.execute("PRAGMA foreign_keys = ON")
    conn.row_factory = sqlite3.Row
    if not _initialized:
        try:
            init_db(conn)
            _initialized = True
        except Exception as e:
            print("DB init error:", e)
    return conn

try:
    init_db()
    _initialized = True
except Exception:
    pass

if __name__ == "__main__":
    init_db()
    print("Database initialized successfully at:", DB_FILE)

