import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

class SchoolEventsScreen extends StatefulWidget {
  const SchoolEventsScreen({super.key});

  @override
  State<SchoolEventsScreen> createState() => _SchoolEventsScreenState();
}

class _SchoolEventsScreenState extends State<SchoolEventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;
  Set<String> _readEventIds = {};

  @override
  void initState() {
    super.initState();
    _loadReadEvents();
    _loadEvents();
  }

  Future<void> _loadReadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final readIds = prefs.getStringList('read_event_ids') ?? [];
    setState(() {
      _readEventIds = readIds.toSet();
    });
  }

  Future<void> _saveReadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_event_ids', _readEventIds.toList());
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');

      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/teacher/events'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        setState(() {
          _events = jsonDecode(response.body) as List;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _markAsRead(String eventId) {
    if (!_readEventIds.contains(eventId)) {
      setState(() {
        _readEventIds.add(eventId);
      });
      _saveReadEvents();
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
          'School Events',
          style: TextStyle(
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF6B4EFF)),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6B4EFF)),
            )
          : _events.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
              onRefresh: _loadEvents,
              color: const Color(0xFF6B4EFF),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _events.length,
                itemBuilder: (context, index) {
                  return _buildEventCard(_events[index]);
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
              Icons.event_available,
              size: 50,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'No Events Yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Check back later for school events',
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(dynamic event) {
    final eventId = event['_id']?.toString() ?? '';
    final isUnread = !_readEventIds.contains(eventId);
    final createdAt =
        DateTime.tryParse(event['createdAt'] ?? '') ?? DateTime.now();
    final dateStr = '${createdAt.day}/${createdAt.month}/${createdAt.year}';

    return GestureDetector(
      onTap: () {
        _markAsRead(eventId);
        _showEventDetails(event);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: isUnread
              ? Border.all(color: const Color(0xFF6B4EFF), width: 2)
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
          child: Row(
            children: [
              // Event Image
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B4EFF).withAlpha(20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildEventImage(event['image'], 30),
              ),
              const SizedBox(width: 12),

              // Event Info
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
                            event['name'] ?? 'Event',
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
                      event['description'] ?? '',
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getStatusColor(
                              event['status'],
                            ).withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            event['status'] ?? 'Active',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: _getStatusColor(event['status']),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
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
    );
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'active':
        return const Color(0xFF28A745);
      case 'completed':
        return const Color(0xFF007BFF);
      case 'cancelled':
        return const Color(0xFFDC3545);
      default:
        return const Color(0xFF6B4EFF);
    }
  }

  Widget _buildEventImage(
    String? imageData,
    double iconSize, {
    double? width,
    double? height,
  }) {
    if (imageData == null || imageData.isEmpty) {
      return Icon(Icons.event, color: const Color(0xFF6B4EFF), size: iconSize);
    }

    // Check if it's a Base64 data URL
    if (imageData.startsWith('data:image')) {
      try {
        // Extract the Base64 part after the comma
        final base64String = imageData.split(',').last;
        final bytes = base64Decode(base64String);
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: width,
            height: height,
            errorBuilder: (c, e, s) => Icon(
              Icons.event,
              color: const Color(0xFF6B4EFF),
              size: iconSize,
            ),
          ),
        );
      } catch (e) {
        return Icon(
          Icons.event,
          color: const Color(0xFF6B4EFF),
          size: iconSize,
        );
      }
    } else {
      // Regular URL
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageData,
          fit: BoxFit.cover,
          width: width,
          height: height,
          errorBuilder: (c, e, s) =>
              Icon(Icons.event, color: const Color(0xFF6B4EFF), size: iconSize),
        ),
      );
    }
  }

  void _showEventDetails(dynamic event) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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

              // Event Image
              if (event['image'] != null &&
                  event['image'].toString().isNotEmpty)
                Container(
                  height: 150,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: _buildEventImage(
                    event['image'],
                    50,
                    width: double.infinity,
                    height: 150,
                  ),
                ),

              Text(
                event['name'] ?? 'Event',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _getStatusColor(event['status']).withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      event['status'] ?? 'Active',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _getStatusColor(event['status']),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF6B4EFF).withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'For: ${event['eventFor'] ?? 'All'}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF6B4EFF),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),
              const Divider(),
              const SizedBox(height: 12),

              const Text(
                'Description',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                event['description'] ?? 'No description available',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
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
