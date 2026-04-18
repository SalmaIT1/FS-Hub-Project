-- Migration to add user_id to clients table
ALTER TABLE clients ADD COLUMN user_id VARCHAR(50) UNIQUE;
ALTER TABLE clients ADD CONSTRAINT fk_client_user FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL;
