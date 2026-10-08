// medicine_colors.dart
import 'package:flutter/material.dart';

const List<Color> medicineColorPalette = [
  Color(0xFFFFD6D6), // แดงอ่อน
  Color(0xFFFFE8C2), // ส้มอ่อน
  Color(0xFFFFF6C2), // เหลืองอ่อน
  Color(0xFFE0F5C2), // เขียวมะนาวอ่อน
  Color(0xFFC2F0D9), // เขียวอ่อน
  Color(0xFFC2F0F0), // ฟ้าอมเขียวอ่อน
  Color(0xFFC2E0FF), // ฟ้าอ่อน
  Color(0xFFD6C2FF), // ม่วงอ่อน
  Color(0xFFF0C2E8), // ชมพูอ่อน
  Color(0xFFE8D6C2), // น้ำตาลอ่อน
];

Color getMedicineColor(String medicineId) {
  int index = medicineId.hashCode.abs() % medicineColorPalette.length;
  return medicineColorPalette[index];
}