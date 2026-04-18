
import 'dart:math';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:intl/intl.dart';

void main() async {
  print('--- TUNISIAN SALARY CALCULATION & POPULATION ---');
  await DBConnection.initialize();
  final db = DBConnection.getConnection();

  final today = DateTime(2026, 4, 8);
  final rand = Random();

  print('Fetching employees...');
  final employeesRes = await db.execute('SELECT id, nom, prenom, departement, poste, dateEmbauche FROM employees WHERE statut = "actif"');
  print('Processing ${employeesRes.rows.length} employees...\n');

  int updatedCount = 0;

  for (final row in employeesRes.rows) {
    final id = row.colAt(0).toString();
    final nom = row.colAt(1).toString();
    final prenom = row.colAt(2).toString();
    final dept = row.colAt(3).toString().toLowerCase();
    final poste = row.colAt(4).toString().toLowerCase();
    final hireDateStr = row.colAt(5).toString();
    
    DateTime hireDate;
    try {
      hireDate = DateTime.parse(hireDateStr);
    } catch (e) {
      hireDate = DateTime(2025, 1, 1);
    }

    // 1. Calculate Experience in Company
    final expYears = today.difference(hireDate).inDays / 365.25;
    
    // 2. Determine Seniority Level
    String level = 'Junior';
    if (expYears >= 9) level = 'Expert';
    else if (expYears >= 5) level = 'Senior';
    else if (expYears >= 2) level = 'Mid';

    // 3. Determine Salary Range based on Dept
    double minSalary = 800;
    double maxSalary = 1200;

    bool isManagement = poste.contains('manager') || poste.contains('directeur') || poste.contains('lead') || poste.contains('responsable');

    if (isManagement) {
       if (poste.contains('directeur')) {
         minSalary = 4000; maxSalary = 7000;
       } else {
         minSalary = 2500; maxSalary = 4000;
       }
    } else {
      // Mapping Dept -> Grid
      if (dept.contains('it') || dept.contains('dév') || dept.contains('dev')) {
        switch (level) {
          case 'Junior': minSalary = 900;  maxSalary = 1300; break;
          case 'Mid':    minSalary = 1300; maxSalary = 2000; break;
          case 'Senior': minSalary = 2000; maxSalary = 3000; break;
          case 'Expert': minSalary = 3000; maxSalary = 4500; break;
        }
      } else if (dept.contains('marketing') || dept.contains('design')) {
        switch (level) {
          case 'Junior': minSalary = 800;  maxSalary = 1200; break;
          case 'Mid':    minSalary = 1200; maxSalary = 1800; break;
          default:       minSalary = 1800; maxSalary = 2500; break;
        }
      } else if (dept.contains('rh')) {
        switch (level) {
          case 'Junior': minSalary = 900;  maxSalary = 1300; break;
          case 'Mid':    minSalary = 1300; maxSalary = 1800; break;
          default:       minSalary = 1800; maxSalary = 2500; break;
        }
      } else if (dept.contains('finance') || dept.contains('compt')) {
        switch (level) {
          case 'Junior': minSalary = 1000; maxSalary = 1500; break;
          case 'Mid':    minSalary = 1500; maxSalary = 2200; break;
          default:       minSalary = 2200; maxSalary = 3000; break;
        }
      } else { // Support / Operations / Others
        switch (level) {
          case 'Junior': minSalary = 700;  maxSalary = 1100; break;
          case 'Mid':    minSalary = 1100; maxSalary = 1600; break;
          default:       minSalary = 1600; maxSalary = 2200; break;
        }
      }
    }

    // 4. Base Calculation with slight randomness (±5%)
    double variation = 0.95 + (rand.nextDouble() * 0.1); 
    double baseSalary = minSalary + (rand.nextDouble() * (maxSalary - minSalary));
    baseSalary *= variation;

    // 5. Seniority Adjustment (+2% per year in company)
    baseSalary *= (1 + (expYears * 0.02));

    // 6. Caps and Clamping
    if (baseSalary < minSalary * 0.9) baseSalary = minSalary * 0.9;
    if (baseSalary > maxSalary * 1.5 && !isManagement) baseSalary = maxSalary * 1.25;

    // 7. Recent Hire Deduction
    if (expYears < 0.5) {
       baseSalary *= 0.9;
    }

    // Rounded to 0 decimal places for TND neatness
    final finalSalary = baseSalary.roundToDouble();

    await db.execute(
      'UPDATE employees SET base_salary = :salary WHERE id = :id',
      {'salary': finalSalary, 'id': id}
    );

    updatedCount++;
    if (updatedCount % 5 == 0) {
      print('Updated $prenom $nom ($poste, $level): $finalSalary TND');
    }
  }

  await DBConnection.close();
  print('\nSUCCESS: $updatedCount salaries updated based on Tunisian market model.');
}
