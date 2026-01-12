import 'package:libphonenumber_plugin/libphonenumber_plugin.dart';

class PhoneFormatterService {
  static Future<String?> formatToE164(String phoneNumber, String region) async {
    try {
      final trimmed = phoneNumber.trim();
      if (trimmed.startsWith('+') || trimmed.startsWith('00')) {
        return null;
      }

      String cleaned = trimmed;

      cleaned = cleaned.replaceAll(RegExp(r'[^\d+]'), '');

      if (cleaned.isEmpty || cleaned.length < 4) {
        return null;
      }

      if (!matchesCountryStructure(cleaned, region)) {
        return null;
      }

      String numberToValidate = cleaned;
      if (!cleaned.startsWith('+')) {
        final countryCode = _getCountryCode(region);
        numberToValidate = '+$countryCode$cleaned';
      }

      final bool? isValid = await PhoneNumberUtil.isValidPhoneNumber(
        numberToValidate,
        region,
      );

      if (isValid == true) {
        return numberToValidate;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  static bool isNumberFromRegion(String phoneNumber, String region) {
    if (phoneNumber.trim().isEmpty) return false;
    final s = phoneNumber.trim();

    final targetCode = _getCountryCode(region);

    if (s.startsWith('+')) {
      final digits = s.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.startsWith(targetCode);
    }

    if (s.startsWith('00')) {
      final digits = s.substring(2).replaceAll(RegExp(r'[^0-9]'), '');
      return digits.startsWith(targetCode);
    }

    return true;
  }

  static bool matchesCountryStructure(String phoneNumber, String region) {
    final digits = phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    final len = digits.length;

    const ranges = {
      'CM': [8, 9],
      'FR': [9, 9],
      'US': [10, 10],
      'GB': [10, 10],
      'DE': [10, 11],
      'IT': [9, 10],
      'ES': [9, 9],
      'CA': [10, 10],
      'NG': [10, 10],
      'GH': [9, 9],
      'KE': [9, 9],
      'ZA': [9, 9],
      'EG': [9, 9],
      'MA': [9, 9],
      'TN': [8, 8],
      'DZ': [9, 9],
      'CI': [8, 8],
      'SN': [9, 9],
    };

    final range = ranges[region];
    if (range != null) {
      return len >= range[0] && len <= range[1];
    }

    return len >= 6 && len <= 12;
  }

  static String _getCountryCode(String region) {
    const codes = {
      'CM': '237',
      'FR': '33',
      'US': '1',
      'GB': '44',
      'DE': '49',
      'IT': '39',
      'ES': '34',
      'CA': '1',
      'NG': '234',
      'GH': '233',
      'KE': '254',
      'ZA': '27',
      'EG': '20',
      'MA': '212',
      'TN': '216',
      'DZ': '213',
      'CI': '225',
      'SN': '221',
      'ML': '223',
      'BF': '226',
      'NE': '227',
      'TG': '228',
      'BJ': '229',
      'MR': '222',
      'TD': '235',
      'CF': '236',
      'CG': '242',
      'GA': '241',
      'GQ': '240',
      'CD': '243',
      'AO': '244',
      'GW': '245',
      'SC': '248',
      'SD': '249',
      'RW': '250',
      'ET': '251',
      'SO': '252',
      'DJ': '253',
      'UG': '256',
      'TZ': '255',
      'BI': '257',
      'MZ': '258',
      'ZM': '260',
      'MG': '261',
      'RE': '262',
      'ZW': '263',
      'NA': '264',
      'MW': '265',
      'LS': '266',
      'BW': '267',
      'SZ': '268',
      'KM': '269',
    };
    return codes[region] ?? '237';
  }
}
