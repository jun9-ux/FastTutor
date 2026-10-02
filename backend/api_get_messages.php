<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?match_id=..&role=..&id=..) และ POST (JSON body)
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $matchId = $_GET['match_id'] ?? null;
    $role    = $_GET['role'] ?? null;
    $id      = $_GET['id'] ?? null;
} else {
    $data    = json_decode(file_get_contents("php://input"), true);
    $matchId = $data['match_id'] ?? null;
    $role    = $data['role'] ?? null;
    $id      = $data['id'] ?? null;
}

if (!$matchId || !in_array($role, ['student', 'tutor'], true) || !$id) {
    echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ครบถ้วน"]);
    exit();
}

try {
    // ตรวจว่า match_id นี้มีอยู่จริง แมตช์สำเร็จแล้ว และผู้เรียกเป็นส่วนหนึ่งของคู่นี้จริง
    $stmt = $pdo->prepare("SELECT * FROM match_table WHERE match_id = ?");
    $stmt->execute([$matchId]);
    $m = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$m || $m['match_status'] !== '1') {
        echo json_encode(["result" => 0, "message" => "ไม่พบห้องแชทนี้"]);
        exit();
    }
    $isParticipant = ($role === 'student' && $m['student_id'] === $id)
        || ($role === 'tutor' && $m['tutor_id'] === $id);
    if (!$isParticipant) {
        echo json_encode(["result" => 0, "message" => "ไม่มีสิทธิ์เข้าถึงห้องแชทนี้"]);
        exit();
    }

    // ชื่อและรูปโปรไฟล์คู่สนทนา (อีกฝ่าย)
    if ($role === 'student') {
        $stmt = $pdo->prepare("SELECT first_name_tutor, last_name_tutor, photo_path FROM tutor WHERE tutor_id = ?");
        $stmt->execute([$m['tutor_id']]);
        $u = $stmt->fetch(PDO::FETCH_ASSOC);
        $partnerName = trim(($u['first_name_tutor'] ?? '') . ' ' . ($u['last_name_tutor'] ?? ''));
    } else {
        $stmt = $pdo->prepare("SELECT first_name_student, last_name_student, photo_path FROM student WHERE student_id = ?");
        $stmt->execute([$m['student_id']]);
        $u = $stmt->fetch(PDO::FETCH_ASSOC);
        $partnerName = trim(($u['first_name_student'] ?? '') . ' ' . ($u['last_name_student'] ?? ''));
    }
    if ($partnerName === '') $partnerName = 'อีกฝ่าย';
    $partnerPhotoUrl = $u['photo_path'] ?? null;

    // ดึงข้อความทั้งหมดของ match นี้ เรียงจากเก่าไปใหม่
    $stmt = $pdo->prepare("
        SELECT * FROM chat
        WHERE match_id = ?
        ORDER BY created_at ASC, chat_id ASC
    ");
    $stmt->execute([$matchId]);
    $messages = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // มาร์คข้อความของอีกฝ่ายว่าอ่านแล้ว
    $stmt = $pdo->prepare("
        UPDATE chat SET is_read = 1
        WHERE match_id = ? AND sender_role != ?
    ");
    $stmt->execute([$matchId, $role]);

    echo json_encode([
        "result"            => 1,
        "match_id"          => $matchId,
        "subject"           => $m['subject'],
        "partner_name"      => $partnerName,
        "partner_photo_url" => $partnerPhotoUrl,
        "messages"          => $messages,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
