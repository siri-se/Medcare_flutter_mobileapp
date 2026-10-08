// schedule_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'add_medicine_screen.dart';
import 'medicine_colors.dart';

class ScheduleScreen extends StatefulWidget {
  final String elderlyId;

  const ScheduleScreen({super.key, required this.elderlyId});

  @override
  State<ScheduleScreen> createState() {
    return _ScheduleScreenState();
  }
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  String _formatStartDate(Map<String, dynamic> data) {
    Timestamp? ts = data['startDate'];
    if (ts == null) return 'ไม่ระบุ';

    DateTime d = ts.toDate();
    String dateStr = '${d.day}/${d.month}/${d.year}';

    String type = data['scheduleType'] ?? '';
    if (type == 'repeat') {
      String? startTime = data['repeatStartTime'];
      if (startTime != null) {
        return '$dateStr เวลา $startTime';
      }
    }

    return dateStr;
  }
  String _describeSchedule(Map<String, dynamic> data) {
    String type = data['scheduleType'] ?? '';
    if (type == 'meal') {
      List meals = data['meals'] ?? [];
      String timing = data['mealTiming'] == 'before'
          ? 'ก่อนอาหาร'
          : data['mealTiming'] == 'after'
          ? 'หลังอาหาร'
          : 'พร้อมอาหาร';
      return '${meals.join(', ')} • $timing';
    } else if (type == 'repeat') {
      return 'ทุก ${data['repeatHours']} ชั่วโมง';
    } else if (type == 'beforeBed') {
      return 'ก่อนนอน 15-30 นาที';
    }
    return '';
  }

  Future<void> _removeMedicine(String medicineId) async {
    await FirebaseFirestore.instance.collection('medicines').doc(medicineId).delete();

    QuerySnapshot relatedReminders = await FirebaseFirestore.instance
        .collection('reminders')
        .where('medicineId', isEqualTo: medicineId)
        .get();

    for (var doc in relatedReminders.docs) {
      await doc.reference.delete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final medicines = FirebaseFirestore.instance
        .collection('medicines')
        .where('elderlyId', isEqualTo: widget.elderlyId);

    return Scaffold(
      appBar: AppBar(
        title: const Text('ตั้งเวลายา'),
        backgroundColor: const Color(0xFF0D3B3E),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddMedicineScreen(elderlyId: widget.elderlyId),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: medicines.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีรายการยา'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;

              String name = data['name'] ?? '';
              String imageUrl = data['imageUrl'] ?? '';
              String dosage = data['dosage'] ?? '';
              int total = data['totalQuantity'] ?? 0;
              int remaining = data['remainingQuantity'] ?? 0;
              bool isEmpty = remaining <= 0;
              Color accentColor = getMedicineColor(doc.id);

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: accentColor, width: 6)),
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
                  // ส่วนหุบ — โชว์แค่ชื่อกับจำนวนคงเหลือ
                  leading: imageUrl.isEmpty
                      ? const CircleAvatar(child: Icon(Icons.medication))
                      : CircleAvatar(backgroundImage: NetworkImage(imageUrl)),
                  title: Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isEmpty ? 'หมดแล้ว' : 'คงเหลือ $remaining',
                        style: TextStyle(
                          color: isEmpty ? Colors.red : const Color(0xFF0D3B3E),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.expand_more),
                    ],
                  ),
                  // ส่วนขยาย — รายละเอียดเต็ม
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl.isNotEmpty)
                            Center(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.network(
                                  imageUrl,
                                  height: 160,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            name,
                            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dosage,
                            style: const TextStyle(color: Colors.black, fontSize: 14),
                          ),
                          const SizedBox(height: 16),
                          _infoRow('เวลาที่กิน', _describeSchedule(data)),
                          _infoRow('เริ่มกินยา', _formatStartDate(data)),
                          _infoRow('จำนวนที่จ่ายทั้งหมด', '$total เม็ด'),
                          _infoRow(
                            'คงเหลือ',
                            isEmpty ? 'หมดแล้ว' : '$remaining เม็ด',
                            valueColor: isEmpty ? Colors.red : null,
                          ),
                          if ((data['doctorName'] ?? '').isNotEmpty)
                            _infoRow('แพทย์ผู้สั่งจ่าย', data['doctorName']),
                          if ((data['doctorPhone'] ?? '').isNotEmpty)
                            _infoRow('เบอร์ติดต่อ', data['doctorPhone']),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.  icon(
                              onPressed: () => _removeMedicine(doc.id),
                              icon: const Icon(Icons.delete, color: Colors.red),
                              label: const Text('ลบรายการนี้', style: TextStyle(color: Colors.red)),
                            ),
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
    );
  }

  Widget _infoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontWeight: FontWeight.bold, color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}