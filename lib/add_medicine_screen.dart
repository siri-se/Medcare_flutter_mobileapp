// add_medicine_screen.dart
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMedicineScreen extends StatefulWidget {
  final String elderlyId;

  const AddMedicineScreen({
    super.key,
    required this.elderlyId,
  });

  @override
  State<AddMedicineScreen> createState() {
    return _AddMedicineScreenState();
  }
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _nameController = TextEditingController();
  final _dosageController = TextEditingController();
  final _totalQuantityController = TextEditingController();
  final _dosePerTakeController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _doctorPhoneController = TextEditingController();

  File? _selectedImage;
  bool _isUploading = false;

  String _scheduleType = 'meal';

  bool _mealMorning = false;
  bool _mealNoon = false;
  bool _mealEvening = false;
  String _mealTiming = 'before';
  Map<String, TimeOfDay> _mealTimes = {};

  int _repeatHours = 4;
  TimeOfDay? _repeatStartTime;

  TimeOfDay? _bedTime;

  DateTime _startDate = DateTime.now();

  // ---------- รูปภาพ ----------

  Future<void> _pickImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
      });
    }
  }

  Future<String?> _uploadImage() async {
    if (_selectedImage == null) return null;

    String fileName =
    DateTime.now().millisecondsSinceEpoch.toString();

    Reference ref = FirebaseStorage.instance
        .ref()
        .child('medicine_images/$fileName.jpg');

    await ref.putFile(_selectedImage!);

    return await ref.getDownloadURL();
  }

  // ---------- วันที่ / เวลา ----------

  Future<void> _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(
        const Duration(days: 365),
      ),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
      });
    }
  }

  Future<void> _pickMealTime(String meal) async {
    TimeOfDay initial =
        _mealTimes[meal] ??
            const TimeOfDay(hour: 8, minute: 0);

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        _mealTimes[meal] = picked;
      });
    }
  }

  Future<void> _pickRepeatStartTime() async {
    TimeOfDay initial =
        _repeatStartTime ?? TimeOfDay.now();

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        _repeatStartTime = picked;
      });
    }
  }

  Future<void> _pickBedTime() async {
    TimeOfDay initial =
        _bedTime ??
            const TimeOfDay(hour: 22, minute: 0);

    TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );

    if (picked != null) {
      setState(() {
        _bedTime = picked;
      });
    }
  }

  String _formatTimeOfDay(TimeOfDay t) {
    String hh = t.hour.toString().padLeft(2, '0');
    String mm = t.minute.toString().padLeft(2, '0');

    return '$hh:$mm';
  }

  String _formatDate(DateTime d) {
    return '${d.day}/${d.month}/${d.year}';
  }

  String _dateKeyFor(DateTime d) {
    return '${d.year}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  DateTime _combineDateWithTime(
      DateTime date,
      String hhmm,
      ) {
    List<String> parts = hhmm.split(':');

    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  // ---------- validation ----------

  bool _validate() {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณากรอกชื่อยา'),
        ),
      );

      return false;
    }

    if (_scheduleType == 'meal') {
      List<String> meals = [];

      if (_mealMorning) meals.add('เช้า');
      if (_mealNoon) meals.add('กลางวัน');
      if (_mealEvening) meals.add('เย็น');

      if (meals.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกอย่างน้อย 1 มื้อ'),
          ),
        );

        return false;
      }

      for (String meal in meals) {
        if (_mealTimes[meal] == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'กรุณาเลือกเวลาสำหรับมื้อ$meal',
              ),
            ),
          );

          return false;
        }
      }
    } else if (_scheduleType == 'repeat') {
      if (_repeatStartTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกเวลามื้อแรก'),
          ),
        );

        return false;
      }
    } else if (_scheduleType == 'beforeBed') {
      if (_bedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกเวลาเข้านอน'),
          ),
        );

        return false;
      }
    }

    return true;
  }

  // ---------- บันทึก ----------

  Future<void> _saveMedicine() async {
    if (!_validate()) return;

    setState(() {
      _isUploading = true;
    });

    try {
      String? imageUrl = await _uploadImage();

      int totalQuantity =
          int.tryParse(
            _totalQuantityController.text,
          ) ??
              0;

      int dosePerTake =
          int.tryParse(
            _dosePerTakeController.text,
          ) ??
              1;

      Map<String, dynamic> data = {
        'elderlyId': widget.elderlyId,
        'name': _nameController.text,
        'dosage': _dosageController.text,
        'imageUrl': imageUrl ?? '',
        'scheduleType': _scheduleType,
        'totalQuantity': totalQuantity,
        'dosePerTake': dosePerTake,
        'remainingQuantity': totalQuantity,
        'startDate': Timestamp.fromDate(_startDate),
        'doctorName': _doctorNameController.text,
        'doctorPhone': _doctorPhoneController.text,
        'createdByUid': FirebaseAuth.instance.currentUser?.uid,
      };

      if (_scheduleType == 'meal') {
        List<String> meals = [];

        if (_mealMorning) meals.add('เช้า');
        if (_mealNoon) meals.add('กลางวัน');
        if (_mealEvening) meals.add('เย็น');

        Map<String, String> mealTimesData = {};

        for (String meal in meals) {
          mealTimesData[meal] =
              _formatTimeOfDay(_mealTimes[meal]!);
        }

        data['meals'] = meals;
        data['mealTiming'] = _mealTiming;
        data['mealTimes'] = mealTimesData;
      } else if (_scheduleType == 'repeat') {
        data['repeatHours'] = _repeatHours;

        data['repeatStartTime'] =
            _formatTimeOfDay(_repeatStartTime!);
      } else if (_scheduleType == 'beforeBed') {
        data['bedTime'] =
            _formatTimeOfDay(_bedTime!);
      }

      DocumentReference medicineRef =
      await FirebaseFirestore.instance
          .collection('medicines')
          .add(data);

      await _createReminders(medicineRef.id);

      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
          ),
        );
      }
    }
  }

  // ---------- สร้าง Reminder ใน Firestore ----------

  Future<void> _createReminders(
      String medicineId,
      ) async {
    final remindersCollection =
    FirebaseFirestore.instance.collection('reminders');

    String startDateKey = _dateKeyFor(_startDate);

    if (_scheduleType == 'meal') {
      List<String> meals = [];

      if (_mealMorning) meals.add('เช้า');
      if (_mealNoon) meals.add('กลางวัน');
      if (_mealEvening) meals.add('เย็น');

      String timingLabel =
      _mealTiming == 'before'
          ? 'ก่อนอาหาร'
          : _mealTiming == 'after'
          ? 'หลังอาหาร'
          : 'พร้อมอาหาร';

      for (String meal in meals) {
        String timeStr =
        _formatTimeOfDay(_mealTimes[meal]!);

        DateTime scheduledTime =
        _combineDateWithTime(
          _startDate,
          timeStr,
        );

        await remindersCollection.add({
          'elderlyId': widget.elderlyId,
          'medicineId': medicineId,
          'name': _nameController.text,
          'time':
          '$meal • $timingLabel (${_formatDate(_startDate)} $timeStr)',
          'scheduleType': 'meal',
          'mealName': meal,
          'scheduledTime':
          Timestamp.fromDate(scheduledTime),
          'dateKey': startDateKey,
          'isDone': false,
          'isOverdue': false,
        });
      }
    } else if (_scheduleType == 'repeat') {
      String startTimeStr =
      _formatTimeOfDay(_repeatStartTime!);

      DateTime scheduledTime =
      _combineDateWithTime(
        _startDate,
        startTimeStr,
      );

      await remindersCollection.add({
        'elderlyId': widget.elderlyId,
        'medicineId': medicineId,
        'name': _nameController.text,
        'time':
        'ทุก $_repeatHours ชั่วโมง (${_formatDate(_startDate)} $startTimeStr)',
        'scheduleType': 'repeat',
        'repeatHours': _repeatHours,
        'scheduledTime':
        Timestamp.fromDate(scheduledTime),
        'dateKey': startDateKey,
        'isDone': false,
        'isOverdue': false,
      });
    } else if (_scheduleType == 'beforeBed') {
      String bedTimeStr =
      _formatTimeOfDay(_bedTime!);

      DateTime bedDateTime =
      _combineDateWithTime(
        _startDate,
        bedTimeStr,
      );

      DateTime scheduledTime =
      bedDateTime.subtract(
        const Duration(minutes: 20),
      );

      await remindersCollection.add({
        'elderlyId': widget.elderlyId,
        'medicineId': medicineId,
        'name': _nameController.text,
        'time':
        'ก่อนนอน 15-30 นาที (ราว $bedTimeStr)',
        'scheduleType': 'beforeBed',
        'scheduledTime':
        Timestamp.fromDate(scheduledTime),
        'dateKey': startDateKey,
        'isDone': false,
        'isOverdue': false,
      });
    }
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('เพิ่มรายการยา'),
        backgroundColor:
        const Color(0xFF0D3B3E),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius:
                BorderRadius.circular(12),
              ),
              child: _selectedImage == null
                  ? const Center(
                child: Icon(
                  Icons.add_a_photo,
                  size: 40,
                ),
              )
                  : ClipRRect(
                borderRadius:
                BorderRadius.circular(12),
                child: Image.file(
                  _selectedImage!,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'ชื่อยา',
            ),
          ),

          TextField(
            controller: _dosageController,
            decoration: const InputDecoration(
              labelText:
              'คำอธิบายปริมาณ (เช่น 1 เม็ด)',
            ),
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextField(
                  controller:
                  _totalQuantityController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'จำนวนที่จ่ายทั้งหมด',
                  ),
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: TextField(
                  controller:
                  _dosePerTakeController,
                  keyboardType:
                  TextInputType.number,
                  decoration:
                  const InputDecoration(
                    labelText:
                    'กินต่อครั้ง (เม็ด)',
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          TextField(
            controller: _doctorNameController,
            decoration: const InputDecoration(
              labelText:
              'ชื่อแพทย์ผู้สั่งจ่าย (ถ้ามี)',
            ),
          ),

          TextField(
            controller: _doctorPhoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText:
              'เบอร์โทรติดต่อ (ถ้ามี)',
            ),
          ),

          const SizedBox(height: 20),

          ListTile(
            contentPadding: EdgeInsets.zero,
            leading:
            const Icon(Icons.calendar_today),
            title:
            const Text('วันที่เริ่มยา'),
            trailing: Text(
              _formatDate(_startDate),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: _pickStartDate,
          ),

          const SizedBox(height: 12),

          const Text(
            'เวลาที่ต้องใช้ยา',
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          RadioListTile<String>(
            title: const Text(
              'ทานตามมื้อเช้า-กลางวัน-เย็น',
            ),
            value: 'meal',
            groupValue: _scheduleType,
            onChanged: (value) {
              setState(() {
                _scheduleType = value!;
              });
            },
          ),

          RadioListTile<String>(
            title: const Text(
              'ทานซ้ำทุก x ชั่วโมง',
            ),
            value: 'repeat',
            groupValue: _scheduleType,
            onChanged: (value) {
              setState(() {
                _scheduleType = value!;
              });
            },
          ),

          RadioListTile<String>(
            title: const Text('ก่อนนอน'),
            value: 'beforeBed',
            groupValue: _scheduleType,
            onChanged: (value) {
              setState(() {
                _scheduleType = value!;
              });
            },
          ),

          if (_scheduleType == 'meal') ...[
            _mealCheckboxRow(
              'เช้า',
              _mealMorning,
                  (v) => setState(
                    () => _mealMorning = v!,
              ),
            ),

            _mealCheckboxRow(
              'กลางวัน',
              _mealNoon,
                  (v) => setState(
                    () => _mealNoon = v!,
              ),
            ),

            _mealCheckboxRow(
              'เย็น',
              _mealEvening,
                  (v) => setState(
                    () => _mealEvening = v!,
              ),
            ),

            const SizedBox(height: 8),

            DropdownButton<String>(
              value: _mealTiming,
              items: const [
                DropdownMenuItem(
                  value: 'before',
                  child: Text('ก่อนอาหาร'),
                ),
                DropdownMenuItem(
                  value: 'with',
                  child: Text('พร้อมอาหาร'),
                ),
                DropdownMenuItem(
                  value: 'after',
                  child: Text('หลังอาหาร'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _mealTiming = value!;
                });
              },
            ),
          ],

          if (_scheduleType == 'repeat') ...[
            const SizedBox(height: 8),

            DropdownButton<int>(
              value: _repeatHours,
              items: List.generate(
                6,
                    (i) => i + 1,
              ).map((hour) {
                return DropdownMenuItem(
                  value: hour,
                  child: Text(
                    'ทุก $hour ชั่วโมง',
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _repeatHours = value!;
                });
              },
            ),

            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
              const Text('เวลาเริ่มมื้อแรก'),
              trailing: Text(
                _repeatStartTime == null
                    ? 'ยังไม่เลือก'
                    : _formatTimeOfDay(
                  _repeatStartTime!,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _pickRepeatStartTime,
            ),
          ],

          if (_scheduleType == 'beforeBed') ...[
            const Padding(
              padding: EdgeInsets.only(
                top: 8,
                bottom: 8,
              ),
              child: Text(
                'จะแจ้งเตือนก่อนเวลาเข้านอน 15-30 นาที',
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title:
              const Text('เวลาเข้านอนปกติ'),
              trailing: Text(
                _bedTime == null
                    ? 'ยังไม่เลือก'
                    : _formatTimeOfDay(
                  _bedTime!,
                ),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: _pickBedTime,
            ),
          ],

          const SizedBox(height: 24),

          ElevatedButton(
            onPressed:
            _isUploading ? null : _saveMedicine,
            style: ElevatedButton.styleFrom(
              backgroundColor:
              const Color(0xFF0D3B3E),
              minimumSize:
              const Size(double.infinity, 48),
            ),
            child: _isUploading
                ? const CircularProgressIndicator(
              color: Colors.white,
            )
                : const Text('บันทึก'),
          ),
        ],
      ),
    );
  }

  Widget _mealCheckboxRow(
      String meal,
      bool value,
      ValueChanged<bool?> onChanged,
      ) {
    return Row(
      children: [
        Expanded(
          child: CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(meal),
            value: value,
            onChanged: onChanged,
          ),
        ),

        if (value)
          TextButton(
            onPressed: () => _pickMealTime(meal),
            child: Text(
              _mealTimes[meal] == null
                  ? 'เลือกเวลา'
                  : _formatTimeOfDay(
                _mealTimes[meal]!,
              ),
            ),
          ),
      ],
    );
  }
}