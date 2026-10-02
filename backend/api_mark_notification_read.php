<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data           = json_decode(file_get_contents("php://input"), true);
$notificationId = $data['notification_id'] ?? null; // ถ้าไม่ระบุ = mark ทั้งหมด
$role           = $data['role'] ?? null;
$id             = $data['id']   ?? null;

if (!$role || !$id) {
    echo json_encode(["result" => 0, "message" => "Missing role or id"]);
    exit();
}

try {
    if ($notificationId) {
        $stmt = $pdo->prepare("
            UPDATE notifications SET is_read = 1
            WHERE notification_id = ? AND recipient_role = ? AND recipient_id = ?
        ");
        $stmt->execute([$notificationId, $role, $id]);
    } else {
        $stmt = $pdo->prepare("
            UPDATE notifications SET is_read = 1
            WHERE recipient_role = ? AND recipient_id = ? AND is_read = 0
        ");
        $stmt->execute([$role, $id]);
    }

    echo json_encode(["result" => 1, "message" => "อัปเดตแล้ว"]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
