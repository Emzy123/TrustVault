/// Country dial-code helpers for registration phone numbers.
class CountryDial {
  const CountryDial({
    required this.name,
    required this.iso2,
    required this.dialCode,
    this.nationalNumberLength = const [7, 8, 9, 10, 11, 12],
  });

  final String name;
  final String iso2;
  final String dialCode;
  final List<int> nationalNumberLength;

  String get label => '$name (+$dialCode)';

  /// Builds E.164-style number: +{dial}{national} (national leading 0 stripped).
  String formatPhone(String nationalRaw) {
    var digits = nationalRaw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    if (digits.startsWith(dialCode)) {
      digits = digits.substring(dialCode.length);
    }
    return '+$dialCode$digits';
  }

  String? validateNational(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Phone number is required';
    }
    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith(dialCode)) digits = digits.substring(dialCode.length);
    if (!nationalNumberLength.contains(digits.length)) {
      return 'Enter a valid $name phone number';
    }
    return null;
  }
}

/// Curated list used on the registration form (Nigeria first — primary market).
const List<CountryDial> kRegistrationCountries = [
  CountryDial(name: 'Nigeria', iso2: 'NG', dialCode: '234', nationalNumberLength: [10]),
  CountryDial(name: 'United States', iso2: 'US', dialCode: '1', nationalNumberLength: [10]),
  CountryDial(name: 'United Kingdom', iso2: 'GB', dialCode: '44', nationalNumberLength: [10]),
  CountryDial(name: 'Ghana', iso2: 'GH', dialCode: '233', nationalNumberLength: [9]),
  CountryDial(name: 'Kenya', iso2: 'KE', dialCode: '254', nationalNumberLength: [9]),
  CountryDial(name: 'South Africa', iso2: 'ZA', dialCode: '27', nationalNumberLength: [9]),
  CountryDial(name: 'Canada', iso2: 'CA', dialCode: '1', nationalNumberLength: [10]),
  CountryDial(name: 'India', iso2: 'IN', dialCode: '91', nationalNumberLength: [10]),
  CountryDial(name: 'United Arab Emirates', iso2: 'AE', dialCode: '971', nationalNumberLength: [9]),
  CountryDial(name: 'Germany', iso2: 'DE', dialCode: '49', nationalNumberLength: [10, 11]),
  CountryDial(name: 'France', iso2: 'FR', dialCode: '33', nationalNumberLength: [9]),
  CountryDial(name: 'Netherlands', iso2: 'NL', dialCode: '31', nationalNumberLength: [9]),
  CountryDial(name: 'Ireland', iso2: 'IE', dialCode: '353', nationalNumberLength: [9]),
  CountryDial(name: 'Australia', iso2: 'AU', dialCode: '61', nationalNumberLength: [9]),
  CountryDial(name: 'Brazil', iso2: 'BR', dialCode: '55', nationalNumberLength: [10, 11]),
  CountryDial(name: 'Egypt', iso2: 'EG', dialCode: '20', nationalNumberLength: [10]),
  CountryDial(name: 'Morocco', iso2: 'MA', dialCode: '212', nationalNumberLength: [9]),
  CountryDial(name: 'Rwanda', iso2: 'RW', dialCode: '250', nationalNumberLength: [9]),
  CountryDial(name: 'Tanzania', iso2: 'TZ', dialCode: '255', nationalNumberLength: [9]),
  CountryDial(name: 'Uganda', iso2: 'UG', dialCode: '256', nationalNumberLength: [9]),
];
