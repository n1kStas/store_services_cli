import 'package:store_services_cli/menu/selection_menu.dart';
import 'package:store_services_cli/configurators/project_configurator.dart';

void main(List<String> arguments) async {
  try {
    final choice = await SelectionMenu.show();
    final configurator = ProjectConfigurator();

    switch (choice) {
      case 1:
        await configurator.applyGms();
        break;
      case 2:
        await configurator.applyHms();
        break;
      case 3:
        await configurator.applyRms();
        break;
      case 4:
        await configurator.applyHybrid();
        break;
      case 5:
        await configurator.clean();
        break;
    }
  } catch (e) {
    print('❌ Ошибка: $e');
  }
}
