import 'bootstrap.dart';
import 'core/routing/app_entry_point.dart';

Future<void> main() async {
  await bootstrap(AppEntryPoint.candidate);
}
