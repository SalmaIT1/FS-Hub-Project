
import 'dart:io';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:intl/intl.dart';

void main() async {
  print('--- TUNISIAN PAYROLL SYSTEM ARCHITECT ---');
  await DBConnection.initialize();
  final db = DBConnection.getConnection();

  final today = DateTime(2026, 4, 8);
  final endPeriod = DateTime(2026, 4, 8);

  print('Fetching employees...');
  final employeesRes = await db.execute('SELECT id, nom, prenom, departement, poste, dateEmbauche, base_salary FROM employees WHERE statut = "actif"');
  
  final dateFormat = DateFormat('yyyy-MM-dd');
  final monthFormat = DateFormat('MM/yyyy');

  final outputDir = Directory('payroll_outputs');
  if (!outputDir.existsSync()) outputDir.createSync();

  for (final empRow in employeesRes.rows) {
    final empId = empRow.colAt(0).toString();
    final nom = empRow.colAt(1).toString();
    final prenom = empRow.colAt(2).toString();
    final dept = empRow.colAt(3).toString();
    final poste = empRow.colAt(4).toString();
    final hireDateStr = empRow.colAt(5).toString();
    final baseSalary = double.tryParse(empRow.colAt(6).toString()) ?? 1200.0;
    
    DateTime hireDate;
    try {
      hireDate = DateTime.parse(hireDateStr);
    } catch (e) {
      hireDate = DateTime(2025, 1, 1);
    }

    print('Processing Salary History for $prenom $nom (Hired: $hireDateStr)...');

    // Start from the first month of hiring
    DateTime currentMonth = DateTime(hireDate.year, hireDate.month, 1);
    int leaveDaysUsedThisYear = 0;
    int currentYear = currentMonth.year;

    while (currentMonth.isBefore(endPeriod)) {
      if (currentMonth.year != currentYear) {
        leaveDaysUsedThisYear = 0;
        currentYear = currentMonth.year;
      }

      final monthStart = DateTime(currentMonth.year, currentMonth.month, 1);
      final monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      
      final monthStr = dateFormat.format(monthStart);
      final monthLabel = monthFormat.format(monthStart);

      // 1. Fetch Attendance for this month
      final attendanceRes = await db.execute(
        'SELECT status, check_in, check_out FROM attendance WHERE employee_id = :id AND attendance_date BETWEEN :start AND :end',
        {'id': empId, 'start': dateFormat.format(monthStart), 'end': dateFormat.format(monthEnd)}
      );

      int presentDays = 0;
      int remoteDays = 0;
      int absentDays = 0;
      int lateCount = 0;
      int leaveDaysThisMonth = 0;
      double otHours = 0;

      for (final att in attendanceRes.rows) {
        final status = att.colAt(0).toString();
        final checkOutStr = att.colAt(2).toString();

        if (status == 'present') presentDays++;
        else if (status == 'remote') remoteDays++;
        else if (status == 'absent') absentDays++;
        else if (status == 'late') { presentDays++; lateCount++; }
        else if (status == 'leave') leaveDaysThisMonth++;

        // Calculate Overtime (after 17:30)
        if (checkOutStr != 'null' && checkOutStr.isNotEmpty) {
           try {
             final checkOut = DateTime.parse(checkOutStr);
             final baseline = DateTime(checkOut.year, checkOut.month, checkOut.day, 17, 30);
             if (checkOut.isAfter(baseline)) {
               otHours += checkOut.difference(baseline).inMinutes / 60.0;
             }
           } catch (_) {}
        }
      }

      // 2. Calculations
      const workingDays = 22.0;
      final dailyRate = baseSalary / workingDays;
      final hourlyRate = dailyRate / 8.0;

      // Unpaid leave if > 21 days
      int unpaidLeaveDays = 0;
      if (leaveDaysUsedThisYear + leaveDaysThisMonth > 21) {
        unpaidLeaveDays = (leaveDaysUsedThisYear + leaveDaysThisMonth) - 21;
        if (unpaidLeaveDays > leaveDaysThisMonth) unpaidLeaveDays = leaveDaysThisMonth;
      }
      leaveDaysUsedThisYear += leaveDaysThisMonth;

      // Adjustments
      final otAmount = otHours * hourlyRate * 1.25;
      final absenceDeduction = (absentDays + unpaidLeaveDays) * dailyRate;
      final latePenalty = lateCount * dailyRate * 0.05;

      // Bonuses
      double perfBonus = 0;
      if (presentDays + remoteDays > 15) {
          perfBonus = baseSalary * (0.05 + (0.1 * (presentDays / 22.0)));
      }
      final attendanceBonus = (absentDays == 0) ? baseSalary * 0.05 : 0.0;

      final totalBonus = perfBonus + attendanceBonus;
      final grossSalary = baseSalary + otAmount + totalBonus - absenceDeduction - latePenalty;
      
      // CNSS (9.18%)
      final cnss = grossSalary * 0.0918;
      final netSalary = grossSalary - cnss;

      // 3. Save to DB (salaries table)
      await db.execute(
        '''INSERT INTO salaries (employee_id, base_salary, bonus_amount, deductions, net_salary, salary_month, payment_status)
           VALUES (:id, :base, :bonus, :deduc, :net, :month, "paid")
           ON DUPLICATE KEY UPDATE 
           base_salary = VALUES(base_salary), bonus_amount = VALUES(bonus_amount), 
           deductions = VALUES(deductions), net_salary = VALUES(net_salary)''',
        {
          'id': empId,
          'base': baseSalary,
          'bonus': totalBonus + otAmount,
          'deduc': cnss + absenceDeduction + latePenalty,
          'net': netSalary,
          'month': monthStr
        }
      );

      // 4. Generate HTML Fiche de Paie
      final html = _generatePayslipHtml(
        nom: nom,
        prenom: prenom,
        dept: dept,
        poste: poste,
        hireDate: hireDateStr,
        month: monthLabel,
        base: baseSalary,
        ot: otAmount,
        bonus: totalBonus,
        absDeduc: absenceDeduction,
        latePen: latePenalty,
        cnss: cnss,
        net: netSalary
      );

      final file = File('payroll_outputs/payslip_${empId}_${currentMonth.year}_${currentMonth.month}.html');
      file.writeAsStringSync(html);

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
  }

  await DBConnection.close();
  print('\n--- ALL PAYROLLS GENERATED SUCCESSFULLY ---');
  print('Payslips are available in the "payroll_outputs" directory.');
}

String _generatePayslipHtml({
  required String nom, required String prenom, required String dept, required String poste,
  required String hireDate, required String month, required double base,
  required double ot, required double bonus, required double absDeduc,
  required double latePen, required double cnss, required double net
}) {
  final nf = NumberFormat('#,##0.000', 'fr_TN');
  return '''
<!DOCTYPE html>
<html lang="fr">
<head>
    <meta charset="UTF-8">
    <title>Bulletin de Paie - $prenom $nom - $month</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; color: #333; line-height: 1.6; padding: 40px; }
        .payslip-container { max-width: 800px; margin: 0 auto; border: 1px solid #ddd; padding: 40px; box-shadow: 0 0 10px rgba(0,0,0,0.1); }
        .header { display: flex; justify-content: space-between; border-bottom: 2px solid #C9A24D; padding-bottom: 20px; margin-bottom: 30px; }
        .company-info h1 { margin: 0; color: #C9A24D; font-size: 24px; }
        .period { font-weight: bold; font-size: 18px; }
        .info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 20px; margin-bottom: 30px; }
        .info-item span { font-weight: bold; color: #666; font-size: 12px; text-transform: uppercase; }
        .info-item p { margin: 5px 0 0 0; font-size: 15px; }
        table { width: 100%; border-collapse: collapse; margin-bottom: 30px; }
        th { background: #f9f9f9; text-align: left; padding: 12px; border-bottom: 2px solid #eee; font-size: 14px; }
        td { padding: 12px; border-bottom: 1px solid #eee; font-size: 14px; }
        .text-right { text-align: right; }
        .bold { font-weight: bold; }
        .negative { color: #d32f2f; }
        .footer { margin-top: 50px; display: flex; justify-content: space-between; border-top: 1px solid #eee; pt: 20px; }
        .summary-box { background: #fcf8ef; border: 1px solid #e9dcb9; padding: 20px; border-radius: 8px; margin-left: auto; width: 250px; }
        .summary-item { display: flex; justify-content: space-between; margin-bottom: 10px; }
        .net-salary { font-size: 20px; color: #C9A24D; border-top: 2px solid #C9A24D; padding-top: 10px; margin-top: 10px; }
    </style>
</head>
<body>
    <div class="payslip-container">
        <div class="header">
            <div class="company-info">
                <h1>FS HUB ENTERPRISE</h1>
                <p>Tunis, Tunisie</p>
            </div>
            <div class="period">BULLETIN DE PAIE<br><small>$month</small></div>
        </div>

        <div class="info-grid">
            <div class="info-item"><span>Employé</span><p>$prenom $nom</p></div>
            <div class="info-item"><span>Département</span><p>$dept</p></div>
            <div class="info-item"><span>Poste</span><p>$poste</p></div>
            <div class="info-item"><span>Date d'embauche</span><p>$hireDate</p></div>
        </div>

        <table>
            <thead>
                <tr>
                    <th>Libellé</th>
                    <th class="text-right">Gain</th>
                    <th class="text-right">Retenu</th>
                </tr>
            </thead>
            <tbody>
                <tr>
                    <td>Salaire de Base</td>
                    <td class="text-right">${nf.format(base)}</td>
                    <td class="text-right"></td>
                </tr>
                <tr>
                    <td>Heures Supplémentaires (125%)</td>
                    <td class="text-right">${nf.format(ot)}</td>
                    <td class="text-right"></td>
                </tr>
                <tr>
                    <td>Primes & Bonus</td>
                    <td class="text-right">${nf.format(bonus)}</td>
                    <td class="text-right"></td>
                </tr>
                <tr>
                    <td>Absences & Congés non payés</td>
                    <td class="text-right"></td>
                    <td class="text-right negative">${nf.format(absDeduc)}</td>
                </tr>
                <tr>
                    <td>Pénalités Retard</td>
                    <td class="text-right"></td>
                    <td class="text-right negative">${nf.format(latePen)}</td>
                </tr>
                <tr>
                    <td>Cotisation Sociale (CNSS 9.18%)</td>
                    <td class="text-right"></td>
                    <td class="text-right negative">${nf.format(cnss)}</td>
                </tr>
            </tbody>
        </table>

        <div class="summary-box">
            <div class="summary-item"><span>Total Gains</span><span class="bold">${nf.format(base + ot + bonus)}</span></div>
            <div class="summary-item"><span>Total Retenues</span><span class="bold negative">${nf.format(absDeduc + latePen + cnss)}</span></div>
            <div class="summary-item net-salary"><span>NET À PAYER</span><span class="bold">${nf.format(net)} TND</span></div>
        </div>

        <div class="footer">
            <div>
                <p>Fait à Tunis, le 08/04/2026</p>
            </div>
            <div style="text-align: right;">
                <p>Signature de l'employeur</p>
                <div style="height: 60px;"></div>
                <p>Cachet FS HUB</p>
            </div>
        </div>
    </div>
</body>
</html>
  ''';
}
