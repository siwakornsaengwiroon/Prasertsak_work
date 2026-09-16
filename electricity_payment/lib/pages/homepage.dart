import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/billing_record_model.dart';
import '../services/database_helper.dart';
import 'billing_entry.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.title});

  final String title;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<BillingRecordModel> billingItems = [];

  // ฟังก์ชันช่วยแปลง String เป็น DateTime แบบปลอดภัย ไม่ให้แอปแดง
  DateTime _parseMonthDate(String monthStr) {
    try {
      return DateFormat("MMMM yyyy").parse(monthStr);
    } catch (_) {
      try {
        return DateFormat("MM/yyyy").parse(monthStr);
      } catch (_) {
        try {
          return DateFormat("M/yyyy").parse(monthStr);
        } catch (_) {
          return DateTime(1970); // คืนค่าวันที่เริ่มต้นหากไม่ตรงรูปแบบใดเลย
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(
          child: Text(widget.title, style: const TextStyle(fontSize: 18)),
        ),
        backgroundColor: Colors.deepPurple,
        foregroundColor: Colors.white,
      ),

      body: StreamBuilder(
        stream: DatabaseHelper().getStreamBillingRecords(),
        builder: (BuildContext context, AsyncSnapshot<QuerySnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No billing records found.'));
          }
          return _buildListView(snapshot);
        },
      ),
      bottomNavigationBar: const BottomAppBar(
        shape: CircularNotchedRectangle(),
        child: Padding(padding: EdgeInsets.all(12.0)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.deepPurple,
        shape: const CircleBorder(),
        tooltip: 'Add Electricity Payment Entry',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => BillingEntry(
                action: 'add',
                billingRecord: BillingRecordModel(
                  userId: 'U001',
                  month: DateFormat('MMMM yyyy').format(DateTime.now()),
                  units: 0,
                  amount: 0.0,
                  paidStatus: 'Paid',
                ),
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // Build the ListView for displaying billing records
  Widget _buildListView(AsyncSnapshot snapshot) {
    billingItems.clear();
    for (var doc in snapshot.data!.docs) {
      billingItems.add(
        BillingRecordModel(
          userId: doc.get('userId'),
          month: doc.get('month'),
          units: doc.get('units') as int,
          amount: doc.get('amount') is int
              ? (doc.get('amount') as int).toDouble()
              : doc.get('amount') as double,
          paidStatus: doc.get('paidStatus'),
          referenceId: doc.id,
        ),
      ); 
    }

    // เรียงลำดับวันที่ด้วยฟังก์ชันปลอดภัย
    billingItems.sort((a, b) {
      DateTime dateA = _parseMonthDate(a.month);
      DateTime dateB = _parseMonthDate(b.month);
      return dateA.compareTo(dateB);
    });

    return ListView.separated(
      itemCount: billingItems.length,
      itemBuilder: (BuildContext context, int index) {
        String titleDate = billingItems[index].month;
        String paidStatusText = billingItems[index].paidStatus == 'Paid'
            ? 'ชำระแล้ว'
            : 'ยังไม่ชำระ';
        String subtitle =
            "หน่วยที่ใช้ ${billingItems[index].units} หน่วย, ${billingItems[index].amount} บาท\n$paidStatusText";
        
        return Dismissible(
          key: Key(billingItems[index].referenceId!),
          
          // Swipe ซ้ายไปขวา (แก้ไขข้อมูล)
          background: Container(
            color: Colors.blue,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.edit, color: Colors.white),
          ),
          
          // Swipe ขวาไปซ้าย (ลบข้อมูล)
          secondaryBackground: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.endToStart) {
              return await _showDeleteDialog(context, billingItems[index].referenceId!);
            } else if (direction == DismissDirection.startToEnd) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BillingEntry(
                    action: 'edit',
                    billingRecord: billingItems[index],
                  ),
                ),
              );
              return false;
            }
            return false;
          },
          child: ListTile(
            title: Text(
              titleDate,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(subtitle, style: const TextStyle(fontSize: 14)),
            onTap: () {},
          ),
        );
      },
      separatorBuilder: (BuildContext context, int index) {
        return const Divider(color: Colors.grey);
      },
    );
  }

  // ป๊อปอัปยืนยันการลบ (Yes/No)
  Future<bool?> _showDeleteDialog(BuildContext context, String docId) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบข้อมูล'),
        content: const Text('คุณต้องการลบรายการนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection(BillingRecordModel.CollectionName)
                  .doc(docId)
                  .delete();
                  
              if (context.mounted) {
                Navigator.pop(context, true);
              }
            },
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}