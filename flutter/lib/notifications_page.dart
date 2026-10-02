import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'chat_page.dart';
import 'app_theme.dart';
import 'api_config.dart';

/// หน้าแสดงการแจ้งเตือนทั้งหมดของผู้ใช้ (นักเรียน/ติวเตอร์)
/// - แจ้งเตือนประเภท "มีคำขอจับคู่ใหม่" จะมีปุ่มยืนยัน/ปฏิเสธ
/// - แจ้งเตือนประเภทผลลัพธ์ (ยืนยันแล้ว/ถูกปฏิเสธ) จะเป็นการ์ดอ่านอย่างเดียว
class NotificationsPage extends StatefulWidget {
  final String role; // 'student' หรือ 'tutor'
  final String userId;

  const NotificationsPage({
    super.key,
    required this.role,
    required this.userId,
  });

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _items = [];
  final Map<int, String> _responding = {}; // notification_id -> 'loading'

  Color get _themeColor => AppColors.forRole(widget.role);

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await http
          .get(
            Uri.parse(
              "$kApiBase/api_get_notifications.php?role=${widget.role}&id=${widget.userId}",
            ),
          )
          .timeout(const Duration(seconds: 15));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(data['notifications'] ?? []);
          _isLoading = false;
        });
        _markAllRead();
      } else {
        setState(() {
          _error = data['message'] ?? 'เกิดข้อผิดพลาด';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'ไม่สามารถเชื่อมต่อเซิร์ฟเวอร์ได้\n$e';
        _isLoading = false;
      });
    }
  }

  Future<void> _markAllRead() async {
    try {
      await http.post(
        Uri.parse("$kApiBase/api_mark_notification_read.php"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"role": widget.role, "id": widget.userId}),
      );
    } catch (_) {
      // ไม่ต้องแจ้งผู้ใช้ถ้า mark read ไม่สำเร็จ
    }
  }

  Future<void> _respond(Map<String, dynamic> item, String action) async {
    final int notifId = (item['notification_id'] as num).toInt();
    final String? matchId = item['match_id'] as String?;
    if (matchId == null || matchId.isEmpty) return;

    setState(() => _responding[notifId] = 'loading');
    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_respond_request.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({"match_id": matchId, "action": action}),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        setState(() {
          item['request_status'] = action == 'accept' ? 'accepted' : 'rejected';
          _responding.remove(notifId);
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                action == 'accept'
                    ? '✅ ยืนยันการจับคู่สำเร็จ'
                    : 'ปฏิเสธคำขอเรียบร้อย',
              ),
              backgroundColor: action == 'accept'
                  ? Colors.green
                  : Colors.grey[700],
            ),
          );
          if (action == 'accept') {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  matchId: matchId,
                  role: widget.role,
                  userId: widget.userId,
                ),
              ),
            );
          }
        }
      } else {
        setState(() => _responding.remove(notifId));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ ${data['message']}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _responding.remove(notifId));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ เชื่อมต่อไม่ได้'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'การแจ้งเตือน',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDark),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : _error != null
          ? _buildError()
          : _items.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _fetchNotifications,
              color: _themeColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _items.length,
                itemBuilder: (ctx, i) => _buildItem(_items[i]),
              ),
            ),
    );
  }

  Widget _buildError() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('ลองใหม่'),
            style: ElevatedButton.styleFrom(backgroundColor: _themeColor),
            onPressed: _fetchNotifications,
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.notifications_none, size: 72, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text(
          'ยังไม่มีการแจ้งเตือน',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildItem(Map<String, dynamic> item) {
    final int notifId = (item['notification_id'] as num).toInt();
    final String type = item['type'] ?? '';
    final String title = item['title'] ?? '';
    final String message = item['message'] ?? '';
    final String requestStatus = item['request_status'] ?? '';
    final String respondingState = _responding[notifId] ?? '';
    final bool isIncomingRequest = type == 'request_received';
    final bool stillPending = requestStatus == 'pending';

    IconData icon;
    Color iconColor;
    switch (type) {
      case 'request_received':
        icon = Icons.mail_outline;
        iconColor = Colors.blue;
        break;
      case 'request_accepted':
        icon = Icons.check_circle_outline;
        iconColor = Colors.green;
        break;
      case 'request_rejected':
        icon = Icons.cancel_outlined;
        iconColor = Colors.red;
        break;
      default:
        icon = Icons.notifications_none;
        iconColor = Colors.grey;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: AppText.bodyLg,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: AppText.body,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                if (isIncomingRequest)
                  stillPending
                      ? (respondingState == 'loading'
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 6),
                                child: SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              )
                            : Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.red[600],
                                        side: BorderSide(
                                          color: Colors.red[200]!,
                                        ),
                                        minimumSize: const Size(
                                          0,
                                          AppSizes.minTouchTarget,
                                        ),
                                        textStyle: const TextStyle(
                                          fontSize: AppText.body,
                                        ),
                                      ),
                                      onPressed: () async {
                                        final confirmed = await confirmDialog(
                                          context,
                                          title: 'ปฏิเสธคำขอ',
                                          message:
                                              'คุณต้องการปฏิเสธคำขอจับคู่นี้ใช่หรือไม่?',
                                          confirmLabel: 'ปฏิเสธ',
                                          danger: true,
                                        );
                                        if (confirmed) _respond(item, 'reject');
                                      },
                                      child: const Text('ปฏิเสธ'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.green,
                                        minimumSize: const Size(
                                          0,
                                          AppSizes.minTouchTarget,
                                        ),
                                      ),
                                      onPressed: () => _respond(item, 'accept'),
                                      child: const Text(
                                        'ยืนยัน',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: AppText.body,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ))
                      : _statusChip(requestStatus),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusChip(String status) {
    final bool accepted = status == 'accepted';
    final Color c = accepted ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        accepted ? 'ยืนยันแล้ว' : 'ปฏิเสธแล้ว',
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w600,
          fontSize: AppText.caption,
        ),
      ),
    );
  }
}
