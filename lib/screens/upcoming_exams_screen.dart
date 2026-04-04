import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class UpcomingExamsScreen extends StatefulWidget {
  const UpcomingExamsScreen({super.key});

  @override
  State<UpcomingExamsScreen> createState() => _UpcomingExamsScreenState();
}

class _UpcomingExamsScreenState extends State<UpcomingExamsScreen> {
  List<dynamic> _exams = [];
  bool _isLoading = true;
  Set<String> _readExamIds = {};

  @override
  void initState() {
    super.initState();
    _loadReadExams();
    _loadExams();
  }

  Future<void> _loadReadExams() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_exam_ids') ?? [];
    setState(() {
      _readExamIds = readIds.toSet();
    });
  }

  Future<void> _saveReadExams() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_exam_ids', _readExamIds.toList());
  }

  Future<void> _loadExams() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/exams'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _exams = jsonDecode(response.body) as List;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _markAsRead(String examId) {
    if (!_readExamIds.contains(examId)) {
      setState(() {
        _readExamIds.add(examId);
      });
      _saveReadExams();
    }
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
          'Upcoming Exams',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadExams,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : _exams.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadExams,
              color: const Color(0xFF6B4EFF),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _exams.length,
                itemBuilder: (context, index) {
                  return _buildExamCard(_exams[index]);
                },
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
              Icons.quiz_outlined,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Upcoming Exams',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'No exams scheduled for now',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildExamCard(dynamic exam) {
    final examId = exam['_id']?.toString() ?? '';
    final isUnread = !_readExamIds.contains(examId);
    final examDate =
        DateTime.tryParse(exam['examDate'] ?? '') ?? DateTime.now();
    final dateStr = '${examDate.day}/${examDate.month}/${examDate.year}';
    final daysLeft = examDate.difference(DateTime.now()).inDays;

    return GestureDetector(
      onTap: () {
        _markAsRead(examId);
        _showExamDetails(exam);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUnread
              ? Border.all(color: const Color(0xFFFF9800), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(10),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Subject Icon
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _getSubjectColor(exam['subject']).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSubjectIcon(exam['subject']),
                      color: _getSubjectColor(exam['subject']),
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Exam Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (isUnread)
                              Container(
                                width: 8,
                                height: 8,
                                margin: const EdgeInsets.only(right: 8),
                                decoration: const BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                exam['name'] ?? 'Exam',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exam['subject'] ?? 'Subject',
                          style: TextStyle(
                            color: _getSubjectColor(exam['subject']),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Days left badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: daysLeft <= 3
                          ? const Color(0xFFDC3545)
                          : const Color(0xFF28A745),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      daysLeft == 0
                          ? 'Today'
                          : daysLeft == 1
                          ? '1 day'
                          : '$daysLeft days',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Exam Details Row
              Row(
                children: [
                  _buildExamDetail(Icons.calendar_today, dateStr),
                  _buildExamDetail(Icons.access_time, exam['startTime'] ?? ''),
                  _buildExamDetail(
                    Icons.timer,
                    '${exam['duration'] ?? 60} min',
                  ),
                  _buildExamDetail(
                    Icons.school,
                    'Class ${exam['className'] ?? ''}',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildExamDetail(IconData icon, String text) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 14, color: Colors.grey),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: Colors.grey),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Color _getSubjectColor(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'mathematics':
        return const Color(0xFF6B4EFF);
      case 'science':
        return const Color(0xFF28A745);
      case 'english':
        return const Color(0xFF007BFF);
      case 'hindi':
        return const Color(0xFFFF9800);
      case 'social studies':
        return const Color(0xFF17A2B8);
      case 'computer':
        return const Color(0xFF6610F2);
      case 'physics':
        return const Color(0xFFDC3545);
      case 'chemistry':
        return const Color(0xFF20C997);
      case 'biology':
        return const Color(0xFF198754);
      default:
        return const Color(0xFF6B4EFF);
    }
  }

  IconData _getSubjectIcon(String? subject) {
    switch (subject?.toLowerCase()) {
      case 'mathematics':
        return Icons.calculate;
      case 'science':
        return Icons.science;
      case 'english':
        return Icons.menu_book;
      case 'hindi':
        return Icons.language;
      case 'social studies':
        return Icons.public;
      case 'computer':
        return Icons.computer;
      case 'physics':
        return Icons.bolt;
      case 'chemistry':
        return Icons.biotech;
      case 'biology':
        return Icons.eco;
      default:
        return Icons.quiz;
    }
  }

  void _showExamDetails(dynamic exam) {
    final examDate =
        DateTime.tryParse(exam['examDate'] ?? '') ?? DateTime.now();
    final dateStr = '${examDate.day}/${examDate.month}/${examDate.year}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                      color: _getSubjectColor(exam['subject']).withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _getSubjectIcon(exam['subject']),
                      color: _getSubjectColor(exam['subject']),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exam['name'] ?? 'Exam',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          exam['subject'] ?? 'Subject',
                          style: TextStyle(
                            fontSize: 14,
                            color: _getSubjectColor(exam['subject']),
                            fontWeight: FontWeight.w600,
                          ),
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
              _buildDetailRow(Icons.calendar_today, 'Date', dateStr),
              _buildDetailRow(
                Icons.access_time,
                'Time',
                exam['startTime'] ?? '-',
              ),
              _buildDetailRow(
                Icons.timer,
                'Duration',
                '${exam['duration'] ?? 60} minutes',
              ),
              _buildDetailRow(Icons.school, 'Class', exam['className'] ?? '-'),
              _buildDetailRow(
                Icons.grade,
                'Total Marks',
                '${exam['totalMarks'] ?? 100}',
              ),
              _buildDetailRow(
                Icons.info_outline,
                'Status',
                exam['status'] ?? 'Scheduled',
              ),
            ],
          ),
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
}
