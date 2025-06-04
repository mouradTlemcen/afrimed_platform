import 'package:flutter/material.dart';

class EditProjectPage extends StatefulWidget {
  final int projectId;
  const EditProjectPage({Key? key, required this.projectId}) : super(key: key);

  @override
  _EditProjectPageState createState() => _EditProjectPageState();
}

class _EditProjectPageState extends State<EditProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController countryController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Fetch project details by ID and populate fields
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Edit Project')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(labelText: 'Project Name'),
              ),
              TextFormField(
                controller: countryController,
                decoration: InputDecoration(labelText: 'Country'),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    // Update project
                  }
                },
                child: Text('Update Project'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}