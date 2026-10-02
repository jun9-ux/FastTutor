<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';
require_once 'matching_score.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data    = json_decode(file_get_contents("php://input"), true);
$matchId = $data['match_id'] ?? null;
$action  = $data['action'] ?? null; // 'accept' หรือ 'reject'

if (!$matchId || !in_array($action, ['accept', 'reject'], true)) {
    echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ถูกต้อง"]);
    exit();
}

try {
    $stmt = $pdo->prepare("SELECT * FROM match_table WHERE match_id = ?");
    $stmt->execute([$matchId]);
    $m = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$m) {
        echo json_encode(["result" => 0, "message" => "ไม่พบคำขอนี้"]);
        exit();
    }
    if ($m['match_status'] !== '0') {
        echo json_encode(["result" => 0, "message" => "คำขอนี้ถูกดำเนินการไปแล้ว"]);
        exit();
    }

    $pdo->beginTransaction();

    $newStatus = $action === 'accept' ? '1' : '2';

    // 🔹 คำนวณ Compatibility Score ตอนแมตช์สำเร็จ (accept)
    // เก็บผลไว้ที่ match_table.match_score เพราะ Score_student / Score_tutor
    // บนตาราง learn/teach จะถูกรีเซ็ตเป็น 0 ทุกครั้งที่ผู้ใช้ส่งความต้องการใหม่
    // จึงใช้เก็บคะแนนของ "แมตช์ที่ยืนยันแล้ว" แบบถาวรไม่ได้
    $matchScore = null;
    if ($action === 'accept' && $m['teach_req_id'] && $m['learn_reg_id']) {
        $stmt = $pdo->prepare("SELECT * FROM teach WHERE teach_req_id = ?");
        $stmt->execute([$m['teach_req_id']]);
        $teachRow = $stmt->fetch(PDO::FETCH_ASSOC);

        $stmt = $pdo->prepare("SELECT * FROM learn WHERE learn_reg_id = ?");
        $stmt->execute([$m['learn_reg_id']]);
        $learnRow = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($teachRow && $learnRow) {
            $scores     = calcScore($learnRow, $teachRow);
            $matchScore = $scores['final']; // 0-100
        }
    }

    if ($action === 'accept') {
        // แมตช์สำเร็จ -> เติมค่าเริ่มต้นให้ end_time / study_date ด้วยเลย
        // (ถ้ามีค่าอยู่แล้วจะไม่ทับ เพราะใช้ COALESCE) และบันทึกคะแนนที่คำนวณได้
        $stmt = $pdo->prepare("
            UPDATE match_table
            SET match_status = ?,
                match_score  = ?,
                end_time     = COALESCE(end_time, CURTIME()),
                study_date   = COALESCE(study_date, CURDATE())
            WHERE match_id = ?
        ");
        $stmt->execute([$newStatus, $matchScore, $matchId]);
    } else {
        $stmt = $pdo->prepare("
            UPDATE match_table SET match_status = ?
            WHERE match_id = ?
        ");
        $stmt->execute([$newStatus, $matchId]);
    }

    // student_id / tutor_id ของคู่นี้ (บันทึกไว้ตั้งแต่ตอนส่งคำขอใน match_table แล้ว
    // จึงไม่ต้องพึ่ง teach/learn ซึ่งกำลังจะถูกลบทิ้งด้านล่างนี้)
    $tutorId   = $m['tutor_id'];
    $studentId = $m['student_id'];

    if ($action === 'accept') {
        // ============================
        // 🔹 แมตช์สำเร็จแล้ว: ปฏิเสธคำขอ pending อื่น ๆ ที่ยังค้างอยู่
        //    ของ requirement เดียวกัน (ทั้งฝั่ง teach และ learn)
        //    เพราะ requirement นี้กำลังจะถูกลบทิ้งไปเลย
        // ============================
        $stmt = $pdo->prepare("
            UPDATE match_table
            SET match_status = '2'
            WHERE match_id != ?
              AND match_status = '0'
              AND (teach_req_id = ? OR learn_reg_id = ?)
        ");
        $stmt->execute([$matchId, $m['teach_req_id'], $m['learn_reg_id']]);

        // ============================
        // 🔹 เปลี่ยนสถานะความต้องการเดิม (teach/learn) เป็น 'matched'
        //    แทนการลบทิ้ง เพื่อให้ยังคงอยู่เป็นประวัติ (ดูหน้าประวัติ)
        //    match_table.teach_req_id / learn_reg_id จะยังคงอ้างอิงแถวนี้ต่อไป
        // ============================
        $stmt = $pdo->prepare("UPDATE teach SET teach_status = 'matched' WHERE teach_req_id = ?");
        $stmt->execute([$m['teach_req_id']]);

        $stmt = $pdo->prepare("UPDATE learn SET learn_status = 'matched' WHERE learn_reg_id = ?");
        $stmt->execute([$m['learn_reg_id']]);
    }

    // ผู้ที่ต้องได้รับแจ้งเตือนผลลัพธ์ คือ "ผู้ส่งคำขอเดิม" (initiated_by)
    // หมายเหตุ: ข้อมูลเก่าบางแถวมี initiated_by = 'system' ซึ่งไม่ใช่ผู้ใช้จริง จึงไม่ต้องแจ้งเตือน
    $notifyRole = in_array($m['initiated_by'], ['student', 'tutor'], true) ? $m['initiated_by'] : null;

    if ($notifyRole) {
        $notifyId         = $notifyRole === 'student' ? $studentId : $tutorId;
        $responderIsTutor = $notifyRole === 'student'; // ผู้ตอบคือฝั่งตรงข้ามกับผู้ส่งคำขอเดิม

        if ($responderIsTutor) {
            $stmt = $pdo->prepare("SELECT first_name_tutor, last_name_tutor FROM tutor WHERE tutor_id = ?");
            $stmt->execute([$tutorId]);
            $u = $stmt->fetch(PDO::FETCH_ASSOC);
            $responderName = trim(($u['first_name_tutor'] ?? '') . ' ' . ($u['last_name_tutor'] ?? ''));
        } else {
            $stmt = $pdo->prepare("SELECT first_name_student, last_name_student FROM student WHERE student_id = ?");
            $stmt->execute([$studentId]);
            $u = $stmt->fetch(PDO::FETCH_ASSOC);
            $responderName = trim(($u['first_name_student'] ?? '') . ' ' . ($u['last_name_student'] ?? ''));
        }
        if ($responderName === '') $responderName = 'อีกฝ่าย';

        $notifType = $action === 'accept' ? 'request_accepted' : 'request_rejected';
        $title     = $action === 'accept' ? 'คำขอของคุณได้รับการยืนยัน' : 'คำขอของคุณถูกปฏิเสธ';
        $message   = $action === 'accept'
            ? "$responderName ยืนยันการจับคู่กับคุณแล้ว ยินดีด้วย!"
            : "$responderName ปฏิเสธคำขอจับคู่ของคุณ";

        $stmt = $pdo->prepare("
            INSERT INTO notifications
                (recipient_role, recipient_id, type, match_id, title, message, is_read, created_at)
            VALUES (?, ?, ?, ?, ?, ?, 0, NOW())
        ");
        $stmt->execute([$notifyRole, $notifyId, $notifType, $matchId, $title, $message]);
    }

    $pdo->commit();

    echo json_encode([
        "result"   => 1,
        "message"  => $action === 'accept' ? 'ยืนยันการจับคู่สำเร็จ' : 'ปฏิเสธคำขอเรียบร้อย',
        "match_id" => $matchId,
    ], JSON_UNESCAPED_UNICODE);

} catch (PDOException $e) {
    if ($pdo->inTransaction()) $pdo->rollBack();
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
