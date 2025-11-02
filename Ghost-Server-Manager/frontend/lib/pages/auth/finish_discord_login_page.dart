import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_sever_hoster/backend/backend.dart';
import 'package:portal2_ghost_sever_hoster/pages/auth/login_page.dart';
import 'package:after_layout/after_layout.dart';

class FinishDiscordLoginPage extends StatefulWidget {
  const FinishDiscordLoginPage({super.key, required this.code});

  final String? code;

  @override
  State<FinishDiscordLoginPage> createState() => _FinishDiscordLoginPageState();
}

class _FinishDiscordLoginPageState extends State<FinishDiscordLoginPage>
    with AfterLayoutMixin {
  @override
  Future<void> afterFirstLayout(BuildContext context) async {
    if (widget.code == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Login with Discord failed")),
      );
      context.go("/login");
      return;
    }

    try {
      var (token, expiry) = await Backend.finishDiscordOauth2Login(
        widget.code!,
      );
      await saveAccessToken(token, expiry);

      if (!context.mounted) return;
      context.go("/");
    } catch (e, stack) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Login failed")),
      );
      debugPrint("Failed logging in: $e\n$stack");
      context.go("/login");
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
