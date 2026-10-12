class Student {
  final String id;
  final String name;
  final String dateOfBirth;
  final String address;
  final String gender;
  final String contactNumber;
  final String email;
  final String emergencyContact;
  final String guardianName;
  final String guardianContact;
  final String className;
  final String enrollmentDate;
  final String? medicalInfo;
  final String? photoPath;

  Student({
    required this.id,
    required this.name,
    required this.dateOfBirth,
    required this.address,
    required this.gender,
    required this.contactNumber,
    required this.email,
    required this.emergencyContact,
    required this.guardianName,
    required this.guardianContact,
    required this.className,
    required this.enrollmentDate,
    this.medicalInfo,
    this.photoPath,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'dateOfBirth': dateOfBirth,
      'address': address,
      'gender': gender,
      'contactNumber': contactNumber,
      'email': email,
      'emergencyContact': emergencyContact,
      'guardianName': guardianName,
      'guardianContact': guardianContact,
      'className': className,
      'enrollmentDate': enrollmentDate,
      'medicalInfo': medicalInfo,
      'photoPath': photoPath,
    };
  }

  factory Student.fromMap(Map<String, dynamic> map) {
    return Student(
      id: map['id'],
      name: map['name'],
      dateOfBirth: map['dateOfBirth'],
      address: map['address'],
      gender: map['gender'],
      contactNumber: map['contactNumber'],
      email: map['email'],
      emergencyContact: map['emergencyContact'],
      guardianName: map['guardianName'],
      guardianContact: map['guardianContact'],
      className: map['className'],
      enrollmentDate: map['enrollmentDate'],
      medicalInfo: map['medicalInfo'],
      photoPath: map['photoPath'],
    );
  }

  factory Student.empty() => Student(
    id: '',
    name: '',
    dateOfBirth: '',
    address: '',
    gender: '',
    contactNumber: '',
    email: '',
    emergencyContact: '',
    guardianName: '',
    guardianContact: '',
    className: '',
    enrollmentDate: '',
    medicalInfo: '',
    photoPath: '',
  );
}