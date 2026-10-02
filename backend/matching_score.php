<?php
// ================================================================
// ฟังก์ชันคำนวณ Compatibility Score ตามสูตรในเอกสาร
// ใช้ร่วมกันระหว่าง api_matching.php และ api_save_match.php
// ================================================================

// s1: Subject Match (25%)
function calcSubjectScore(string $sub1, string $sub2): float {
    $s1 = mb_strtolower(trim($sub1));
    $s2 = mb_strtolower(trim($sub2));
    if ($s1 === $s2) return 1.0;
    $groups = [
        ['คณิต', 'ฟิสิกส์', 'เคมี', 'ชีวะ', 'วิทยาศาสตร์', 'math', 'physics', 'chemistry', 'biology', 'science'],
        ['ภาษาไทย', 'วรรณคดี', 'thai'],
        ['ภาษาอังกฤษ', 'english', 'toeic', 'ielts'],
        ['ประวัติ', 'สังคม', 'history', 'social'],
        ['โปรแกรม', 'คอมพิวเตอร์', 'programming', 'coding', 'python', 'java'],
        ['บัญชี', 'การเงิน', 'เศรษฐศาสตร์', 'accounting', 'finance'],
    ];
    foreach ($groups as $group) {
        $m1 = false; $m2 = false;
        foreach ($group as $kw) {
            if (mb_strpos($s1, $kw) !== false) $m1 = true;
            if (mb_strpos($s2, $kw) !== false) $m2 = true;
        }
        if ($m1 && $m2) return 0.8;
    }
    similar_text($s1, $s2, $pct);
    if ($pct >= 50) return 0.5;
    return 0.0;
}

// s2: Level Match (15%) — s2 = 1 - |L1-L2|/3, any(3)=1.0
function calcLevelScore(int $l1, int $l2): float {
    if ($l1 == 3 || $l2 == 3) return 1.0;
    return max(0.0, 1.0 - abs($l1 - $l2) / 3.0);
}

// s3: Time Match (20%)
function calcTimeScore(int $t1, int $t2): float {
    return ($t1 === $t2) ? 1.0 : 0.0;
}

// s4: Price Match (15%)
function calcPriceScore(int $pLearn, int $pTeach): float {
    if ($pLearn === $pTeach) return 1.0;
    $diff = abs($pLearn - $pTeach);
    if ($diff == 1) return 0.6;
    return 0.2;
}

// s5: Style/Method/Format combined (10%)
function calcStyleScore(int $st1, int $st2, int $me1, int $me2, int $fo1, int $fo2): float {
    $match = 0;
    if ($st1 === $st2) $match++;
    if ($me1 === $me2) $match++;
    if ($fo1 === $fo2 || $fo1 == 2 || $fo2 == 2) $match++; // hybrid ยืดหยุ่น
    return $match / 3.0;
}

// s6: Language Match (10%) — DB: 0=thai,1=english,2=both
function calcLanguageScore(int $l1, int $l2): float {
    if ($l1 === $l2) return 1.0;
    if ($l1 == 2 || $l2 == 2) return 0.7;
    return 0.0;
}

// s7: Distance Match (5%) — online(0)=1.0
function calcDistanceScore(int $d1, int $d2, int $format): float {
    if ($format == 0) return 1.0;
    if ($d1 === $d2) return 1.0;
    if (abs($d1 - $d2) == 1) return 0.5;
    return 0.0;
}

// sub-scores
function calcExpScore(int $req, int $has): float {
    if ($has >= $req) return 1.0;
    return max(0.0, 1.0 - abs($req - $has) / 2.0);
}
function calcEduScore(int $req, int $has): float {
    if ($req == 3) return 1.0;
    if ($has >= $req) return 1.0;
    return max(0.0, 1.0 - abs($req - $has) / 3.0);
}
function calcGroupScore(int $g1, int $g2): float { return ($g1 === $g2) ? 1.0 : 0.0; }
function calcGenderScore(int $g1, int $g2): float {
    if ($g1 == 2 || $g2 == 2) return 1.0;
    return ($g1 === $g2) ? 1.0 : 0.0;
}

// ================================================================
// คำนวณคะแนนรวม
// ================================================================
function calcScore(array $learn, array $teach): array {
    $fmt   = (int)($learn['learning_format_learn'] ?? 0);

    $s1 = calcSubjectScore($learn['subject_learn'] ?? '', $teach['subject_teach'] ?? '');
    $s2 = calcLevelScore((int)($learn['content_level'] ?? 0), (int)($teach['teach_level'] ?? 0));
    $s3 = calcTimeScore((int)($learn['preferred_time_learn'] ?? 0), (int)($teach['preferred_time_teach'] ?? 0));
    $s4 = calcPriceScore((int)($learn['budget_per_hour'] ?? 0), (int)($teach['teaching_rate_per_hour'] ?? 0));
    $s5 = calcStyleScore(
        (int)($learn['teaching_style_learn'] ?? 0),  (int)($teach['teaching_style_teach'] ?? 0),
        (int)($learn['teaching_method_learn'] ?? 0), (int)($teach['teaching_method_teach'] ?? 0),
        $fmt,                                         (int)($teach['learning_format_teach'] ?? 0)
    );
    $s6 = calcLanguageScore((int)($learn['teaching_language_learn'] ?? 0), (int)($teach['teaching_language_teach'] ?? 0));
    $s7 = calcDistanceScore((int)($learn['teachable_distance_learn'] ?? 0), (int)($teach['teachable_distance_teach'] ?? 0), $fmt);

    // ปัจจัยย่อยใน s5 group
    $sExp   = calcExpScore((int)($learn['required_experience_learn'] ?? 0), (int)($teach['required_experience_teach'] ?? 0));
    $sEdu   = calcEduScore((int)($learn['preferred_teaching_method_learn'] ?? 3), (int)($teach['preferred_teaching_method_teach'] ?? 3));
    $sGroup = calcGroupScore((int)($learn['group_size_learn'] ?? 0), (int)($teach['group_size_teach'] ?? 0));
    $sKnow  = calcLevelScore((int)($learn['tutor_knowledge_level_learn'] ?? 0), (int)($teach['tutor_knowledge_level_teach'] ?? 0));
    $sGender= calcGenderScore((int)($learn['preferred_gender_learn'] ?? 2), (int)($teach['preferred_gender_teach'] ?? 2));

    $s5combined = ($s5 + $sExp + $sEdu + $sGroup + $sKnow) / 5.0;

    $base = (0.25 * $s1) + (0.15 * $s2) + (0.20 * $s3)
          + (0.15 * $s4) + (0.10 * $s5combined)
          + (0.10 * $s6) + (0.05 * $s7);

    // Bonus
    $bonus = 0.0;
    if ($sGender == 1.0 && (int)($learn['preferred_gender_learn'] ?? 2) != 2) $bonus += 0.02;

    $final = min(1.0, $base * (1 + $bonus));

    return [
        'final'    => round($final * 100, 1),
        'subject'  => round($s1 * 100, 1),
        'level'    => round($s2 * 100, 1),
        'time'     => round($s3 * 100, 1),
        'price'    => round($s4 * 100, 1),
        'style'    => round($s5 * 100, 1),
        'language' => round($s6 * 100, 1),
        'distance' => round($s7 * 100, 1),
    ];
}

