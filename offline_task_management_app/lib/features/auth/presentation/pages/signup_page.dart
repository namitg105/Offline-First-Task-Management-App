import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/common/widgets/loader.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/utils/show_snackbar.dart';
import '../../../../core/utils/validators.dart';
import '../bloc/auth_bloc.dart';
import '../widgets/auth_divider.dart';
import '../widgets/auth_field.dart';
import '../widgets/auth_gradient_button.dart';
import '../widgets/google_auth_button.dart';

class SignUpPage extends StatefulWidget {
  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const SignUpPage());

  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _signUp() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthSignUpSubmitted(
            name: _nameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text.trim(),
          ),
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: Padding(
        padding: const EdgeInsets.all(15),
        child: BlocConsumer<AuthBloc, AuthState>(
          listener: (context, state) {
            if (state is AuthFailure) {
              showSnackBar(context, state.message);
            } else if (state is AuthSuccess) {
              // AppUserBloc has already been told, so the root widget is
              // about to swap to the task list. Just clear this page off
              // the stack.
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          },
          builder: (context, state) {
            if (state is AuthLoading) return const Loader();

            return Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Sign Up.',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    AuthField(
                      hintText: 'Name',
                      controller: _nameController,
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 15),
                    AuthField(
                      hintText: 'Email',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 15),
                    AuthField(
                      hintText: 'Password',
                      controller: _passwordController,
                      isObscureText: true,
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 20),
                    AuthGradientButton(
                      buttonText: 'Create account',
                      onPressed: _signUp,
                    ),
                    const SizedBox(height: 20),
                    const AuthDivider(),
                    const SizedBox(height: 20),
                    GoogleAuthButton(
                      onPressed: () =>
                          context.read<AuthBloc>().add(const AuthGoogleSignInPressed()),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: RichText(
                          text: TextSpan(
                            text: 'Already have an account? ',
                            style: Theme.of(context).textTheme.titleMedium,
                            children: [
                              TextSpan(
                                text: 'Sign In',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: AppPalette.gradient2,
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
