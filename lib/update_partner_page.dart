import 'dart:io' show File;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UpdatePartnerPage extends StatefulWidget {
  final String partnerId;

  const UpdatePartnerPage({Key? key, required this.partnerId}) : super(key: key);

  @override
  _UpdatePartnerPageState createState() => _UpdatePartnerPageState();
}

class _UpdatePartnerPageState extends State<UpdatePartnerPage> {
  /// A key to identify the form and track validation state.
  final _formKey = GlobalKey<FormState>();

  /// Whether we are currently loading data or performing an update.
  bool isLoading = false;

  /// Data fetched from Firestore for the given partner.
  Map<String, dynamic>? partnerData;

  // Basic info controllers
  final TextEditingController nameController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController commentController = TextEditingController();


  // Contact details
  final TextEditingController contactEmailController = TextEditingController();
  final TextEditingController contactPhoneController = TextEditingController();

  // Supplier details
  final TextEditingController serviceNameController = TextEditingController();
  final TextEditingController brandNameController = TextEditingController();

  // Persons in organization
  List<Map<String, String>> persons = [];

  // Dropdown selections
  String selectedPartnershipType = '';
  String selectedCountry = "Select Country";

  // Potentially updated partner logo file
  XFile? partnerLogo;

  // List of countries (same as in AddPartnerPage)
  final List<String> _countries = [
    "Select Country",
    "Afghanistan",
    "Albania",
    "Algeria",
    "Andorra",
    "Angola",
    "Antigua and Barbuda",
    "Argentina",
    "Armenia",
    "Australia",
    "Austria",
    "Azerbaijan",
    "Bahamas",
    "Bahrain",
    "Bangladesh",
    "Barbados",
    "Belarus",
    "Belgium",
    "Belize",
    "Benin",
    "Bhutan",
    "Bolivia",
    "Bosnia and Herzegovina",
    "Botswana",
    "Brazil",
    "Brunei",
    "Bulgaria",
    "Burkina Faso",
    "Burundi",
    "Côte d'Ivoire",
    "Cabo Verde",
    "Cambodia",
    "Cameroon",
    "Canada",
    "Central African Republic",
    "Chad",
    "Chile",
    "China",
    "Colombia",
    "Comoros",
    "Congo (Congo-Brazzaville)",
    "Costa Rica",
    "Croatia",
    "Cuba",
    "Cyprus",
    "Czechia (Czech Republic)",
    "Democratic Republic of the Congo",
    "Denmark",
    "Djibouti",
    "Dominica",
    "Dominican Republic",
    "Ecuador",
    "Egypt",
    "El Salvador",
    "Equatorial Guinea",
    "Eritrea",
    "Estonia",
    "Eswatini (fmr. 'Swaziland')",
    "Ethiopia",
    "Fiji",
    "Finland",
    "France",
    "Gabon",
    "Gambia",
    "Georgia",
    "Germany",
    "Ghana",
    "Greece",
    "Grenada",
    "Guatemala",
    "Guinea",
    "Guinea-Bissau",
    "Guyana",
    "Haiti",
    "Holy See",
    "Honduras",
    "Hungary",
    "Iceland",
    "India",
    "Indonesia",
    "Iran",
    "Iraq",
    "Ireland",
    "Israel",
    "Italy",
    "Jamaica",
    "Japan",
    "Jordan",
    "Kazakhstan",
    "Kenya",
    "Kiribati",
    "Kuwait",
    "Kyrgyzstan",
    "Laos",
    "Latvia",
    "Lebanon",
    "Lesotho",
    "Liberia",
    "Libya",
    "Liechtenstein",
    "Lithuania",
    "Luxembourg",
    "Madagascar",
    "Malawi",
    "Malaysia",
    "Maldives",
    "Mali",
    "Malta",
    "Marshall Islands",
    "Mauritania",
    "Mauritius",
    "Mexico",
    "Micronesia",
    "Moldova",
    "Monaco",
    "Mongolia",
    "Montenegro",
    "Morocco",
    "Mozambique",
    "Myanmar (formerly Burma)",
    "Namibia",
    "Nauru",
    "Nepal",
    "Netherlands",
    "New Zealand",
    "Nicaragua",
    "Niger",
    "Nigeria",
    "North Korea",
    "North Macedonia",
    "Norway",
    "Oman",
    "Pakistan",
    "Palau",
    "Palestine State",
    "Panama",
    "Papua New Guinea",
    "Paraguay",
    "Peru",
    "Philippines",
    "Poland",
    "Portugal",
    "Qatar",
    "Romania",
    "Russia",
    "Rwanda",
    "Saint Kitts and Nevis",
    "Saint Lucia",
    "Saint Vincent and the Grenadines",
    "Samoa",
    "San Marino",
    "Sao Tome and Principe",
    "Saudi Arabia",
    "Senegal",
    "Serbia",
    "Seychelles",
    "Sierra Leone",
    "Singapore",
    "Slovakia",
    "Slovenia",
    "Solomon Islands",
    "Somalia",
    "South Africa",
    "South Korea",
    "South Sudan",
    "Spain",
    "Sri Lanka",
    "Sudan",
    "Suriname",
    "Sweden",
    "Switzerland",
    "Syria",
    "Tajikistan",
    "Tanzania",
    "Thailand",
    "Timor-Leste",
    "Togo",
    "Tonga",
    "Trinidad and Tobago",
    "Tunisia",
    "Turkey",
    "Turkmenistan",
    "Tuvalu",
    "Uganda",
    "Ukraine",
    "United Arab Emirates",
    "United Kingdom",
    "United States of America",
    "Uruguay",
    "Uzbekistan",
    "Vanuatu",
    "Venezuela",
    "Vietnam",
    "Yemen",
    "Zambia",
    "Zimbabwe",
  ];

