import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AddUserPage extends StatefulWidget {
  @override
  _AddUserPageState createState() => _AddUserPageState();
}

class _AddUserPageState extends State<AddUserPage> {
  final _formKey = GlobalKey<FormState>();

  // Basic details controllers
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController  = TextEditingController();
  final TextEditingController emailController     = TextEditingController();
  final TextEditingController passwordController  = TextEditingController();

  // Additional personal details
  final TextEditingController phoneController = TextEditingController();
  DateTime? dob; // Date of Birth
  String? gender = "Male";

  // Address / Location – default value is "Default Location"
  final TextEditingController addressController = TextEditingController(text: "Default Location");

  // Work details
  // Updated department options include additional departments
  String? department = "HR";

  // New field for role
  String? role = "Visitor";

  // Reporting and expertise details (Domain of Expertise)
  // --- ADDED "MGPS" HERE ---
  Map<String, bool> expertiseOptions = {
    "Electrical engineering skills": false,
    "Mechanical engineering skills": false,
    "Full PSA skills": false,
    "Construction design and architecture skills": false,
    "IT skills": false,
    "Management skills": false,
    "Administration skills": false,
    "Tender preparation skills": false,
    "MGPS": false,         // <--- NEW SKILL
    "Other": false,
  };

  final TextEditingController otherExpertiseController = TextEditingController();

  // Employment details
  String employmentType = 'Full-Time';
  String selectedPosition = 'Technician';
  DateTime? startDate;

  // Profile picture fields
  XFile? pickedProfileImage;

  // CV file fields
  PlatformFile? pickedCVFile;

  bool isLoading = false;

