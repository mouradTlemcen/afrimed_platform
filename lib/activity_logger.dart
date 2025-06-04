import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> logActivity({
  required String userId,
  required String action,
  String details = '',
}) async {
  await FirebaseFirestore.instance.collection('activity_logs').add({
    'userId': userId,
    'action': action,
    'details': details,
    'timestamp': FieldValue.serverTimestamp(),
  });
}
