<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$role = $_POST['role'] ?? null;
$id   = $_POST['id'] ?? null;

$idPatterns = ['student' => '/^ST\d{3,}$/', 'tutor' => '/^TU\d{3,}$/'];

if (!in_array($role, ['student', 'tutor'], true) || !$id || !preg_match($idPatterns[$role], $id)) {
    echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ถูกต้อง"]);
    exit();
}

if (!isset($_FILES['photo']) || $_FILES['photo']['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(["result" => 0, "message" => "ไม่พบไฟล์รูปภาพ"]);
    exit();
}

$file = $_FILES['photo'];

// จำกัดขนาดไฟล์ไม่เกิน 5MB
if ($file['size'] > 5 * 1024 * 1024) {
    echo json_encode(["result" => 0, "message" => "ไฟล์มีขนาดใหญ่เกินไป (สูงสุด 5MB)"]);
    exit();
}

// ตรวจสอบว่าเป็นไฟล์รูปภาพจริง และอนุญาตเฉพาะ jpg/jpeg/png
$imageInfo = @getimagesize($file['tmp_name']);
$allowedMime = ['image/jpeg' => 'jpg', 'image/png' => 'png'];
if (!$imageInfo || !isset($allowedMime[$imageInfo['mime']])) {
    echo json_encode(["result" => 0, "message" => "รองรับเฉพาะไฟล์ JPG หรือ PNG เท่านั้น"]);
    exit();
}
$ext = $allowedMime[$imageInfo['mime']];

try {
    $idColumn = $role === 'student' ? 'student_id' : 'tutor_id';
    $table    = $role === 'student' ? 'student' : 'tutor';

    // ตรวจว่ามีผู้ใช้นี้อยู่จริง
    $stmt = $pdo->prepare("SELECT $idColumn FROM $table WHERE $idColumn = ?");
    $stmt->execute([$id]);
    if (!$stmt->fetch()) {
        echo json_encode(["result" => 0, "message" => "ไม่พบผู้ใช้นี้"]);
        exit();
    }

    $uploadDir = __DIR__ . '/uploads/profile_photos/';
    if (!is_dir($uploadDir)) {
        mkdir($uploadDir, 0755, true);
    }

    $filename = $role . '_' . $id . '_' . time() . '.' . $ext;
    $destPath = $uploadDir . $filename;

    if (!move_uploaded_file($file['tmp_name'], $destPath)) {
        echo json_encode(["result" => 0, "message" => "บันทึกไฟล์ไม่สำเร็จ"]);
        exit();
    }

    $relativePath = 'uploads/profile_photos/' . $filename;

    $stmt = $pdo->prepare("UPDATE $table SET photo_path = ? WHERE $idColumn = ?");
    $stmt->execute([$relativePath, $id]);

    echo json_encode([
        "result"     => 1,
        "message"    => "อัปโหลดรูปโปรไฟล์สำเร็จ",
        "photo_path" => $relativePath,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
