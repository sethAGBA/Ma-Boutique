import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

import '../data/db.dart';

class LicenseStatus {
  final String? key;
  final DateTime? registeredAt;
  final DateTime? expiry;
  final DateTime? trialStartedAt;

  const LicenseStatus({
    this.key,
    this.registeredAt,
    this.expiry,
    this.trialStartedAt,
  });

  bool get hasKey => (key != null && key!.trim().isNotEmpty);
  bool get isTrial => !hasKey;

  DateTime get trialExpiry =>
      (trialStartedAt ?? DateTime.now()).add(const Duration(days: 14));

  bool get isLifetime {
    if (!hasKey || registeredAt == null || expiry == null) return false;
    // Plus de 800 ans
    return expiry!.difference(registeredAt!).inDays > (800 * 365);
  }

  bool get hasExpiry => hasKey ? expiry != null : true;

  bool get isExpired {
    if (hasKey) {
      return expiry != null ? DateTime.now().isAfter(expiry!) : false;
    }
    // Mode essai 14 jours
    return DateTime.now().isAfter(trialExpiry);
  }

  bool get isActive => !isExpired;

  int get daysRemaining {
    if (hasKey) {
      if (expiry == null) return 0;
      final diff = expiry!.difference(DateTime.now()).inDays;
      return diff < 0 ? 0 : diff;
    } else {
      // Jours restants sur l'essai de 14 jours
      final diff = trialExpiry.difference(DateTime.now()).inDays;
      return diff < 0 ? 0 : diff;
    }
  }
}

class LicenseService {
  LicenseService._();
  static final LicenseService instance = LicenseService._();

  // 12 clés uniques standards à usage unique (validité 12 mois)
  static const List<String> validKeys = [
    'Z7KJ-3PMQ-XA49-NE2T',
    'Q5HL-UD93-RBKN-17ZX',
    'T9MW-2GQF-LA58-Y3RD',
    'P6VN-X4JE-8KQT-5H2C',
    'H4DQ-RT2N-9SVE-M7K1',
    'B2YM-5ZQ8-CLN7-J4TX',
    'N8KF-3RJL-7Q2P-VD65',
    'R1TE-6H9M-PQ47-X2LB',
    'C7PX-M2Q8-9LRT-HE54',
    'J5QN-7K2V-U8RD-3XLP',
    'L9HT-4MVE-2QX7-BK13',
    'V3ZP-8Q1N-R6JL-D5TC',
  ];

  static String _normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  static final Set<String> _validNormalized = validKeys.map(_normalize).toSet();

  // Clés spéciales de test et permanente
  static const Map<String, int> _specialKeysMonths = {
    'ACTETEST3MALPHA': 3, // 3 mois
    'ACTELIFE2025': 9999, // À vie
  };

  static const _keyActive = 'license_key';
  static const _keyRegisteredAt = 'license_registered_at';
  static const _keyExpiry = 'license_expiry';
  static const _keyTrialStartedAt = 'license_trial_started_at';
  static const _keyUsedList = 'license_used_keys';

  static const String _supAdminSecret = String.fromEnvironment(
    'SUPADMIN_PASSWORD',
    defaultValue: 'ACTE#SupAdmin2025!',
  );

  final ValueNotifier<bool> activeNotifier = ValueNotifier<bool>(false);

  Future<Database> get _db async => AppDb.instance.db;

  Future<String?> _getParam(String cle) async {
    final d = await _db;
    final rows = await d.query('parametres', where: 'cle = ?', whereArgs: [cle], limit: 1);
    if (rows.isEmpty) return null;
    return rows.first['valeur'] as String?;
  }

  Future<void> _setParam(String cle, String valeur) async {
    final d = await _db;
    await d.insert('parametres', {'cle': cle, 'valeur': valeur},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<LicenseStatus> getStatus() async {
    final key = await _getParam(_keyActive);
    final regStr = await _getParam(_keyRegisteredAt);
    final expiryStr = await _getParam(_keyExpiry);

    DateTime? regAt;
    DateTime? expiry;
    if (regStr != null && regStr.isNotEmpty) {
      try {
        regAt = DateTime.parse(regStr);
      } catch (_) {}
    }
    if (expiryStr != null && expiryStr.isNotEmpty) {
      try {
        expiry = DateTime.parse(expiryStr);
      } catch (_) {}
    }

    // Gestion du démarrage de la période d'essai de 14 jours
    final trialStr = await _getParam(_keyTrialStartedAt);
    DateTime? trialAt;
    if (trialStr != null && trialStr.isNotEmpty) {
      try {
        trialAt = DateTime.parse(trialStr);
      } catch (_) {}
    } else {
      trialAt = DateTime.now();
      await _setParam(_keyTrialStartedAt, trialAt.toIso8601String());
    }

    return LicenseStatus(
      key: key,
      registeredAt: regAt,
      expiry: expiry,
      trialStartedAt: trialAt,
    );
  }

  Future<bool> hasActive() async {
    final st = await getStatus();
    return st.isActive;
  }

  Future<void> saveLicense({required String key}) async {
    final normalized = _normalize(key);
    final usedRaw = await _getParam(_keyUsedList) ?? '';
    final used = usedRaw.isEmpty ? <String>[] : usedRaw.split(',');

    final isStandard = _validNormalized.contains(normalized);
    final isSpecial = _specialKeysMonths.containsKey(normalized);
    final alreadyUsed = used.contains(normalized);

    if (!(isStandard || isSpecial) || alreadyUsed) {
      throw Exception('Clé de licence invalide ou déjà utilisée.');
    }

    final now = DateTime.now();
    final months = isStandard ? 12 : (_specialKeysMonths[normalized] ?? 12);
    final expiry = DateTime(now.year, now.month + months, now.day, 23, 59, 59);

    await _setParam(_keyActive, normalized);
    await _setParam(_keyRegisteredAt, now.toIso8601String());
    await _setParam(_keyExpiry, expiry.toIso8601String());

    final newUsed = [...used, normalized].join(',');
    await _setParam(_keyUsedList, newUsed);

    await refreshActive();
  }

  Future<void> clearLicense() async {
    final d = await _db;
    await d.delete('parametres', where: 'cle IN (?, ?, ?)',
        whereArgs: [_keyActive, _keyRegisteredAt, _keyExpiry]);
    await refreshActive();
  }

  Future<void> refreshActive() async {
    final st = await getStatus();
    activeNotifier.value = st.isActive;
  }

  Future<bool> allKeysUsed() async {
    final usedRaw = await _getParam(_keyUsedList) ?? '';
    final used = usedRaw.isEmpty ? <String>{} : usedRaw.split(',').toSet();
    return _validNormalized.difference(used).isEmpty;
  }

  Future<bool> verifySupAdmin(String password) async {
    String h(String s) => sha256.convert(utf8.encode(s)).toString();
    return constantTimeEquals(h(password), h(_supAdminSecret));
  }

  bool constantTimeEquals(String a, String b) {
    if (a.length != b.length) return false;
    int result = 0;
    for (int i = 0; i < a.length; i++) {
      result |= a.codeUnitAt(i) ^ b.codeUnitAt(i);
    }
    return result == 0;
  }
}
