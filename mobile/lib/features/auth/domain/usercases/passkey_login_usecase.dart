import 'package:dartz/dartz.dart';
import '../../../../core/network/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class PasskeyLoginUseCase {
  final AuthRepository repository;

  PasskeyLoginUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String biometricToken,
  }) async {
    return repository.passkeyLogin(
      biometricToken: biometricToken,
    );
  }
}
