import 'package:flutter/material.dart';
import '../services/teacher_service.dart';
import 'add_student_screen.dart';

class MyStudentsScreen extends StatefulWidget {
  final List<dynamic> classAssignments;
  final Map<String, dynamic>? selectedClass;

  const MyStudentsScreen({
    super.key,
    required this.classAssignments,
    this.selectedClass,
  });

  @override
  State<MyStudentsScreen> createState() => _MyStudentsScreenState();
}

class _MyStudentsScreenState extends State<MyStudentsScreen> {
  final _teacherService = TeacherService();
  List<dynamic> _students = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadStudents();
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
      }
    });
  }

  List<dynamic> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students.where((s) {
      final name = (s['name'] ?? '').toString().toLowerCase();
      final rollNo = (s['rollNo'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || rollNo.contains(query);
    }).toList();
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
          'My Students',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadStudents,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Search by name or roll no...',
                hintStyle: const TextStyle(color: Colors.grey),
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFF5F5F5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          // Stats Row
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _buildMiniStat(
                  label: 'Total',
                  value: '${_students.length}',
                  color: const Color(0xFF6B4EFF),
                ),
                const SizedBox(width: 12),
                _buildMiniStat(
                  label: 'Active',
                  value:
                      '${_students.where((s) => s['status'] == 'Active').length}',
                  color: const Color(0xFF28A745),
                ),
                const SizedBox(width: 12),
                _buildMiniStat(
                  label: 'With Login',
                  value:
                      '${_students.where((s) => s['parentUsername'] != null && s['parentUsername'] != '').length}',
                  color: const Color(0xFF007BFF),
                ),
              ],
            ),
          ),

          // Student List
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
                  )
                : _filteredStudents.isEmpty
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _loadStudents,
                    color: const Color(0xFF6B4EFF),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredStudents.length,
                      itemBuilder: (context, index) {
                        return _buildStudentCard(_filteredStudents[index]);
                      },
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  AddStudentScreen(classAssignments: widget.classAssignments),
            ),
          );
          if (result == true) _loadStudents();
        },
        backgroundColor: const Color(0xFF6B4EFF),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Student', style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildMiniStat({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
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
            child: const Icon(
              Icons.people_outline,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Students Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add your first student to get started',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildStudentCard(dynamic student) {
    final hasLogin =
        student['parentUsername'] != null && student['parentUsername'] != '';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(10),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showStudentDetails(student),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _getAvatarColor(student['name'] ?? ''),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(student['name'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              student['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                            ),
                          ),
                          if (hasLogin)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF28A745),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.key,
                                    color: Colors.white,
                                    size: 12,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Login',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6B4EFF).withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Class ${student['className'] ?? '-'}-${student['section'] ?? 'A'}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B4EFF),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          if (student['rollNo'] != null &&
                              student['rollNo'] != '') ...[
                            const SizedBox(width: 8),
                            Text(
                              'Roll: ${student['rollNo']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getAvatarColor(String name) {
    final colors = [
      const Color(0xFF6B4EFF),
      const Color(0xFF28A745),
      const Color(0xFF007BFF),
      const Color(0xFFFF9800),
      const Color(0xFFDC3545),
      const Color(0xFF17A2B8),
    ];
    return colors[name.isEmpty ? 0 : name.codeUnitAt(0) % colors.length];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  void _showStudentDetails(dynamic student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StudentDetailsSheet(
        student: student,
        onGenerateLogin: () async {
          Navigator.pop(ctx);
          final result = await _teacherService.generateParentLogin(
            student['_id'],
          );
          if (result['success']) {
            _loadStudents();
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Login generated: ${result['data']['parentUsername']}',
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            }
          }
        },
      ),
    );
  }
}

class _StudentDetailsSheet extends StatelessWidget {
  final dynamic student;
  final VoidCallback onGenerateLogin;

  const _StudentDetailsSheet({
    required this.student,
    required this.onGenerateLogin,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogin =
        student['parentUsername'] != null && student['parentUsername'] != '';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Header
            Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: const Color(0xFF6B4EFF),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(student['name'] ?? ''),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'] ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      Text(
                        'Class ${student['className'] ?? '-'}-${student['section'] ?? 'A'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),

            // Details
            _buildDetailRow(Icons.numbers, 'Roll No', student['rollNo'] ?? '-'),
            _buildDetailRow(Icons.email, 'Email', student['email'] ?? '-'),
            _buildDetailRow(Icons.phone, 'Mobile', student['mobileNo'] ?? '-'),
            _buildDetailRow(
              Icons.person,
              'Parent Name',
              student['parentName'] ?? '-',
            ),
            _buildDetailRow(
              Icons.phone_android,
              'Parent Mobile',
              student['parentMobile'] ?? '-',
            ),

            if (hasLogin) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFD4EDDA),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.key, color: Color(0xFF155724), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Parent Login Credentials',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF155724),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildCredentialRow('Username', student['parentUsername']),
                    const SizedBox(height: 4),
                    _buildCredentialRow(
                      'Password',
                      student['parentPassword'] ?? '••••••••',
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),

            if (!hasLogin)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: onGenerateLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6B4EFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.key),
                  label: const Text(
                    'Generate Parent Login',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 12),
          Text(label, style: const TextStyle(color: Colors.grey)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF155724))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            value,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontWeight: FontWeight.bold,
              color: Color(0xFF155724),
            ),
          ),
        ),
      ],
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }
}
