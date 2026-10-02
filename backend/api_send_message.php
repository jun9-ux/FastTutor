<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data       = json_decode(file_get_contents("php://input"), true);
$matchId    = $data['match_id'] ?? null;
$senderRole = $data['sender_role'] ?? null; // 'student' หรือ 'tutor'
$message    = trim($data['message'] ?? '');

if (!$matchId || !in_array($senderRole, ['student', 'tutor'], true) || $message === '') {
    echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ครบถ้วน"]);
    exit();
}

try {
    // ตรวจสอบว่า match นี้แมตช์สำเร็จแล้วจริง ('1' = ยืนยันแล้ว) ก่อนอนุญาตให้แชท
    $stmt = $pdo->prepare("SELECT * FROM match_table WHERE match_id = ?");
    $stmt->execute([$matchId]);
    $m = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$m) {
        echo json_encode(["result" => 0, "message" => "ไม่พบการจับคู่นี้"]);
        exit();
    }
    if ($m['match_status'] !== '1') {
        echo json_encode(["result" => 0, "message" => "แชทได้เฉพาะคู่ที่แมตช์สำเร็จแล้วเท่านั้น"]);
        exit();
    }

    // สร้าง chat_id รูปแบบ CH### ต่อจากตัวล่าสุด
    $stmt = $pdo->query("
        SELECT chat_id FROM chat
        ORDER BY CAST(SUBSTRING(chat_id, 3) AS UNSIGNED) DESC
        LIMIT 1
    ");
    $last = $stmt->fetchColumn();
    $num = $last ? ((int)substr($last, 2)) + 1 : 1;
    $chatId = 'CH' . str_pad((string)$num, 3, '0', STR_PAD_LEFT);

    $stmt = $pdo->prepare("
        INSERT INTO chat
            (chat_id, match_id, sender_role, chat_message, student_id, tutor_id, is_read, created_at)
        VALUES (?, ?, ?, ?, ?, ?, 0, NOW())
    ");
    $stmt->execute([$chatId, $matchId, $senderRole, $message, $m['student_id'], $m['tutor_id']]);

    echo json_encode([
        "result"   => 1,
        "message"  => "ส่งข้อความสำเร็จ",
        "chat_id"  => $chatId,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
