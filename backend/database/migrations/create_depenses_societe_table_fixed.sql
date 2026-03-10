-- Migration: Create depenses_societe table (without indexes)
-- This should be run on existing databases to add the company expenses table

CREATE TABLE IF NOT EXISTS company_expense_categories (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nom VARCHAR(100) NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS depenses_societe (
    id INT PRIMARY KEY AUTO_INCREMENT,
    categorie VARCHAR(100) NOT NULL,
    montant DECIMAL(15,2) NOT NULL,
    date_depense DATE NOT NULL,
    description TEXT,
    category_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_by VARCHAR(50),
    FOREIGN KEY (category_id) REFERENCES company_expense_categories(id) ON DELETE SET NULL
);

-- Insert default company expense categories
INSERT IGNORE INTO company_expense_categories (nom, description) VALUES
('Salaires et Charges Sociales', 'Salaires, cotisations sociales, assurances'),
('Loyer et Charges Locatives', 'Loyer du bureau, charges locatives, taxes foncières'),
('Équipements et Matériel', 'Achat d''équipements, matériel de bureau, maintenance'),
('Services Professionnels', 'Honoraires consultants, frais juridiques, services externes'),
('Marketing et Publicité', 'Campagnes publicitaires, événements, promotion'),
('Déplacements et Voyages', 'Frais de déplacement, hébergement, restauration professionnelle'),
('Assurances et Garanties', 'Assurances professionnelles, garanties diverses'),
('Communication et Télécom', 'Abonnements téléphoniques, internet, logiciels SaaS'),
('Formation et Développement', 'Formations employés, certifications, développement professionnel'),
('Impôts et Taxes', 'Taxes diverses, impôts sur les sociétés, taxes professionnelles'),
('Autres Charges', 'Autres dépenses opérationnelles non catégorisées');
