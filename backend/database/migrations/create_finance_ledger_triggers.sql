-- ============================================================
-- Migration: Finance Ledger Triggers (P0 Remediation)
-- Purpose  : Atomically synchronize facture.statut and
--            clients.solde_du whenever a payment is inserted,
--            updated, or deleted. This replaces the stale
--            in-Dart accounting that was previously removed.
-- Run once : Apply on top of the existing schema.
-- ============================================================

DELIMITER //

-- ── Helper procedure ─────────────────────────────────────────
-- Recalculates the invoice status and client debt for a given
-- facture_id. Called by all three triggers below.
CREATE PROCEDURE IF NOT EXISTS _recalc_invoice_and_client(IN p_facture_id INT)
BEGIN
    DECLARE v_montant_ttc   DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_total_paid    DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_client_id     INT           DEFAULT NULL;
    DECLARE v_new_statut    VARCHAR(50);
    DECLARE v_old_solde_du  DECIMAL(12,2) DEFAULT 0.00;
    DECLARE v_old_statut    VARCHAR(50)   DEFAULT 'Brouillon';

    -- 1. Read the facture being affected (lock the row)
    SELECT montant_ttc, client_id, statut
    INTO   v_montant_ttc, v_client_id, v_old_statut
    FROM   factures
    WHERE  id = p_facture_id
    FOR UPDATE;

    -- 2. Sum all payments against this invoice
    SELECT COALESCE(SUM(montant), 0.00)
    INTO   v_total_paid
    FROM   paiements
    WHERE  facture_id = p_facture_id;

    -- 3. Derive new invoice status
    IF v_total_paid <= 0 THEN
        SET v_new_statut = 'Envoyée';          -- sent but unpaid
    ELSEIF v_total_paid >= v_montant_ttc THEN
        SET v_new_statut = 'Payée';
    ELSE
        SET v_new_statut = 'Partiellement payée';
    END IF;

    -- 4. Update facture status only if it changed
    IF v_new_statut != v_old_statut THEN
        UPDATE factures
        SET    statut = v_new_statut
        WHERE  id = p_facture_id;
    END IF;

    -- 5. Recalculate and sync client.solde_du
    --    solde_du = SUM of all outstanding invoice balances for that client
    IF v_client_id IS NOT NULL THEN
        UPDATE clients
        SET    solde_du = (
                   SELECT COALESCE(SUM(f.montant_ttc - COALESCE(pay.paid, 0)), 0)
                   FROM   factures f
                   LEFT JOIN (
                       SELECT facture_id, SUM(montant) AS paid
                       FROM   paiements
                       GROUP BY facture_id
                   ) pay ON pay.facture_id = f.id
                   WHERE  f.client_id = v_client_id
                   AND    f.statut NOT IN ('Brouillon', 'Annulée')
               )
        WHERE  id = v_client_id;
    END IF;
END //

-- ── AFTER INSERT on paiements ─────────────────────────────────
DROP TRIGGER IF EXISTS trg_payment_after_insert //
CREATE TRIGGER trg_payment_after_insert
    AFTER INSERT ON paiements
    FOR EACH ROW
BEGIN
    CALL _recalc_invoice_and_client(NEW.facture_id);
END //

-- ── AFTER UPDATE on paiements ─────────────────────────────────
-- (handles amount corrections)
DROP TRIGGER IF EXISTS trg_payment_after_update //
CREATE TRIGGER trg_payment_after_update
    AFTER UPDATE ON paiements
    FOR EACH ROW
BEGIN
    CALL _recalc_invoice_and_client(NEW.facture_id);
    -- If facture_id itself changed (edge case), recalc old invoice too
    IF OLD.facture_id != NEW.facture_id THEN
        CALL _recalc_invoice_and_client(OLD.facture_id);
    END IF;
END //

-- ── AFTER DELETE on paiements ─────────────────────────────────
-- Restores invoice to pending state and re-adds to client debt
DROP TRIGGER IF EXISTS trg_payment_after_delete //
CREATE TRIGGER trg_payment_after_delete
    AFTER DELETE ON paiements
    FOR EACH ROW
BEGIN
    CALL _recalc_invoice_and_client(OLD.facture_id);
END //

DELIMITER ;
