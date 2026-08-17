import 'package:open_space_parking/core/common/failures/failure.dart';

abstract class BaseRepository {
  Failure mapExceptionToFailure(Object exception);
}
