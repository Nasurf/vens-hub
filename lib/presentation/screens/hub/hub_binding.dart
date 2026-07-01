import 'package:get/get.dart';
import 'package:vens_hub/presentation/screens/hub/hub_page.mobile.dart';

class HubBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => HubController());
  }
}
