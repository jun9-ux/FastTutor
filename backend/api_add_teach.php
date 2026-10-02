<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result"=>0,"message"=>"Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);
$tutorId = $data['tutor_id'] ?? null;

if (!$tutorId) {
    echo json_encode(["result"=>0,"message"=>"Missing tutor_id"]);
    exit();
}

try {

    // ============================
    // 🔹 ค่าฟิลด์ที่จะบันทึก (ใช้ร่วมกันทั้ง insert/update)
    // ============================
    $fieldValues = [
        $data['subject_teach'] ?? null,
        $data['teach_level'] ?? null,
        $data['objective_teach'] ?? null,
        $data['preferred_time_teach'] ?? null,
        $data['duration_teach'] ?? null,
        $data['learning_format_teach'] ?? null,
        $data['teachable_distance_teach'] ?? null,
        $data['teaching_rate_per_hour'] ?? null,
        $data['required_experience_teach'] ?? null,
        $data['preferred_teaching_method_teach'] ?? null,
        $data['tutor_knowledge_level_teach'] ?? null,
        $data['group_size_teach'] ?? null,
        $data['teaching_style_teach'] ?? null,
        $data['teaching_method_teach'] ?? null,
        $data['teaching_language_teach'] ?? null,
        $data['preferred_gender_teach'] ?? null,
    ];

    // ============================
    // 🔹 เช็คว่าติวเตอร์คนนี้มีความต้องการสอนที่ยัง active อยู่หรือไม่
    //    (ติวเตอร์ 1 คน มีความต้องการสอนที่ active ได้แค่ 1 รายการ
    //    แถวที่ matched แล้วจะไม่ถูกนับ/ทับ เพื่อให้ยังเป็นประวัติอยู่ได้)
    // ============================
    $stmt = $pdo->prepare("SELECT teach_req_id FROM teach WHERE tutor_id = ? AND teach_status = 'active' LIMIT 1");
    $stmt->execute([$tutorId]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        // ============================
        // 🔹 มีอยู่แล้ว -> UPDATE ทับของเดิม และรีเซ็ตคะแนนกลับ 0
        //    เพื่อรอเข้าสู่กระบวนการจับคู่ใหม่อีกครั้ง
        // ============================
        $newId = $existing['teach_req_id'];

        $stmt = $pdo->prepare("
            UPDATE teach SET
                subject_teach = ?,
                teach_level = ?,
                objective_teach = ?,
                preferred_time_teach = ?,
                duration_teach = ?,
                learning_format_teach = ?,
                teachable_distance_teach = ?,
                teaching_rate_per_hour = ?,
                required_experience_teach = ?,
                preferred_teaching_method_teach = ?,
                tutor_knowledge_level_teach = ?,
                group_size_teach = ?,
                teaching_style_teach = ?,
                teaching_method_teach = ?,
                teaching_language_teach = ?,
                preferred_gender_teach = ?,
                Score_tutor = 0
            WHERE teach_req_id = ?
        ");
        $stmt->execute([...$fieldValues, $newId]);

        $message = "อัพเดตความต้องการสอนเรียบร้อยแล้ว";

    } else {
        // ============================
        // 🔹 ยังไม่เคยมี -> สร้าง teach_req_id ใหม่ และ INSERT
        // ============================
        $stmt = $pdo->query("SELECT teach_req_id FROM teach ORDER BY CAST(SUBSTRING(teach_req_id, 3) AS UNSIGNED) DESC LIMIT 1");
        $last = $stmt->fetch(PDO::FETCH_ASSOC);

        $num = $last ? ((int)substr($last['teach_req_id'], 2)) + 1 : 1;
        $newId = "TR" . str_pad($num, 3, "0", STR_PAD_LEFT);

        $stmt = $pdo->prepare("
            INSERT INTO teach (
                teach_req_id,
                subject_teach,
                teach_level,
                objective_teach,
                preferred_time_teach,
                duration_teach,
                learning_format_teach,
                teachable_distance_teach,
                teaching_rate_per_hour,
                required_experience_teach,
                preferred_teaching_method_teach,
                tutor_knowledge_level_teach,
                group_size_teach,
                teaching_style_teach,
                teaching_method_teach,
                teaching_language_teach,
                preferred_gender_teach,
                tutor_id,
                Score_tutor
            )
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ");
        $stmt->execute([$newId, ...$fieldValues, $tutorId, 0]);

        $message = "Teach added successfully";
    }

    echo json_encode([
        "result"       => 1,
        "message"      => $message,
        "teach_req_id" => $newId,
    ], JSON_UNESCAPED_UNICODE);

} catch(PDOException $e){
    echo json_encode([
        "result"=>0,
        "message"=>$e->getMessage()
    ]);
}
?>
