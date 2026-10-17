import 'package:fpdart/fpdart.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecase/usecase.dart';
import '../repository/task_repository.dart';

/// SELECT DISTINCT category ... — used to populate the filter sheet with the
/// categories this user actually uses, rather than a hard-coded list.
class GetTaskCategories implements UseCase<List<String>, String> {
  final TaskRepository taskRepository;

  const GetTaskCategories(this.taskRepository);

  @override
  Future<Either<Failure, List<String>>> call(String userId) async {
    try {
      return right(await taskRepository.getCategories(userId));
    } catch (e) {
      return left(CacheFailure(e.toString()));
    }
  }
}
