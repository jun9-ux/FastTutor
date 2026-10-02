<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

// รองรับทั้ง GET (?student_id=xxx) และ POST (json body {"student_id":"xxx"})
if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    $studentId = $_GET['student_id'] ?? null;
} else {
    $data = json_decode(file_get_contents("php://input"), true);
    $studentId = $data['student_id'] ?? null;
}

if (!$studentId) {
    echo json_encode(["result" => 0, "message" => "Missing student_id"]);
    exit();
}

try {
    $stmt = $pdo->prepare("
        SELECT * FROM learn
        WHERE student_id = ? AND learn_status = 'matched'
        ORDER BY learn_reg_id DESC
    ");
    $stmt->execute([$studentId]);
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
