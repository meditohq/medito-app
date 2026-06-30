import 'package:equatable/equatable.dart';
import 'package:medito/exceptions/app_error.dart';

class ApiResponse<T> extends Equatable {
  final Status status;
  final T? body;
  final AppError? error;

  const ApiResponse.loading()
    : status = Status.loading,
      body = null,
      error = null;

  const ApiResponse.completed(this.body)
    : status = Status.completed,
      error = null;

  const ApiResponse.error(this.error) : status = Status.error, body = null;

  bool hasData() {
    return status != Status.loading && body != null;
  }

  @override
  String toString() {
    return 'Status : $status \n Error : $error \n Data : $body';
  }

  @override
  List<Object?> get props => [status, body, error];
}

enum Status { loading, completed, error }
