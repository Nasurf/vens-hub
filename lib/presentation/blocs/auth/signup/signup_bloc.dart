import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/material.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_bloc.dart';
import 'package:vens_hub/presentation/blocs/auth/auth_event.dart';
import 'package:vens_hub/presentation/blocs/auth/signup/signup_event.dart';
import 'package:vens_hub/presentation/blocs/auth/signup/signup_state.dart';

class SignUpBloc extends Bloc<SignUpEvent, SignUpState> {
  final AuthBloc authBloc;

  SignUpBloc({required this.authBloc})
    : super(
        SignUpState(
          formKey1: GlobalKey<FormState>(),
          formKey4: GlobalKey<FormState>(),
        ),
      ) {
    on<SignUpFirstNameChanged>((event, emit) {
      emit(state.copyWith(firstName: event.firstName));
    });

    on<SignUpLastNameChanged>((event, emit) {
      emit(state.copyWith(lastName: event.lastName));
    });

    on<SignUpEmailChanged>((event, emit) {
      emit(state.copyWith(email: event.email));
    });

    on<SignUpPasswordChanged>((event, emit) {
      emit(state.copyWith(password: event.password));
    });

    on<SignUpConfirmPasswordChanged>((event, emit) {
      emit(state.copyWith(confirmPassword: event.confirmPassword));
    });

    on<SignUpLevelSelected>((event, emit) {
      emit(state.copyWith(selectedLevel: event.level));
    });

    on<SignUpDepartmentSelected>((event, emit) {
      emit(state.copyWith(selectedDepartment: event.department));
    });

    on<SignUpNextStep>((event, emit) {
      if (state.currentStep < 3) {
        emit(state.copyWith(currentStep: state.currentStep + 1));
      }
    });

    on<SignUpPreviousStep>((event, emit) {
      if (state.currentStep > 0) {
        emit(state.copyWith(currentStep: state.currentStep - 1));
      }
    });

    on<SignUpSubmitted>((event, emit) {
      if (state.formKey4.currentState!.validate()) {
        authBloc.add(
          AuthSignUpRequested(
            email: state.email,
            password: state.password,
            firstName: state.firstName,
            lastName: state.lastName,
            level: state.selectedLevel,
            department: state.selectedDepartment,
          ),
        );
      }
    });

    on<SignUpPasswordVisibilityToggled>((event, emit) {
      emit(state.copyWith(passwordVisible: !state.passwordVisible));
    });

    on<SignUpConfirmPasswordVisibilityToggled>((event, emit) {
      emit(
        state.copyWith(confirmPasswordVisible: !state.confirmPasswordVisible),
      );
    });
  }
}
