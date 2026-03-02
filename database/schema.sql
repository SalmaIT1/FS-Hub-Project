-- Conversations
CREATE TABLE conversations (
  id TEXT PRIMARY KEY,
  title TEXT,
  is_group BOOLEAN DEFAULT FALSE,
  last_activity BIGINT
);

-- Messages
CREATE TABLE messages (
  id TEXT PRIMARY KEY,
  conversation_id TEXT REFERENCES conversations(id),
  sender_id TEXT NOT NULL,
  type TEXT NOT NULL,
  content TEXT,
  meta JSONB,
  created_at BIGINT,
  read_by JSONB DEFAULT '[]'::jsonb
);

CREATE INDEX idx_messages_conv_created ON messages(conversation_id, created_at);

-- Uploads
CREATE TABLE uploads (
  id TEXT PRIMARY KEY,
  filename TEXT,
  mime TEXT,
  size BIGINT,
  storage_path TEXT,
  created_at BIGINT,
  scanned BOOLEAN DEFAULT FALSE,
  allowed BOOLEAN DEFAULT FALSE
);

-- Clients
CREATE TABLE clients (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nom VARCHAR(150),
    prenom VARCHAR(150),
    raison_sociale VARCHAR(200),
    email VARCHAR(150),
    telephone VARCHAR(20),
    type ENUM('Entreprise','Particulier'),
    score_credit INT DEFAULT 0
);
