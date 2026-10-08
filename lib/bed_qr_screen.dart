// bed_qr_screen.dart
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';

class BedQrScreen extends StatefulWidget {
  final String bedId;
  final String elderlyName;

  const BedQrScreen({super.key, required this.bedId, required this.elderlyName});

  @override
  State<BedQrScreen> createState() {
    return _BedQrScreenState();
  }
}

class _BedQrScreenState extends State<BedQrScreen> {
  final GlobalKey _qrKey = GlobalKey();
  bool _isSaving = false;

  Future<void> _saveQr() async {
    setState(() {
      _isSaving = true;
    });

    try {
      RenderRepaintBoundary boundary =
      _qrKey.currentContext!.findRenderObject() as RenderRepaintBoundary;

      // pixelRatio สูง = ภาพละเอียด พิมพ์แล้วไม่แตก
      ui.Image image = await boundary.toImage(pixelRatio: 4.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(pngBytes, album: 'MedCare QR');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกรูป QR ลงแกลลอรี่แล้ว')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('บันทึกไม่สำเร็จ กรุณาอนุญาตการเข้าถึงรูปภาพแล้วลองใหม่')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QR ประจำเตียง'),
        backgroundColor: const Color(0xFF0D3B3E),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ส่วนที่อยู่ใน RepaintBoundary คือสิ่งที่จะถูกบันทึกเป็นรูป
              RepaintBoundary(
                key: _qrKey,
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      QrImageView(
                        data: widget.bedId,
                        version: QrVersions.auto,
                        size: 260,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'เตียง ${widget.bedId}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.elderlyName,
                        style: const TextStyle(fontSize: 16, color: Colors.black54),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveQr,
                icon: _isSaving
                    ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
                    : const Icon(Icons.download),
                label: const Text('บันทึกเป็นรูปภาพ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D3B3E),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 48),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'บันทึกแล้วนำไปพิมพ์ ติดที่เตียงนี้',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}