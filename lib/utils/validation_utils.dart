import 'package:email_validator/email_validator.dart';

const String _invalidEmail = 'Invalid Email.';
const String _fieldRequired = 'Field is Required';
const String _invalidInput = 'Invalid Input';

class ValidationUtils {
  static const patternDigits = r'^[0-9]*$';

  bool isEmailValid(String email) {
    return EmailValidator.validate(email);
  }

  bool isValidateDigit(String digit) {
    var regexName = RegExp(patternDigits);

    return regexName.hasMatch(digit);
  }

  String? validateEmail(String? email, {String? errorMessage}) {
    if (email!.isEmpty) {
      return _fieldRequired;
    } else if (isEmailValid(email)) {
      return null;
    } else {
      return errorMessage ?? _invalidEmail;
    }
  }

  String? validateFieldEmpty(String? input, {String? errorMessage}) {
    return input!.isEmpty ? errorMessage ?? _fieldRequired : null;
  }

  String? validateOTP(String? input, {String? errorMessage}) {
    if (input!.isEmpty) {
      return _fieldRequired;
    } else if (!isValidateDigit(input)) {
      return _invalidInput;
    } else if (isValidateDigit(input) && input.length == 6) {
      return null;
    } else {
      return errorMessage;
    }
  }
}
