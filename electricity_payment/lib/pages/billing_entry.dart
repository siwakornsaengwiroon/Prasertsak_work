import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/billing_record_model.dart';
import '../services/database_helper.dart';
import 'package:month_picker_dialog/month_picker_dialog.dart';

class BillingEntry extends StatefulWidget {
  final BillingRecordModel billingRecord;
  final String action;
  const BillingEntry({
    super.key,
    required this.action,
    required this.billingRecord,
  });

  @override
  State<BillingEntry> createState() => _BillingEntryState();
}

class _BillingEntryState extends State<BillingEntry> {
  late BillingRecordModel newBillingRecord;
  late String title, buttonText;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _monthController = TextEditingController();

  @override
  void initState() {
    super.initState();
    title = widget.action == 'add'
        ? 'Billing Entry (ADD)'
        : 'Billing Entry (EDIT)';
    buttonText = widget.action == 'add' ? 'Add' : 'Update';
    
    // คัดลอกค่าจาก Object เดิมมาใช้
    newBillingRecord = BillingRecordModel(
      userId: widget.billingRecord.userId,
      month: widget.billingRecord.month,
      units: widget.billingRecord.units,
      amount: widget.billingRecord.amount,
      paidStatus: widget.billingRecord.paidStatus,
      referenceId: widget.billingRecord.referenceId,
    );

    if (widget.action == 'edit') {
      _monthController.text = newBillingRecord.month;
    }
  }

  @override
  void dispose() {
    _monthController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              // User ID
              TextFormField(
                initialValue: newBillingRecord.userId,
                decoration: const InputDecoration(
                  labelText: 'รหัสผู้ใช้ไฟฟ้า (User ID)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอก User ID' : null,
                onSaved: (value) => newBillingRecord.userId = value!,
              ),
              const SizedBox(height: 15),

              // Month (with month picker)
              TextFormField(
                controller: _monthController,
                decoration: InputDecoration(
                  labelText: 'เดือน/ปี',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: () async {
                      String pickerDate = await selectMonth();
                      setState(() {
                        newBillingRecord.month = pickerDate;
                        _monthController.text = pickerDate;
                      });
                    },
                  ),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'กรุณากรอกเดือน/ปี' : null,
                onSaved: (value) => newBillingRecord.month = value!,
              ),
              const SizedBox(height: 15),

              // Units
              TextFormField(
                initialValue: widget.action == 'edit' ? newBillingRecord.units.toString() : '',
                decoration: const InputDecoration(
                  labelText: 'จำนวนหน่วย (Units)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value!.isEmpty) return 'กรุณากรอกจำนวนหน่วย';
                  if (int.tryParse(value) == null) {
                    return 'กรุณากรอกเป็นตัวเลขจำนวนเต็ม';
                  }
                  return null;
                },
                onSaved: (value) => newBillingRecord.units = int.parse(value!),
              ),
              const SizedBox(height: 15),

              // Amount
              TextFormField(
                initialValue: widget.action == 'edit' ? newBillingRecord.amount.toString() : '',
                decoration: const InputDecoration(
                  labelText: 'ยอดเงิน (Amount)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (value) {
                  if (value!.isEmpty) return 'กรุณากรอกยอดเงิน';
                  if (double.tryParse(value) == null) {
                    return 'กรุณากรอกเป็นตัวเลขทศนิยม';
                  }
                  return null;
                },
                onSaved: (value) =>
                    newBillingRecord.amount = double.parse(value!),
              ),
              const SizedBox(height: 20),

              // 🌟 สถานะการชำระเงิน (Standard RadioListTile)
              const Text(
                'สถานะการชำระเงิน:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              
              RadioListTile<String>(
                title: const Text('ยังไม่ได้ชำระ (Unpaid)'),
                value: 'Unpaid',
                groupValue: newBillingRecord.paidStatus,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      newBillingRecord.paidStatus = value;
                    });
                  }
                },
              ),
              
              RadioListTile<String>(
                title: const Text('ชำระแล้ว (Paid)'),
                value: 'Paid',
                groupValue: newBillingRecord.paidStatus,
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      newBillingRecord.paidStatus = value;
                    });
                  }
                },
              ),
              
              const SizedBox(height: 30),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: const Text('บันทึกข้อมูล', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      processBillingEntry(newBillingRecord);
    }
  }

  Future<void> processBillingEntry(dynamic billingRecord) async {
    if (widget.action == 'add') {
      try {
        await DatabaseHelper().addBillingRecord(billingRecord);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Billing record added successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to add billing record: $error'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } else if (widget.action == 'edit') {
      try {
        await DatabaseHelper().updateBillingRecord(
          widget.billingRecord.referenceId!,
          billingRecord,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Billing record updated successfully!'),
              duration: Duration(seconds: 2),
            ),
          );
          Navigator.pop(context);
        }
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to update billing record: $error'),
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    }
  }

  Future<String> selectMonth() async {
    final selected = await showMonthPicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2080),
    );
    if (selected != null) {
      return DateFormat('MMMM yyyy').format(selected);
    }
    return DateFormat('MMMM yyyy').format(DateTime.now());
  }
}