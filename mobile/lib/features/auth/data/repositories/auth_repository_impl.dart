import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import '../../../../core/network/dio_message.dart';
import '../../../../core/network/failures.dart';
import '../../../../core/network/token_storage.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource _remoteDataSource;
  final TokenStorage _tokenStorage;

  AuthRepositoryImpl(this._remoteDataSource, this._tokenStorage);

  @override
  Future<Either<Failure, UserEntity>> login({
    required String phoneNumber,
  }) async {
    try {
      final user = await _remoteDataSource.login(
        phoneNumber: phoneNumber,
      );
      return Right(user);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> passkeyLogin({
    required String biometricToken,
  }) async {
    try {
      final user = await _remoteDataSource.passkeyLogin(
        biometricToken: biometricToken,
      );
      return Right(user);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, UserEntity>> register({
    required String name,
    required String phoneNumber,
  }) async {
    try {
      final user = await _remoteDataSource.register(
        name: name,
        phoneNumber: phoneNumber,
      );
      return Right(user);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  @override
  Future<Either<Failure, void>> logout() async {
    await _tokenStorage.clearTokens();
    return const Right(null);
  }

  @override
  Future<Either<Failure, UserEntity>> getCurrentUser() async {
    try {
      final user = await _remoteDataSource.getCurrentUser();
      return Right(user);
    } on DioException catch (e) {
      return Left(_handleDioError(e));
    } catch (_) {
      return const Left(UnexpectedFailure());
    }
  }

  Failure _handleDioError(DioException e) {
    if (e.response?.statusCode == 401) return const AuthFailure();
    if (e.type == DioExceptionType.badResponse) {
      return ServerFailure(
        describeDioError(e),
        statusCode: e.response?.statusCode,
      );
    }
    return NetworkFailure(describeDioError(e));
  }
}
