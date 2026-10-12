import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:school_manager/constants/sizes.dart';
import 'package:school_manager/constants/strings.dart';
import 'package:school_manager/models/class.dart';
import 'package:school_manager/models/student.dart';
import 'package:school_manager/services/database_service.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:school_manager/utils/academic_year.dart';
import 'package:school_manager/utils/date_formatter.dart';

import 'form_field.dart';

class StudentRegistrationForm extends StatefulWidget {
  final VoidCallback onSubmit;
  final Student? student;
  final String? className;
  final bool classFieldReadOnly;

  const StudentRegistrationForm({
    required this.onSubmit,
    this.student,
    this.className,
    this.classFieldReadOnly = false,
    Key? key,
  }) : super(key: key);

  @override
  _StudentRegistrationFormState createState() =>
      _StudentRegistrationFormState();
}

class _StudentRegistrationFormState extends State<StudentRegistrationForm> {
  final _formKey = GlobalKey<FormState>();
  final DatabaseService _dbService = DatabaseService();

  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _dateOfBirthController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _guardianNameController = TextEditingController();
  final TextEditingController _guardianContactController =
      TextEditingController();
  final TextEditingController _medicalInfoController = TextEditingController();
  final TextEditingController _studentLastNameController =
      TextEditingController();

  String? _selectedClass;
  String? _selectedGender;
  File? _studentPhoto;
  List<Class> _classes = [];

  @override
  void initState() {
    super.initState();
    _loadClasses();
    if (widget.student != null) {
      final s = widget.student!;
      _studentIdController.text = s.id;
      // Sépare prénom/nom si possible
      final nameParts = s.name.split(' ');
      _studentNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
      _studentLastNameController.text =
          nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
      _dateOfBirthController.text = formatDdMmYyyy(parseDdMmYyyy(s.dateOfBirth));
      _addressController.text = s.address;
      _selectedGender = s.gender;
      _contactNumberController.text = s.contactNumber;
      _emailController.text = s.email;
      _emergencyContactController.text = s.emergencyContact;
      _guardianNameController.text = s.guardianName;
      _guardianContactController.text = s.guardianContact;
      _selectedClass = s.className;
      _medicalInfoController.text = s.medicalInfo ?? '';
      if (s.photoPath != null && File(s.photoPath!).existsSync()) {
        _studentPhoto = File(s.photoPath!);
      }
    } else if (widget.className != null) {
      _selectedClass = widget.className;
      _studentIdController.text = const Uuid().v4();
    } else {
      _studentIdController.text = const Uuid().v4();
    }
    getCurrentAcademicYear().then((year) {
      if (_selectedClass == null && _studentIdController.text.isEmpty) {
        // Nouvelle inscription
        _dateOfBirthController.text = '';
        // Pré-remplir année scolaire si champ existe
        // (à adapter selon le modèle Student si besoin)
      }
    });
  }

