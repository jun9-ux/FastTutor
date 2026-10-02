import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_nav_bar.dart';
import 'chat_page.dart';
import 'app_session.dart';
import 'app_theme.dart';
import 'Learn.dart' hide Duration;
import 'teach.dart' hide Duration;
import 'match.dart';
import 'EditProfilePage.dart';
import 'api_config.dart';

/// หน้ารายการคู่สนทนาที่แมตช์สำเร็จแล้วทั้งหมด (แท็บ "แชท" ใน Bottom Navigation Bar)
class ChatListPage extends StatefulWidget {
  final String role; // 'student' หรือ 'tutor'
  final String userId;

  const ChatListPage({super.key, required this.role, required this.userId});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _conversations = [];
  final int _currentIndex = 3; // แชท

  bool get _isStudent => widget.role == 'student';
  Color get _themeColor => AppColors.forRole(widget.role);

  @override
  void initState() {
    super.initState();
    _fetchConversations();
  }

  Future<void> _fetchConversations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final uri = Uri.parse(
        "$kApiBase/api_get_conversations.php"
        "?role=${widget.role}&id=${widget.userId}",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        final list = (data['conversations'] as List?) ?? [];
        setState(() {
          _conversations = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'ไม่สามารถโหลดรายการแชทได้';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่';
        _isLoading = false;
      });
    }
  }

  void _onNavTap(int index) {
    if (index == _currentIndex) return;
    switch (index) {
      case 0:
        goToDashboard(context);
        break;
      case 1:
        goToTab(
          context,
          _isStudent
              ? AddLearnPage(studentId: widget.userId)
              : AddTeachPage(tutorId: widget.userId),
        );
        break;
      case 2:
        goToTab(
          context,
          MatchPage(role: widget.role, userId: widget.userId, userName: ''),
        );
        break;
      case 4:
        goToTab(
          context,
          EditProfilePage(
            role: widget.role,
            userData: AppSession.userData,
            onUpdated: (_) {},
          ),
        );
        break;
      case 3:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'แชท',
          style: TextStyle(
            color: AppColors.textDark,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textDark),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textDark),
            onPressed: _fetchConversations,
          ),
        ],
      ),
      bottomNavigationBar: AppNavBar(
        role: widget.role,
        currentIndex: _currentIndex,
        onTap: _onNavTap,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: _themeColor))
          : _error != null
          ? _buildError()
          : _conversations.isEmpty
          ? _buildEmpty()
          : RefreshIndicator(
              onRefresh: _fetchConversations,
              color: _themeColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _conversations.length,
                itemBuilder: (_, i) => _buildItem(_conversations[i]),
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
            onPressed: _fetchConversations,
          ),
        ],
      ),
    ),
  );

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.chat_bubble_outline, size: 72, color: Colors.grey[400]),
        const SizedBox(height: 16),
        const Text(
          'ยังไม่มีคู่สนทนา\nแชทจะเปิดใช้งานได้เมื่อแมตช์สำเร็จ',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildItem(Map<String, dynamic> item) {
    final String matchId = item['match_id']?.toString() ?? '';
    final String partnerName = item['partner_name']?.toString() ?? 'อีกฝ่าย';
    final String subject = item['subject']?.toString() ?? '';
    final String lastMessage =
        item['last_message']?.toString() ?? 'เริ่มต้นบทสนทนาได้เลย';
    final int unread = (item['unread_count'] is num)
        ? (item['unread_count'] as num).toInt()
        : int.tryParse(item['unread_count']?.toString() ?? '0') ?? 0;
    final bool isOnline = item['partner_is_online'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: AvatarWithStatus(
          apiBase: kApiBase,
          photoPath: item['partner_photo_url'],
          radius: 24,
          isOnline: isOnline,
          backgroundColor: _themeColor.withOpacity(0.12),
          fallback: Icon(Icons.person, color: _themeColor),
        ),
        title: Text(
          partnerName,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: AppText.bodyLg,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (subject.isNotEmpty)
              Text(
                subject,
                style: const TextStyle(
                  fontSize: AppText.caption,
                  color: Color(0xFF999999),
                ),
              ),
            Text(
              lastMessage,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: AppText.body,
                color: Color(0xFF666666),
              ),
            ),
          ],
        ),
        trailing: unread > 0 ? UnreadBadge(count: unread) : null,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChatPage(
                matchId: matchId,
                role: widget.role,
                userId: widget.userId,
              ),
            ),
          ).then((_) => _fetchConversations());
        },
      ),
    );
  }
}
