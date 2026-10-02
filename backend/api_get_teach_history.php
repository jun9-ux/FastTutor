<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?tutor_id=xxx) และ POST (json body {"tutor_id":"xxx"})
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $tutorId = $_GET['tutor_id'] ?? null;
} else {
    $data = json_decode(file_get_contents("php://input"), true);
    $tutorId = $data['tutor_id'] ?? null;
}

if (!$tutorId) {
    echo json_encode(["result" => 0, "message" => "Missing tutor_id"]);
    exit();
}

try {
    $stmt = $pdo->prepare("
        SELECT * FROM teach
        WHERE tutor_id = ? AND teach_status = 'matched'
        ORDER BY teach_req_id DESC
    ");
    $stmt->execute([$tutorId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    echo json_encode([
        "result"   => 1,
        "message"  => "OK",
        "datalist" => $rows,
    ], JSON_UNESCAPED_UNICODE);
} catch (PDOException $e) {
    echo json_encode([
        "result"  => 0,
        "message" => $e->getMessage(),
    ]);
}
?>
