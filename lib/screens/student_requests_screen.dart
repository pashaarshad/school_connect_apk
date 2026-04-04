import 'package:flutter/material.dart';
import '../services/teacher_service.dart';

class StudentRequestsScreen extends StatefulWidget {
  final Map<String, dynamic>? selectedClass;

  const StudentRequestsScreen({super.key, this.selectedClass});

  @override
  State<StudentRequestsScreen> createState() => _StudentRequestsScreenState();
}

class _StudentRequestsScreenState extends State<StudentRequestsScreen>
    with SingleTickerProviderStateMixin {
  final _teacherService = TeacherService();
  late TabController _tabController;

  List<dynamic> _pending = [];
  List<dynamic> _approved = [];
  List<dynamic> _rejected = [];
  bool _isLoading = true;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _rejectedCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }


  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    final result = await _teacherService.getMyRequests();
    setState(() {
      _isLoading = false;
      if (result['success']) {
        final data = result['data'];
        // Show all requests regardless of selected class tab
        _pending = List<dynamic>.from(data['pending'] ?? []);
        _approved = List<dynamic>.from(data['approved'] ?? []);
        _rejected = List<dynamic>.from(data['rejected'] ?? []);
        _pendingCount = _pending.length;
        _approvedCount = _approved.length;
        _rejectedCount = _rejected.length;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
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
          'Student Requests',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF6B4EFF),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFF6B4EFF),
          tabs: [
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Pending'),
                  if (_pendingCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_pendingCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Approved'),
                  if (_approvedCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_approvedCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Rejected'),
                  if (_rejectedCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$_rejectedCount',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildStudentList(_pending, 'Pending', Colors.orange),
                _buildStudentList(_approved, 'Approved', Colors.green),
                _buildStudentList(_rejected, 'Rejected', Colors.red),
              ],
            ),
    );
  }

  Widget _buildStudentList(
    List<dynamic> students,
    String status,
    Color statusColor,
  ) {
    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == 'Pending'
                  ? Icons.hourglass_empty
                  : status == 'Approved'
                  ? Icons.check_circle_outline
                  : Icons.cancel_outlined,
              size: 60,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              'No $status Students',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              status == 'Pending'
                  ? 'All your student requests have been processed'
                  : status == 'Approved'
                  ? 'No approved students yet'
                  : 'No rejected requests',
              style: const TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: students.length,
        itemBuilder: (context, index) {
          final student = students[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(10),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: statusColor.withAlpha(30),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      (student['name'] ?? 'S')[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
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
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Class ${student['className'] ?? '-'}-${student['section'] ?? 'A'} | Roll: ${student['rollNo'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
