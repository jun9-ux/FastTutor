<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?role=student&id=xxx) และ POST (json body)
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $role = $_GET['role'] ?? null;
    $id   = $_GET['id']   ?? null;
} else {
    $data = json_decode(file_get_contents("php://input"), true);
    $role = $data['role'] ?? null;
    $id   = $data['id']   ?? null;
}

if (!$role || !$id || !in_array($role, ['student', 'tutor'], true)) {
    echo json_encode(["result" => 0, "message" => "Missing or invalid role/id"]);
    exit();
}

try {
    // ดึงแมตช์ล่าสุดที่ "ยืนยันแล้ว" (match_status = '1') ของผู้ใช้คนนี้
    if ($role === 'student') {
        $stmt = $pdo->prepare("
            SELECT mt.*, tu.first_name_tutor, tu.last_name_tutor
            FROM match_table mt
            LEFT JOIN tutor tu ON mt.tutor_id = tu.tutor_id
            WHERE mt.student_id = ? AND mt.match_status = '1'
            ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC
            LIMIT 1
        ");
        $stmt->execute([$id]);
    } else {
        $stmt = $pdo->prepare("
            SELECT mt.*, st.first_name_student, st.last_name_student
            FROM match_table mt
            LEFT JOIN student st ON mt.student_id = st.student_id
            WHERE mt.tutor_id = ? AND mt.match_status = '1'
            ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC
            LIMIT 1
        ");
        $stmt->execute([$id]);
    }

    $match = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$match) {
        echo json_encode([
            "result"  => 1,
            "has_match" => false,
            "message" => "ยังไม่มีการจับคู่ที่ยืนยันแล้ว",
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    $partnerName = $role === 'student'
        ? trim(($match['first_name_tutor'] ?? '') . ' ' . ($match['last_name_tutor'] ?? ''))
        : trim(($match['first_name_student'] ?? '') . ' ' . ($match['last_name_student'] ?? ''));

    echo json_encode([
        "result"      => 1,
        "has_match"   => true,
        "match_id"    => $match['match_id'],
        "subject"     => $match['subject'],
        "score"       => $match['match_score'] !== null ? (float)$match['match_score'] : null,
        "partner_name" => $partnerName !== '' ? $partnerName : '-',
        "study_date"  => $match['study_date'],
        "end_time"    => $match['end_time'],
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
?>
