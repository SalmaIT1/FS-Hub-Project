import 'dart:convert';
import '../../../auth/data/services/auth_service.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/remote_work_model.dart';
import '../models/salary_model.dart';
import '../models/bonus_model.dart';

class HrService {
  // --- Attendance ---

  static Future<List<Attendance>> getAttendance(String employeeId, {String? startDate, String? endDate}) async {
    try {
      String url = '/hr/attendance/$employeeId';
      if (startDate != null && endDate != null) {
        url += '?startDate=$startDate&endDate=$endDate';
      }
      
      final response = await AuthService.authenticatedRequest(url, 'GET');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => Attendance.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getAttendance error: $e');
      return [];
    }
  }

  static Future<bool> logAttendance(Attendance attendance) async {
    try {
      final response = await AuthService.authenticatedRequest(
        '/hr/attendance',
        'POST',
        body: attendance.toJson(),
      );
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('logAttendance error: $e');
      return false;
    }
  }

  // --- Leaves ---

  static Future<List<LeaveRequest>> getLeaveRequests() async {
    try {
      final response = await AuthService.authenticatedRequest('/hr/leaves', 'GET');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => LeaveRequest.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getLeaveRequests error: $e');
      return [];
    }
  }

  static Future<bool> submitLeaveRequest(LeaveRequest request) async {
    try {
       final response = await AuthService.authenticatedRequest(
        '/hr/leaves',
        'POST',
        body: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('submitLeaveRequest error: $e');
      return false;
    }
  }
  
  static Future<bool> updateLeaveStatus(int id, String status) async {
     try {
       final response = await AuthService.authenticatedRequest(
        '/hr/leaves/$id',
        'PUT',
        body: {'status': status},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('updateLeaveStatus error: $e');
      return false;
    }
  }

  // --- Remote Work ---
  
  static Future<List<RemoteWork>> getRemoteWorkRequests() async {
     try {
      final response = await AuthService.authenticatedRequest('/hr/remote-work', 'GET');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => RemoteWork.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getRemoteWorkRequests error: $e');
      return [];
    }
  }

  static Future<bool> submitRemoteWorkRequest(RemoteWork request) async {
    try {
       final response = await AuthService.authenticatedRequest(
        '/hr/remote-work',
        'POST',
        body: request.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('submitRemoteWorkRequest error: $e');
      return false;
    }
  }

  static Future<bool> updateRemoteWorkStatus(int id, String status) async {
     try {
       final response = await AuthService.authenticatedRequest(
        '/hr/remote-work/$id',
        'PUT',
        body: {'status': status},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('updateRemoteWorkStatus error: $e');
      return false;
    }
  }

  // --- Salaries & Bonuses ---

  static Future<List<Salary>> getSalaries({String? employeeId}) async {
     try {
       String url = '/hr/salaries';
       if (employeeId != null) {
         url += '?employeeId=$employeeId';
       }
       
      final response = await AuthService.authenticatedRequest(url, 'GET');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => Salary.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getSalaries error: $e');
      return [];
    }
  }

  static Future<bool> createSalary(Salary salary) async {
     try {
       final response = await AuthService.authenticatedRequest(
        '/hr/salaries',
        'POST',
        body: salary.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('createSalary error: $e');
      return false;
    }
  }

  static Future<bool> updateSalaryStatus(int id, String status) async {
    try {
       final response = await AuthService.authenticatedRequest(
        '/hr/salaries/$id',
        'PUT',
        body: {'status': status},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('updateSalaryStatus error: $e');
      return false;
    }
  }
  
  static Future<List<Bonus>> getBonuses(String employeeId) async {
    try {
      final response = await AuthService.authenticatedRequest('/hr/bonuses/$employeeId', 'GET');
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final List<dynamic> list = data['data'];
          return list.map((item) => Bonus.fromJson(item)).toList();
        }
      }
      return [];
    } catch (e) {
      print('getBonuses error: $e');
      return [];
    }
  }

  static Future<bool> grantBonus(Bonus bonus) async {
    try {
       final response = await AuthService.authenticatedRequest(
        '/hr/bonuses',
        'POST',
        body: bonus.toJson(),
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      print('grantBonus error: $e');
      return false;
    }
  }
}
