import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import 'take_attendance_screen.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedClass;

  const AttendanceHistoryScreen({super.key, this.selectedClass});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  List<dynamic> _attendanceRecords = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  Future<void> _loadAttendance() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final dateStr = _formatDate(_selectedDate);

      // Build URL with optional class filter
      String url = '${ApiConfig.baseUrl}/teacher/attendance?date=$dateStr';
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

      setState(() {
        _isLoading = false;
        if (response.statusCode == 200) {
          final allRecords = jsonDecode(response.body) ?? [];
          // Filter by class if selectedClass is provided
          if (widget.selectedClass != null) {
            _attendanceRecords = (allRecords as List).where((r) {
              final student = r['studentId'];
              return student != null &&
                  student['className'] == widget.selectedClass!['className'] &&
                  student['section'] == widget.selectedClass!['section'];
            }).toList();
          } else {
            _attendanceRecords = allRecords;
          }
        }
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
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

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: Color(0xFF6B4EFF)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendance();
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendanceRecords
        .where((r) => r['status'] == 'present')
        .length;
    final absentCount = _attendanceRecords
        .where((r) => r['status'] == 'absent')
        .length;

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
          'Attendance History',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Column(
        children: [
          // Date Picker
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _selectDate,
                  child: Container(
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
                          _formatDisplayDate(_selectedDate),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF6B4EFF),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(
                          Icons.arrow_drop_down,
                          color: Color(0xFF6B4EFF),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Stats Row
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
                // Edit Button (only show if there are records for this date)
                if (_attendanceRecords.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TakeAttendanceScreen(
                              selectedClass: widget.selectedClass,
                              editDate: _selectedDate,
                            ),
                          ),
                        );
                        // Reload attendance if edited
                        if (result == true) {
                          _loadAttendance();
                        }
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('Edit Attendance'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6B4EFF),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Records List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
                  )
                : _attendanceRecords.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _attendanceRecords.length,
                    itemBuilder: (context, index) {
                      return _buildRecordCard(
                        _attendanceRecords[index],
                        index + 1,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(50),
            ),
            child: const Icon(Icons.history, size: 50, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Attendance Records',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No attendance found for this date',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(dynamic record, int index) {
    final student = record['studentId'];
    final isPresent = record['status'] == 'present';

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
          // Index
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

          // Student Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student?['name'] ?? 'Unknown',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Roll: ${student?['rollNo'] ?? '-'} | ${student?['className'] ?? '-'}-${student?['section'] ?? 'A'}',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isPresent
                  ? const Color(0xFF28A745)
                  : const Color(0xFFDC3545),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isPresent ? 'PRESENT' : 'ABSENT',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
