<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);
$role = $data['role'] ?? null;

if (!$role) {
    echo json_encode(["result" => 0, "message" => "Missing role"]);
    exit();
}


require_once 'age_helper.php';
// วันเกิด (YYYY-MM-DD): ถ้าส่งมาต้องถูกต้อง แล้วใช้คำนวณอายุ; ถ้าไม่ส่ง (แอปรุ่นเก่า) ใช้ age เดิม
$birth = isset($data['birth_date']) && $data['birth_date'] !== '' ? $data['birth_date'] : null;
if ($birth !== null) {
    if (!valid_birth_date($birth)) {
        echo json_encode(["result" => 0, "message" => "วันเกิดไม่ถูกต้อง"], JSON_UNESCAPED_UNICODE);
        exit();
    }
    $data['age'] = calc_age($birth);
}

try {

    if ($role === 'student') {
        $id = $data['student_id'] ?? null;
        if (!$id) {
            echo json_encode(["result" => 0, "message" => "Missing student_id"]);
            exit();
        }

        $stmt = $pdo->prepare("
            UPDATE student SET
                first_name_student    = ?,
                last_name_student     = ?,
                gender_student        = ?,
                age_student           = ?,
                birth_date            = COALESCE(?, birth_date),
                occupation            = ?,
                education_level       = ?,
                email_student         = ?,
                phone_number_student  = ?,
                address_student       = ?,
                learning_zone         = ?,
                language_used         = ?,
                knowledge_level       = ?,
                course_interest       = ?
            WHERE student_id = ?
        ");
        $stmt->execute([
            $data['first_name']      ?? null,
            $data['last_name']       ?? null,
            $data['gender']          ?? null,
            $data['age']             ?? null,
            $birth,
            $data['occupation']      ?? null,
            $data['education_level'] ?? null,
            $data['email']           ?? null,
            $data['phone']           ?? null,
            $data['address']         ?? null,
            $data['learning_zone']   ?? null,
            $data['language_used']   ?? null,
            $data['knowledge_level'] ?? null,
            $data['course_interest'] ?? null,
            $id,
        ]);

        // ดึงข้อมูลล่าสุดกลับไป
        $stmt = $pdo->prepare("SELECT * FROM student WHERE student_id = ?");
        $stmt->execute([$id]);
        $updated = $stmt->fetch(PDO::FETCH_ASSOC);
        apply_computed_age($updated, 'age_student');

        echo json_encode([
            "result"  => 1,
            "message" => "อัปเดตโปรไฟล์สำเร็จ",
            "datalist" => $updated,
        ], JSON_UNESCAPED_UNICODE);

    } elseif ($role === 'tutor') {
        $id = $data['tutor_id'] ?? null;
        if (!$id) {
            echo json_encode(["result" => 0, "message" => "Missing tutor_id"]);
            exit();
        }

        $stmt = $pdo->prepare("
            UPDATE tutor SET
                first_name_tutor        = ?,
                last_name_tutor         = ?,
                gender_tutor            = ?,
                age_tutor               = ?,
                birth_date              = COALESCE(?, birth_date),
                subject_teach           = ?,
                education_qualification = ?,
                email_tutor             = ?,
                phone_number_tutor      = ?,
                address_tutor           = ?,
                teaching_zone           = ?,
                language_teach          = ?,
                teachable_level         = ?,
                teaching_experience     = ?,
                experience              = ?,
                performance             = ?,
                expertise               = ?
            WHERE tutor_id = ?
        ");
        $stmt->execute([
            $data['first_name']              ?? null,
            $data['last_name']               ?? null,
            $data['gender']                  ?? null,
            $data['age']                     ?? null,
            $birth,
            $data['subject_teach']           ?? null,
            $data['education_qualification'] ?? null,
            $data['email']                   ?? null,
            $data['phone']                   ?? null,
            $data['address']                 ?? null,
            $data['teaching_zone']           ?? null,
            $data['language_teach']          ?? null,
            $data['teachable_level']         ?? null,
            $data['teaching_experience']     ?? null,
            $data['experience']              ?? null,
            $data['performance']             ?? null,
            $data['expertise']               ?? null,
            $id,
        ]);

        // ดึงข้อมูลล่าสุดกลับไป
        $stmt = $pdo->prepare("SELECT * FROM tutor WHERE tutor_id = ?");
        $stmt->execute([$id]);
        $updated = $stmt->fetch(PDO::FETCH_ASSOC);
        apply_computed_age($updated, 'age_tutor');

        echo json_encode([
            "result"  => 1,
            "message" => "อัปเดตโปรไฟล์สำเร็จ",
            "datalist" => $updated,
        ], JSON_UNESCAPED_UNICODE);

    } else {
        echo json_encode(["result" => 0, "message" => "Invalid role"]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
?>
