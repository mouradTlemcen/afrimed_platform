import 'package:flutter/material.dart';

class EditMGPSPage extends StatelessWidget {
  final String mgpsId;
  final Map<String, dynamic> mgpsData;

  const EditMGPSPage({Key? key, required this.mgpsId, required this.mgpsData})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit MGPS: $mgpsId')),
      body: Center(child: Text('EditMGPSPage for $mgpsId')),
    );
  }
}