  @override
  void initState() {
    super.initState();
    fetchPartnerData();
  }

  /// Fetches the existing partner data from Firestore
  /// and populates the local controllers/fields.
  void fetchPartnerData() async {
    setState(() {
      isLoading = true;
    });

    try {
      DocumentSnapshot partnerDoc = await FirebaseFirestore.instance
          .collection('partners')
          .doc(widget.partnerId)
          .get();

      if (partnerDoc.exists) {
        partnerData = partnerDoc.data() as Map<String, dynamic>;

        // Basic info
        nameController.text = partnerData?['name'] ?? '';
        addressController.text = partnerData?['address'] ?? '';
        commentController.text = partnerData?['comment'] ?? '';


        // Partnership type & country
        selectedPartnershipType = partnerData?['partnershipType'] ?? '';
        selectedCountry = partnerData?['country'] ?? "Select Country";

        // Contact details
        contactEmailController.text =
            partnerData?['contactDetails']?['email'] ?? '';
        contactPhoneController.text =
            partnerData?['contactDetails']?['phone'] ?? '';

        // Supplier details
        if (partnerData?['supplierDetails'] != null) {
          serviceNameController.text =
              partnerData!['supplierDetails']['serviceName'] ?? '';
          brandNameController.text =
              partnerData!['supplierDetails']['brandName'] ?? '';
        }

        // Persons in organization
        if (partnerData?['persons'] != null) {
          persons = List<Map<String, String>>.from(
            (partnerData!['persons'] as List<dynamic>).map((item) {
              return Map<String, String>.from(item as Map<dynamic, dynamic>);
            }),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Partner not found.')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch partner data: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Picks a new partner logo from the device/gallery
  Future<void> _pickLogoImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile =
      await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile != null) {
        setState(() {
          partnerLogo = pickedFile;
        });
      }
    } catch (e) {
      print("Error picking partner logo: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error picking partner logo: $e")),
      );
    }
  }

  /// Uploads the newly selected partner logo to Firebase Storage
  Future<String?> _uploadLogoImage() async {
    if (partnerLogo == null) return null;
    try {
      final String fileName =
          "${DateTime.now().millisecondsSinceEpoch}_${partnerLogo!.name}";
      final Reference storageRef =
      FirebaseStorage.instance.ref().child("partnerLogos").child(fileName);

      TaskSnapshot snapshot;
      if (kIsWeb) {
        final bytes = await partnerLogo!.readAsBytes();
        snapshot = await storageRef.putData(bytes);
      } else {
        final File localFile = File(partnerLogo!.path);
        snapshot = await storageRef.putFile(localFile);
      }
      return await snapshot.ref.getDownloadURL();
    } catch (e) {
      print("Error uploading partner logo: $e");
      return null;
    }
  }

