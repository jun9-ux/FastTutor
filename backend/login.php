<?php
    // config.php จัดการ CORS header + OPTIONS preflight ให้แล้ว (ใช้ร่วมกันทุกไฟล์)
    require_once 'config.php';

    if ($_SERVER['REQUEST_METHOD'] === 'HEAD') {
        http_response_code(200);
        exit();
    }

    if ($_SERVER['REQUEST_METHOD'] === 'POST') {
        $content   = @file_get_contents('php://input');
        $json_data = @json_decode($content, true);
        $username  = trim($json_data['username'] ?? '');
        $password  = trim($json_data['password'] ?? '');
        _log($content, null);
    } else {
        http_response_code(405);
        echo json_encode(['message' => 'Method Not Allowed']);
        exit();
    }

    // ============================================================
    // 🔹 เทียบรหัสผ่านแบบ hash (password_verify) พร้อม fallback
    //    รองรับ password เดิมที่ยังเป็น plaintext อยู่ในฐานข้อมูล
    //    ถ้า plaintext ตรงกัน จะ rehash แล้วอัปเดตกลับลง DB ทันที
    // ============================================================
    require_once 'age_helper.php';
    // คืนแถวผู้ใช้พร้อมอายุที่คำนวณจากวันเกิด (ให้แอปเดิมอ่าน age_* ได้อายุปัจจุบัน)
    function apply_age_row($row, $ageKey) {
        apply_computed_age($row, $ageKey);
        return $row;
    }

    function verifyAndUpgradePassword($pdo, $plain, $hash, $table, $passwordColumn, $idColumn, $idValue) {
        if (password_verify($plain, $hash)) {
            return true;
        }
        if (hash_equals((string)$hash, (string)$plain)) {
            $newHash = password_hash($plain, PASSWORD_DEFAULT);
            $stmt = $pdo->prepare("UPDATE $table SET $passwordColumn = :newHash WHERE $idColumn = :id");
            $stmt->execute(['newHash' => $newHash, 'id' => $idValue]);
            return true;
        }
        return false;
    }

    try {

        // ============================================================
        // 🔹 1. เช็ค admin ก่อน (ตรวจสอบก่อน student / tutor)
        // ============================================================
        $stmt = $pdo->prepare("SELECT * FROM admin WHERE ad_username = :username");
        $stmt->execute(['username' => $username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user && verifyAndUpgradePassword($pdo, $password, $user['ad_password'], 'admin', 'ad_password', 'admin_id', $user['admin_id'])) {
            $resp = json_encode([
                "result"   => 1,
                "message"  => "success",
                "role"     => "admin",           // ← Flutter ใช้ role นี้นำทางไปหน้า Admin
                "datalist" => [
                    "admin_id"   => $user['admin_id'],
                    "first_name" => $user['first_name'],
                    "last_name"  => $user['last_name'],
                    "email"      => $user['email'],
                ]
            ], JSON_UNESCAPED_UNICODE);
            echo $resp;
            _log($content, $resp);
            exit();
        }

        // ============================================================
        // 🔹 2. เช็ค student
        // ============================================================
        $stmt = $pdo->prepare("SELECT * FROM student WHERE st_username = :username");
        $stmt->execute(['username' => $username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user && verifyAndUpgradePassword($pdo, $password, $user['st_password'], 'student', 'st_password', 'student_id', $user['student_id'])) {
            $resp = json_encode([
                "result"   => 1,
                "message"  => "success",
                "role"     => "student",
                "datalist" => apply_age_row($user, 'age_student')
            ], JSON_UNESCAPED_UNICODE);
            echo $resp;
            _log($content, $resp);
            exit();
        }

        // ============================================================
        // 🔹 3. เช็ค tutor
        // ============================================================
        $stmt = $pdo->prepare("SELECT * FROM tutor WHERE tu_username = :username");
        $stmt->execute(['username' => $username]);
        $user = $stmt->fetch(PDO::FETCH_ASSOC);

        if ($user && verifyAndUpgradePassword($pdo, $password, $user['tu_password'], 'tutor', 'tu_password', 'tutor_id', $user['tutor_id'])) {
            $resp = json_encode([
                "result"   => 1,
                "message"  => "success",
                "role"     => "tutor",
                "datalist" => apply_age_row($user, 'age_tutor')
            ], JSON_UNESCAPED_UNICODE);
            echo $resp;
            _log($content, $resp);
            exit();
        }

        // ============================================================
        // ❌ ไม่เจอในทุกตาราง
        // ============================================================
        $resp = json_encode([
            "result"   => 0,
            "message"  => "fail",
            "datalist" => null
        ]);
        echo $resp;
        _log($content, $resp);
        exit();

    } catch (PDOException $e) {
        http_response_code(500);
        $resp = json_encode(["error" => $e->getMessage()], JSON_UNESCAPED_UNICODE);
        echo $resp;
        _log($content, $resp);
        exit();
    }

    function _log($request, $response) {
        $ip          = $_SERVER['REMOTE_ADDR'];
        $date        = date('Y-m-d H:i:s');
        $message_log = "\n" . $date . " ," . $ip
                     . ", request: " . $request
                     . ", response: " . $response;
        $objFopen = @fopen("log/" . date("Y-m-d") . ".log", "a+");
        @fwrite($objFopen, $message_log);
        @fclose($objFopen);
    }
?>