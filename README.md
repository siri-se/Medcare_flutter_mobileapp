# MedCare Reminder

แอป Flutter สำหรับจัดการตารางยาของผู้สูงอายุในสถานดูแล ผู้ดูแล (Caregiver) สแกน QR code ที่เตียงเพื่อจัดการยาและการแจ้งเตือนของผู้สูงอายุแต่ละคน ส่วนผู้จัดการ (Care Manager) ดูแลข้อมูลเตียงและผู้สูงอายุ

> แพลตฟอร์ม: Android (ตั้งค่า Firebase สำหรับ Android เท่านั้น)

## ภาพหน้าจอ

<!-- ใส่ screenshot หรือ GIF เดโมที่นี่ -->
| ตั้งเวลายา | แจ้งเตือน | สรุปสถานะ |
|---|---|---|
| <img width="212" height="486" alt="รูปภาพ1" src="https://github.com/user-attachments/assets/d41389c4-5949-4315-bb64-3e11bb610ff4" /> | <img width="250" height="568" alt="รูปภาพ1" src="https://github.com/user-attachments/assets/12842826-c3e5-43ab-b41e-049be449b72c" /> | <img width="302" height="320" alt="รูปภาพ2" src="https://github.com/user-attachments/assets/d49db2fc-418c-4915-8765-fc77686ba7ee" />|

## ฟีเจอร์

**บัญชีและบทบาท** (Firebase Auth แบบอีเมล/รหัสผ่าน เก็บบทบาทใน `users`)
- **ผู้ดูแล (CG):** มีรายการเตียงโปรด เพิ่มเตียงโดยสแกน QR ด้วยกล้องหรือพิมพ์รหัสเตียง แล้วจัดการยาของผู้สูงอายุคนนั้น
- **ผู้จัดการ (CM):** เพิ่ม แก้ไข ลบข้อมูลเตียงและผู้สูงอายุ สร้างและบันทึก QR ของแต่ละเตียงเป็นรูป PNG ลงแกลลอรี่ และดูรายชื่อผู้ดูแลทั้งหมดพร้อมเตียงที่รับผิดชอบ

**จัดการยา (แท็บตั้งเวลายา)**
- เพิ่มยาพร้อมรูป คำอธิบายปริมาณ จำนวนที่จ่ายทั้งหมด จำนวนต่อครั้ง วันที่เริ่มยา และข้อมูลแพทย์ผู้สั่งจ่าย (ไม่บังคับ)
- รองรับเวลากินยา 3 แบบ:
  - **ตามมื้ออาหาร:** เช้า/กลางวัน/เย็น เลือกก่อน พร้อม หรือหลังอาหาร และกำหนดเวลาแต่ละมื้อ
  - **ทุก x ชั่วโมง:** ทุก 1-6 ชั่วโมงนับจากเวลาที่เลือก เมื่อกดยืนยันกินยาแล้วระบบสร้างรอบถัดไปให้อัตโนมัติ
  - **ก่อนนอน:** แจ้งเตือนก่อนเวลาเข้านอน 20 นาที
- การ์ดยาแบบขยายดูรายละเอียดได้ และแต่ละยามีแถบสีประจำตัว

**แจ้งเตือน (แท็บแจ้งเตือน)**
- ซิงก์กับ Firestore แบบเรียลไทม์ เรียงตามความเร่งด่วน (เลยเวลา > ใกล้เวลาสุด > เสร็จแล้ว)
- แสดงสถานะเลยเวลา/ค้างจากเมื่อวาน มี badge จำนวนรายการเลยเวลาบนแท็บ และปุ่มยืนยัน/ลบ
- กดยืนยันกินยาแล้วระบบหักจำนวนยาคงเหลือ
- แจ้งเตือนในเครื่อง (local notification) ตามเวลาที่ตั้ง ส่งเฉพาะบัญชีที่เป็นผู้เพิ่มยา
- สร้างรายการประจำวัน (ตามมื้อ/ก่อนนอน) ใหม่อัตโนมัติเมื่อเปิดแอป โดยไม่ต้องใช้ Cloud Functions

