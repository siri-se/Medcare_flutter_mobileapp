// cg_roster_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class CgRosterScreen extends StatelessWidget {
  const CgRosterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final caregivers = FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'CG');

    return Scaffold(
      appBar: AppBar(
        title: const Text('รายชื่อผู้ดูแลทั้งหมด'),
        backgroundColor: const Color(0xFF0D3B3E),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: caregivers.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีผู้ดูแลในระบบ'));
          }

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              String name = data['name'] ?? '';
              String email = data['email'] ?? '';

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
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(email),
                  trailing: _buildBedCountBadge(doc.id),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: _buildBedList(doc.id),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBedCountBadge(String caregiverUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caregiver_beds')
          .where('caregiverUid', isEqualTo: caregiverUid)
          .snapshots(),
      builder: (context, snapshot) {
        int count = snapshot.hasData ? snapshot.data!.docs.length : 0;
        return Text('$count เตียง', style: const TextStyle(fontWeight: FontWeight.bold));
      },
    );
  }

  Widget _buildBedList(String caregiverUid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('caregiver_beds')
          .where('caregiverUid', isEqualTo: caregiverUid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Text('กำลังโหลด...', style: TextStyle(color: Colors.grey));
        }

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) {
          return const Text('ยังไม่ได้รับผิดชอบเตียงไหนเลย', style: TextStyle(color: Colors.grey));
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            String elderlyId = data['elderlyId'] ?? '';

            return FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('elderlies').doc(elderlyId).get(),
              builder: (context, elderlySnap) {
                if (!elderlySnap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('• กำลังโหลด...'),
                  );
                }

                if (!elderlySnap.data!.exists) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('• (เตียงนี้ถูกลบไปแล้ว)', style: TextStyle(color: Colors.grey)),
                  );
                }

                final elderlyData = elderlySnap.data!.data() as Map<String, dynamic>;
                String bedNumber = elderlyData['bedNumber'] ?? '';
                String elderlyName = elderlyData['name'] ?? '';

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.bed, size: 18, color: Color(0xFF0D3B3E)),
                      const SizedBox(width: 8),
                      Text(
                        'เตียง $bedNumber',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 8),
                      Text('— $elderlyName'),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}