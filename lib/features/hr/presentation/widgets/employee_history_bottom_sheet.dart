import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fs_hub/core/state/settings_controller.dart';
import 'package:fs_hub/shared/models/employee_model.dart';
import '../../data/services/hr_service.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/leave_request_model.dart';

class EmployeeHistoryBottomSheet extends StatefulWidget {
  final Employee employee;

  const EmployeeHistoryBottomSheet({super.key, required this.employee});

  @override
  State<EmployeeHistoryBottomSheet> createState() => _EmployeeHistoryBottomSheetState();
}

class _EmployeeHistoryBottomSheetState extends State<EmployeeHistoryBottomSheet> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  bool _isLoading = true;
  List<Attendance> _attendance = [];
  List<LeaveRequest> _leaves = [];

  static const _gold = Color(0xFFC9A24D);

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    
    // Calculate start and end of the current month
    final startOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final endOfMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);

    final startStr = DateFormat('yyyy-MM-dd').format(startOfMonth);
    final endStr = DateFormat('yyyy-MM-dd').format(endOfMonth);

    try {
      final attendance = await HrService.getAttendance(
        widget.employee.id!,
        startDate: startStr,
        endDate: endStr,
      );

      final allLeaves = await HrService.getLeaveRequests();
      final approvedLeaves = allLeaves.where((l) => 
        l.employeeId == widget.employee.id && l.status == 'approved'
      ).toList();

      if (mounted) {
        setState(() {
          _attendance = attendance;
          _leaves = approvedLeaves;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
    _loadHistory();
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
    _loadHistory();
  }

  String _getDayStatus(DateTime date) {
    // Check if it's a leave day
    for (var leave in _leaves) {
      // normalize dates for comparison without time
      final lStart = DateTime(leave.startDate.year, leave.startDate.month, leave.startDate.day);
      final lEnd = DateTime(leave.endDate.year, leave.endDate.month, leave.endDate.day);
      final cDate = DateTime(date.year, date.month, date.day);

      if ((cDate.isAfter(lStart) || cDate.isAtSameMomentAs(lStart)) &&
          (cDate.isBefore(lEnd) || cDate.isAtSameMomentAs(lEnd))) {
        return 'leave';
      }
    }

    // Check attendance
    for (var a in _attendance) {
      if (a.attendanceDate.year == date.year &&
          a.attendanceDate.month == date.month &&
          a.attendanceDate.day == date.day) {
        return a.status;
      }
    }

    return 'none';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase().trim()) {
      case 'present': return const Color(0xFF22C55E);
      case 'late':    return const Color(0xFFF59E0B);
      case 'absent':  return const Color(0xFFEF4444);
      case 'remote':  return const Color(0xFF3B82F6);
      case 'leave':   
      case 'on_leave': return const Color(0xFF8B5CF6); // Purple for leave
      default:        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFr = context.watch<SettingsController>().languageCode == 'fr';
    final surface = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.black12,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            
            // Header info: Employee name + Month navigator
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(color: _gold, shape: BoxShape.circle),
                  child: Center(
                    child: Text(
                      widget.employee.nom.isNotEmpty ? widget.employee.nom[0].toUpperCase() : '?',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.employee.prenom} ${widget.employee.nom}',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                          color: textColor,
                        ),
                      ),
                      Text(
                        isFr ? 'Historique de présence' : 'Attendance History',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Month selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: Icon(Icons.chevron_left_rounded, color: textColor),
                  onPressed: _previousMonth,
                ),
                Text(
                  DateFormat('MMMM yyyy', isFr ? 'fr' : 'en').format(_currentMonth).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.5,
                    color: textColor,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.chevron_right_rounded, color: textColor),
                  onPressed: _nextMonth,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Calendar Grid Component
            _isLoading
                ? const SizedBox(
                    height: 260, 
                    child: Center(child: CircularProgressIndicator(color: _gold)),
                  )
                : _buildCalendarGrid(isFr, isDark, textColor),
            
            const SizedBox(height: 24),
            
            // Legend
            Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _legendItem(isFr ? 'Présent' : 'Present', _statusColor('present'), isDark),
                _legendItem(isFr ? 'En retard' : 'Late', _statusColor('late'), isDark),
                _legendItem(isFr ? 'Absent' : 'Absent', _statusColor('absent'), isDark),
                _legendItem(isFr ? 'Remote' : 'Remote', _statusColor('remote'), isDark),
                _legendItem(isFr ? 'En congé' : 'On Leave', _statusColor('leave'), isDark),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white70 : Colors.black87),
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(bool isFr, bool isDark, Color textColor) {
    final daysOfWeek = isFr
        ? ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim']
        : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    final firstDayOfMonth = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    
    // adjust weekday to be 0-indexed starting on Monday
    final startOffset = firstDayOfMonth.weekday - 1; 

    return Column(
      children: [
        // Days of week header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: daysOfWeek.map((day) => SizedBox(
            width: 36,
            child: Text(
              day,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.grey),
            ),
          )).toList(),
        ),
        const SizedBox(height: 12),
        // Grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
          ),
          itemCount: startOffset + daysInMonth,
          itemBuilder: (context, index) {
            if (index < startOffset) {
              return const SizedBox.shrink();
            }

            final day = index - startOffset + 1;
            final date = DateTime(_currentMonth.year, _currentMonth.month, day);
            final status = _getDayStatus(date);
            final color = _statusColor(status);
            
            final isToday = date.year == DateTime.now().year &&
                            date.month == DateTime.now().month &&
                            date.day == DateTime.now().day;

            return Container(
              decoration: BoxDecoration(
                color: status != 'none' ? color.withOpacity(0.15) : (isDark ? Colors.white10 : Colors.black.withOpacity(0.04)),
                borderRadius: BorderRadius.circular(10),
                border: isToday ? Border.all(color: _gold, width: 2) : null,
              ),
              child: Stack(
                children: [
                  Center(
                    child: Text(
                      '$day',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: (status != 'none' && color != Colors.transparent) 
                            ? color 
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                  if (status != 'none')
                    Positioned(
                      bottom: 4,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}
