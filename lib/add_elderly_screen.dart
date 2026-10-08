// add_elderly_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AddElderlyScreen extends StatefulWidget {
  final String? elderlyId; // null = โหมดเพิ่มใหม่, มีค่า = โหมดแก้ไข
  final Map<String, dynamic>? initialData;

  const AddElderlyScreen({super.key, this.elderlyId, this.initialData});

  @override
  State<AddElderlyScreen> createState() {
    return _AddElderlyScreenState();
  }
}

class _AddElderlyScreenState extends State<AddElderlyScreen> {
  late TextEditingController _bedIdController;
  late TextEditingController _nameController;
  late TextEditingController _relationController;
  late TextEditingController _ageController;

  bool _isSaving = false;
  String _errorMessage = '';

  bool get _isEditMode => widget.elderlyId != null;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? {};
    _bedIdController = TextEditingController(text: widget.elderlyId ?? '');
    _nameController = TextEditingController(text: data['name'] ?? '');
    _relationController = TextEditingController(text: data['relation'] ?? '');
    _ageController = TextEditingController(
      text: (data['age'] != null && data['age'] != 0) ? data['age'].toString() : '',
    );
  }

  Future<void> _save() async {
    if (_bedIdController.text.isEmpty || _nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกรหัสเตียงและชื่อผู้สูงอายุ';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = '';
    });

    String bedId = _bedIdController.text.trim();

    Map<String, dynamic> data = {
      'bedNumber': bedId,
      'name': _nameController.text,
      'relation': _relationController.text,
      'age': int.tryParse(_ageController.text) ?? 0,
    };

    if (_isEditMode) {
      // แก้ไข: เขียนทับ document เดิมตรงๆ ไม่ต้องเช็คซ้ำ
      await FirebaseFirestore.instance.collection('elderlies').doc(bedId).update(data);
    } else {
      // เพิ่มใหม่: เช็คก่อนว่ารหัสเตียงซ้ำหรือไม่
      DocumentSnapshot existing =
      await FirebaseFirestore.instance.collection('elderlies').doc(bedId).get();

      if (existing.exists) {
        setState(() {
          _errorMessage = 'รหัสเตียงนี้ถูกใช้ไปแล้ว กรุณาใช้รหัสอื่น';
          _isSaving = false;
        });
        return;
      }

      await FirebaseFirestore.instance.collection('elderlies').doc(bedId).set(data);
    }

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'แก้ไขข้อมูลเตียง' : 'เพิ่มเตียง/ผู้สูงอายุ'),
        backgroundColor: const Color(0xFF0D3B3E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _bedIdController,
              enabled: !_isEditMode, // ห้ามแก้รหัสเตียงตอนอยู่โหมดแก้ไข เพราะเป็น document ID
              decoration: InputDecoration(
                labelText: 'รหัสเตียง (เช่น A-101)',
                helperText: _isEditMode
                    ? 'แก้รหัสเตียงไม่ได้ — ถ้าต้องเปลี่ยน ให้ลบแล้วสร้างใหม่'
                    : 'ค่านี้จะใช้พิมพ์ลงบน QR code ประจำเตียง',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อผู้สูงอายุ'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _relationController,
              decoration: const InputDecoration(labelText: 'ความสัมพันธ์ (เช่น ยาย, ตา) — ถ้ามี'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'อายุ — ถ้ามี'),
            ),
            const SizedBox(height: 16),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isSaving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B3E),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isSaving
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isEditMode ? 'บันทึกการแก้ไข' : 'บันทึก'),
            ),
          ],
        ),
      ),
    );
  }
}