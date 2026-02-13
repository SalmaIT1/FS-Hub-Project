-- File uploads table
CREATE TABLE IF NOT EXISTS file_uploads (
  id TEXT PRIMARY KEY,
  original_filename TEXT NOT NULL,
  stored_filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  uploaded_by TEXT NOT NULL,
  is_public BOOLEAN DEFAULT FALSE,
  download_count INTEGER DEFAULT 0,
  created_at TEXT NOT NULL,
  expires_at TEXT NOT NULL
);

-- Message attachments table
CREATE TABLE IF NOT EXISTS message_attachments (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL,
  filename TEXT NOT NULL,
  original_filename TEXT NOT NULL,
  file_path TEXT NOT NULL,
  file_size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  thumbnail_path TEXT,
  metadata TEXT, -- JSON string for additional metadata
  created_at TEXT NOT NULL,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Voice messages table
CREATE TABLE IF NOT EXISTS voice_messages (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  message_id TEXT NOT NULL,
  file_path TEXT NOT NULL,
  duration_seconds INTEGER NOT NULL,
  waveform_data TEXT, -- JSON array of waveform points
  transcript TEXT,
  file_size BIGINT NOT NULL,
  created_at TEXT NOT NULL,
  FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_file_uploads_created_at ON file_uploads(created_at);
CREATE INDEX IF NOT EXISTS idx_file_uploads_uploaded_by ON file_uploads(uploaded_by);
CREATE INDEX IF NOT EXISTS idx_message_attachments_message_id ON message_attachments(message_id);
CREATE INDEX IF NOT EXISTS idx_voice_messages_message_id ON voice_messages(message_id);

-- Cleanup procedure for expired uploads
CREATE TRIGGER IF NOT EXISTS cleanup_expired_uploads
AFTER INSERT ON file_uploads
WHEN NEW.expires_at < datetime('now')
BEGIN
  DELETE FROM file_uploads WHERE id = NEW.id;
END;
