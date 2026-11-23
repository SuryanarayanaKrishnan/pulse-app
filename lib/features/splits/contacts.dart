import 'package:flutter/foundation.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/phone.dart';

/// A device contact reduced to what splitting needs.
class DeviceContact {
  const DeviceContact({required this.name, required this.phones});
  final String name;

  /// E.164 numbers (normalised; invalid ones dropped).
  final List<String> phones;
  String? get primaryPhone => phones.isEmpty ? null : phones.first;
}

enum ContactsAccess { granted, limited, denied }

/// Reads the address book. Phone numbers never leave the device: only their
/// SHA-256 hashes are sent for matching.
abstract class ContactsSource {
  Future<ContactsAccess> requestAccess();
  Future<List<DeviceContact>> load();
}

/// flutter_contacts on iOS / Android.
class DeviceContactsSource implements ContactsSource {
  @override
  Future<ContactsAccess> requestAccess() async {
    final s = await fc.FlutterContacts.permissions.request(
      fc.PermissionType.read,
    );
    return switch (s) {
      fc.PermissionStatus.granted => ContactsAccess.granted,
      fc.PermissionStatus.limited => ContactsAccess.limited,
      _ => ContactsAccess.denied,
    };
  }

  @override
  Future<List<DeviceContact>> load() async {
    final all = await fc.FlutterContacts.getAll(
      properties: {fc.ContactProperty.phone},
    );
    return toDeviceContacts([
      for (final c in all)
        (c.displayName ?? '', [for (final p in c.phones) p.number]),
    ]);
  }
}

/// Normalises raw (name, numbers) pairs: E.164, de-duplicated, sorted,
/// contacts without a usable number dropped.
List<DeviceContact> toDeviceContacts(List<(String, List<String>)> raw) {
  final out = <DeviceContact>[];
  for (final (name, numbers) in raw) {
    final phones = <String>{
      for (final n in numbers) ?toE164(n),
    }.toList();
    if (name.trim().isEmpty || phones.isEmpty) continue;
    out.add(DeviceContact(name: name.trim(), phones: phones));
  }
  out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  return out;
}

/// Demo address book (web preview, tests).
class SampleContactsSource implements ContactsSource {
  const SampleContactsSource();
  @override
  Future<ContactsAccess> requestAccess() async => ContactsAccess.granted;

  @override
  Future<List<DeviceContact>> load() async => toDeviceContacts(const [
    ('Ahmed Khalil', ['050 123 4567']),
    ('Sara Haddad', ['+971 55 234 5678']),
    ('Omar Farouk', ['056 345 6789']),
    ('Layla Nasser', ['0504445566']),
    ('Priya Menon', ['+971 58 555 0101']),
    ('Daniel Brooks', ['+44 7700 900123']),
    ('Fatima Al Zarooni', ['052 777 8899']),
  ]);
}

final contactsSourceProvider = Provider<ContactsSource>(
  (ref) => kIsWeb ? const SampleContactsSource() : DeviceContactsSource(),
);
