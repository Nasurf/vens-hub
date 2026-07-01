import 'package:equatable/equatable.dart';

abstract class SignUpEvent extends Equatable {
  const SignUpEvent();

  @override
  List<Object> get props => [];
}

class SignUpFirstNameChanged extends SignUpEvent {
  final String firstName;

  const SignUpFirstNameChanged(this.firstName);

  @override
  List<Object> get props => [firstName];
}

class SignUpLastNameChanged extends SignUpEvent {
  final String lastName;

  const SignUpLastNameChanged(this.lastName);

  @override
  List<Object> get props => [lastName];
}

class SignUpEmailChanged extends SignUpEvent {
  final String email;

  const SignUpEmailChanged(this.email);

  @override
  List<Object> get props => [email];
}

class SignUpPasswordChanged extends SignUpEvent {
  final String password;

  const SignUpPasswordChanged(this.password);

  @override
  List<Object> get props => [password];
}

class SignUpConfirmPasswordChanged extends SignUpEvent {
  final String confirmPassword;

  const SignUpConfirmPasswordChanged(this.confirmPassword);

  @override
  List<Object> get props => [confirmPassword];
}

class SignUpLevelSelected extends SignUpEvent {
  final String level;

  const SignUpLevelSelected(this.level);

  @override
  List<Object> get props => [level];
}

class SignUpDepartmentSelected extends SignUpEvent {
  final String department;

  const SignUpDepartmentSelected(this.department);

  @override
  List<Object> get props => [department];
}

class SignUpNextStep extends SignUpEvent {}

class SignUpPreviousStep extends SignUpEvent {}

class SignUpSubmitted extends SignUpEvent {}

class SignUpPasswordVisibilityToggled extends SignUpEvent {}

class SignUpConfirmPasswordVisibilityToggled extends SignUpEvent {}