  /// Validates required fields, optionally uploads a new logo,
  /// and updates the partner document in Firestore.
  void updatePartner() async {
    // Debug prints
    print("Debug: Partner Name = '${nameController.text}'");
    print("Debug: Address = '${addressController.text}'");

    print("Debug: Partnership Type = '$selectedPartnershipType'");
    print("Debug: Country = '$selectedCountry'");
    print("Debug: Comment = '${commentController.text}'");
    print("Debug: Contact Email = '${contactEmailController.text}'");
    print("Debug: Contact Phone = '${contactPhoneController.text}'");
    print("Debug: Service Name (Supplier) = '${serviceNameController.text}'");
    print("Debug: Brand Name (Supplier) = '${brandNameController.text}'");
    print("Debug: persons.length = ${persons.length}");

    // Required fields check
    List<String> missingFields = [];
    if (nameController.text.trim().isEmpty) {
      missingFields.add('Partner Name');
    }
    if (addressController.text.trim().isEmpty) {
      missingFields.add('Address');
    }

    if (selectedPartnershipType.trim().isEmpty) {
      missingFields.add('Partnership Type');
    }
    if (selectedCountry == "Select Country" || selectedCountry.trim().isEmpty) {
      missingFields.add('Country');
    }
    if (contactEmailController.text.trim().isEmpty) {
      missingFields.add('Contact Email');
    }
    if (contactPhoneController.text.trim().isEmpty) {
      missingFields.add('Contact Phone');
    }

    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please fill out the following required fields: ${missingFields.join(', ')}.',
          ),
        ),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Upload new logo if picked
      String? logoUrl = await _uploadLogoImage();

      // Build updated partner data
      Map<String, dynamic> partnerUpdate = {
        'name': nameController.text.trim(),
        'address': addressController.text.trim(),

        'partnershipType': selectedPartnershipType,
        'country': selectedCountry,
        'comment': commentController.text.trim(),
        'contactDetails': {
          'email': contactEmailController.text.trim(),
          'phone': contactPhoneController.text.trim(),
        },
        'persons': persons,
      };

      // If 'Supplier', add supplier details
      if (selectedPartnershipType == 'Supplier') {
        partnerUpdate['supplierDetails'] = {
          'serviceName': serviceNameController.text.trim(),
          'brandName': brandNameController.text.trim(),
        };
      }

      // If a new logo is picked, update the 'logoUrl'
      if (logoUrl != null) {
        partnerUpdate['logoUrl'] = logoUrl;
      }

      // Perform Firestore update
      await FirebaseFirestore.instance
          .collection('partners')
          .doc(widget.partnerId)
          .update(partnerUpdate);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Partner updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e, st) {
      print("Debug: Failed to update partner. Error: $e");
      print("Debug: Stack Trace: $st");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update partner: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  /// Adds a new empty person to the 'persons' list.
  void addPerson() {
    setState(() {
      persons.add({
        'name': '',
        'position': '',
        'email': '',
        'phone': '',
      });
    });
  }

  /// Removes a person at a given index from the 'persons' list.
  void removePerson(int index) {
    setState(() {
      persons.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Update Partner'),
        centerTitle: true,
        backgroundColor: const Color(0xFF003366),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Partner Information Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Partner Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Partner Name *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: addressController,
                        decoration: const InputDecoration(
                          labelText: 'Address *',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),

                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedPartnershipType.isEmpty
                            ? null
                            : selectedPartnershipType,
                        decoration: const InputDecoration(
                          labelText: 'Partnership Type *',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          'Supplier',
                          'Distributor',
                          'Client',
                          'Other',
                        ].map((type) {
                          return DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedPartnershipType = value ?? '';
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedCountry,
                        decoration: const InputDecoration(
                          labelText: 'Country *',
                          border: OutlineInputBorder(),
                        ),
                        items: _countries.map((country) {
                          return DropdownMenuItem(
                            value: country,
                            child: Text(country),
                          );
                        }).toList(),
                        validator: (value) {
                          if (value == null ||
                              value == "Select Country") {
                            return 'Please select a country';
                          }
                          return null;
                        },
                        onChanged: (value) {
                          setState(() {
                            selectedCountry = value ?? "Select Country";
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: commentController,
                        decoration: const InputDecoration(
                          labelText: 'Comment (Optional)',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Contact Information Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Contact Information',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      TextFormField(
                        controller: contactEmailController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Email *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: contactPhoneController,
                        decoration: const InputDecoration(
                          labelText: 'Contact Phone *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Partner Logo Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const Text(
                        'Partner Logo',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: Colors.grey.shade300,
                        backgroundImage: partnerLogo != null
                            ? FileImage(File(partnerLogo!.path))
                            : partnerData?['logoUrl'] != null
                            ? NetworkImage(
                          partnerData!['logoUrl'],
                        )
                            : null,
                        child: (partnerLogo == null &&
                            (partnerData?['logoUrl'] == null))
                            ? const Icon(
                          Icons.business,
                          size: 50,
                          color: Colors.grey,
                        )
                            : null,
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _pickLogoImage,
                        icon: const Icon(Icons.image),
                        label: const Text("Change Logo"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8D1B3D),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Supplier Details Card
              if (selectedPartnershipType == 'Supplier')
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Supplier Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Divider(),
                        TextFormField(
                          controller: serviceNameController,
                          decoration: const InputDecoration(
                            labelText: 'Service Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: brandNameController,
                          decoration: const InputDecoration(
                            labelText: 'Brand Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Persons in Organization Card
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Text(
                            'Persons in Organization',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Color(0xFF0073E6),
                            ),
                            onPressed: addPerson,
                          ),
                        ],
                      ),
                      const Divider(),
                      ...List.generate(persons.length, (index) {
                        final person = persons[index];
                        return Card(
                          margin:
                          const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              children: [
                                TextFormField(
                                  initialValue: person['name'],
                                  onChanged: (value) {
                                    persons[index]['name'] = value;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: person['position'],
                                  onChanged: (value) {
                                    persons[index]['position'] = value;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Position',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: person['email'],
                                  onChanged: (value) {
                                    persons[index]['email'] = value;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  initialValue: person['phone'],
                                  onChanged: (value) {
                                    persons[index]['phone'] = value;
                                  },
                                  decoration: const InputDecoration(
                                    labelText: 'Phone',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    ),
                                    onPressed: () => removePerson(index),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Update Partner Button
              ElevatedButton(
                onPressed: updatePartner,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003366),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Update Partner',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
