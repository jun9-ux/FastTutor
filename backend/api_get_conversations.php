<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?role=..&id=..) และ POST (JSON body)
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $role = $_GET['role'] ?? null;
    $id   = $_GET['id'] ?? null;
} else {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? null;
    $id   = $data['id'] ?? null;
}

if (!in_array($role, ['student', 'tutor'], true) || !$id) {
    echo json_encode(["result" => 0, "message" => "Missing role or id"]);
    exit();
}

try {
    $idColumn = $role === 'student' ? 'student_id' : 'tutor_id';

    if ($role === 'student') {
        $nameExpr   = "TRIM(CONCAT(tu.first_name_tutor, ' ', tu.last_name_tutor))";
        $photoExpr  = "tu.photo_path";
        $onlineExpr = "tu.is_online";
        $joinSql    = "LEFT JOIN tutor tu ON mt.tutor_id = tu.tutor_id";
    } else {
        $nameExpr   = "TRIM(CONCAT(st.first_name_student, ' ', st.last_name_student))";
        $photoExpr  = "st.photo_path";
        $onlineExpr = "st.is_online";
        $joinSql    = "LEFT JOIN student st ON mt.student_id = st.student_id";
    }

    $stmt = $pdo->prepare("
        SELECT
            mt.match_id,
            mt.subject,
            mt.student_id,
            mt.tutor_id,
            $nameExpr AS partner_name,
            $photoExpr AS partner_photo_url,
            $onlineExpr AS partner_is_online,
            (
                SELECT c.chat_message FROM chat c
                WHERE c.match_id = mt.match_id
                ORDER BY c.created_at DESC, c.chat_id DESC LIMIT 1
            ) AS last_message,
            (
                SELECT c.created_at FROM chat c
                WHERE c.match_id = mt.match_id
                ORDER BY c.created_at DESC, c.chat_id DESC LIMIT 1
            ) AS last_message_at,
            (
                SELECT COUNT(*) FROM chat c
                WHERE c.match_id = mt.match_id AND c.sender_role != ? AND c.is_read = 0
            ) AS unread_count
        FROM match_table mt
        $joinSql
        WHERE mt.match_status = '1' AND mt.$idColumn = ?
        ORDER BY last_message_at IS NULL, last_message_at DESC, mt.match_date DESC
    ");
    $stmt->execute([$role, $id]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    foreach ($rows as &$r) {
        $r['unread_count'] = (int)$r['unread_count'];
        $r['partner_is_online'] = (bool)$r['partner_is_online'];
        if (!$r['partner_name']) $r['partner_name'] = 'อีกฝ่าย';
    }
    unset($r);

    echo json_encode([
        "result"        => 1,
        "conversations" => $rows,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
