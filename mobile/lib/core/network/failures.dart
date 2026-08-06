/// Base failure class — every feature's repository returns either
/// a Failure or a value (via dartz Either)
abstract class Failure {
  final String message;
  const Failure(this.message);
}

/// Network / HTTP failures
class ServerFailure extends Failure {
  final int? statusCode;
  const ServerFailure(super.message, {this.statusCode});
}

/// The request never got an answer.
///
/// Named for what is known — nothing came back — rather than for a cause.
/// It used to carry the fixed sentence "No internet connection. Please try
/// again." for timeouts, connection errors and dio's `unknown` alike, and
/// it was the one explanation that was wrong when Android blocked a debug
/// build's cleartext request to a healthy local server.
class NetworkFailure extends Failure {
  const NetworkFailure(super.message);
}

/// Token expired and refresh failed → force logout
class AuthFailure extends Failure {
  const AuthFailure() : super('Your session has expired. Please log in again.');
}

/// Local cache / storage failure
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}

/// Validation errors (e.g. wrong password format)
class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}

/// Generic unexpected error
class UnexpectedFailure extends Failure {
  const UnexpectedFailure() : super('Something went wrong. Please try again.');
}
