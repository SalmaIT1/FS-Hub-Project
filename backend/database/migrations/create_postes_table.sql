-- Migration: Create postes table and insert default positions
-- This should be run on existing databases to add the postes table

CREATE TABLE IF NOT EXISTS postes (
    id INT AUTO_INCREMENT PRIMARY KEY,
    nom VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert default positions if they don't exist
INSERT IGNORE INTO postes (nom, description) VALUES
('Directeur', 'Responsable de la direction générale et de la stratégie de l''entreprise'),
('Manager de projet', 'Gère les projets et coordonne les équipes de développement'),
('Team Lead', 'Encadre une équipe technique et assure la qualité des livrables'),
('Développeur', 'Développe des applications et des fonctionnalités techniques'),
('Designer', 'Crée les interfaces utilisateur et l''expérience visuelle'),
('Responsable RH', 'Gère les ressources humaines et les relations employés'),
('Comptable', 'Gère la comptabilité et les finances de l''entreprise'),
('Support technique', 'Assiste les utilisateurs et résout les problèmes techniques');
