<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';
require_once 'matching_score.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);

$action       = $data['action']       ?? null; // "accept" or "reject"
$teach_req_id = $data['teach_req_id'] ?? null;
$learn_reg_id = $data['learn_reg_id'] ?? null;

if (!$action || !$teach_req_id || !$learn_reg_id) {
    echo json_encode(["result" => 0, "message" => "Missing required fields"]);
    exit();
}

// reject ไม่ต้องบันทึก DB
if ($action === 'reject') {
    echo json_encode(["result" => 1, "message" => "Rejected"]);
    exit();
}

try {

    // เช็คว่าเคย match คู่นี้แล้วหรือยัง
    $stmt = $pdo->prepare("
        SELECT match_id FROM match_table
        WHERE teach_req_id = ? AND learn_reg_id = ?
        LIMIT 1
    ");
    $stmt->execute([$teach_req_id, $learn_reg_id]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        echo json_encode([
            "result"   => 2,
            "message"  => "คู่นี้ถูก Match ไปแล้ว",
            "match_id" => $existing['match_id']
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // ดึง tutor_id / student_id / วิชา เก็บเป็น snapshot ไว้ใน match_table
    // ดึงข้อมูลเต็มแถวไว้คำนวณ Compatibility Score ด้วย
    $stmt = $pdo->prepare("SELECT * FROM teach WHERE teach_req_id = ?");
    $stmt->execute([$teach_req_id]);
    $teach = $stmt->fetch(PDO::FETCH_ASSOC);

    $stmt = $pdo->prepare("SELECT * FROM learn WHERE learn_reg_id = ?");
    $stmt->execute([$learn_reg_id]);
    $learn = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$teach || !$learn) {
        echo json_encode(["result" => 0, "message" => "ไม่พบข้อมูลการจับคู่ที่ระบุ"]);
        exit();
    }

    $tutorId        = $teach['tutor_id'];
    $studentId      = $learn['student_id'];
    $subjectMatched = $teach['subject_teach'] ?: $learn['subject_learn'];

    // 🔹 คำนวณ Compatibility Score แล้วบันทึกลง learn.Score_student / teach.Score_tutor
    $scores = calcScore($learn, $teach);
    $matchScore = $scores['final']; // 0-100

    $stmt = $pdo->prepare("UPDATE learn SET Score_student = ? WHERE learn_reg_id = ?");
    $stmt->execute([$matchScore, $learn_reg_id]);

    $stmt = $pdo->prepare("UPDATE teach SET Score_tutor = ? WHERE teach_req_id = ?");
    $stmt->execute([$matchScore, $teach_req_id]);

    // สร้าง match_id แบบ MA001
    $stmt = $pdo->query("SELECT match_id FROM match_table ORDER BY match_id DESC LIMIT 1");
    $last = $stmt->fetch(PDO::FETCH_ASSOC);
    $num  = $last ? (int)substr($last['match_id'], 2) + 1 : 1;
    $newId = "MA" . str_pad($num, 3, "0", STR_PAD_LEFT);

    // INSERT ลง match_table
    // match_status = 2 = รอแมต์ (รอนัดหมาย)
    $stmt = $pdo->prepare("
        INSERT INTO match_table (
            match_id,
            start_time,
            end_time,
            study_date,
            match_date,
            match_status,
            teach_req_id,
            learn_reg_id,
            student_id,
            tutor_id,
            subject
        ) VALUES (?, NULL, NULL, NULL, CURDATE(), 2, ?, ?, ?, ?, ?)
    ");
    $stmt->execute([$newId, $teach_req_id, $learn_reg_id, $studentId, $tutorId, $subjectMatched]);

    echo json_encode([
        "result"   => 1,
        "message"  => "Match สำเร็จ! รอการนัดหมาย",
        "match_id" => $newId,
        "score"    => $matchScore
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
?>
