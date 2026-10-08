// cm_home_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'add_elderly_screen.dart';
import 'bed_qr_screen.dart';
import 'cg_roster_screen.dart';
import 'login_screen.dart';

class CmHomeScreen extends StatelessWidget {
  const CmHomeScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    await FirebaseAuth.instance.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
            (route) => false,
      );
    }
  }

  Future<void> _deleteElderly(String elderlyId) async {
    await FirebaseFirestore.instance.collection('elderlies').doc(elderlyId).delete();

    QuerySnapshot favorites = await FirebaseFirestore.instance
        .collection('caregiver_beds')
        .where('elderlyId', isEqualTo: elderlyId)
        .get();

    for (var doc in favorites.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final elderlies = FirebaseFirestore.instance.collection('elderlies');

    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการเตียง/ผู้สูงอายุ'),
        backgroundColor: const Color(0xFF0D3B3E),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            tooltip: 'รายชื่อผู้ดูแลทั้งหมด',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CgRosterScreen()),
              );
            },
          ),
          IconButton(icon: const Icon(Icons.logout), onPressed: () => _logout(context)),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: elderlies.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีเตียงในระบบ'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              String name = data['name'] ?? '';
              String bedNumber = data['bedNumber'] ?? '';
              String relation = data['relation'] ?? '';
              int age = data['age'] ?? 0;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFF0D3B3E),
                    child: Icon(Icons.bed, color: Colors.white),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('เตียง $bedNumber'),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (relation.isNotEmpty) Text('ความสัมพันธ์: $relation'),
                          if (age > 0) Text('อายุ: $age ปี'),
                          const SizedBox(height: 12),
                          const Text('ผู้ดูแลที่บันทึกเตียงนี้ไว้', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _buildCaregiverList(doc.id),
                          const SizedBox(height: 16),
                          Wrap(
                            alignment: WrapAlignment.end,
                            spacing: 8,
                            children: [
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => BedQrScreen(
                                        bedId: doc.id,
                                        elderlyName: name,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.qr_code, color: Color(0xFF0D3B3E)),
                                label: const Text('QR', style: TextStyle(color: Color(0xFF0D3B3E))),
                              ),
                              TextButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => AddElderlyScreen(
                                        elderlyId: doc.id,
                                        initialData: data,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.edit, color: Color(0xFF0D3B3E)),
                                label: const Text('แก้ไข', style: TextStyle(color: Color(0xFF0D3B3E))),
                              ),
                              TextButton.icon(
                                onPressed: () => _deleteElderly(doc.id),
                                icon: const Icon(Icons.delete, color: Colors.red),
                                label: const Text('ลบเตียงนี้', style: TextStyle(color: Colors.red)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
            MaterialPageRoute(builder: (context) => const AddElderlyScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('เพิ่มเตียง'),
      ),
    );
  }

  Widget _buildCaregiverList(String elderlyId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caregiver_beds')
          .where('elderlyId', isEqualTo: elderlyId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('กำลังโหลด...', style: TextStyle(color: Colors.grey));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text('ยังไม่มีผู้ดูแลบันทึกเตียงนี้ไว้', style: TextStyle(color: Colors.grey));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            String caregiverUid = data['caregiverUid'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(caregiverUid).get(),
              builder: (context, userSnap) {
                if (!userSnap.hasData) {
                  return const Text('• กำลังโหลด...');
                }
                if (!userSnap.data!.exists) {
                  return const Text('• (ไม่พบข้อมูลผู้ดูแล)');
                }
                final userData = userSnap.data!.data() as Map<String, dynamic>;
                String name = userData['name'] ?? '';
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text('• $name'),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}