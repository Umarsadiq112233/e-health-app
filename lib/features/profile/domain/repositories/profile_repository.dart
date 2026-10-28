import '../models/setup_progress.dart';

abstract class ProfileRepository {
  Future<SetupProgress> load(String userId);
  Future<void> save(String userId, SetupProgress progress);
}
