import 'package:Medito/constants/constants.dart';
import 'package:email_validator/email_validator.dart';

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
      return StringConstants.fieldRequired;
    } else if (isEmailValid(email)) {
      return null;
    } else {
      return errorMessage ?? StringConstants.invalidEmail;
    }
  }

  String? validateFieldEmpty(String? input, {String? errorMessage}) {
    return input!.isEmpty
        ? errorMessage ?? StringConstants.fieldRequired
        : null;
  }

  String? validateOTP(String? input, {String? errorMessage}) {
    if (input!.isEmpty) {
      return StringConstants.fieldRequired;
    } else if (!isValidateDigit(input)) {
      return StringConstants.invalidInput;
    } else if (isValidateDigit(input) && input.length == 6) {
      return null;
    } else {
      return errorMessage ?? StringConstants.fieldRequired;
    }
  }
}
