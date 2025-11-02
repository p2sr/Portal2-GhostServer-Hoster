import 'package:email_validator/email_validator.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_sever_hoster/backend/backend.dart';
import 'package:portal2_ghost_sever_hoster/main.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web/web.dart' as html;

Future<void> loginWithDiscord() async {
  var url = await Backend.getDiscordOauth2Url();
  html.window.open(url, '_self');
}

Future<void> saveAccessToken(String token, DateTime expiry) async {
  var sp = await SharedPreferences.getInstance();
  sp.setString(spAuthTokenKey, token);
  sp.setInt(spAuthTokenExpiryKey, expiry.millisecondsSinceEpoch);
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final formKey = GlobalKey<FormState>();

  String email = "";
  String password = "";

  Future<void> login() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    try {
      var (token, expiry) = await Backend.login(email, password);
      await saveAccessToken(token, expiry);

      if (!mounted) return;
      context.go("/");
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed")),
      );
      debugPrint("Failed logging in: $e\n$stack");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Login"), centerTitle: true),
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
                const SizedBox(height: 50),
                FilledButton(
                  onPressed: login,
                  child: const Text("Login"),
                ),
                if (kSupportsDiscordAuth) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: loginWithDiscord,
                    icon: const Icon(Icons.discord),
                    label: const Text("Login with Discord"),
                  ),
                ],
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => context.go("/login/register"),
                  child: const Text("Register"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
