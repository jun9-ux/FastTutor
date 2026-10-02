import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'photo_helper.dart';
import 'app_theme.dart';
import 'admin_report_page.dart';
import 'api_config.dart';

// ─────────────────────────────────────────────────────────────────
// URI ของ server
// ─────────────────────────────────────────────────────────────────
final Uri _adminUri = Uri.parse('$kApiBase/api_admin.php');

// ─────────────────────────────────────────────────────────────────
// Model: AppUser (student / tutor)
// ─────────────────────────────────────────────────────────────────
class AppUser {
  final String id;
  final String role;
  final String firstName;
  final String lastName;
  final int gender;
  final int age;
  final String email;
  final String phone;
  final String address;
  final String extra;
  final String education;
  final bool isOnline;
  final String? lastSeen;
  final String? photoPath;
  AppUser({
    required this.id,
    required this.role,
    required this.firstName,
    required this.lastName,
    required this.gender,
    required this.age,
    required this.email,
    required this.phone,
    required this.address,
    required this.extra,
    required this.education,
    required this.isOnline,
    this.lastSeen,
    this.photoPath,
  });
  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
    id: j['id'] ?? '',
    role: j['role'] ?? '',
    firstName: j['first_name'] ?? '',
    lastName: j['last_name'] ?? '',
    gender: int.tryParse(j['gender'].toString()) ?? 0,
    age: int.tryParse(j['age'].toString()) ?? 0,
    email: j['email'] ?? '-',
    phone: j['phone'] ?? '-',
    address: j['address'] ?? '-',
    extra: j['occupation'] ?? j['subject_teach'] ?? '-',
    education: j['education_level'] ?? j['education'] ?? '-',
    isOnline: j['is_online'] == true || j['is_online'] == 1,
    lastSeen: j['last_seen'],
    photoPath: j['photo_path'],
  );
  String get fullName => '$firstName $lastName';
  String get genderLabel => gender == 0
      ? 'ชาย'
      : gender == 1
      ? 'หญิง'
      : 'อื่นๆ';
  String get roleLabel => role == 'student' ? 'นักเรียน' : 'ติวเตอร์';
}

// ─────────────────────────────────────────────────────────────────
// Model: AdminUser
// (ตรงกับตาราง admin จริง: admin_id, first_name, last_name, email,
//  ad_username, ad_password, created_at — ไม่มี gender/phone/address)
// ─────────────────────────────────────────────────────────────────
class AdminUser {
  final String id;
  final String firstName;
  final String lastName;
  final String email;
  final String username;
  final String? createdAt;

  AdminUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.username,
    this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> j) => AdminUser(
    id: j['id'] ?? '',
    firstName: j['first_name'] ?? '',
    lastName: j['last_name'] ?? '',
    email: j['email'] ?? '-',
    username: j['username'] ?? '-',
    createdAt: j['created_at'],
  );

  String get fullName => '$firstName $lastName';
}

// ─────────────────────────────────────────────────────────────────
// AdminDashboard Widget
// ─────────────────────────────────────────────────────────────────
class AdminDashboardPage extends StatefulWidget {
  final Map<String, dynamic> adminData;
  const AdminDashboardPage({super.key, required this.adminData});
  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _refreshTimer;
  List<AppUser> _students = [];
  List<AppUser> _tutors = [];
  List<AdminUser> _admins = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String _search = '';
  String _filterStudents = 'all';
  String _filterTutors = 'all';
  int _currentTabIndex = 0;

