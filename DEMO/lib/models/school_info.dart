import 'package:shared_preferences/shared_preferences.dart';

class SchoolInfo {
  final String name;
  final String address;
  final String director;
  final String? logoPath;
  final String? telephone;
  final String? email;
  final String? website;
  final String? motto;

  SchoolInfo({
    required this.name,
    required this.address,
    required this.director,
    this.logoPath,
    this.telephone,
    this.email,
    this.website,
    this.motto,
  });
}

Future<SchoolInfo> loadSchoolInfo() async {
  final prefs = await SharedPreferences.getInstance();
  return SchoolInfo(
    name: prefs.getString('school_name') ?? '',
    address: prefs.getString('school_address') ?? '',
    director: prefs.getString('school_director') ?? '',
    logoPath: prefs.getString('school_logo'),
    telephone: prefs.getString('school_phone'),
    email: prefs.getString('school_email'),
    website: prefs.getString('school_website'),
    motto: prefs.getString('school_motto'),
  );
}
