import 'package:dartz/dartz.dart';
import '../../../../core/network/failures.dart';
import '../entities/user_entity.dart';

abstract class AuthRepository {
  Future<Either<Failure, UserEntity>> login({
    required String phoneNumber,
  });

  Future<Either<Failure, UserEntity>> passkeyLogin({
    required String biometricToken,
  });

  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String phoneNumber,
  });

  Future<Either<Failure, void>> logout();

  Future<Either<Failure, UserEntity>> getCurrentUser();
}
