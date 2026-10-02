<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data = json_decode(file_get_contents("php://input"), true);
$role = $data['role'] ?? null; // "student" or "tutor"
$id   = $data['id']   ?? null; // student_id or tutor_id

if (!$role || !$id) {
    echo json_encode(["result" => 0, "message" => "Missing role or id"]);
    exit();
}

// match_table.match_status: '0' = รอการยืนยัน, '1' = ยืนยันแล้ว, '2' = ปฏิเสธแล้ว
$MATCH_STATUS_MAP = ['0' => 'pending', '1' => 'accepted', '2' => 'rejected'];

require_once 'matching_score.php';

// ================================================================
// MAIN
// ================================================================
try {
    // ทำงานต่อเมื่อ role เป็น student
    if ($role === 'student') {

        // 1. ดึง learn record ล่าสุดของ student จาก DB
        $stmt = $pdo->prepare("
            SELECT * FROM learn
            WHERE student_id = ? AND learn_status = 'active'
            ORDER BY learn_reg_id DESC
            LIMIT 1
        ");
        $stmt->execute([$id]);
        $learn = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$learn) {
            echo json_encode(["result" => 0, "message" => "ไม่พบข้อมูลความต้องการเรียน กรุณาเพิ่มความต้องการก่อน"]);
            exit();
        }

        // 2. ดึง teach ทั้งหมด JOIN tutor จาก DB พร้อมสถานะคำขอจับคู่ล่าสุด (ถ้ามี)
        $stmt = $pdo->prepare("
            SELECT
                t.teach_req_id,
                t.subject_teach,
                t.teach_level,
                t.objective_teach,
                t.preferred_time_teach,
                t.duration_teach,
                t.learning_format_teach,
                t.teachable_distance_teach,
                t.teaching_rate_per_hour,
                t.required_experience_teach,
                t.preferred_teaching_method_teach,
                t.tutor_knowledge_level_teach,
                t.group_size_teach,
                t.teaching_style_teach,
                t.teaching_method_teach,
                t.teaching_language_teach,
                t.preferred_gender_teach,
                t.tutor_id,
                tu.first_name_tutor,
                tu.last_name_tutor,
                tu.gender_tutor,
                COALESCE(TIMESTAMPDIFF(YEAR, tu.birth_date, CURDATE()), tu.age_tutor) AS age_tutor,
                tu.education_qualification,
                tu.email_tutor,
                tu.phone_number_tutor,
                tu.photo_path,
                (
                    SELECT mt.match_status FROM match_table mt
                    WHERE mt.teach_req_id = t.teach_req_id AND mt.learn_reg_id = ?
                    ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC LIMIT 1
                ) AS match_status_raw,
                (
                    SELECT mt.initiated_by FROM match_table mt
                    WHERE mt.teach_req_id = t.teach_req_id AND mt.learn_reg_id = ?
                    ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC LIMIT 1
                ) AS request_initiator
            FROM teach t
            INNER JOIN tutor tu ON t.tutor_id = tu.tutor_id
            WHERE t.teach_status = 'active'
        ");
        $stmt->execute([$learn['learn_reg_id'], $learn['learn_reg_id']]);
        $teaches = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // 3. คำนวณ score และกรองผล
        $results = [];
        foreach ($teaches as $teach) {
            $scores = calcScore($learn, $teach);
            if ($scores['final'] >= 30) { // กรองคะแนนมากกว่า 30 ขึ้นไป
                $results[] = [
                    'teach_req_id'    => $teach['teach_req_id'],
                    'learn_reg_id'    => $learn['learn_reg_id'],
                    'tutor_id'        => $teach['tutor_id'],
                    'tutor_name'      => $teach['first_name_tutor'] . ' ' . $teach['last_name_tutor'],
                    'gender'          => $teach['gender_tutor'],
                    'age'             => (int)$teach['age_tutor'],
                    'subject'         => $teach['subject_teach'],
                    'level'           => (int)$teach['teach_level'],
                    'rate'            => (int)$teach['teaching_rate_per_hour'],
                    'format'          => (int)$teach['learning_format_teach'],
                    'time'            => (int)$teach['preferred_time_teach'],
                    'education'       => $teach['education_qualification'] ?? '-',
                    'email'           => $teach['email_tutor'] ?? '-',
                    'phone'           => $teach['phone_number_tutor'] ?? '-',
                    'photo_url'       => $teach['photo_path'] ?? null,
                    'score'           => $scores['final'],
                    'score_detail'    => $scores,
                    'request_status'    => $MATCH_STATUS_MAP[$teach['match_status_raw'] ?? ''] ?? null,
                    'request_initiator' => $teach['request_initiator'] ?? null,  // student / tutor
                ];
            }
        }
        // 4. เรียงลำดับคะแนนและตัด top 10 จากมากไปน้อย
        usort($results, fn($a, $b) => $b['score'] <=> $a['score']);
        $top = array_slice($results, 0, 10);
        // 5. ส่งผลลัพธ์กลับเป็น JSON
        echo json_encode([
            "result"   => 1,
            "role"     => "student",
            "learn_id" => $learn['learn_reg_id'],
            "subject"  => $learn['subject_learn'],
            "my_request" => $learn, // ความต้องการเรียนปัจจุบัน (แถวเดียวกับที่ใช้จับคู่) ให้แอปแสดงรายละเอียด
            "total"    => count($top),
            "matches"  => $top,
        ], JSON_UNESCAPED_UNICODE);

    } elseif ($role === 'tutor') {

        // 1. ดึง teach record ล่าสุดของ tutor จาก DB
        $stmt = $pdo->prepare("
            SELECT * FROM teach
            WHERE tutor_id = ? AND teach_status = 'active'
            ORDER BY teach_req_id DESC
            LIMIT 1
        ");
        $stmt->execute([$id]);
        $teach = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$teach) {
            echo json_encode(["result" => 0, "message" => "ไม่พบข้อมูลความต้องการสอน กรุณาเพิ่มความต้องการก่อน"]);
            exit();
        }

        // 2. ดึง learn ทั้งหมด JOIN student จาก DB พร้อมสถานะคำขอจับคู่ล่าสุด (ถ้ามี)
        $stmt = $pdo->prepare("
            SELECT
                l.learn_reg_id,
                l.subject_learn,
                l.content_level,
                l.objective_learn,
                l.preferred_time_learn,
                l.duration_learn,
                l.learning_format_learn,
                l.teachable_distance_learn,
                l.budget_per_hour,
                l.required_experience_learn,
                l.preferred_teaching_method_learn,
                l.tutor_knowledge_level_learn,
                l.group_size_learn,
                l.teaching_style_learn,
                l.teaching_method_learn,
                l.teaching_language_learn,
                l.preferred_gender_learn,
                l.student_id,
                st.first_name_student,
                st.last_name_student,
                st.gender_student,
                COALESCE(TIMESTAMPDIFF(YEAR, st.birth_date, CURDATE()), st.age_student) AS age_student,
                st.education_level,
                st.email_student,
                st.phone_number_student,
                st.photo_path,
                (
                    SELECT mt.match_status FROM match_table mt
                    WHERE mt.learn_reg_id = l.learn_reg_id AND mt.teach_req_id = ?
                    ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC LIMIT 1
                ) AS match_status_raw,
                (
                    SELECT mt.initiated_by FROM match_table mt
                    WHERE mt.learn_reg_id = l.learn_reg_id AND mt.teach_req_id = ?
                    ORDER BY CAST(SUBSTRING(mt.match_id, 3) AS UNSIGNED) DESC LIMIT 1
                ) AS request_initiator
            FROM learn l
            INNER JOIN student st ON l.student_id = st.student_id
            WHERE l.learn_status = 'active'
        ");
        $stmt->execute([$teach['teach_req_id'], $teach['teach_req_id']]);
        $learns = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // 3. คำนวณ score และกรองผล
        $results = [];
        foreach ($learns as $learn) {
            $scores = calcScore($learn, $teach);
            if ($scores['final'] >= 30) {
                $results[] = [
                    'learn_reg_id'  => $learn['learn_reg_id'],
                    'teach_req_id'  => $teach['teach_req_id'],
                    'student_id'    => $learn['student_id'],
                    'student_name'  => $learn['first_name_student'] . ' ' . $learn['last_name_student'],
                    'gender'        => $learn['gender_student'],
                    'age'           => (int)$learn['age_student'],
                    'subject'       => $learn['subject_learn'],
                    'level'         => (int)$learn['content_level'],
                    'budget'        => (int)$learn['budget_per_hour'],
                    'format'        => (int)$learn['learning_format_learn'],
                    'time'          => (int)$learn['preferred_time_learn'],
                    'education'     => $learn['education_level'] ?? '-',
                    'email'         => $learn['email_student'] ?? '-',
                    'phone'         => $learn['phone_number_student'] ?? '-',
                    'photo_url'     => $learn['photo_path'] ?? null,
                    'score'         => $scores['final'],
                    'score_detail'  => $scores,
                    'request_status'    => $MATCH_STATUS_MAP[$learn['match_status_raw'] ?? ''] ?? null,
                    'request_initiator' => $learn['request_initiator'] ?? null,  // student / tutor
                ];
            }
        }

        usort($results, fn($a, $b) => $b['score'] <=> $a['score']);
        $top = array_slice($results, 0, 10);

        echo json_encode([
            "result"   => 1,
            "role"     => "tutor",
            "teach_id" => $teach['teach_req_id'],
            "subject"  => $teach['subject_teach'],
            "my_request" => $teach, // ความต้องการสอนปัจจุบัน (แถวเดียวกับที่ใช้จับคู่) ให้แอปแสดงรายละเอียด
            "total"    => count($top),
            "matches"  => $top,
        ], JSON_UNESCAPED_UNICODE);

    } else {
        echo json_encode(["result" => 0, "message" => "Invalid role"]);
    }

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
?>