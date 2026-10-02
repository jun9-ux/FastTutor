import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'app_theme.dart';
import 'api_config.dart';

/// หน้าห้องแชทระหว่างนักเรียน-ติวเตอร์ที่แมตช์สำเร็จแล้ว (match_status = '1')
class ChatPage extends StatefulWidget {
  final String matchId;
  final String role; // 'student' หรือ 'tutor'
  final String userId;

  const ChatPage({
    super.key,
    required this.matchId,
    required this.role,
    required this.userId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  bool _isLoading = true;
  String? _error;
  bool _sending = false;
  List<Map<String, dynamic>> _messages = [];
  String _partnerName = '';
  String _subject = '';

  Color get _accentColor => AppColors.forRole(widget.role);

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _fetchMessages(showLoading: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _fetchMessages(showLoading: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchMessages({required bool showLoading}) async {
    if (showLoading) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }
    try {
      final uri = Uri.parse(
        "$kApiBase/api_get_messages.php"
        "?match_id=${widget.matchId}&role=${widget.role}&id=${widget.userId}",
      );
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        final list = (data['messages'] as List?) ?? [];
        setState(() {
          _messages = list
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
          _partnerName = data['partner_name']?.toString() ?? '';
          _subject = data['subject']?.toString() ?? '';
          _isLoading = false;
        });
        _scrollToBottom();
      } else {
        setState(() {
          _error = data['message']?.toString() ?? 'ไม่สามารถโหลดข้อความได้';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (showLoading) {
        setState(() {
          _error = 'เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ กรุณาลองใหม่';
          _isLoading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    _messageController.clear();
    try {
      final res = await http
          .post(
            Uri.parse("$kApiBase/api_send_message.php"),
            headers: {"Content-Type": "application/json"},
            body: jsonEncode({
              "match_id": widget.matchId,
              "sender_role": widget.role,
              "message": text,
            }),
          )
          .timeout(const Duration(seconds: 10));
      final data = jsonDecode(res.body);
      if (data['result'] == 1) {
        await _fetchMessages(showLoading: false);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(data['message']?.toString() ?? 'ส่งข้อความไม่สำเร็จ'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        backgroundColor: AppColors.dark,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _partnerName.isEmpty ? 'แชท' : _partnerName,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (_subject.isNotEmpty)
              Text(
                _subject,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: AppText.caption,
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: _accentColor))
                : _error != null
                ? _buildError()
                : _messages.isEmpty
                ? _buildEmpty()
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) => _buildBubble(_messages[i]),
                  ),
          ),
          _buildInputBar(),
        ],
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
            style: ElevatedButton.styleFrom(backgroundColor: _accentColor),
            onPressed: () => _fetchMessages(showLoading: true),
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
          'เริ่มต้นบทสนทนาได้เลย',
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ],
    ),
  );

  Widget _buildBubble(Map<String, dynamic> item) {
    final bool isMine = item['sender_role'] == widget.role;
    final String text = item['chat_message']?.toString() ?? '';

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        decoration: BoxDecoration(
          color: isMine ? _accentColor : AppColors.bubbleReceived,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 4),
            bottomRight: Radius.circular(isMine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isMine ? Colors.white : AppColors.textDark,
            fontSize: AppText.bodyLg,
          ),
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _messageController,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _sendMessage(),
                decoration: InputDecoration(
                  hintText: 'พิมพ์ข้อความ...',
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 24,
              backgroundColor: _accentColor,
              child: IconButton(
                icon: _sending
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.send, color: Colors.white, size: 22),
                onPressed: _sending ? null : _sendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