  Future<void> _loadClasses() async {
    try {
      final classes = await _dbService.getClasses();
      print('Loaded ${classes.length} classes');
      setState(() {
        _classes = classes;
      });
    } catch (e) {
      print('Error loading classes: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du chargement des classes')),
      );
    }
  }

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    _dateOfBirthController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _emailController.dispose();
    _emergencyContactController.dispose();
    _guardianNameController.dispose();
    _guardianContactController.dispose();
    _medicalInfoController.dispose();
    _studentLastNameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );
      if (result != null && result.files.isNotEmpty) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          setState(() {
            _studentPhoto = File(filePath);
          });
        }
      }
    } catch (e) {
      print('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible de sélectionner l’image')),
      );
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 10)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dateOfBirthController.text = formatDdMmYyyy(picked);
      });
    }
  }

  Future<String?> _savePhoto(File photo) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(photo.path).toLowerCase();
      final photoPath = path.join(
        directory.path,
        'photos',
        'student_${_studentIdController.text}_$timestamp$extension',
      );
      final photoFile = File(photoPath);
      await photoFile.create(recursive: true);
      await photo.copy(photoPath);
      return photoPath;
    } catch (e) {
      print('Error saving photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d’enregistrer l’image')),
      );
      return null;
    }
  }

  void submitForm() async {
    if (_formKey.currentState!.validate()) {
      if (_classes.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Aucune classe disponible. Ajoutez une classe d’abord.',
            ),
          ),
        );
        return;
      }
      String? photoPath;
      if (_studentPhoto != null) {
        photoPath = await _savePhoto(_studentPhoto!);
      }
      final student = Student(
        id: _studentIdController.text,
        name:
            _studentNameController.text +
            (_studentLastNameController.text.isNotEmpty
                ? ' ' + _studentLastNameController.text
                : ''),
        dateOfBirth: parseDdMmYyyy(_dateOfBirthController.text)!.toIso8601String(),
        address: _addressController.text,
        gender: _selectedGender!,
        contactNumber: _contactNumberController.text,
        email: _emailController.text,
        emergencyContact: _emergencyContactController.text,
        guardianName: _guardianNameController.text,
        guardianContact: _guardianContactController.text,
        className: _selectedClass!,
        enrollmentDate: DateTime.now().toIso8601String(),
        medicalInfo:
            _medicalInfoController.text.isEmpty
                ? null
                : _medicalInfoController.text,
        photoPath: photoPath,
      );
      try {
        if (widget.student != null) {
          // update
          await _dbService.updateStudent(widget.student!.id, student);
        } else {
          // insert
          await _dbService.insertStudent(student);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.student != null
                  ? 'Étudiant mis à jour avec succès!'
                  : 'Étudiant enregistré avec succès!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onSubmit();
        _formKey.currentState!.reset();
        setState(() {
          _selectedClass = null;
          _selectedGender = null;
          _studentPhoto = null;
        });
      } catch (e) {
        print('Error saving student: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de l\'enregistrement: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    print('Building StudentRegistrationForm');
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Photo de l’étudiant'),
            _buildPhotoSection(),
            const SizedBox(height: AppSizes.spacing),
            _buildSectionTitle('Détails Personnels'),
            CustomFormField(
              controller: _studentIdController,
              labelText: 'ID Étudiant',
              hintText: 'Généré automatiquement',
              readOnly: true,
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            CustomFormField(
              controller: _studentNameController,
              labelText: 'Prénom',
              hintText: 'Entrez le prénom de l’étudiant',
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            CustomFormField(
              controller: _studentLastNameController,
              labelText: 'Nom',
              hintText: 'Entrez le nom de famille de l’étudiant',
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            CustomFormField(
              controller: _dateOfBirthController,
              labelText: 'Date de Naissance',
              hintText: 'Sélectionnez la date',
              readOnly: true,
              onTap: _selectDate,
              suffixIcon: Icons.calendar_today,
              validator: (value) => value!.isEmpty ? AppStrings.required : null,
            ),
            CustomFormField(
              controller: _addressController,
              labelText: 'Adresse',
              hintText: 'Entrez l’adresse',
            ),
            CustomFormField(
              isDropdown: true,
              labelText: AppStrings.gender,
              hintText: 'Sélectionnez le sexe',
              dropdownItems: const ['M', 'F'],
              dropdownValue: _selectedGender,
              onDropdownChanged:
                  (value) => setState(() => _selectedGender = value),
              validator:
                  (value) =>
                      value == null ? 'Veuillez sélectionner le sexe' : null,
            ),
            const SizedBox(height: AppSizes.spacing),
            _buildSectionTitle('Informations de Contact'),
            CustomFormField(
              controller: _contactNumberController,
              labelText: 'Numéro de Contact',
              hintText: 'Entrez le numéro de contact',
            ),
            CustomFormField(
              controller: _emailController,
              labelText: 'Adresse Email',
              hintText: 'Entrez l’adresse email',
            ),
            CustomFormField(
              controller: _emergencyContactController,
              labelText: 'Contact d’Urgence',
              hintText: 'Entrez le nom et numéro de contact d’urgence',
            ),
            const SizedBox(height: AppSizes.spacing),
            _buildSectionTitle('Informations du Tuteur'),
            CustomFormField(
              controller: _guardianNameController,
              labelText: 'Nom du Tuteur',
              hintText: 'Entrez le nom complet du tuteur',
            ),
            CustomFormField(
              controller: _guardianContactController,
              labelText: 'Numéro de Contact du Tuteur',
              hintText: 'Entrez le numéro de contact du tuteur',
            ),
            const SizedBox(height: AppSizes.spacing),
            _buildSectionTitle('Informations Académiques'),
            CustomFormField(
              isDropdown: true,
              labelText: AppStrings.classLabel,
              hintText:
                  _classes.isEmpty
                      ? 'Aucune classe disponible'
                      : 'Sélectionnez la classe',
              dropdownItems: _classes.map((cls) => cls.name).toList(),
              dropdownValue: _selectedClass,
              onDropdownChanged:
                  widget.classFieldReadOnly
                      ? null
                      : (value) => setState(() => _selectedClass = value),
              validator:
                  (value) =>
                      value == null ? 'Veuillez sélectionner une classe' : null,
              readOnly: widget.classFieldReadOnly,
            ),
            const SizedBox(height: AppSizes.spacing),
            _buildSectionTitle('Informations Médicales'),
            CustomFormField(
              controller: _medicalInfoController,
              labelText: 'Informations Médicales',
              hintText: 'Entrez les informations médicales pertinentes',
              isTextArea: true,
            ),
            const SizedBox(height: AppSizes.spacing),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.spacing / 2),
      child: Text(
        title,
        style: TextStyle(
          fontSize: AppSizes.titleFontSize,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).textTheme.bodyLarge!.color,
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: AppSizes.smallSpacing),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Photo de l’étudiant',
            style: TextStyle(
              fontSize: AppSizes.textFontSize,
              fontWeight: FontWeight.w500,
              color: Theme.of(context).textTheme.bodyMedium!.color,
            ),
          ),
          const SizedBox(height: AppSizes.smallSpacing / 2),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: double.infinity,
              height: 150,
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Theme.of(context).dividerColor!),
              ),
              child:
                  _studentPhoto != null
                      ? Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _studentPhoto!,
                              width: double.infinity,
                              height: 150,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (context, error, stackTrace) => const Center(
                                    child: Icon(Icons.error, color: Colors.red),
                                  ),
                            ),
                          ),
                          Positioned(
                            top: 8,
                            right: 8,
                            child: GestureDetector(
                              onTap: () => setState(() => _studentPhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                      : const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                          SizedBox(height: 4),
                          Text(
                            'Sélectionner une image',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: AppSizes.textFontSize - 2,
                            ),
                          ),
                        ],
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

typedef StudentRegistrationFormState = _StudentRegistrationFormState;
