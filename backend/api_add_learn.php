<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result"=>0,"message"=>"Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);
$studentId = $data['student_id'] ?? null;

if (!$studentId) {
    echo json_encode(["result"=>0,"message"=>"Missing student_id"]);
    exit();
}

try {

    // ============================
    // 🔹 ค่าฟิลด์ที่จะบันทึก (ใช้ร่วมกันทั้ง insert/update)
    // ============================
    $fieldValues = [
        $data['subject_learn'] ?? null,
        $data['content_level'] ?? null,
        $data['objective_learn'] ?? null,
        $data['preferred_time_learn'] ?? null,
        $data['duration_learn'] ?? null,
        $data['learning_format_learn'] ?? null,
        $data['teachable_distance_learn'] ?? null,
        $data['budget_per_hour'] ?? null,
        $data['required_experience_learn'] ?? null,
        $data['preferred_teaching_method_learn'] ?? null,
        $data['tutor_knowledge_level_learn'] ?? null,
        $data['group_size_learn'] ?? null,
        $data['teaching_style_learn'] ?? null,
        $data['teaching_method_learn'] ?? null,
        $data['teaching_language_learn'] ?? null,
        $data['preferred_gender_learn'] ?? null,
    ];

    // ============================
    // 🔹 เช็คว่านักเรียนคนนี้มีความต้องการเรียนที่ยัง active อยู่หรือไม่
    //    (นักเรียน 1 คน มีความต้องการเรียนที่ active ได้แค่ 1 รายการ
    //    แถวที่ matched แล้วจะไม่ถูกนับ/ทับ เพื่อให้ยังเป็นประวัติอยู่ได้)
    // ============================
    $stmt = $pdo->prepare("SELECT learn_reg_id FROM learn WHERE student_id = ? AND learn_status = 'active' LIMIT 1");
    $stmt->execute([$studentId]);
    $existing = $stmt->fetch(PDO::FETCH_ASSOC);

    if ($existing) {
        // ============================
        // 🔹 มีอยู่แล้ว -> UPDATE ทับของเดิม และรีเซ็ตคะแนนกลับ 0
        //    เพื่อรอเข้าสู่กระบวนการจับคู่ใหม่อีกครั้ง
        // ============================
        $newId = $existing['learn_reg_id'];

        $stmt = $pdo->prepare("
            UPDATE learn SET
                subject_learn = ?,
                content_level = ?,
                objective_learn = ?,
                preferred_time_learn = ?,
                duration_learn = ?,
                learning_format_learn = ?,
                teachable_distance_learn = ?,
                budget_per_hour = ?,
                required_experience_learn = ?,
                preferred_teaching_method_learn = ?,
                tutor_knowledge_level_learn = ?,
                group_size_learn = ?,
                teaching_style_learn = ?,
                teaching_method_learn = ?,
                teaching_language_learn = ?,
                preferred_gender_learn = ?,
                Score_student = 0
            WHERE learn_reg_id = ?
        ");
        $stmt->execute([...$fieldValues, $newId]);

        $message = "อัพเดตความต้องการเรียนเรียบร้อยแล้ว";

    } else {
        // ============================
        // 🔹 ยังไม่เคยมี -> สร้าง learn_reg_id ใหม่ และ INSERT
        // ============================
        $stmt = $pdo->query("SELECT learn_reg_id FROM learn ORDER BY CAST(SUBSTRING(learn_reg_id, 3) AS UNSIGNED) DESC LIMIT 1");
        $last = $stmt->fetch(PDO::FETCH_ASSOC);

        $num = $last ? ((int)substr($last['learn_reg_id'], 2)) + 1 : 1;
        $newId = "LR" . str_pad($num, 3, "0", STR_PAD_LEFT);

        $stmt = $pdo->prepare("
            INSERT INTO learn (
                learn_reg_id,
                subject_learn,
                content_level,
                objective_learn,
                preferred_time_learn,
                duration_learn,
                learning_format_learn,
                teachable_distance_learn,
                budget_per_hour,
                required_experience_learn,
                preferred_teaching_method_learn,
                tutor_knowledge_level_learn,
                group_size_learn,
                teaching_style_learn,
                teaching_method_learn,
                teaching_language_learn,
                preferred_gender_learn,
                student_id,
                Score_student
            )
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        ");
        $stmt->execute([$newId, ...$fieldValues, $studentId, 0]);

        $message = "Learn added successfully";
    }

    echo json_encode([
        "result"       => 1,
        "message"      => $message,
        "learn_reg_id" => $newId,
    ], JSON_UNESCAPED_UNICODE);

} catch(PDOException $e){
    echo json_encode([
        "result"=>0,
        "message"=>$e->getMessage()
    ]);
}
?>