  String? get _currentAdminId =>
      (widget.adminData['id'] ?? widget.adminData['admin_id'])?.toString();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => _currentTabIndex = _tabController.index);
      }
    });
    _fetchAll();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchAll(),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchAll() async {
    await Future.wait([_fetchUsers(), _fetchAdmins()]);
  }

  Future<void> _fetchUsers() async {
    try {
      final res = await http.post(
        _adminUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get_users'}),
      );
      final json = jsonDecode(res.body);
      if (json['result'] == 1) {
        setState(() {
          _students = (json['students'] as List)
              .map((e) => AppUser.fromJson(e))
              .toList();
          _tutors = (json['tutors'] as List)
              .map((e) => AppUser.fromJson(e))
              .toList();
          _summary = json['summary'] ?? {};
          _loading = false;
        });
      }
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  Future<void> _fetchAdmins() async {
    try {
      final res = await http.post(
        _adminUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'action': 'get_admins'}),
      );
      final json = jsonDecode(res.body);
      if (json['result'] == 1) {
        setState(() {
          _admins = (json['admins'] as List)
              .map((e) => AdminUser.fromJson(e))
              .toList();
        });
      }
    } catch (e) {
      // เงียบไว้ ไม่ต้อง block ทั้งหน้าถ้าโหลด admin ไม่สำเร็จ
    }
  }

  List<AppUser> _filtered(List<AppUser> list, String filter) {
    return list.where((u) {
      final q = _search.toLowerCase();
      final matchSearch =
          q.isEmpty ||
          u.fullName.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.contains(q);
      final matchFilter =
          filter == 'all' ||
          (filter == 'online' && u.isOnline) ||
          (filter == 'offline' && !u.isOnline);
      return matchSearch && matchFilter;
    }).toList();
  }

  List<AdminUser> get _filteredAdmins {
    final q = _search.toLowerCase();
    if (q.isEmpty) return _admins;
    return _admins
        .where(
          (a) =>
              a.fullName.toLowerCase().contains(q) ||
              a.email.toLowerCase().contains(q) ||
              a.username.toLowerCase().contains(q),
        )
        .toList();
  }

  static const _navy = AppColors.dark;
  static const _accent = AppColors.primary;
  static const _green = AppColors.online;
  static const _gray = Color(0xFF94A3B8);
  static const _orange = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5FB),
      appBar: _buildAppBar(),
      floatingActionButton: _currentTabIndex == 2
          ? FloatingActionButton.extended(
              backgroundColor: _accent,
              onPressed: _openAddAdminForm,
              icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
              label: const Text(
                'เพิ่มแอดมิน',
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildSummaryBar(),
                if (_currentTabIndex != 3) _buildSearchBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildUserList(
                        _filtered(_students, _filterStudents),
                        'student',
                        _filterStudents,
                        (v) => setState(() => _filterStudents = v),
                      ),
                      _buildUserList(
                        _filtered(_tutors, _filterTutors),
                        'tutor',
                        _filterTutors,
                        (v) => setState(() => _filterTutors = v),
                      ),
                      _buildAdminList(),
                      AdminReportTab(adminUri: _adminUri),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  PreferredSizeWidget _buildAppBar() => AppBar(
    backgroundColor: _navy,
    elevation: 0,
    automaticallyImplyLeading: false,
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'แดชบอร์ดผู้ดูแลระบบ',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        Text(
          'ยินดีต้อนรับ ${widget.adminData['first_name'] ?? ''}',
          style: const TextStyle(color: Color(0xFFB0C4DE), fontSize: 13),
        ),
      ],
    ),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh, color: Colors.white),
        onPressed: () {
          setState(() => _loading = true);
          _fetchAll();
        },
      ),
      IconButton(
        icon: const Icon(Icons.logout, color: Colors.white),
        onPressed: _logout,
      ),
    ],
  );

  Widget _buildSummaryBar() => Container(
    color: _navy,
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Row(
      children: [
        _summaryChip(
          'นักเรียน',
          _summary['total_students'] ?? 0,
          Icons.school,
          Colors.blueAccent,
        ),
        const SizedBox(width: 10),
        _summaryChip(
          'ติวเตอร์',
          _summary['total_tutors'] ?? 0,
          Icons.person_pin,
          Colors.purpleAccent,
        ),
        const SizedBox(width: 10),
        _summaryChip(
          'แอดมิน',
          _admins.length,
          Icons.admin_panel_settings,
          _orange,
        ),
      ],
    ),
  );

  Widget _summaryChip(String label, int count, IconData icon, Color color) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFFB0C4DE),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );

  Widget _buildSearchBar() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
    child: TextField(
      onChanged: (v) => setState(() => _search = v),
      decoration: InputDecoration(
        hintText: 'ค้นหาชื่อ, อีเมล, เบอร์โทร, ชื่อผู้ใช้...',
        prefixIcon: const Icon(Icons.search, color: _gray),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _buildTabBar() => Container(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
    ),
    child: TabBar(
      controller: _tabController,
      indicator: BoxDecoration(
        color: _accent,
        borderRadius: BorderRadius.circular(10),
      ),
      labelColor: Colors.white,
      unselectedLabelColor: _navy,
      labelStyle: const TextStyle(fontSize: 13),
      tabs: [
        Tab(text: 'นักเรียน (${_students.length})'),
        Tab(text: 'ติวเตอร์ (${_tutors.length})'),
        Tab(text: 'แอดมิน (${_admins.length})'),
        const Tab(text: 'รายงาน'),
      ],
    ),
  );

  Widget _buildUserList(
    List<AppUser> list,
    String role,
    String filter,
    ValueChanged<String> onFilter,
  ) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: ['all', 'online', 'offline'].map((f) {
            final labels = {
              'all': 'ทั้งหมด',
              'online': 'ออนไลน์',
              'offline': 'ออฟไลน์',
            };
            final selected = filter == f;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(labels[f]!),
                selected: selected,
                onSelected: (_) => onFilter(f),
                selectedColor: _accent,
                checkmarkColor: Colors.white,
                labelStyle: TextStyle(
                  color: selected ? Colors.white : _navy,
                  fontSize: 13,
                ),
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: selected ? _accent : _gray.withOpacity(0.3),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(
        child: list.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: _gray.withOpacity(0.4),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'ไม่พบผู้ใช้',
                      style: TextStyle(color: _gray, fontSize: 15),
                    ),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchUsers,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _UserCard(user: list[i]),
                ),
              ),
      ),
    ],
  );

  Widget _buildAdminList() {
    final list = _filteredAdmins;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: list.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.admin_panel_settings_outlined,
                    size: 64,
                    color: _gray.withOpacity(0.4),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'ไม่พบแอดมิน',
                    style: TextStyle(color: _gray, fontSize: 15),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchAdmins,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 90),
                itemCount: list.length,
                itemBuilder: (_, i) => _AdminCard(
                  admin: list[i],
                  isSelf: list[i].id == _currentAdminId,
                  onEdit: () => _openEditAdminForm(list[i]),
                  onDelete: () => _confirmDeleteAdmin(list[i]),
                ),
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // Add / Edit Admin
  // ─────────────────────────────────────────────────────────────
  Future<void> _openAddAdminForm() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AdminFormSheet(),
    );
    if (result == true) _fetchAdmins();
  }

  Future<void> _openEditAdminForm(AdminUser admin) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AdminFormSheet(existing: admin),
    );
    if (result == true) _fetchAdmins();
  }

  Future<void> _confirmDeleteAdmin(AdminUser admin) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ยืนยันการลบ'),
        content: Text('ต้องการลบแอดมิน "${admin.fullName}" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบ', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final res = await http.post(
        _adminUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': 'delete_admin',
          'id': admin.id,
          'current_admin_id': _currentAdminId,
        }),
      );
      final json = jsonDecode(res.body);
      if (!mounted) return;
      if (json['result'] == 1) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'ลบสำเร็จ'),
            backgroundColor: _green,
          ),
        );
        _fetchAdmins();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'ลบไม่สำเร็จ'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _logout() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }
}

