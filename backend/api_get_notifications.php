<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?role=..&id=..) และ POST (JSON body)
$role = $_GET['role'] ?? null;
$id   = $_GET['id']   ?? null;

if (!$role || !$id) {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $role ?? ($data['role'] ?? null);
    $id   = $id   ?? ($data['id']   ?? null);
}

if (!$role || !$id) {
    echo json_encode(["result" => 0, "message" => "Missing role or id"]);
    exit();
}

try {
    $stmt = $pdo->prepare("
        SELECT
            n.notification_id,
            n.type,
            n.match_id,
            n.title,
            n.message,
            n.is_read,
            n.created_at,
            mt.teach_req_id,
            mt.learn_reg_id,
            mt.student_id,
            mt.tutor_id,
            mt.subject,
            mt.match_status,
            mt.initiated_by
        FROM notifications n
        LEFT JOIN match_table mt ON n.match_id = mt.match_id
        WHERE n.recipient_role = ? AND n.recipient_id = ?
        ORDER BY n.created_at DESC
        LIMIT 50
    ");
    $stmt->execute([$role, $id]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // แปลงรหัสสถานะ ('0'/'1'/'2') ให้เป็นข้อความที่ frontend ใช้ได้ทันที
    $statusMap = ['0' => 'pending', '1' => 'accepted', '2' => 'rejected'];
    foreach ($rows as &$r) {
        $r['request_status'] = $statusMap[$r['match_status']] ?? null;
    }
    unset($r);

    $stmt2 = $pdo->prepare("
        SELECT COUNT(*) AS cnt FROM notifications
        WHERE recipient_role = ? AND recipient_id = ? AND is_read = 0
    ");
    $stmt2->execute([$role, $id]);
    $unread = (int)($stmt2->fetch(PDO::FETCH_ASSOC)['cnt'] ?? 0);

    echo json_encode([
        "result"        => 1,
        "unread"        => $unread,
        "notifications" => $rows,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