**สรุปสถานะ (แท็บสรุป)**
- เตือนยาใกล้หมดเมื่อเหลือต่ำกว่า 30% พร้อม badge บนแท็บ
- การ์ดแต่ละยาแสดงรูป จำนวนคงเหลือ และเวลากินรอบถัดไป
- ประวัติการกินยาย้อนหลัง 7 วัน (กินแล้ว/พลาด/รอถึงเวลา)

## เทคโนโลยีที่ใช้

| ส่วน | เทคโนโลยี |
|---|---|
| Framework | Flutter, Dart |
| Backend | Firebase Auth, Cloud Firestore, Firebase Storage |
| กล้อง/รูปภาพ | `mobile_scanner`, `image_picker` |
| QR | `qr_flutter` (สร้าง), `gal` (บันทึกลงแกลลอรี่) |
| แจ้งเตือน | `flutter_local_notifications` 19.0.0, `timezone` |
| IDE | Android Studio |

## โครงสร้างโปรเจกต์

```
lib/
├── main.dart                  # จุดเริ่มต้น, เริ่มต้น Firebase และระบบแจ้งเตือน
├── main_app.dart              # แถบนำทางล่าง, รีเซ็ตรายการประจำวัน, ตั้งแจ้งเตือน
├── login_screen.dart
├── register_screen.dart       # สมัครสมาชิกพร้อมเลือกบทบาท (CG / CM)
├── cg_home_screen.dart        # หน้าหลักผู้ดูแล (เตียงโปรด)
├── qr_scan_screen.dart        # สแกน QR + พิมพ์รหัสเตียง
├── cm_home_screen.dart        # หน้าหลักผู้จัดการ (จัดการเตียง)
├── add_elderly_screen.dart    # เพิ่ม/แก้ไขเตียงและผู้สูงอายุ
├── bed_qr_screen.dart         # สร้างและบันทึก QR ประจำเตียง
├── cg_roster_screen.dart      # รายชื่อผู้ดูแลและเตียงที่รับผิดชอบ
├── schedule_screen.dart
├── add_medicine_screen.dart
├── reminder_screen.dart
├── summary_screen.dart
├── notification_service.dart
├── medicine_colors.dart
└── firebase_options.dart
```

## วิธีติดตั้งและรัน

**ต้องมี:** Flutter SDK, Android Studio, Android emulator หรืออุปกรณ์จริง, โปรเจกต์ Firebase

1. โคลนโปรเจกต์
   ```bash
   git clone https://github.com/siri-se/Medcare_flutter_mobileapp.git
   cd <repo-name>
   ```
2. ติดตั้ง dependencies
   ```bash
   flutter pub get
   ```
3. เชื่อมต่อ Firebase ของตัวเอง
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure
   ```
   เปิดใช้ **Authentication (Email/Password)**, **Cloud Firestore** และ **Storage** ใน Firebase console
4. รันแอป
   ```bash
   flutter run
   ```

### Collections ใน Firestore

| Collection | หน้าที่ |
|---|---|
| `users` | ชื่อ อีเมล และบทบาท (CG / CM) ตาม uid |
| `elderlies` | ข้อมูลเตียงและผู้สูงอายุ (doc ID = รหัสเตียง) |
| `caregiver_beds` | เตียงโปรดของผู้ดูแล (`caregiverUid`, `elderlyId`) |
| `medicines` | ข้อมูลยา ตารางเวลา และจำนวน (`createdByUid`) |
| `reminders` | รายการแจ้งเตือนแต่ละรอบ (`scheduledTime`, `dateKey`, `isDone`, `hidden`) |

## ข้อจำกัดที่ทราบ

- Firestore ยังอยู่ใน test mode ไม่มี security rules และการตรวจบทบาททำฝั่งแอปเท่านั้น
- เมื่อบันทึกยาพร้อมรูปภาพอาจล้มเหลวด้วย `firebase_storage/object-not-found`
- รายการประจำวันอาจถูกสร้างซ้ำเมื่อสลับ/เปิดแอปใหม่
- รองรับเฉพาะ Android ยังไม่มี iOS
