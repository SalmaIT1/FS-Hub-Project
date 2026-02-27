-- Projects table
CREATE TABLE IF NOT EXISTS projects (
    id INT AUTO_INCREMENT PRIMARY KEY,
    client_id INT NOT NULL,
    titre VARCHAR(200) NOT NULL,
    description TEXT,
    montant_total DECIMAL(12, 2) NOT NULL,
    statut ENUM('En cours', 'Terminé', 'Annulé', 'En attente') DEFAULT 'En cours',
    date_debut DATE,
    date_fin_prevue DATE,
    date_fin DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (client_id) REFERENCES clients(id) ON DELETE CASCADE
);

-- Payments table
CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    project_id INT NOT NULL,
    montant_paye DECIMAL(12, 2) NOT NULL,
    date_paiement DATE NOT NULL,
    mode_paiement ENUM('Espèces', 'Virement', 'Chèque', 'Carte bancaire'),
    reference VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (project_id) REFERENCES projects(id) ON DELETE CASCADE
);

-- Update clients table to add calculated credit score column
ALTER TABLE clients ADD COLUMN credit_score_calculated INT DEFAULT 0;

-- Trigger to automatically calculate client credit score
DELIMITER //
CREATE TRIGGER update_client_credit_score 
AFTER INSERT ON payments
FOR EACH ROW
BEGIN
    UPDATE clients c 
    SET credit_score_calculated = (
        SELECT COALESCE(SUM(p.montant_total - COALESCE(SUM(pa.montant_paye), 0)), 0)
        FROM projects pr
        LEFT JOIN payments pa ON pr.id = pa.project_id
        WHERE pr.client_id = NEW.project_id
    )
    WHERE c.id = (
        SELECT client_id FROM projects WHERE id = NEW.project_id
    );
END //

CREATE TRIGGER update_client_credit_score_payment_update
AFTER UPDATE ON payments
FOR EACH ROW
BEGIN
    UPDATE clients c 
    SET credit_score_calculated = (
        SELECT COALESCE(SUM(p.montant_total - COALESCE(SUM(pa.montant_paye), 0)), 0)
        FROM projects pr
        LEFT JOIN payments pa ON pr.id = pa.project_id
        WHERE pr.client_id = (SELECT client_id FROM projects WHERE id = NEW.project_id)
    )
    WHERE c.id = (SELECT client_id FROM projects WHERE id = NEW.project_id);
END //

CREATE TRIGGER update_client_credit_score_payment_delete
AFTER DELETE ON payments
FOR EACH ROW
BEGIN
    UPDATE clients c 
    SET credit_score_calculated = (
        SELECT COALESCE(SUM(p.montant_total - COALESCE(SUM(pa.montant_paye), 0)), 0)
        FROM projects pr
        LEFT JOIN payments pa ON pr.id = pa.project_id
        WHERE pr.client_id = OLD.project_id
    )
    WHERE c.id = OLD.project_id;
END //

DELIMITER ;

-- Insert sample data for testing
INSERT INTO projects (client_id, titre, description, montant_total, statut, date_debut, date_fin_prevue) VALUES
(1, 'Site Web E-commerce', 'Développement site e-commerce complet', 5000.00, 'En cours', '2024-01-15', '2024-03-15'),
(1, 'Application Mobile', 'App iOS et Android', 3000.00, 'Terminé', '2024-02-01', '2024-02-28'),
(2, 'Refonte Site', 'Refonte site existant', 2500.00, 'En cours', '2024-01-20', '2024-02-20');

INSERT INTO payments (project_id, montant_paye, date_paiement, mode_paiement, reference) VALUES
(2, 3000.00, '2024-02-28', 'Virement', 'VIR-2024-001'),
(1, 2000.00, '2024-02-15', 'Chèque', 'CHQ-2024-001');
