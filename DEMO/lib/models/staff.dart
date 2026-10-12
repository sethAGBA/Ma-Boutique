import 'package:flutter/foundation.dart';

class Staff {
  final String id;
  final String name;
  final String role;
  final String department;
  final String phone;
  final String email;
  final String qualifications;
  final List<String> courses; // Liste des cours assignés
  final List<String> classes; // Liste des classes assignées
  final String status;
  final DateTime hireDate;
  final String typeRole; // 'Professeur' ou 'Administration'

  Staff({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.phone,
    required this.email,
    required this.qualifications,
    required this.courses,
    required this.classes,
    required this.status,
    required this.hireDate,
    required this.typeRole,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'role': role,
      'department': department,
      'phone': phone,
      'email': email,
      'qualifications': qualifications,
      'courses': courses.join(','),
      'classes': classes.join(','),
      'status': status,
      'hireDate': hireDate.toIso8601String(),
      'typeRole': typeRole,
    };
  }

  factory Staff.fromMap(Map<String, dynamic> map) {
    return Staff(
      id: map['id'],
      name: map['name'],
      role: map['role'],
      department: map['department'],
      phone: map['phone'],
      email: map['email'],
      qualifications: map['qualifications'],
      courses: map['courses'] != null && map['courses'] != '' ? (map['courses'] as String).split(',') : [],
      classes: map['classes'] != null && map['classes'] != '' ? (map['classes'] as String).split(',') : [],
      status: map['status'],
      hireDate: DateTime.parse(map['hireDate']),
      typeRole: map['typeRole'] ?? 'Administration',
    );
  }

  factory Staff.empty() => Staff(
    id: '',
    name: '',
    role: '',
    department: '',
    phone: '',
    email: '',
    qualifications: '',
    courses: [],
    classes: [],
    status: 'Actif',
    hireDate: DateTime.now(),
    typeRole: 'Administration',
  );
} 