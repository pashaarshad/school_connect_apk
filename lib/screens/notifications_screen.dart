import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<dynamic> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/messages'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _messages = jsonDecode(response.body) as List;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsRead(String messageId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      await http.post(
        Uri.parse('${ApiConfig.baseUrl}/teacher/messages/$messageId/read'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      // Update local state
      setState(() {
        final index = _messages.indexWhere((m) => m['_id'] == messageId);
        if (index != -1) {
          _messages[index]['isRead'] = true;
        }
      });
    } catch (e) {
      // Silently fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final unreadCount = _messages.where((m) => m['isRead'] != true).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            const Text(
              'Notifications',
              style: TextStyle(
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.bold,
              ),
            ),
            if (unreadCount > 0) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$unreadCount new',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            ],
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadMessages,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : _messages.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadMessages,
              color: const Color(0xFF6B4EFF),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  return _buildNotificationCard(_messages[index]);
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
              Icons.notifications_none,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'You\'re all caught up!',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(dynamic message) {
    final isRead = message['isRead'] == true;
    final createdAt =
        DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
    final now = DateTime.now();
    final diff = now.difference(createdAt);

    String timeAgo;
    if (diff.inMinutes < 60) {
      timeAgo = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      timeAgo = '${diff.inHours}h ago';
    } else {
      timeAgo = '${diff.inDays}d ago';
    }

    return GestureDetector(
      onTap: () {
        if (!isRead) {
          _markAsRead(message['_id']);
        }
        _showMessageDetails(message);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isRead ? Colors.white : const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(16),
          border: isRead
              ? null
              : Border.all(color: const Color(0xFFFF9800), width: 2),
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
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  color: isRead
                      ? const Color(0xFFF5F5F5)
                      : const Color(0xFFFF9800).withAlpha(30),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.notifications,
                  color: isRead ? Colors.grey : const Color(0xFFFF9800),
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (!isRead)
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
                            message['heading'] ?? 'Notification',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                              color: const Color(0xFF1A1A1A),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          timeAgo,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message['message'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMessageDetails(dynamic message) {
    final createdAt =
        DateTime.tryParse(message['createdAt'] ?? '') ?? DateTime.now();
    final dateStr =
        '${createdAt.day}/${createdAt.month}/${createdAt.year} at ${createdAt.hour}:${createdAt.minute.toString().padLeft(2, '0')}';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.5,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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

              Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF).withAlpha(20),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFF6B4EFF),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message['heading'] ?? 'Notification',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              Text(
                message['message'] ?? 'No message content',
                style: const TextStyle(
                  fontSize: 15,
                  color: Color(0xFF333333),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
