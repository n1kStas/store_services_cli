import 'package:store_services_cli/configurators/gms_configurator.dart';
import 'package:store_services_cli/configurators/hms_configurator.dart';
import 'package:store_services_cli/configurators/rms_configurator.dart';
import 'package:store_services_cli/configurators/app_code_configurator.dart';

class ProjectConfigurator {
  final _gms = GmsConfigurator();
  final _hms = HmsConfigurator();
  final _rms = RmsConfigurator();
  final _appCode = AppCodeConfigurator();

  Future<void> applyGms() async {
    await clean(); // Clean everything first to avoid duplicates or conflicts
    await _gms.apply();
    await _appCode.apply(StoreMode.gms);
  }

  Future<void> applyHms() async {
    await clean();
    await _hms.apply();
    await _appCode.apply(StoreMode.hms);
  }

  Future<void> applyRms() async {
    await clean();
    await _rms.apply();
    await _appCode.apply(StoreMode.rms);
  }

  Future<void> applyHybrid() async {
    print('🔧 Applying Hybrid configuration...');
    await clean(); // Reset state
    await _gms.apply();
    await _hms.apply();
    await _rms.apply();
    await _appCode.apply(StoreMode.hybrid);
  }

  Future<void> clean() async {
    print('🧹 Cleaning configurations...');
    await _gms.remove();
    await _hms.remove();
    await _rms.remove();
    await _appCode.remove();
    print('✨ Clean complete.');
  }
}
