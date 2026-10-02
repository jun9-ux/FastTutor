<?php
header('Content-Type: application/json; charset=utf-8');
require_once 'config.php';
$content = file_get_contents("php://input");
$data = json_decode($content, true);
$role = $data['role'];

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

// ===============================
// 🔹 ฟังก์ชันเช็กข้อมูลซ้ำ (email, phone, username)
//    เช็กข้ามทั้งตาราง student และ tutor
// ===============================
function checkDuplicate($pdo, $email, $phone, $username) {
    $errors = [];
    $fields = [];

    // เช็ก username ซ้ำ
    $stmt = $pdo->prepare("
        SELECT st_username AS val FROM student WHERE st_username = ?
        UNION
        SELECT tu_username AS val FROM tutor WHERE tu_username = ?
    ");
    $stmt->execute([$username, $username]);
    if ($stmt->fetch()) {
        $errors[] = "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว";
        $fields[] = "username";
    }

    // เช็ก email ซ้ำ
    $stmt = $pdo->prepare("
        SELECT email_student AS val FROM student WHERE email_student = ?
        UNION
        SELECT email_tutor AS val FROM tutor WHERE email_tutor = ?
    ");
    $stmt->execute([$email, $email]);
    if ($stmt->fetch()) {
        $errors[] = "อีเมลนี้ถูกใช้งานแล้ว";
        $fields[] = "email";
    }

    // เช็ก phone ซ้ำ
    $stmt = $pdo->prepare("
        SELECT phone_number_student AS val FROM student WHERE phone_number_student = ?
        UNION
        SELECT phone_number_tutor AS val FROM tutor WHERE phone_number_tutor = ?
    ");
    $stmt->execute([$phone, $phone]);
    if ($stmt->fetch()) {
        $errors[] = "เบอร์โทรศัพท์นี้ถูกใช้งานแล้ว";
        $fields[] = "phone";
    }

    return ["errors" => $errors, "fields" => $fields];
}

try {
    // ===============================
    // 🔹 ตรวจสอบข้อมูลซ้ำก่อน insert
    // ===============================
    $check = checkDuplicate($pdo, $data['email'], $data['phone'], $data['username']);

    if (count($check['errors']) > 0) {
        echo json_encode([
            "result" => 0,
            "message" => implode(", ", $check['errors']),
            "duplicate_fields" => $check['fields']
        ]);
        exit;
    }

    if ($role == "student") {
        // ===============================
        // 🔹 สร้าง student_id แบบ ST001
        // ===============================
        $stmt = $pdo->query("SELECT student_id FROM student ORDER BY student_id DESC LIMIT 1");
        $last = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($last) {
            $number = (int)substr($last['student_id'], 2);
            $number++;
        } else {
            $number = 1;
        }
        $newId = "ST" . str_pad($number, 3, "0", STR_PAD_LEFT);

        $stmt = $pdo->prepare("INSERT INTO student 
            (student_id, first_name_student, last_name_student, gender_student,
             age_student, birth_date, occupation, education_level, email_student,
             phone_number_student, address_student, st_username, st_password,
             learning_zone, language_used, knowledge_level, course_interest)
            VALUES
            (:id, :fname, :lname, :gender, :age, :birth_date, :occupation, :education,
             :email, :phone, :address, :username, :password,
             :learning_zone, :language_used, :knowledge_level, :course_interest)");
        $stmt->execute([
            'id' => $newId,
            'fname' => $data['first_name'],
            'lname' => $data['last_name'],
            'gender' => $data['gender'],
            'age' => $data['age'],
            'birth_date' => $birth,
            'occupation' => $data['occupation'],
            'education' => $data['education_level'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'address' => $data['address'],
            'username' => $data['username'],
            'password' => password_hash($data['password'], PASSWORD_DEFAULT),
            'learning_zone'   => $data['learning_zone']   ?? null,
            'language_used'   => $data['language_used']   ?? null,
            'knowledge_level' => $data['knowledge_level'] ?? null,
            'course_interest' => $data['course_interest'] ?? null,
        ]);
    } else if ($role == "tutor") {
        // ===============================
        // 🔹 สร้าง tutor_id แบบ TU001
        // ===============================
        $stmt = $pdo->query("SELECT tutor_id FROM tutor ORDER BY tutor_id DESC LIMIT 1");
        $last = $stmt->fetch(PDO::FETCH_ASSOC);
        if ($last) {
            $number = (int)substr($last['tutor_id'], 2);
            $number++;
        } else {
            $number = 1;
        }
        $newId = "TU" . str_pad($number, 3, "0", STR_PAD_LEFT);

        $stmt = $pdo->prepare("INSERT INTO tutor 
            (tutor_id, first_name_tutor, last_name_tutor, gender_tutor, age_tutor, birth_date,
             subject_teach, education_qualification, email_tutor,
             phone_number_tutor, address_tutor, teaching_zone, language_teach,
             teachable_level, teaching_experience, experience, performance, expertise,
             tu_username, tu_password)
            VALUES
            (:id, :fname, :lname, :gender, :age, :birth_date, :subject, :education,
             :email, :phone, :address, :teaching_zone, :language_teach,
             :teachable_level, :teaching_experience, :experience, :performance, :expertise,
             :username, :password)");
        $stmt->execute([
            'id' => $newId,
            'fname' => $data['first_name'],
            'lname' => $data['last_name'],
            'gender' => $data['gender'],
            'age' => $data['age'],
            'birth_date' => $birth,
            'subject' => $data['subject_teach'],
            'education' => $data['education_qualification'],
            'email' => $data['email'],
            'phone' => $data['phone'],
            'address' => $data['address'],
            'teaching_zone' => $data['teaching_zone'] ?? null,
            'language_teach' => $data['language_teach'] ?? null,
            'teachable_level' => $data['teachable_level'] ?? null,
            'teaching_experience' => $data['teaching_experience'] ?? null,
            'experience' => $data['experience'] ?? null,
            'performance' => $data['performance'] ?? null,
            'expertise' => $data['expertise'] ?? null,
            'username' => $data['username'],
            'password' => password_hash($data['password'], PASSWORD_DEFAULT)
        ]);
    } else {
        echo json_encode([
            "result" => 0,
            "message" => "role ไม่ถูกต้อง (ต้องเป็น student หรือ tutor)"
        ]);
        exit;
    }
    echo json_encode([
        "result" => 1,
        "message" => "Register success"
    ]);
} catch(PDOException $e){
    echo json_encode([
        "result" => 0,
        "message" => $e->getMessage()
    ]);
}
?>