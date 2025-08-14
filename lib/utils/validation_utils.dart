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

  String? validateEmail(String? email,
      {String? errorMessage,
      String? fieldRequiredMessage,
      String? invalidEmailMessage}) {
    if (email!.isEmpty) {
      return fieldRequiredMessage ?? 'Field is Required';
    } else if (isEmailValid(email)) {
      return null;
    } else {
      return errorMessage ?? invalidEmailMessage ?? 'Invalid Email.';
    }
  }

  String? validateFieldEmpty(String? input,
      {String? errorMessage, String? fieldRequiredMessage}) {
    return input!.isEmpty
        ? errorMessage ?? fieldRequiredMessage ?? 'Field is Required'
        : null;
  }

  String? validateOTP(String? input,
      {String? errorMessage,
      String? fieldRequiredMessage,
      String? invalidInputMessage}) {
    if (input!.isEmpty) {
      return fieldRequiredMessage ?? 'Field is Required';
    } else if (!isValidateDigit(input)) {
      return invalidInputMessage ?? 'Invalid Input';
    } else if (isValidateDigit(input) && input.length == 6) {
      return null;
    } else {
      return errorMessage ?? fieldRequiredMessage ?? 'Field is Required';
    }
  }
}
