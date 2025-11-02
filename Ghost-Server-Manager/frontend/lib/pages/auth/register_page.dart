import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_sever_hoster/backend/backend.dart';

import 'login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final formKey = GlobalKey<FormState>();

  String email = "";
  String password = "";

  Future<void> register() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    try {
      await Backend.register(email, password);
      if (!mounted) return;
      context.go("/login");
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed registering")),
      );
      debugPrint("Failed registering: $e\n$stack");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register"), centerTitle: true),
      body: Center(
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width / 3,
          child: Form(
            key: formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextFormField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Email",
                  ),
                  keyboardType: TextInputType.emailAddress,
                  validator: (email) {
                    if (email == null || email.isEmpty) {
                      return "Please provide an Email address.";
                    }
                    if (!EmailValidator.validate(email)) {
                      return "Please provide a valid Email address!";
                    }

                    return null;
                  },
                  onChanged: (s) => email = s.trim(),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Password",
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  validator: (password) {
                    if (password == null || password.isEmpty) {
                      return "Please provide a password.";
                    }

                    return null;
                  },
                  onChanged: (s) => password = s,
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Confirm password",
                  ),
                  keyboardType: TextInputType.visiblePassword,
                  validator: (confirmPassword) {
                    if (confirmPassword == null || confirmPassword.isEmpty) {
                      return "Please provide your password.";
                    }
                    if (confirmPassword != password) {
                      return "Passwords don't match!";
                    }

                    return null;
                  },
                  obscureText: true,
                ),
                const SizedBox(height: 50),
                FilledButton(
                  onPressed: register,
                  child: const Text("Register"),
                ),
                if (kSupportsDiscordAuth) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: loginWithDiscord,
                    icon: const Icon(Icons.discord),
                    label: const Text("Login with Discord"),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
