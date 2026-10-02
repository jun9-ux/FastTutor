/// สร้าง URL เต็มของรูปโปรไฟล์จาก path สัมพัทธ์ที่ backend คืนมา (เช่น "uploads/profile_photos/xxx.jpg")
/// คืนค่า null ถ้าไม่มีรูป
String? buildPhotoUrl(String apiBase, dynamic photoPath) {
  final p = photoPath?.toString();
  if (p == null || p.isEmpty) return null;
  return '$apiBase/$p';
}
