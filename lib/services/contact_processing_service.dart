import 'package:flutter_contacts/flutter_contacts.dart';

import '../models/contact_result.dart';
import 'phone_formatter_service.dart';

class ServicePreviewItem {
  final String contactId;
  final String contactName;
  final String original;
  final String predicted;
  final String status;

  ServicePreviewItem({required this.contactId, required this.contactName, required this.original, required this.predicted, required this.status});
}

class ProcessingResult {
  final List<ContactResult> results;
  final int totalProcessed;
  final int updated;
  final int skipped;
  final int failed;
  final int updatedContacts;
  final int skippedContacts;

  ProcessingResult({
    required this.results,
    required this.totalProcessed,
    required this.updated,
    required this.skipped,
    required this.failed,
    required this.updatedContacts,
    required this.skippedContacts,
  });
}

class ContactProcessingService {
  static Future<List<ServicePreviewItem>> computePreview(List<Contact> contacts, String region, {bool fastPreview = false, void Function(double)? onProgress}) async {
    final List<ServicePreviewItem> out = [];
    int processed = 0;
    final total = contacts.length;

    for (final contact in contacts) {
      final String id = contact.id;
      final String name = contact.displayName.isNotEmpty ? contact.displayName : 'Unknown';

      if (contact.phones.isEmpty) {
        processed++;
        onProgress?.call(total > 0 ? processed / total : 1.0);
        continue;
      }

      for (final phone in contact.phones) {
        final orig = phone.number.trim();
        String status = 'Will Fail';
        String predicted = '';

        if (orig.isEmpty || orig.length < 4) {
          status = 'Will Skip';
          predicted = orig;
        } else {
          final normalized = orig.replaceAll(RegExp(r'\s+'), '');

          if (normalized.startsWith('+')) {
            status = 'Will Skip';
            predicted = orig;
          } else if (normalized.startsWith('00')) {
            final without00 = normalized.substring(2);
            status = 'Will Update';
            predicted = '+$without00';
          } else {
            if (!PhoneFormatterService.isNumberFromRegion(orig, region)) {
              continue;
            }

            final matches = PhoneFormatterService.matchesCountryStructure(orig, region);
            if (!matches) {
              status = 'Will Fail';
              predicted = 'invalid structure';
            } else {
              status = 'Will Update';
              predicted = 'will format to E.164';
            }
          }
        }

        out.add(ServicePreviewItem(contactId: id, contactName: name, original: orig, predicted: predicted, status: status));
      }

      processed++;
      if (processed % 10 == 0) {
        onProgress?.call(total > 0 ? processed / total : 1.0);
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    onProgress?.call(1.0);
    return out;
  }

  static Future<ProcessingResult> processContacts(List<Contact> contacts, String region, {Set<String>? skipSet, void Function(double)? onProgress, void Function(String)? onLog}) async {
    final results = <ContactResult>[];
    int totalContacts = contacts.length;
    int processed = 0;
    int updated = 0;
    int skipped = 0;
    int failed = 0;
    int updatedContacts = 0;
    int skippedContacts = 0;
    int contactsWithPhones = 0;

    for (final contact in contacts) {
      final contactName = contact.displayName.isNotEmpty ? contact.displayName : 'Unknown';

      if (contact.phones.isEmpty) {
        skipped++;
        skippedContacts++;
        results.add(ContactResult(contactName: contactName, originalNumber: '', finalNumber: '', status: 'Skipped (no phones)'));
        processed++;
        onProgress?.call(totalContacts > 0 ? processed / totalContacts : 1.0);
        continue;
      }

      contactsWithPhones++;
      bool contactModified = false;
      bool anyPhoneProcessed = false;
      bool anyPhoneUpdated = false;

      for (int i = 0; i < contact.phones.length; i++) {
        final phone = contact.phones[i];
        final original = phone.number.trim();
        final key = '${contact.id}|$original';

        if (!PhoneFormatterService.isNumberFromRegion(original, region)) {
          skipped++;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: original, status: 'Skipped (other country)'));
          continue;
        }

        if (skipSet != null && skipSet.contains(key)) {
          skipped++;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: original, status: 'Skipped (user opted out)'));
          continue;
        }

        if (original.isEmpty || original.length < 4) {
          skipped++;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: original, status: 'Skipped (too short)'));
          continue;
        }

        if (original.startsWith('+')) {
          skipped++;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: original, status: 'Skipped (already E.164)'));
          continue;
        }

        if (original.startsWith('00')) {
          final converted = '+${original.substring(2)}';
          contact.phones[i] = Phone(converted, label: phone.label, customLabel: phone.customLabel, isPrimary: phone.isPrimary);
          contactModified = true;
          updated++;
          anyPhoneProcessed = true;
          anyPhoneUpdated = true;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: converted, status: 'Updated'));
          onLog?.call('Updated: $contactName $original -> $converted');
          continue;
        }

        final formatted = await PhoneFormatterService.formatToE164(original, region);
        if (formatted != null && formatted != original) {
          contact.phones[i] = Phone(formatted, label: phone.label, customLabel: phone.customLabel, isPrimary: phone.isPrimary);
          contactModified = true;
          updated++;
          anyPhoneProcessed = true;
          anyPhoneUpdated = true;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: formatted, status: 'Updated'));
          onLog?.call('Updated: $contactName $original -> $formatted');
        } else {
          failed++;
          anyPhoneProcessed = true;
          results.add(ContactResult(contactName: contactName, originalNumber: original, finalNumber: original, status: 'Failed (invalid)'));
          onLog?.call('Failed: $contactName $original');
        }
      }

      if (contactModified) {
        try {
          await contact.update();
          onLog?.call('Saved: $contactName');
        } catch (e) {
          onLog?.call('ERROR saving $contactName: ${e.toString()}');
        }
      }

      if (anyPhoneUpdated) {
        updatedContacts++;
      } else {
        if (anyPhoneProcessed) {
          skippedContacts++;
        }
      }

      processed++;
      if (processed % 3 == 0) {
        onProgress?.call(totalContacts > 0 ? processed / totalContacts : 1.0);
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    onProgress?.call(1.0);

    return ProcessingResult(
      results: results,
      totalProcessed: contactsWithPhones,
      updated: updated,
      skipped: skipped,
      failed: failed,
      updatedContacts: updatedContacts,
      skippedContacts: skippedContacts,
    );
  }
}
