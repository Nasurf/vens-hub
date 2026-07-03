// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:get/get.dart';
// import 'package:vens_hub/core/services/auth/firebase_auth_service.dart';
// import 'package:vens_hub/core/services/data/firestore_service.dart'; // Corrected path
// import 'package:vens_hub/data/models/user_model.dart';
// import 'package:vens_hub/presentation/screens/onboarding/onboarding_page.dart'; // Corrected path

// class UserRepository extends GetxController {
//   final FirebaseAuthService _authService = Get.find<FirebaseAuthService>();
//   final FireStoreServices _firestoreService = Get.find<FireStoreServices>();
//
//   // Reactive variable for the user model. Rxn allows null values.
//   final Rxn<UserModel> currentUserModel = Rxn<UserModel>();
//
//   @override
//   void onReady() {
//     super.onReady();
//
//     // Listen to Firebase authentication state changes.
//     _authService.authStateChanges().listen((User? user) {
//       if (user != null) {
//         // When the user is authenticated, bind the user's Firestore document
//         // to the reactive variable.
//         currentUserModel.bindStream(_firestoreService.userDataStream(user.uid));
//       } else {
//         // No user is signed in.
//         currentUserModel.value = null;
//         Get.offAll(OnboardingPage());
//       }
//     });
//   }
//
//   // Getter for the current user.
//   UserModel? get user => currentUserModel.value;
// }
