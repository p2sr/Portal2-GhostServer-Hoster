import 'package:after_layout/after_layout.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_server_hoster/backend/backend.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.email,
    required this.token,
  });

  final String email;
  final String token;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with AfterLayoutMixin {
  final formKey = GlobalKey<FormState>();

  String password = "";
  bool loading = true;

  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    if (!await Backend.validatePasswordResetCredentials(
      widget.email,
      widget.token,
    )) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            "Password reset request invalid! Please try again.",
          ),
        ),
      );
      context.go("/login");
      return;
    }

    setState(() => loading = false);
  }

  Future<void> changePassword() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    setState(() => loading = true);

    try {
      await Backend.resetPassword(widget.email, widget.token, password);
    } catch (e, stack) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed resetting password: $e")),
      );
      debugPrint("PW reset failed: $e\n$stack");
      return;
    }

    await Backend.logout();
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Password successfully changed! Please login again."),
      ),
    );

    context.go("/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Center(
        child: !loading
            ? SizedBox(
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
                          labelText: "New Password",
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
                          if (confirmPassword == null ||
                              confirmPassword.isEmpty) {
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
                        onPressed: changePassword,
                        child: const Text("Change Password"),
                      ),
                    ],
                  ),
                ),
              )
            : const CircularProgressIndicator(),
      ),
    );
  }
}
