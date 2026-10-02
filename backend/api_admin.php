<?php
header("Content-Type: application/json; charset=utf-8");
require_once 'config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(["result" => 0, "message" => "Method Not Allowed"]);
    exit();
}

$data   = json_decode(file_get_contents("php://input"), true);
$action = $data['action'] ?? null;

// ================================================================
// action: "get_users"  — ดึงรายชื่อ student + tutor ทั้งหมด
// action: "ping"       — อัปเดต is_online / last_seen ของผู้ใช้
// ================================================================

try {

    // ------------------------------------------------------------
    // PING: Flutter เรียกทุก 30-60 วินาทีเพื่ออัปเดตสถานะ online
    // ------------------------------------------------------------
    if ($action === 'ping') {
        $role = $data['role'] ?? null;
        $id   = $data['id']   ?? null;

        if (!$role || !$id) {
            echo json_encode(["result" => 0, "message" => "Missing role or id"]);
            exit();
        }

        if ($role === 'student') {
            $stmt = $pdo->prepare("UPDATE student
                                   SET is_online = 1, last_seen = NOW()
                                   WHERE student_id = ?");
            $stmt->execute([$id]);
        } elseif ($role === 'tutor') {
            $stmt = $pdo->prepare("UPDATE tutor
                                   SET is_online = 1, last_seen = NOW()
                                   WHERE tutor_id = ?");
            $stmt->execute([$id]);
        }

        echo json_encode(["result" => 1, "message" => "ping ok"]);
        exit();
    }

    // ------------------------------------------------------------
    // LOGOUT: เซ็ต offline ทันที
    // ------------------------------------------------------------
    if ($action === 'logout') {
        $role = $data['role'] ?? null;
        $id   = $data['id']   ?? null;

        if (!$role || !$id) {
            echo json_encode(["result" => 0, "message" => "Missing role or id"]);
            exit();
        }

        if ($role === 'student') {
            $stmt = $pdo->prepare("UPDATE student
                                   SET is_online = 0, last_seen = NOW()
                                   WHERE student_id = ?");
            $stmt->execute([$id]);
        } elseif ($role === 'tutor') {
            $stmt = $pdo->prepare("UPDATE tutor
                                   SET is_online = 0, last_seen = NOW()
                                   WHERE tutor_id = ?");
            $stmt->execute([$id]);
        }

        echo json_encode(["result" => 1, "message" => "logout ok"]);
        exit();
    }

    // ------------------------------------------------------------
    // GET_USERS: แอดมินดึงข้อมูลผู้ใช้ทั้งหมด
    // auto-offline ถ้า last_seen เกิน 2 นาที
    // ------------------------------------------------------------
    if ($action === 'get_users') {

        // Auto-mark offline: ถ้า last_seen เกิน 2 นาที
        $pdo->exec("UPDATE student SET is_online = 0
                    WHERE is_online = 1
                      AND last_seen < DATE_SUB(NOW(), INTERVAL 2 MINUTE)");
        $pdo->exec("UPDATE tutor SET is_online = 0
                    WHERE is_online = 1
                      AND last_seen < DATE_SUB(NOW(), INTERVAL 2 MINUTE)");

        // ดึง students
        $stmt = $pdo->query("
            SELECT
                student_id      AS id,
                'student'       AS role,
                first_name_student  AS first_name,
                last_name_student   AS last_name,
                gender_student      AS gender,
                COALESCE(TIMESTAMPDIFF(YEAR, birth_date, CURDATE()), age_student) AS age,
                occupation,
                education_level,
                email_student       AS email,
                phone_number_student AS phone,
                address_student     AS address,
                photo_path,
                is_online,
                last_seen
            FROM student
            ORDER BY is_online DESC, last_seen DESC
        ");
        $students = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // ดึง tutors
        $stmt = $pdo->query("
            SELECT
                tutor_id        AS id,
                'tutor'         AS role,
                first_name_tutor    AS first_name,
                last_name_tutor     AS last_name,
                gender_tutor        AS gender,
                COALESCE(TIMESTAMPDIFF(YEAR, birth_date, CURDATE()), age_tutor) AS age,
                subject_teach,
                education_qualification AS education,
                email_tutor         AS email,
                phone_number_tutor  AS phone,
                address_tutor       AS address,
                photo_path,
                is_online,
                last_seen
            FROM tutor
            ORDER BY is_online DESC, last_seen DESC
        ");
        $tutors = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // แปลง is_online เป็น bool, last_seen เป็น string
        $mapUser = function (array $u): array {
            $u['is_online'] = (bool)$u['is_online'];
            return $u;
        };

        echo json_encode([
            "result"   => 1,
            "students" => array_map($mapUser, $students),
            "tutors"   => array_map($mapUser, $tutors),
            "summary"  => [
                "total_students"   => count($students),
                "total_tutors"     => count($tutors),
                "online_students"  => count(array_filter($students, fn($u) => $u['is_online'])),
                "online_tutors"    => count(array_filter($tutors,   fn($u) => $u['is_online'])),
            ]
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    if ($action === 'get_admins') {
        $stmt = $pdo->query("
            SELECT
                admin_id     AS id,
                first_name,
                last_name,
                email,
                ad_username  AS username,
                created_at
            FROM admin
            ORDER BY admin_id ASC
        ");
        $admins = $stmt->fetchAll(PDO::FETCH_ASSOC);
        echo json_encode([
            "result" => 1,
            "admins" => $admins
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    // ------------------------------------------------------------
    // ADD_ADMIN: เพิ่มแอดมินใหม่
    // ------------------------------------------------------------
    if ($action === 'add_admin') {
        $fname    = trim($data['first_name'] ?? '');
        $lname    = trim($data['last_name'] ?? '');
        $email    = trim($data['email'] ?? '');
        $username = trim($data['username'] ?? '');
        $password = $data['password'] ?? '';

        if ($fname === '' || $lname === '' || $username === '' || $password === '') {
            echo json_encode(["result" => 0, "message" => "กรอกข้อมูลให้ครบ"]);
            exit();
        }

        // เช็กซ้ำ (username / email) ภายในตาราง admin
        $dupErrors = [];
        $dupFields = [];

        $stmt = $pdo->prepare("SELECT admin_id FROM admin WHERE ad_username = ?");
        $stmt->execute([$username]);
        if ($stmt->fetch()) { $dupErrors[] = "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"; $dupFields[] = "username"; }

        if ($email !== '') {
            $stmt = $pdo->prepare("SELECT admin_id FROM admin WHERE email = ?");
            $stmt->execute([$email]);
            if ($stmt->fetch()) { $dupErrors[] = "อีเมลนี้ถูกใช้งานแล้ว"; $dupFields[] = "email"; }
        }

        if (count($dupErrors) > 0) {
            echo json_encode([
                "result" => 0,
                "message" => implode(", ", $dupErrors),
                "duplicate_fields" => $dupFields
            ]);
            exit();
        }

        // สร้าง admin_id แบบ AD001
        $stmt = $pdo->query("SELECT admin_id FROM admin ORDER BY admin_id DESC LIMIT 1");
        $last = $stmt->fetch(PDO::FETCH_ASSOC);
        $number = $last ? ((int)substr($last['admin_id'], 2) + 1) : 1;
        $newId = "AD" . str_pad($number, 3, "0", STR_PAD_LEFT);

        $stmt = $pdo->prepare("INSERT INTO admin
            (admin_id, first_name, last_name, email, ad_username, ad_password, created_at)
            VALUES (:id, :fname, :lname, :email, :username, :password, NOW())");
        $stmt->execute([
            'id' => $newId,
            'fname' => $fname,
            'lname' => $lname,
            'email' => $email,
            'username' => $username,
            'password' => password_hash($password, PASSWORD_DEFAULT),
        ]);

        echo json_encode(["result" => 1, "message" => "เพิ่มแอดมินสำเร็จ", "id" => $newId]);
        exit();
    }

    // ------------------------------------------------------------
    // UPDATE_ADMIN: แก้ไขข้อมูลแอดมิน (เว้นรหัสผ่านว่าง = ไม่เปลี่ยนรหัสผ่าน)
    // ------------------------------------------------------------
    if ($action === 'update_admin') {
        $id       = $data['id'] ?? '';
        $fname    = trim($data['first_name'] ?? '');
        $lname    = trim($data['last_name'] ?? '');
        $email    = trim($data['email'] ?? '');
        $username = trim($data['username'] ?? '');
        $password = $data['password'] ?? '';

        if ($id === '' || $fname === '' || $lname === '' || $username === '') {
            echo json_encode(["result" => 0, "message" => "กรอกข้อมูลให้ครบ"]);
            exit();
        }

        $dupErrors = [];
        $dupFields = [];

        $stmt = $pdo->prepare("SELECT admin_id FROM admin WHERE ad_username = ? AND admin_id != ?");
        $stmt->execute([$username, $id]);
        if ($stmt->fetch()) { $dupErrors[] = "ชื่อผู้ใช้นี้ถูกใช้งานแล้ว"; $dupFields[] = "username"; }

        if ($email !== '') {
            $stmt = $pdo->prepare("SELECT admin_id FROM admin WHERE email = ? AND admin_id != ?");
            $stmt->execute([$email, $id]);
            if ($stmt->fetch()) { $dupErrors[] = "อีเมลนี้ถูกใช้งานแล้ว"; $dupFields[] = "email"; }
        }

        if (count($dupErrors) > 0) {
            echo json_encode([
                "result" => 0,
                "message" => implode(", ", $dupErrors),
                "duplicate_fields" => $dupFields
            ]);
            exit();
        }

        if ($password !== '') {
            $stmt = $pdo->prepare("UPDATE admin SET
                first_name = :fname, last_name = :lname, email = :email,
                ad_username = :username, ad_password = :password
                WHERE admin_id = :id");
            $stmt->execute([
                'fname' => $fname, 'lname' => $lname, 'email' => $email,
                'username' => $username, 'password' => password_hash($password, PASSWORD_DEFAULT), 'id' => $id,
            ]);
        } else {
            $stmt = $pdo->prepare("UPDATE admin SET
                first_name = :fname, last_name = :lname, email = :email,
                ad_username = :username
                WHERE admin_id = :id");
            $stmt->execute([
                'fname' => $fname, 'lname' => $lname, 'email' => $email,
                'username' => $username, 'id' => $id,
            ]);
        }

        echo json_encode(["result" => 1, "message" => "แก้ไขข้อมูลสำเร็จ"]);
        exit();
    }

    // ------------------------------------------------------------
    // DELETE_ADMIN: ลบแอดมิน
    // ป้องกัน: ลบตัวเองไม่ได้ / ต้องเหลือแอดมินอย่างน้อย 1 คน
    // ------------------------------------------------------------
    if ($action === 'delete_admin') {
        $id        = $data['id'] ?? '';
        $currentId = $data['current_admin_id'] ?? null;

        if ($id === '') {
            echo json_encode(["result" => 0, "message" => "ไม่พบรหัสแอดมิน"]);
            exit();
        }

        if ($currentId !== null && $currentId === $id) {
            echo json_encode(["result" => 0, "message" => "ไม่สามารถลบบัญชีตัวเองได้"]);
            exit();
        }

        $countStmt = $pdo->query("SELECT COUNT(*) AS c FROM admin");
        $count = (int)$countStmt->fetch(PDO::FETCH_ASSOC)['c'];
        if ($count <= 1) {
            echo json_encode(["result" => 0, "message" => "ต้องมีแอดมินอย่างน้อย 1 บัญชี"]);
            exit();
        }

        $stmt = $pdo->prepare("DELETE FROM admin WHERE admin_id = ?");
        $stmt->execute([$id]);

        echo json_encode(["result" => 1, "message" => "ลบแอดมินสำเร็จ"]);
        exit();
    }

    // ------------------------------------------------------------
    // DELETE_ACCOUNT: ให้ student/tutor ลบบัญชีตัวเอง (ต้องยืนยันรหัสผ่าน)
    // ลบข้อมูลที่เกี่ยวข้องทั้งหมดแบบ cascade ภายใน transaction เดียว
    // ------------------------------------------------------------
    if ($action === 'delete_account') {
        $role     = $data['role'] ?? '';
        $id       = $data['id'] ?? '';
        $password = $data['password'] ?? '';

        if (!in_array($role, ['student', 'tutor'], true) || $id === '' || $password === '') {
            echo json_encode(["result" => 0, "message" => "ข้อมูลไม่ครบถ้วน"]);
            exit();
        }

        $idColumn       = $role === 'student' ? 'student_id' : 'tutor_id';
        $table          = $role === 'student' ? 'student' : 'tutor';
        $passwordColumn = $role === 'student' ? 'st_password' : 'tu_password';

        $stmt = $pdo->prepare("SELECT * FROM $table WHERE $idColumn = ?");
        $stmt->execute([$id]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if (!$user) {
            echo json_encode(["result" => 0, "message" => "ไม่พบผู้ใช้นี้"]);
            exit();
        }

        $storedHash = $user[$passwordColumn];
        $passwordOk = password_verify($password, $storedHash) || hash_equals((string)$storedHash, (string)$password);

        if (!$passwordOk) {
            echo json_encode(["result" => 0, "message" => "รหัสผ่านไม่ถูกต้อง"]);
            exit();
        }

        $pdo->beginTransaction();
        try {
            $stmt = $pdo->prepare("DELETE FROM chat WHERE $idColumn = ?");
            $stmt->execute([$id]);

            $stmt = $pdo->prepare("DELETE FROM notifications WHERE recipient_role = ? AND recipient_id = ?");
            $stmt->execute([$role, $id]);

            $stmt = $pdo->prepare("DELETE FROM match_table WHERE $idColumn = ?");
            $stmt->execute([$id]);

            if ($role === 'student') {
                $stmt = $pdo->prepare("DELETE FROM learn WHERE student_id = ?");
                $stmt->execute([$id]);
            } else {
                $stmt = $pdo->prepare("DELETE FROM teach WHERE tutor_id = ?");
                $stmt->execute([$id]);
            }

            $stmt = $pdo->prepare("DELETE FROM $table WHERE $idColumn = ?");
            $stmt->execute([$id]);

            $pdo->commit();
        } catch (PDOException $e) {
            $pdo->rollBack();
            http_response_code(500);
            echo json_encode(["result" => 0, "message" => "ลบบัญชีไม่สำเร็จ กรุณาลองใหม่"]);
            exit();
        }

        if (!empty($user['photo_path'])) {
            @unlink(__DIR__ . '/' . $user['photo_path']);
        }

        echo json_encode(["result" => 1, "message" => "ลบบัญชีสำเร็จ"]);
        exit();
    }

    // ------------------------------------------------------------
    // GET_REPORT: สรุปสถิติภาพรวมของระบบสำหรับหน้ารายงานแอดมิน
    // รองรับ start_date/end_date (YYYY-MM-DD, ไม่บังคับ) กรองเฉพาะ
    // สถิติที่มาจาก match_table (มีคอลัมน์ match_date) — ตัวเลขจำนวน
    // ผู้ใช้/สถานะออนไลน์ไม่มีวันที่ให้กรอง จึงเป็นค่าปัจจุบันเสมอ
    // ------------------------------------------------------------
    if ($action === 'get_report') {
        $startDate = $data['start_date'] ?? null;
        $endDate   = $data['end_date'] ?? null;

        $dateWhere  = [];
        $dateParams = [];
        if ($startDate) {
            $dateWhere[]  = "match_date >= ?";
            $dateParams[] = $startDate;
        }
        if ($endDate) {
            $dateWhere[]  = "match_date <= ?";
            $dateParams[] = $endDate;
        }
        $dateSql = $dateWhere ? ("WHERE " . implode(" AND ", $dateWhere)) : "";

        // จำนวนผู้ใช้ (ค่าปัจจุบัน ไม่มีวันที่ให้กรอง)
        $totalStudents = (int)$pdo->query("SELECT COUNT(*) AS c FROM student")->fetch(PDO::FETCH_ASSOC)['c'];
        $totalTutors   = (int)$pdo->query("SELECT COUNT(*) AS c FROM tutor")->fetch(PDO::FETCH_ASSOC)['c'];
        $totalAdmins   = (int)$pdo->query("SELECT COUNT(*) AS c FROM admin")->fetch(PDO::FETCH_ASSOC)['c'];

        // สถานะการจับคู่ทั้งหมด ('0'=รอยืนยัน, '1'=ยืนยันแล้ว, '2'=ปฏิเสธแล้ว) — กรองตามวันที่ได้
        $stmt = $pdo->prepare("
            SELECT match_status, COUNT(*) AS cnt
            FROM match_table
            $dateSql
            GROUP BY match_status
        ");
        $stmt->execute($dateParams);
        $statusRows = $stmt->fetchAll(PDO::FETCH_ASSOC);
        $matchStatusCounts = ['pending' => 0, 'confirmed' => 0, 'rejected' => 0];
        $statusMap = ['0' => 'pending', '1' => 'confirmed', '2' => 'rejected'];
        foreach ($statusRows as $r) {
            $key = $statusMap[$r['match_status']] ?? null;
            if ($key) $matchStatusCounts[$key] = (int)$r['cnt'];
        }
        $totalMatches = array_sum($matchStatusCounts);

        // คะแนนความเข้ากันได้เฉลี่ยของแมตช์ที่ยืนยันแล้ว — กรองตามวันที่ได้
        $confirmedWhere = $dateWhere;
        array_unshift($confirmedWhere, "match_status = '1'", "match_score IS NOT NULL");
        $stmt = $pdo->prepare("
            SELECT AVG(match_score) AS avg_score
            FROM match_table
            WHERE " . implode(" AND ", $confirmedWhere) . "
        ");
        $stmt->execute($dateParams);
        $avgScoreRow = $stmt->fetch(PDO::FETCH_ASSOC);
        $avgMatchScore = $avgScoreRow['avg_score'] !== null ? round((float)$avgScoreRow['avg_score'], 1) : null;

        // วิชายอดนิยม 5 อันดับแรก (จากแมตช์ในช่วงที่กรอง) — กรองตามวันที่ได้
        $subjectWhere = $dateWhere;
        array_unshift($subjectWhere, "subject IS NOT NULL", "subject != ''");
        $stmt = $pdo->prepare("
            SELECT subject, COUNT(*) AS cnt
            FROM match_table
            WHERE " . implode(" AND ", $subjectWhere) . "
            GROUP BY subject
            ORDER BY cnt DESC
            LIMIT 5
        ");
        $stmt->execute($dateParams);
        $topSubjects = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // ความต้องการเรียน/สอนที่ยังเปิดรับอยู่ (ค่าปัจจุบัน ไม่มีวันที่ให้กรอง)
        $activeLearnCount = (int)$pdo->query("SELECT COUNT(*) AS c FROM learn WHERE learn_status = 'active'")->fetch(PDO::FETCH_ASSOC)['c'];
        $activeTeachCount = (int)$pdo->query("SELECT COUNT(*) AS c FROM teach WHERE teach_status = 'active'")->fetch(PDO::FETCH_ASSOC)['c'];

        // ผู้สอนยอดนิยม 5 อันดับแรก (จำนวนแมตช์ที่ยืนยันแล้วมากที่สุดในช่วงที่กรอง)
        $tutorWhere = $dateWhere;
        array_unshift($tutorWhere, "mt.match_status = '1'");
        $stmt = $pdo->prepare("
            SELECT
                mt.tutor_id,
                CONCAT(tu.first_name_tutor, ' ', tu.last_name_tutor) AS tutor_name,
                COUNT(*) AS cnt
            FROM match_table mt
            INNER JOIN tutor tu ON tu.tutor_id = mt.tutor_id
            WHERE " . implode(" AND ", $tutorWhere) . "
            GROUP BY mt.tutor_id, tutor_name
            ORDER BY cnt DESC
            LIMIT 5
        ");
        $stmt->execute($dateParams);
        $topTutors = $stmt->fetchAll(PDO::FETCH_ASSOC);

        // ผู้ใช้ที่ออนไลน์อยู่ตอนนี้ (ค่าปัจจุบัน ไม่มีวันที่ให้กรอง)
        $onlineStudents = (int)$pdo->query("SELECT COUNT(*) AS c FROM student WHERE is_online = 1")->fetch(PDO::FETCH_ASSOC)['c'];
        $onlineTutors   = (int)$pdo->query("SELECT COUNT(*) AS c FROM tutor WHERE is_online = 1")->fetch(PDO::FETCH_ASSOC)['c'];

        // ประสิทธิภาพการจับคู่: อัตราสำเร็จ = สำเร็จ ÷ (สำเร็จ + ปฏิเสธ) (ไม่นับที่ยังรอยืนยัน เพราะยังไม่มีผลตัดสิน)
        $confirmedMatches = $matchStatusCounts['confirmed'];
        $decidedMatches   = $confirmedMatches + $matchStatusCounts['rejected'];
        $successRate   = $decidedMatches > 0 ? round($confirmedMatches * 100 / $decidedMatches, 1) : null;
        $rejectionRate = $decidedMatches > 0 ? round($matchStatusCounts['rejected'] * 100 / $decidedMatches, 1) : null;

        // อุปสงค์-อุปทานรายวิชา: ความต้องการเรียนที่เปิดอยู่ เทียบกับความต้องการสอนที่เปิดอยู่
        // (ชื่อวิชาเป็นข้อความที่ผู้ใช้พิมพ์เอง จึงเทียบแบบตัดช่องว่างและไม่สนตัวพิมพ์เล็ก/ใหญ่)
        $demandRows = $pdo->query("
            SELECT LOWER(TRIM(subject_learn)) AS k, MIN(TRIM(subject_learn)) AS subject, COUNT(*) AS c
            FROM learn
            WHERE learn_status = 'active' AND subject_learn IS NOT NULL AND TRIM(subject_learn) <> ''
            GROUP BY k
        ")->fetchAll(PDO::FETCH_ASSOC);
        $supplyRows = $pdo->query("
            SELECT LOWER(TRIM(subject_teach)) AS k, MIN(TRIM(subject_teach)) AS subject, COUNT(*) AS c
            FROM teach
            WHERE teach_status = 'active' AND subject_teach IS NOT NULL AND TRIM(subject_teach) <> ''
            GROUP BY k
        ")->fetchAll(PDO::FETCH_ASSOC);
        $gapMap = [];
        foreach ($demandRows as $r) {
            $gapMap[$r['k']] = ['subject' => $r['subject'], 'demand' => (int)$r['c'], 'supply' => 0];
        }
        foreach ($supplyRows as $r) {
            if (!isset($gapMap[$r['k']])) {
                $gapMap[$r['k']] = ['subject' => $r['subject'], 'demand' => 0, 'supply' => 0];
            }
            $gapMap[$r['k']]['supply'] = (int)$r['c'];
        }
        $subjectGaps = [];
        foreach ($gapMap as $g) {
            if ($g['demand'] <= 0) continue; // สนใจเฉพาะวิชาที่มีคนต้องการเรียน
            $g['gap'] = $g['demand'] - $g['supply'];
            $subjectGaps[] = $g;
        }
        usort($subjectGaps, fn($a, $b) => [$b['gap'], $b['demand']] <=> [$a['gap'], $a['demand']]);
        $subjectGaps = array_slice($subjectGaps, 0, 5);

        // การใช้งานแชท (กรองตามวันที่ส่งข้อความ) และสัดส่วนแมตช์ที่ยืนยันแล้วมีการคุยกันจริง
        $chatWhere  = [];
        $chatParams = [];
        if ($startDate) { $chatWhere[] = "DATE(created_at) >= ?"; $chatParams[] = $startDate; }
        if ($endDate)   { $chatWhere[] = "DATE(created_at) <= ?"; $chatParams[] = $endDate; }
        $chatSql = $chatWhere ? ("WHERE " . implode(" AND ", $chatWhere)) : "";
        $stmt = $pdo->prepare("SELECT COUNT(*) AS msgs, COUNT(DISTINCT match_id) AS rooms FROM chat $chatSql");
        $stmt->execute($chatParams);
        $chatRow = $stmt->fetch(PDO::FETCH_ASSOC);

        $stmt = $pdo->prepare("
            SELECT COUNT(*) AS total,
                   SUM(EXISTS (SELECT 1 FROM chat c WHERE c.match_id = mt.match_id)) AS with_chat
            FROM match_table mt
            WHERE " . implode(" AND ", $confirmedOnly = array_merge(["match_status = '1'"], $dateWhere)) . "
        ");
        $stmt->execute($dateParams);
        $wcRow = $stmt->fetch(PDO::FETCH_ASSOC);
        // ห้องแชทที่ไม่มีการคุย = แมตช์ที่ยืนยันแล้ว (เปิดห้องแชทได้) แต่ยังไม่มีข้อความสักข้อความ
        $silentChatRooms = (int)$wcRow['total'] - (int)$wcRow['with_chat'];
        $confirmedWithChatRate = ((int)$wcRow['total']) > 0
            ? round(((int)$wcRow['with_chat']) * 100 / (int)$wcRow['total'], 1)
            : null;

        echo json_encode([
            "result" => 1,
            "report" => [
                "start_date"          => $startDate,
                "end_date"            => $endDate,
                "total_students"      => $totalStudents,
                "total_tutors"        => $totalTutors,
                "total_admins"        => $totalAdmins,
                "online_students"     => $onlineStudents,
                "online_tutors"       => $onlineTutors,
                "total_matches"       => $totalMatches,
                "match_status_counts" => $matchStatusCounts,
                "avg_match_score"     => $avgMatchScore,
                "top_subjects"        => $topSubjects,
                "active_learn_count"  => $activeLearnCount,
                "active_teach_count"  => $activeTeachCount,
                "top_tutors"          => $topTutors,
                "confirmed_matches"   => $confirmedMatches,
                "decided_matches"     => $decidedMatches,
                "success_rate"        => $successRate,
                "rejection_rate"      => $rejectionRate,
                "subject_gaps"        => $subjectGaps,
                "chat_messages"       => (int)$chatRow['msgs'],
                "chat_rooms"          => (int)$chatRow['rooms'],
                "chat_rooms_silent"   => $silentChatRooms,
                "confirmed_with_chat_rate" => $confirmedWithChatRate,
            ],
        ], JSON_UNESCAPED_UNICODE);
        exit();
    }

    echo json_encode(["result" => 0, "message" => "Unknown action"]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(["result" => 0, "message" => $e->getMessage()]);
}
?>
