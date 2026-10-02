<?php
    //print_r("connnect db _shop");
    // CORS: อนุญาตให้ frontend (เว็บ/มือถือ) เรียก API ข้ามโดเมนได้ — ใช้ร่วมกันทุกไฟล์ผ่าน require_once
    $origin = isset($_SERVER['HTTP_ORIGIN']) ? $_SERVER['HTTP_ORIGIN'] : '*';
    header("Access-Control-Allow-Origin: $origin");
    header('Access-Control-Allow-Methods: GET, HEAD, OPTIONS, POST');
    header('Access-Control-Allow-Headers: Content-Type, X-Requested-With, Accept, Authorization');

    // Preflight request: ตอบ 200 ทันที ไม่ต้องต่อฐานข้อมูล
    if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
        http_response_code(200);
        exit();
    }

    header("Content-Type: application/json; charset=UTF-8");
    define('DB_USERNAME', 'YOUR_DB_USER');
    define('DB_PASSWORD', 'YOUR_DB_PASSWORD');
    define('DB_NAME', '_project');
    try {
        $dsn = "mysql:host=127.0.0.1;dbname=" . DB_NAME . ";charset=utf8";
        $pdo = new PDO($dsn, DB_USERNAME, DB_PASSWORD, [
            PDO::ATTR_ERRMODE=> PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_PERSISTENT => true,
            PDO::ATTR_EMULATE_PREPARES => false,
            PDO::ATTR_STRINGIFY_FETCHES => false,
        ]);
        //echo json_encode(["message" => "Connection success"]);
    }catch (PDOException $e){
        http_response_code(500);
        ob_end_clean();
        echo json_encode(["message" => "Connection failed"]);
        exit;
    }