  // --- Date pickers ---
  Future<void> _pickDOB() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        dob = picked;
      });
    }
  }

  Future<void> _pickStartDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        startDate = picked;
      });
    }
  }

  // --- Input decoration helper ---
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.0)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      errorStyle: const TextStyle(color: Colors.red),
    );
  }

  // --- Employee ID Generator ---
  String _generateEmployeeID() {
    if (firstNameController.text.isNotEmpty &&
        dob != null &&
        addressController.text.length >= 3) {
      String namePart = firstNameController.text.trim().replaceAll(" ", "");
      String dayPart = dob!.day.toString().padLeft(2, '0');
      String addressPart = addressController.text.trim().substring(0, 3).toUpperCase();
      return "$namePart\_$dayPart\_$addressPart";
    }
    return "UNDEFINED";
  }

  // --- Pick Profile Picture using ImagePicker ---
  Future<void> _pickProfileImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          pickedProfileImage = pickedFile;
        });
      }
    } catch (e) {
      print("Error picking profile image: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking profile image: $e")),
      );
    }
  }

  // --- Pick CV File (PDF/Word) using FilePicker ---
  Future<void> _pickCVFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx'],
      );
      if (result != null && result.files.isNotEmpty) {
        setState(() {
          pickedCVFile = result.files.first;
        });
      }
    } catch (e) {
      print("Error picking CV file: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking CV file: $e")),
      );
    }
  }

  // --- Upload Profile Picture to Firebase Storage ---
  Future<String?> _uploadProfilePicture(String userId) async {
    if (pickedProfileImage == null) return null;
    try {
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${pickedProfileImage!.name}";
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("profilePictures")
          .child(userId)
          .child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        final bytes = await pickedProfileImage!.readAsBytes();
        snapshot = await storageRef.putData(bytes);
      } else {
        final File localFile = File(pickedProfileImage!.path);
        snapshot = await storageRef.putFile(localFile);
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading profile picture: $e");
      return null;
    }
  }

  // --- Upload CV to Firebase Storage ---
  Future<String?> _uploadCVFile(String userId) async {
    if (pickedCVFile == null) return null;
    try {
      final String fileName = "${DateTime.now().millisecondsSinceEpoch}_${pickedCVFile!.name}";
      final Reference storageRef = FirebaseStorage.instance
          .ref()
          .child("cvDocuments")
          .child(userId)
          .child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        final fileBytes = pickedCVFile!.bytes;
        if (fileBytes == null) throw Exception("No file bytes found for CV");
        snapshot = await storageRef.putData(fileBytes);
      } else {
        final filePath = pickedCVFile!.path;
        if (filePath == null) throw Exception("No file path found for CV");
        final File localFile = File(filePath);
        snapshot = await storageRef.putFile(localFile);
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading CV: $e");
      return null;
    }
  }

  // --- Add User ---
  void addUser() async {
    if (!_formKey.currentState!.validate() ||
        dob == null ||
        gender == null ||
        department == null ||
        startDate == null ||
        role == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all required fields.")),
      );
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      // Create the user via Firebase Auth.
      UserCredential userCredential =
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );
      String userId = userCredential.user!.uid;
      String computedEmployeeID = _generateEmployeeID();

      // Upload profile picture (if any)
      String? profilePicUrl = await _uploadProfilePicture(userId);
      // Upload CV (if any)
      String? cvUrl = await _uploadCVFile(userId);

      // Prepare the domain of expertise list based on selected options.
      List<String> selectedExpertise = [];
      expertiseOptions.forEach((key, value) {
        if (value) {
          if (key == "Other" && otherExpertiseController.text.trim().isNotEmpty) {
            selectedExpertise.add(otherExpertiseController.text.trim());
          } else if (key != "Other") {
            selectedExpertise.add(key);
          }
        }
      });

      // Save personnel details in Firestore.
      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'firstName': firstNameController.text.trim(),
        'lastName': lastNameController.text.trim(),
        'email': emailController.text.trim(),
        'password': passwordController.text.trim(), // Storing password (consider security best practices)
        'phone': phoneController.text.trim(),
        'dateOfBirth': dob!.toIso8601String().split('T')[0],
        'gender': gender,
        'address': addressController.text.trim(),
        'department': department,
        'role': role, // New role field
        'employeeID': computedEmployeeID,
        'domainsOfExpertise': selectedExpertise,
        'position': selectedPosition,
        'employmentType': employmentType,
        'startDate': startDate!.toIso8601String().split('T')[0],
        // New fields for profile picture and CV.
        'profileImageUrl': profilePicUrl,
        'cvUrl': cvUrl,
        'has_tasks': 'NO',
      });

      // Optionally, create a default displacement record.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('displacements')
          .add({
        'location': addressController.text.trim(),
        'gpsLocation': {'latitude': 0.0, 'longitude': 0.0},
        'details': 'Default displacement record',
        'startDate': '',
        'endDate': '',
        'addedDate': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User added successfully.")),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to add user: $e")),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Personnel'),
        backgroundColor: const Color(0xFF003366),
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          margin: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Page heading
                  Text(
                    'Enter Personnel Details',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF003366)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Basic Information
                  TextFormField(
                    controller: firstNameController,
                    decoration: _inputDecoration('First Name'),
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: lastNameController,
                    decoration: _inputDecoration('Last Name'),
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: emailController,
                    decoration: _inputDecoration('Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: passwordController,
                    decoration: _inputDecoration('Password'),
                    obscureText: true,
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Contact Details
                  TextFormField(
                    controller: phoneController,
                    decoration: _inputDecoration('Phone Number'),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Date of Birth Picker
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          dob == null
                              ? 'No Date of Birth selected'
                              : 'DOB: ${dob!.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickDOB,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0073E6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Select DOB'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: gender,
                    onChanged: (value) {
                      setState(() {
                        gender = value;
                      });
                    },
                    items: ['Male', 'Female', 'Other']
                        .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                        .toList(),
                    decoration: _inputDecoration('Gender'),
                    validator: (value) =>
                    value == null ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Address / Location (editable)
                  TextFormField(
                    controller: addressController,
                    decoration: _inputDecoration('Address / Location'),
                    validator: (value) =>
                    value!.isEmpty ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Department / Team Dropdown
                  DropdownButtonFormField<String>(
                    value: department,
                    onChanged: (value) {
                      setState(() {
                        department = value;
                      });
                    },
                    items: [
                      'HR',
                      'Sales',
                      'Engineering',
                      'Finance',
                      'Operations',
                      'Management',
                      'Legal',
                      'Marketing'
                    ]
                        .map(
                          (dep) =>
                          DropdownMenuItem(value: dep, child: Text(dep)),
                    )
                        .toList(),
                    decoration: _inputDecoration('Department / Team'),
                    validator: (value) =>
                    value == null ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Role Dropdown Field
                  DropdownButtonFormField<String>(
                    value: role,
                    onChanged: (value) {
                      setState(() {
                        role = value;
                      });
                    },
                    items: ['admin', 'Technician', 'field manager', 'Visitor']
                        .map((roleValue) => DropdownMenuItem(
                      value: roleValue,
                      child: Text(roleValue),
                    ))
                        .toList(),
                    decoration: _inputDecoration('Role'),
                    validator: (value) =>
                    value == null ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Domain of Expertise Section
                  const Text(
                    "Domain of Expertise",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: expertiseOptions.keys.map((option) {
                      return FilterChip(
                        label: Text(
                          option,
                          style: TextStyle(
                            color: option == "Other" ? Colors.orange : Colors.black,
                            fontSize: 12,
                          ),
                        ),
                        selected: expertiseOptions[option]!,
                        onSelected: (selected) {
                          setState(() {
                            expertiseOptions[option] = selected;
                          });
                        },
                      );
                    }).toList(),
                  ),
                  if (expertiseOptions["Other"] == true)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: TextFormField(
                        controller: otherExpertiseController,
                        decoration: _inputDecoration('Other Expertise (please specify)'),
                      ),
                    ),
                  const SizedBox(height: 16),

                  // Position
                  DropdownButtonFormField<String>(
                    value: selectedPosition,
                    onChanged: (value) {
                      setState(() {
                        selectedPosition = value!;
                      });
                    },
                    items: [
                      'Local Hospital operator',
                      'Technician',
                      'Engineer',
                      'Site Manager',
                      'Project Manager',
                      'Program Manager',
                      'Tender departement Manager',
                      'Clients relationships Manager',
                      'Suppliers relationships Manager',
                      'Operations Manager',
                      'Top Manager',
                      'Admin'
                    ].map((pos) => DropdownMenuItem(value: pos, child: Text(pos))).toList(),
                    decoration: _inputDecoration('Position'),
                    validator: (value) => value == null ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Employment Type
                  DropdownButtonFormField<String>(
                    value: employmentType,
                    onChanged: (value) {
                      setState(() {
                        employmentType = value!;
                      });
                    },
                    items: ['Full-Time', 'Part-Time']
                        .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    decoration: _inputDecoration('Employment Type'),
                    validator: (value) => value == null ? 'This field is required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Start Date
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          startDate == null
                              ? 'No start date selected'
                              : 'Start Date: ${startDate!.toLocal().toString().split(' ')[0]}',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _pickStartDate,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0073E6),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('Choose Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Profile Picture
                  const Text(
                    "Profile Picture (Optional)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickProfileImage,
                        icon: const Icon(Icons.camera_alt),
                        label: const Text("Select Picture"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D1B3D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pickedProfileImage == null
                              ? "No picture selected"
                              : pickedProfileImage!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // CV Document
                  const Text(
                    "CV Document (PDF/Word) (Optional)",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: _pickCVFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text("Select CV"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D1B3D),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          pickedCVFile == null
                              ? "No CV selected"
                              : pickedCVFile!.name ?? "Unnamed file",
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Submit Button
                  isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton.icon(
                    onPressed: addUser,
                    icon: const Icon(Icons.save),
                    label: const Text(
                      'Add Personnel',
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF003366),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
