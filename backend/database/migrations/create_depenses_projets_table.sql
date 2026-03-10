-- Migration: Create depenses_projets table
-- This should be run on existing databases to add the project expenses table

CREATE TABLE IF NOT EXISTS expense_categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nom VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS depenses_projets (
    id INT PRIMARY KEY AUTO_INCREMENT,
    categorie VARCHAR(100) NOT NULL,
    montant DECIMAL(15,2) NOT NULL,
    date_depense DATE NOT NULL,
    description TEXT,
    projet_id INT NULL,
    category_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    FOREIGN KEY (projet_id) REFERENCES projets(id) ON DELETE SET NULL,
    FOREIGN KEY (category_id) REFERENCES expense_categories(id) ON DELETE SET NULL
);

-- Add indexes for better performance
CREATE INDEX idx_depenses_projets_projet_id ON depenses_projets(projet_id);
CREATE INDEX idx_depenses_projets_date ON depenses_projets(date_depense);
CREATE INDEX idx_depenses_projets_categorie ON depenses_projets(categorie);
CREATE INDEX idx_depenses_projets_category_id ON depenses_projets(category_id);

-- Insert default expense categories
INSERT IGNORE INTO expense_categories (nom, description) VALUES
('Matériel', 'Coûts des matériaux et équipements'),
('Transport', 'Frais de transport et déplacement'),
('Hébergement', 'Coûts d''hébergement et restauration'),
('Logiciel', 'Licences logicielles et abonnements'),
('Communication', 'Téléphone et internet'),
('Formation', 'Coûts de formation et développement'),
('Marketing', 'Dépenses marketing et publicité'),
('Autres', 'Autres dépenses non catégorisées');
