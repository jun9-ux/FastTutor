<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);

$senderRole = $data['sender_role'] ?? null; // "student" หรือ "tutor" — ฝั่งที่กดส่งคำขอ
$teachReqId = $data['teach_req_id'] ?? null;
$learnRegId = $data['learn_reg_id'] ?? null;

if (!in_array($senderRole, ['student', 'tutor'], true) || !$teachReqId || !$learnRegId) {
    echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ครบถ้วน"]);
    exit();
}

// สร้าง match_id รูปแบบ MA### ต่อจากตัวล่าสุดในตาราง (เช่น MA006 -> MA007)
function generateMatchId(PDO $pdo): string {
    $stmt = $pdo->query("
        SELECT match_id FROM match_table
        ORDER BY CAST(SUBSTRING(match_id, 3) AS UNSIGNED) DESC
        LIMIT 1
    ");
    $last = $stmt->fetchColumn();
    $num = $last ? ((int)substr($last, 2)) + 1 : 1;
    return 'MA' . str_pad((string)$num, 3, '0', STR_PAD_LEFT);
}

try {
    // ตรวจสอบว่า teach/learn มีอยู่จริง และดึง tutor_id / student_id / วิชา ที่แท้จริง
    $stmt = $pdo->prepare("SELECT tutor_id, subject_teach FROM teach WHERE teach_req_id = ?");
    $stmt->execute([$teachReqId]);
    $teach = $stmt->fetch(PDO::FETCH_ASSOC);

    $stmt = $pdo->prepare("SELECT student_id, subject_learn FROM learn WHERE learn_reg_id = ?");
    $stmt->execute([$learnRegId]);
    $learn = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$teach || !$learn) {
        echo json_encode(["result" => 0, "message" => "ไม่พบข้อมูลการจับคู่ที่ระบุ"]);
        exit();
    }

    $tutorId   = $teach['tutor_id'];
    $studentId = $learn['student_id'];
    // เก็บชื่อวิชาไว้ล่วงหน้า (snapshot) เผื่อ requirement เดิมถูกลบทิ้งหลังแมตช์สำเร็จ
    $subjectMatched = $teach['subject_teach'] ?: $learn['subject_learn'];

    // ป้องกันการส่งคำขอซ้ำ ถ้ามี record pending('0') หรือ accepted('1') อยู่แล้วสำหรับคู่นี้
    $stmt = $pdo->prepare("
        SELECT match_id, match_status FROM match_table
        WHERE teach_req_id = ? AND learn_reg_id = ?
        ORDER BY CAST(SUBSTRING(match_id, 3) AS UNSIGNED) DESC
        LIMIT 1
    ");
    $stmt->execute([$teachReqId, $learnRegId]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing && $existing['match_status'] === '0') {
        echo json_encode([
            "result"   => 2,
            "message"  => "มีคำขอที่ส่งไปแล้ว กำลังรอการยืนยัน",
            "match_id" => $existing['match_id'],
        ]);
        exit();
    }
    if ($existing && $existing['match_status'] === '1') {
        echo json_encode([
            "result"   => 2,
            "message"  => "จับคู่กันแล้ว",
            "match_id" => $existing['match_id'],
        ]);
        exit();
    }

    // หาชื่อผู้ส่งคำขอ เพื่อใช้ในข้อความแจ้งเตือน
    if ($senderRole === 'student') {
        $stmt = $pdo->prepare("SELECT first_name_student, last_name_student FROM student WHERE student_id = ?");
        $stmt->execute([$studentId]);
        $u = $stmt->fetch(PDO::FETCH_ASSOC);
        $senderName = trim(($u['first_name_student'] ?? '') . ' ' . ($u['last_name_student'] ?? ''));
    } else {
        $stmt = $pdo->prepare("SELECT first_name_tutor, last_name_tutor FROM tutor WHERE tutor_id = ?");
        $stmt->execute([$tutorId]);
        $u = $stmt->fetch(PDO::FETCH_ASSOC);
        $senderName = trim(($u['first_name_tutor'] ?? '') . ' ' . ($u['last_name_tutor'] ?? ''));
    }
    if ($senderName === '') $senderName = 'ผู้ใช้งาน';

    $recipientRole = $senderRole === 'student' ? 'tutor' : 'student';
    $recipientId   = $senderRole === 'student' ? $tutorId : $studentId;

    // สร้าง record คำขอ + แจ้งเตือน โดย retry สูงสุด 3 ครั้งหาก match_id ชนกัน (race condition)
    $attempts = 0;
    $matchId  = null;
    $lastError = null;

    while ($attempts < 3) {
        $attempts++;
        $matchId = generateMatchId($pdo);
        try {
            $pdo->beginTransaction();

            $stmt = $pdo->prepare("
                INSERT INTO match_table
                    (match_id, match_date, match_status, initiated_by, teach_req_id, learn_reg_id, student_id, tutor_id, subject)
                VALUES (?, CURDATE(), '0', ?, ?, ?, ?, ?, ?)
            ");
            $stmt->execute([$matchId, $senderRole, $teachReqId, $learnRegId, $studentId, $tutorId, $subjectMatched]);

            $stmt = $pdo->prepare("
                INSERT INTO notifications
                    (recipient_role, recipient_id, type, match_id, title, message, is_read, created_at)
                VALUES (?, ?, 'request_received', ?, ?, ?, 0, NOW())
            ");
            $stmt->execute([
                $recipientRole,
                $recipientId,
                $matchId,
                'มีคำขอจับคู่ใหม่',
                "$senderName ต้องการจับคู่กับคุณ กรุณายืนยันหรือปฏิเสธคำขอ",
            ]);

            $pdo->commit();
            $lastError = null;
            break;
        } catch (PDOException $e) {
            if ($pdo->inTransaction()) $pdo->rollBack();
            $lastError = $e;
            // รหัสข้อผิดพลาด duplicate key -> สร้าง match_id ใหม่แล้วลองอีกครั้ง
            if ((string)$e->getCode() === '23000' && $attempts < 3) {
                continue;
            }
            break;
        }
    }

    if ($lastError !== null) {
        throw $lastError;
    }

    echo json_encode([
        "result"   => 1,
        "message"  => "ส่งคำขอเรียบร้อย กรุณารอการยืนยันจากอีกฝ่าย",
        "match_id" => $matchId,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
