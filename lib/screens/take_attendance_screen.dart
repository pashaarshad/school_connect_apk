import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../services/teacher_service.dart';

class TakeAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedClass;
  final DateTime? editDate; // For editing existing attendance

  const TakeAttendanceScreen({super.key, this.selectedClass, this.editDate});

  @override
  State<TakeAttendanceScreen> createState() => _TakeAttendanceScreenState();
}

class _TakeAttendanceScreenState extends State<TakeAttendanceScreen> {
  final _teacherService = TeacherService();
  List<dynamic> _students = [];
  final Map<String, String> _attendance = {};
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _alreadySubmitted = false;
  String _selectedDate = '';
  bool _isEditMode = false;

  @override
  void initState() {
    super.initState();
    // Use editDate if provided (editing mode), otherwise use today
    if (widget.editDate != null) {
      _isEditMode = true;
      _selectedDate = _formatDate(widget.editDate!);
    } else {
      _selectedDate = _formatDate(DateTime.now());
    }
    _loadStudents();
    _checkIfAlreadySubmitted();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  String _formatDisplayDate(DateTime date) {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${days[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoading = true);

    // Filter by selected class if provided
    final result = widget.selectedClass != null
        ? await _teacherService.getStudents(
            className: widget.selectedClass!['className']?.toString(),
            section: widget.selectedClass!['section']?.toString(),
          )
        : await _teacherService.getStudents();

    setState(() {
      _isLoading = false;
      if (result['success']) {
        _students = result['data'] ?? [];
        for (var student in _students) {
          _attendance[student['_id']] = 'present';
        }
      }
    });
  }

  Future<void> _checkIfAlreadySubmitted() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      // Build URL with optional class filter
      String url =
          '${ApiConfig.baseUrl}/teacher/attendance?date=$_selectedDate';
      if (widget.selectedClass != null) {
        url +=
            '&className=${widget.selectedClass!['className']}&section=${widget.selectedClass!['section']}';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List && data.isNotEmpty) {
          // Filter by class if selectedClass is provided
          List filteredRecords = data;
          if (widget.selectedClass != null) {
            filteredRecords = data.where((record) {
              return record['className'] ==
                      widget.selectedClass!['className'] &&
                  record['section'] == widget.selectedClass!['section'];
            }).toList();
          }

          // In edit mode, prefill the attendance map with existing data
          if (_isEditMode && filteredRecords.isNotEmpty) {
            setState(() {
              for (var record in filteredRecords) {
                final studentId =
                    record['studentId']?['_id'] ?? record['studentId'];
                if (studentId != null) {
                  _attendance[studentId.toString()] =
                      record['status'] ?? 'present';
                }
              }
              _alreadySubmitted = false; // Allow re-submission in edit mode
            });
          } else {
            setState(() => _alreadySubmitted = filteredRecords.isNotEmpty);
          }
        } else {
          setState(() => _alreadySubmitted = false);
        }
      }
    } catch (e) {
      // Ignore errors
    }
  }

  void _setAttendance(String studentId, String status) {
    setState(() {
      _attendance[studentId] = status;
    });
  }

  Future<void> _submitAttendance() async {
    final confirmed = await _showConfirmationDialog();
    if (!confirmed) return;

    setState(() => _isSubmitting = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final attendanceData = _students.map((s) {
        return {
          'studentId': s['_id'],
          'status': _attendance[s['_id']] ?? 'present',
          'className': s['className'],
          'section': s['section'],
        };
      }).toList();

      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/teacher/attendance'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'attendanceData': attendanceData,
          'date': _selectedDate,
        }),
      );

      setState(() => _isSubmitting = false);

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Attendance submitted successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.pop(context, true);
        }
      } else {
        final data = jsonDecode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['message'] ?? 'Failed to submit attendance'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isSubmitting = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Connection error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showConfirmationDialog() async {
    final presentCount = _attendance.values.where((s) => s == 'present').length;
    final absentCount = _attendance.values.where((s) => s == 'absent').length;

    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Color(0xFF6B4EFF)),
                SizedBox(width: 12),
                Text('Confirm Submission'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submit attendance for $_selectedDate?',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$presentCount',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF28A745),
                            ),
                          ),
                          const Text(
                            'Present',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                      Container(width: 1, height: 50, color: Colors.grey[300]),
                      Column(
                        children: [
                          Text(
                            '$absentCount',
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFDC3545),
                            ),
                          ),
                          const Text(
                            'Absent',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6B4EFF),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Submit'),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendance.values.where((s) => s == 'present').length;
    final absentCount = _attendance.values.where((s) => s == 'absent').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Take Attendance',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4EFF).withAlpha(20),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.calendar_today,
                        color: Color(0xFF6B4EFF),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatDisplayDate(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B4EFF),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF28A745),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$presentCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Present',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC3545),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              '$absentCount',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const Text(
                              'Absent',
                              style: TextStyle(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: const Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    'Student',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                ),
                SizedBox(
                  width: 140,
                  child: Center(
                    child: Text(
                      'Attendance',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
                  )
                : _students.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _students.length,
                    itemBuilder: (context, index) =>
                        _buildStudentRow(_students[index], index + 1),
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_alreadySubmitted)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF3CD),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFFEEBA)),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Color(0xFF856404),
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Attendance already submitted for today',
                            style: TextStyle(
                              color: Color(0xFF856404),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting || _students.isEmpty || _alreadySubmitted
                        ? null
                        : _submitAttendance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _alreadySubmitted
                          ? Colors.grey
                          : const Color(0xFF28A745),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _alreadySubmitted
                                    ? Icons.check
                                    : Icons.check_circle,
                                size: 22,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _alreadySubmitted
                                    ? 'ALREADY SUBMITTED'
                                    : 'SUBMIT TODAY\'S ATTENDANCE',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 50, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No Students Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Text(
            'Add students first to take attendance',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentRow(dynamic student, int index) {
    final studentId = student['_id'];
    final status = _attendance[studentId] ?? 'present';
    final isPresent = status == 'present';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(5),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFF6B4EFF).withAlpha(20),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '$index',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B4EFF),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll: ${student['rollNo'] ?? '-'} | ${student['className']}-${student['section'] ?? 'A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => _setAttendance(studentId, 'absent'),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: !isPresent
                        ? const Color(0xFFDC3545)
                        : const Color(0xFFDC3545).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDC3545),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: !isPresent
                            ? Colors.white
                            : const Color(0xFFDC3545),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _setAttendance(studentId, 'present'),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: isPresent
                        ? const Color(0xFF28A745)
                        : const Color(0xFF28A745).withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFF28A745),
                      width: 2,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'P',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: isPresent
                            ? Colors.white
                            : const Color(0xFF28A745),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
