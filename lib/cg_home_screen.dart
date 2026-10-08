// cg_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'main_app.dart';
import 'qr_scan_screen.dart';
import 'notification_service.dart';

class CgHomeScreen extends StatelessWidget {
  const CgHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await NotificationService.cancelAll();
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    String uid = FirebaseAuth.instance.currentUser!.uid;

    final favorites = FirebaseFirestore.instance
        .collection('caregiver_beds')
        .where('caregiverUid', isEqualTo: uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('เตียงที่ดูแล'),
        backgroundColor: const Color(0xFF0D3B3E),
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: favorites.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'ยังไม่มีเตียงที่บันทึกไว้\nกดปุ่มสแกน QR ด้านล่างเพื่อเพิ่ม',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final favData = docs[index].data() as Map<String, dynamic>;
              String elderlyId = favData['elderlyId'] ?? '';

              return FutureBuilder<DocumentSnapshot>(
                future: FirebaseFirestore.instance.collection('elderlies').doc(elderlyId).get(),
                builder: (context, elderlySnap) {
                  if (!elderlySnap.hasData) {
                    return const ListTile(title: Text('กำลังโหลด...'));
                  }
                  if (!elderlySnap.data!.exists) {
                    return const Card(
                      child: ListTile(
                        leading: Icon(Icons.error_outline, color: Colors.red),
                        title: Text('ไม่พบข้อมูลเตียงนี้ (อาจถูกลบไปแล้ว)'),
                      ),
                    );
                  }

                  final elderlyData = elderlySnap.data!.data() as Map<String, dynamic>;
                  String name = elderlyData['name'] ?? '';
                  String bedNumber = elderlyData['bedNumber'] ?? '';

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF0D3B3E),
                        child: Icon(Icons.bed, color: Colors.white),
                      ),
                      title: Text(name),
                      subtitle: Text('เตียง $bedNumber'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'เอาออกจากรายการโปรด',
                            onPressed: () {
                              docs[index].reference.delete();
                            },
                          ),
                          const Icon(Icons.arrow_forward_ios, size: 16),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => MainApp(elderlyId: elderlyId, elderlyName: name),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF0D3B3E),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const QrScanScreen()),
          );
        },
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('สแกน QR'),
      ),
    );
  }
}