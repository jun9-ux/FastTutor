# FastTutor

ซอร์สโค้ด PHP API และ Flutter สำหรับเก็บใน Git

- backend/: PHP API จาก C:/xampp/htdocs/project
- flutter/: ซอร์ส Flutter, assets, tests และไฟล์โปรเจกต์แต่ละแพลตฟอร์มจาก C:/myfutter68/project
- database/schema.sql: โครงสร้างตารางจาก FastTutor_Docker/database/01_project.sql ไม่มีข้อมูลผู้ใช้ ต้องตรวจเทียบกับฐานข้อมูลที่ใช้งานจริงอีกครั้ง

## ตั้งค่าเพื่อรัน

1. สร้างฐานข้อมูลว่างชื่อ _project และนำเข้า database/schema.sql
2. วางไฟล์ใน backend/ ไว้ในโฟลเดอร์ project ของเว็บเซิร์ฟเวอร์ PHP ที่รองรับ PDO MySQL
3. คัดลอก backend/config.example.php เป็น config.php แล้วตั้ง DB_USERNAME, DB_PASSWORD และ DB_NAME ให้ตรงกับเครื่อง ไฟล์ config.php ถูกกันออกจาก Git
4. ตรวจให้เว็บเซิร์ฟเวอร์สร้างและเขียน uploads/profile_photos/ ได้
5. แก้ flutter/lib/api_config.dart ให้ kApiBase เป็น URL ของ PHP API ที่อุปกรณ์เข้าถึงได้
6. เข้าโฟลเดอร์ flutter แล้วใช้ flutter pub get และ flutter run

ฐานข้อมูลชุดนี้ไม่มีบัญชีหรือข้อมูลตั้งต้น ต้องสร้างบัญชีใหม่สำหรับทดสอบ
โค้ด Flutter ยังใช้ URL ของเครื่องเดิม จึงต้องปรับก่อนรันในเครื่องอื่น

## ไฟล์ที่ตัดออก

build, cache, การตั้งค่าเฉพาะเครื่อง, ไฟล์บีบอัด, เอกสารที่ export,
ภาพออกแบบ ux_ui.jpg, log, รูปที่ผู้ใช้อัปโหลด, ข้อมูลในฐานข้อมูล และ config.php จริง

นี่เป็นสำเนาที่เตรียมสำหรับ Git การแก้ไฟล์ต้นฉบับหลังจากนี้จะไม่อัปเดตสำเนาอัตโนมัติ

## ขึ้น GitHub

รันจากโฟลเดอร์ FastTutor_Git หลังตรวจไฟล์:

    git add .
    git commit -m "Initial commit"
    git remote add origin https://github.com/USERNAME/REPO.git
    git push -u origin main

สร้าง repository ว่างบน GitHub และแทน USERNAME/REPO ด้วยชื่อจริงก่อนใช้คำสั่ง