// ─────────────────────────────────────────────────────────────────
// Admin Add/Edit Form (Bottom Sheet)
// ─────────────────────────────────────────────────────────────────
class _AdminFormSheet extends StatefulWidget {
  final AdminUser? existing;
  const _AdminFormSheet({this.existing});
  @override
  State<_AdminFormSheet> createState() => _AdminFormSheetState();
}

class _AdminFormSheetState extends State<_AdminFormSheet> {
  static const _accent = AppColors.primary;
  static const _navy = AppColors.dark;

  late final TextEditingController fnameCtrl;
  late final TextEditingController lnameCtrl;
  late final TextEditingController emailCtrl;
  late final TextEditingController usernameCtrl;
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  bool _obscurePassword = true;

  String? emailError;
  String? usernameError;

  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    fnameCtrl = TextEditingController(text: a?.firstName ?? '');
    lnameCtrl = TextEditingController(text: a?.lastName ?? '');
    emailCtrl = TextEditingController(
      text: a?.email == '-' ? '' : a?.email ?? '',
    );
    usernameCtrl = TextEditingController(
      text: a?.username == '-' ? '' : a?.username ?? '',
    );
  }

  @override
  void dispose() {
    fnameCtrl.dispose();
    lnameCtrl.dispose();
    emailCtrl.dispose();
    usernameCtrl.dispose();
    passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      emailError = null;
      usernameError = null;
    });

    if (fnameCtrl.text.trim().isEmpty ||
        lnameCtrl.text.trim().isEmpty ||
        usernameCtrl.text.trim().isEmpty ||
        (!isEdit && passwordCtrl.text.isEmpty)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('กรอกข้อมูลให้ครบ')));
      return;
    }

    setState(() => isLoading = true);

    final body = {
      'action': isEdit ? 'update_admin' : 'add_admin',
      'first_name': fnameCtrl.text.trim(),
      'last_name': lnameCtrl.text.trim(),
      'email': emailCtrl.text.trim(),
      'username': usernameCtrl.text.trim(),
      'password': passwordCtrl.text, // edit: เว้นว่างได้ = ไม่เปลี่ยนรหัส
      if (isEdit) 'id': widget.existing!.id,
    };

    try {
      final res = await http.post(
        _adminUri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      final json = jsonDecode(res.body);
      setState(() => isLoading = false);

      if (json['result'] == 1) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(json['message'] ?? 'สำเร็จ'),
            backgroundColor: const Color(0xFF22C55E),
          ),
        );
        Navigator.pop(context, true);
      } else {
        final List<dynamic> dupFields = json['duplicate_fields'] ?? [];
        setState(() {
          if (dupFields.contains('email')) emailError = 'อีเมลนี้ถูกใช้งานแล้ว';
          if (dupFields.contains('username')) {
            usernameError = 'ชื่อผู้ใช้นี้ถูกใช้งานแล้ว';
          }
        });
        if (!mounted) return;
        final msg = (json['message'] ?? 'เกิดข้อผิดพลาด').toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg.startsWith('SQLSTATE')
                  ? 'เกิดข้อผิดพลาดในระบบ กรุณาลองใหม่'
                  : msg,
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('เชื่อมต่อเซิร์ฟเวอร์ไม่สำเร็จ'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool isPassword = false,
    TextInputType keyboardType = TextInputType.text,
    String? errorText,
    VoidCallback? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        obscureText: isPassword ? _obscurePassword : false,
        keyboardType: keyboardType,
        onChanged: (_) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          filled: true,
          fillColor: const Color(0xFFF8FAFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: SingleChildScrollView(
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
              const SizedBox(height: 16),
              Text(
                isEdit ? 'แก้ไขข้อมูลแอดมิน' : 'เพิ่มแอดมินใหม่',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _navy,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _field(fnameCtrl, 'ชื่อ')),
                  const SizedBox(width: 10),
                  Expanded(child: _field(lnameCtrl, 'นามสกุล')),
                ],
              ),
              _field(
                emailCtrl,
                'อีเมล',
                keyboardType: TextInputType.emailAddress,
                errorText: emailError,
                onChanged: () {
                  if (emailError != null) setState(() => emailError = null);
                },
              ),
              _field(
                usernameCtrl,
                'ชื่อผู้ใช้',
                errorText: usernameError,
                onChanged: () {
                  if (usernameError != null)
                    setState(() => usernameError = null);
                },
              ),
              _field(
                passwordCtrl,
                isEdit ? 'รหัสผ่านใหม่ (เว้นว่างถ้าไม่เปลี่ยน)' : 'รหัสผ่าน',
                isPassword: true,
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                  ),
                  child: isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isEdit ? 'บันทึกการแก้ไข' : 'เพิ่มแอดมิน',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// UserCard Widget (student / tutor)
// ─────────────────────────────────────────────────────────────────
class _UserCard extends StatelessWidget {
  final AppUser user;
  const _UserCard({required this.user});
  static const _navy = AppColors.dark;
  static const _green = AppColors.online;
  static const _gray = Color(0xFF94A3B8);
  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FAFF),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showDetail(context),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 26,
                    backgroundColor: user.role == 'student'
                        ? Colors.blueAccent.withOpacity(0.15)
                        : Colors.purpleAccent.withOpacity(0.15),
                    backgroundImage:
                        buildPhotoUrl(kApiBase, user.photoPath) != null
                        ? NetworkImage(buildPhotoUrl(kApiBase, user.photoPath)!)
                        : null,
                    child: buildPhotoUrl(kApiBase, user.photoPath) == null
                        ? Text(
                            user.firstName.isNotEmpty
                                ? user.firstName[0].toUpperCase()
                                : '?',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: user.role == 'student'
                                  ? Colors.blueAccent
                                  : Colors.purpleAccent,
                            ),
                          )
                        : null,
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: user.isOnline ? _green : _gray,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          user.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(width: 6),
                        _RoleBadge(role: user.role),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      style: const TextStyle(fontSize: 13, color: _gray),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.extra,
                      style: const TextStyle(fontSize: 13, color: _gray),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: user.isOnline
                          ? _green.withOpacity(0.12)
                          : _gray.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      user.isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                      style: TextStyle(
                        color: user.isOnline ? _green : _gray,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (user.lastSeen != null && !user.isOnline)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _formatLastSeen(user.lastSeen!),
                        style: const TextStyle(fontSize: 13, color: _gray),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatLastSeen(String raw) {
    try {
      final dt = DateTime.parse(raw).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes} นาทีที่แล้ว';
      if (diff.inHours < 24) return '${diff.inHours} ชม.ที่แล้ว';
      return '${diff.inDays} วันที่แล้ว';
    } catch (_) {
      return '';
    }
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _UserDetailSheet(user: user),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// Admin Card
// ─────────────────────────────────────────────────────────────────
class _AdminCard extends StatelessWidget {
  final AdminUser admin;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AdminCard({
    required this.admin,
    required this.isSelf,
    required this.onEdit,
    required this.onDelete,
  });

  static const _navy = AppColors.dark;
  static const _gray = Color(0xFF94A3B8);
  static const _orange = AppColors.primary;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFFF8FAFF),
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.grey.withOpacity(0.12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: _orange.withOpacity(0.15),
              child: Text(
                admin.firstName.isNotEmpty
                    ? admin.firstName[0].toUpperCase()
                    : '?',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: _orange,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          admin.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: _navy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isSelf) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: _orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'คุณ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '@${admin.username}',
                    style: const TextStyle(fontSize: 13, color: _gray),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    admin.email,
                    style: const TextStyle(fontSize: 13, color: _gray),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: _gray),
              onSelected: (v) {
                if (v == 'edit') onEdit();
                if (v == 'delete') onDelete();
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit_outlined, size: 18),
                      SizedBox(width: 8),
                      Text('แก้ไข'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  enabled: !isSelf,
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: 18,
                        color: isSelf ? _gray : Colors.redAccent,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'ลบ',
                        style: TextStyle(
                          color: isSelf ? _gray : Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────
// User Detail Bottom Sheet (student / tutor)
// ─────────────────────────────────────────────────────────────────
class _UserDetailSheet extends StatelessWidget {
  final AppUser user;
  const _UserDetailSheet({required this.user});
  static const _navy = AppColors.dark;
  static const _green = AppColors.online;
  static const _gray = Color(0xFF94A3B8);
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
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
              CircleAvatar(
                radius: 32,
                backgroundColor: user.role == 'student'
                    ? Colors.blueAccent.withOpacity(0.15)
                    : Colors.purpleAccent.withOpacity(0.15),
                backgroundImage: buildPhotoUrl(kApiBase, user.photoPath) != null
                    ? NetworkImage(buildPhotoUrl(kApiBase, user.photoPath)!)
                    : null,
                child: buildPhotoUrl(kApiBase, user.photoPath) == null
                    ? Text(
                        user.firstName.isNotEmpty
                            ? user.firstName[0].toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: user.role == 'student'
                              ? Colors.blueAccent
                              : Colors.purpleAccent,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _RoleBadge(role: user.role),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: user.isOnline
                              ? _green.withOpacity(0.12)
                              : _gray.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.circle,
                              size: 8,
                              color: user.isOnline ? _green : _gray,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              user.isOnline ? 'ออนไลน์' : 'ออฟไลน์',
                              style: TextStyle(
                                color: user.isOnline ? _green : _gray,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 12),
          _infoRow(Icons.badge_outlined, 'รหัส', user.id),
          _infoRow(Icons.person_outline, 'เพศ', user.genderLabel),
          _infoRow(Icons.cake_outlined, 'อายุ', '${user.age} ปี'),
          _infoRow(Icons.email_outlined, 'อีเมล', user.email),
          _infoRow(Icons.phone_outlined, 'โทรศัพท์', user.phone),
          _infoRow(Icons.school_outlined, 'การศึกษา', user.education),
          _infoRow(
            Icons.work_outline,
            user.role == 'student' ? 'อาชีพ' : 'วิชาที่สอน',
            user.extra,
          ),
          _infoRow(Icons.location_on_outlined, 'ที่อยู่', user.address),
          if (user.lastSeen != null)
            _infoRow(
              Icons.access_time_outlined,
              'เข้าใช้ล่าสุด',
              user.lastSeen!,
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _gray),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: _gray),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _navy,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────
// Role Badge
// ─────────────────────────────────────────────────────────────────
class _RoleBadge extends StatelessWidget {
  final String role;
  const _RoleBadge({required this.role});
  @override
  Widget build(BuildContext context) {
    final isStudent = role == 'student';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: isStudent
            ? Colors.blueAccent.withOpacity(0.12)
            : Colors.purpleAccent.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isStudent ? 'นักเรียน' : 'ติวเตอร์',
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: isStudent ? Colors.blueAccent : Colors.purpleAccent,
        ),
      ),
    );
  }
}
