import 'dart:math';
import 'package:fs_hub_backend/shared/database/connection.dart';
import 'package:intl/intl.dart';

void main() async {
  try {
    print('Starting attendance population script...');
    await DBConnection.initialize();
    final db = DBConnection.getConnection();

    // 1. Fetch all employees
    final employeesResult = await db.execute('SELECT id, nom, prenom, dateEmbauche FROM employees WHERE statut = "actif"');
    
    final targetDate = DateTime(2026, 4, 8);
    final random = Random();
    final dateFormatter = DateFormat('yyyy-MM-dd');
    final dateTimeFormatter = DateFormat('yyyy-MM-dd HH:mm:ss');

    int totalInserted = 0;

    for (final row in employeesResult.rows) {
      final employeeId = row.colAt(0);
      final fullName = '${row.colAt(2)} ${row.colAt(1)}';
      final hireDateStr = row.colAt(3);
      
      if (hireDateStr == null) {
        print('Skipping employee $fullName: No hire date.');
        continue;
      }

      DateTime currentDate = DateTime.parse(hireDateStr);
      print('Processing $fullName (Hired: $hireDateStr)...');

      // Trackers
      int leaveDaysCurrentYear = 0;
      int currentYear = currentDate.year;
      
      int absencesCurrentMonth = 0;
      int latesCurrentMonth = 0;
      int currentMonth = currentDate.month;

      int remoteDaysCurrentWeek = 0;
      int currentWeekNumber = _getWeekNumber(currentDate);

      int consecutiveLates = 0;
      int leaveBlockRemaining = 0;

      while (currentDate.isBefore(targetDate) || _isSameDay(currentDate, targetDate)) {
        // Reset trackers
        if (currentDate.year != currentYear) {
          leaveDaysCurrentYear = 0;
          currentYear = currentDate.year;
        }
        if (currentDate.month != currentMonth) {
          absencesCurrentMonth = 0;
          latesCurrentMonth = 0;
          currentMonth = currentDate.month;
        }
        int weekNum = _getWeekNumber(currentDate);
        if (weekNum != currentWeekNumber) {
          remoteDaysCurrentWeek = 0;
          currentWeekNumber = weekNum;
        }

        // Skip weekends
        if (currentDate.weekday == DateTime.saturday || currentDate.weekday == DateTime.sunday) {
          currentDate = currentDate.add(Duration(days: 1));
          continue;
        }

        String status = 'present';
        DateTime? checkIn;
        DateTime? checkOut;

        // Determine Status
        
        // 1. Continue Leave Block
        if (leaveBlockRemaining > 0) {
          status = 'leave';
          leaveBlockRemaining--;
          leaveDaysCurrentYear++;
        } 
        // 2. Start Leave? (Check limit)
        else if (leaveDaysCurrentYear < 21 && random.nextDouble() < 0.025) {
          int maxPossible = min(21 - leaveDaysCurrentYear, random.nextInt(4) + 2); // 2-5 days
          status = 'leave';
          leaveDaysCurrentYear++;
          leaveBlockRemaining = maxPossible - 1; 
          consecutiveLates = 0;
        }
        // 3. Absent? (Rare, max 2/month, target 2-4%)
        else if (absencesCurrentMonth < 2 && random.nextDouble() < 0.025) {
          status = 'absent';
          absencesCurrentMonth++;
          consecutiveLates = 0;
        }
        // 4. Remote? (Max 3/week, target 10-15%)
        else if (remoteDaysCurrentWeek < 3 && random.nextDouble() < 0.12) {
          status = 'remote';
          remoteDaysCurrentWeek++;
          consecutiveLates = 0;
        }
        // 5. Late? (3-6/month, max 2 consecutive, target 5-8%)
        else if (latesCurrentMonth < 6 && consecutiveLates < 2 && random.nextDouble() < 0.07) {
          status = 'late';
          latesCurrentMonth++;
          consecutiveLates++;
        }
        // 6. Present (Default)
        else {
          status = 'present';
          consecutiveLates = 0;
        }

        // Times
        if (status == 'present') {
          checkIn = _randomTime(currentDate, 8, 45, 9, 5);
          checkOut = _randomTime(currentDate, 17, 0, 17, 30);
        } else if (status == 'late') {
          checkIn = _randomTime(currentDate, 9, 6, 9, 40);
          checkOut = _randomTime(currentDate, 17, 0, 17, 30);
        } else if (status == 'remote') {
          checkIn = _randomTime(currentDate, 8, 30, 9, 15);
          checkOut = _randomTime(currentDate, 16, 45, 17, 30);
        }

        // Insert
        try {
          double? workHours;
          if (checkIn != null && checkOut != null) {
            workHours = checkOut.difference(checkIn).inMinutes / 60.0;
          }

          await db.execute(
            'INSERT IGNORE INTO attendance (employee_id, attendance_date, check_in, check_out, status, work_hours) VALUES (:empId, :date, :checkIn, :checkOut, :status, :hours)',
            {
              'empId': employeeId,
              'date': dateFormatter.format(currentDate),
              'checkIn': checkIn != null ? dateTimeFormatter.format(checkIn) : null,
              'checkOut': checkOut != null ? dateTimeFormatter.format(checkOut) : null,
              'status': status,
              'hours': workHours,
            }
          );
          totalInserted++;
        } catch (e) {
          print('Error inserting for $fullName on ${dateFormatter.format(currentDate)}: $e');
        }

        currentDate = currentDate.add(Duration(days: 1));
      }
    }

    print('Finished. Total records processed/inserted: $totalInserted');
    await DBConnection.close();
  } catch (e, stack) {
    print('Failed to populate attendance: $e');
    print(stack);
  }
}

bool _isSameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

int _getWeekNumber(DateTime date) {
  // Simple week number (doesn't need to be ISO standard, just consistent for resetting)
  int dayOfYear = int.parse(DateFormat("D").format(date));
  return ((dayOfYear - date.weekday + 10) / 7).floor();
}

DateTime _randomTime(DateTime date, int hStart, int mStart, int hEnd, int mEnd) {
  final random = Random();
  int startMinutes = hStart * 60 + mStart;
  int endMinutes = hEnd * 60 + mEnd;
  int randomMinutes = startMinutes + random.nextInt(endMinutes - startMinutes + 1);
  
  return DateTime(date.year, date.month, date.day, randomMinutes ~/ 60, randomMinutes % 60);
}
