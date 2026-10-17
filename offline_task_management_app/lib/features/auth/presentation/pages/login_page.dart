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
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  static Route<void> route() =>
      MaterialPageRoute(builder: (_) => const LoginPage());

  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthBloc>().add(
          AuthLoginSubmitted(
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
                      'Sign In.',
                      style: TextStyle(
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
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
                    AuthGradientButton(buttonText: 'Sign in', onPressed: _login),
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
                        onTap: () =>
                            Navigator.push(context, SignUpPage.route()),
                        child: RichText(
                          text: TextSpan(
                            text: 'Don\'t have an account? ',
                            style: Theme.of(context).textTheme.titleMedium,
                            children: [
                              TextSpan(
                                text: 'Sign Up',
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
