// register_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() {
    return _RegisterScreenState();
  }
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  String _role = 'CG'; // 'CG' | 'CM'
  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _register() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty || _nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'กรุณากรอกข้อมูลให้ครบ';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      UserCredential credential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      await credential.user?.updateDisplayName(_nameController.text);

      // บันทึก role ไว้ใน collection users แยกต่างหาก
      await FirebaseFirestore.instance.collection('users').doc(credential.user!.uid).set({
        'name': _nameController.text,
        'email': _emailController.text.trim(),
        'role': _role,
      });

      if (mounted) {
        Navigator.pop(context);
      }
    } on FirebaseAuthException catch (e) {
      print('Firebase error code: ${e.code}');
      print('Firebase error message: ${e.message}');
      String message;
      if (e.code == 'email-already-in-use') {
        message = 'อีเมลนี้ถูกใช้สมัครแล้ว';
      } else if (e.code == 'weak-password') {
        message = 'รหัสผ่านสั้นเกินไป (อย่างน้อย 6 ตัวอักษร)';
      } else if (e.code == 'invalid-email') {
        message = 'รูปแบบอีเมลไม่ถูกต้อง';
      } else {
        message = 'สมัครไม่สำเร็จ กรุณาลองใหม่';
      }
      setState(() {
        _errorMessage = message;
      });
    } catch (e) {
      print('Unexpected error: $e');
      setState(() {
        _errorMessage = 'เกิดข้อผิดพลาด: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('สมัครสมาชิก'),
        backgroundColor: const Color(0xFF0D3B3E),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('ตำแหน่ง', style: TextStyle(fontWeight: FontWeight.bold)),
            RadioListTile<String>(
              title: const Text('ผู้ดูแลผู้สูงอายุ (Caregiver)'),
              value: 'CG',
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
            ),
            RadioListTile<String>(
              title: const Text('ผู้จัดการการดูแล (Care Manager)'),
              value: 'CM',
              groupValue: _role,
              onChanged: (value) => setState(() => _role = value!),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'ชื่อ-นามสกุล'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'อีเมล'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'รหัสผ่าน (อย่างน้อย 6 ตัว)'),
            ),
            const SizedBox(height: 12),
            if (_errorMessage.isNotEmpty)
              Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _isLoading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D3B3E),
                minimumSize: const Size(double.infinity, 48),
              ),
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('สมัครสมาชิก'),
            ),
          ],
        ),
      ),
    );
  }
}