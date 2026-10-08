// qr_scan_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'main_app.dart';

class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() {
    return _QrScanScreenState();
  }
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _scannerController = MobileScannerController();
  final _bedIdController = TextEditingController();

  bool _isProcessing = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _scannerController.dispose();
    _bedIdController.dispose();
    super.dispose();
  }

  // ฟังก์ชันกลาง ใช้ร่วมกันทั้งตอนสแกนกล้องและตอนพิมพ์เอง
  Future<void> _processBedId(String rawBedId, {required bool fromCamera}) async {
    if (_isProcessing) return;

    String bedId = rawBedId.trim();
    if (bedId.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกรหัสเตียง';
      });
      return;
    }

    setState(() {
      _isProcessing = true;
      _errorMessage = '';
    });

    if (fromCamera) {
      await _scannerController.stop();
    }

    try {
      DocumentSnapshot elderlyDoc =
      await FirebaseFirestore.instance.collection('elderlies').doc(bedId).get();

      if (!elderlyDoc.exists) {
        setState(() {
          _errorMessage = 'ไม่พบข้อมูลเตียง "$bedId" ในระบบ';
          _isProcessing = false;
        });
        if (fromCamera) {
          await _scannerController.start();
        }
        return;
      }

      final elderlyData = elderlyDoc.data() as Map<String, dynamic>;
      String name = elderlyData['name'] ?? '';

      String uid = FirebaseAuth.instance.currentUser!.uid;

      QuerySnapshot existing = await FirebaseFirestore.instance
          .collection('caregiver_beds')
          .where('caregiverUid', isEqualTo: uid)
          .where('elderlyId', isEqualTo: bedId)
          .get();

      if (existing.docs.isEmpty) {
        await FirebaseFirestore.instance.collection('caregiver_beds').add({
          'caregiverUid': uid,
          'elderlyId': bedId,
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainApp(elderlyId: bedId, elderlyName: name),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด กรุณาลองใหม่';
        _isProcessing = false;
      });
      if (fromCamera) {
        await _scannerController.start();
      }
    }
  }

  void _onDetect(BarcodeCapture capture) {
    if (capture.barcodes.isEmpty) return;
    String? value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;
    _processBedId(value, fromCamera: true);
  }

  void _submitManual() {
    FocusScope.of(context).unfocus(); // ซ่อนคีย์บอร์ด
    _processBedId(_bedIdController.text, fromCamera: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มเตียงที่ดูแล'),
        backgroundColor: const Color(0xFF0D3B3E),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
            tooltip: 'เปิด/ปิดไฟฉาย',
          ),
        ],
      ),
      body: Column(
        children: [
          // ส่วนบน: กล้องสแกน
          Expanded(
            child: Stack(
              children: [
                MobileScanner(
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                Center(
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.white, width: 3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                  ),
              ],
            ),
          ),

          // ส่วนล่าง: พิมพ์รหัสเตียงเอง
          Container(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            color: Colors.white,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'สแกนไม่ได้? พิมพ์รหัสเตียงแทน',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _bedIdController,
                        textInputAction: TextInputAction.done,
                        onSubmitted: (_) => _submitManual(),
                        decoration: const InputDecoration(
                          labelText: 'รหัสเตียง (เช่น A-102)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _submitManual,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D3B3E),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(72, 48),
                      ),
                      child: const Text('เพิ่ม'),
                    ),
                  ],
                ),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(_errorMessage, style: const TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}