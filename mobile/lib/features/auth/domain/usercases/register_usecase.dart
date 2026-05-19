import 'package:dartz/dartz.dart';
import '../../../../core/network/failures.dart';
import '../entities/user_entity.dart';
import '../repositories/auth_repository.dart';

class RegisterUseCase {
  final AuthRepository repository;

  RegisterUseCase(this.repository);

  Future<Either<Failure, UserEntity>> call({
    required String name,
    required String phoneNumber,
  }) async {
    return repository.register(
      name: name,
      phoneNumber: phoneNumber,
    );
  }
}
