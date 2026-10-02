<?php
// ตัวช่วยคำนวณอายุจากวันเกิด (เก็บ birth_date แล้วคำนวณอายุสดทุกครั้ง อายุจึงเพิ่มเองทุกปี)

/** ตรวจวันเกิดรูปแบบ YYYY-MM-DD: วันที่มีจริง ไม่อยู่ในอนาคต และอายุ 1-120 ปี */
function valid_birth_date($s) {
    if (!is_string($s) || !preg_match('/^(\d{4})-(\d{2})-(\d{2})$/', $s, $m)) return false;
    if (!checkdate((int)$m[2], (int)$m[3], (int)$m[1])) return false;
    $age = calc_age($s);
    return $age !== null && $age >= 1 && $age <= 120;
}

/** อายุเต็มปี ณ วันนี้ คืน null ถ้าวันเกิดว่าง ผิดรูปแบบ หรืออยู่ในอนาคต */
function calc_age($birthDate) {
    if (!is_string($birthDate) || !preg_match('/^(\d{4})-(\d{2})-(\d{2})/', $birthDate, $m)) return null;
    if (!checkdate((int)$m[2], (int)$m[3], (int)$m[1])) return null;
    try {
        $birth = new DateTime(substr($birthDate, 0, 10));
        $today = new DateTime('today');
    } catch (Exception $e) {
        return null;
    }
    if ($birth > $today) return null;
    return (int)$birth->diff($today)->y;
}

/** ถ้าแถวผู้ใช้มี birth_date ให้เขียนทับคอลัมน์อายุ ($ageKey) ด้วยอายุที่คำนวณ ณ วันนี้ */
function apply_computed_age(&$row, $ageKey) {
    if (!is_array($row) || empty($row['birth_date'])) return;
    $age = calc_age($row['birth_date']);
    if ($age !== null) $row[$ageKey] = $age;
}
