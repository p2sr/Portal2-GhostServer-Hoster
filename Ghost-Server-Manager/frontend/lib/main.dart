import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_server_hoster/pages/auth/finish_discord_login_page.dart';
import 'package:portal2_ghost_server_hoster/pages/auth/login_page.dart';
import 'package:portal2_ghost_server_hoster/pages/auth/register_page.dart';
import 'package:portal2_ghost_server_hoster/pages/auth/reset_password_page.dart';
import 'package:portal2_ghost_server_hoster/pages/help_dialog.dart';
import 'package:portal2_ghost_server_hoster/pages/home_page.dart';
import 'package:portal2_ghost_server_hoster/pages/webinterface/webinterface_page.dart';
import 'package:simple_icons/simple_icons.dart';
import 'package:url_launcher/url_launcher.dart';

const spAuthTokenKey = "auth_token";
const spAuthTokenExpiryKey = "auth_token_expiry";

const spLastPreCountdownCommands = "last_pre_countdown_commands";
const spLastPostCountdownCommands = "last_post_countdown_commands";

Future<void> main() async {
  usePathUrlStrategy();

  await dotenv.load();

  runApp(
    MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          ShellRoute(
            builder: (context, state, child) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: child),
                _SiteFooter(),
              ],
            ),
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const HomePage(),
                routes: [
                  GoRoute(
                    path: 'webinterface/:serverId',
                    redirect: (context, state) {
                      var serverIdParam = state.pathParameters["serverId"];
                      if (serverIdParam == null ||
                          int.tryParse(serverIdParam) == null) {
                        return "/";
                      }
                      return null;
                    },
                    builder: (context, state) => WebinterfacePage(
                      serverId: int.parse(state.pathParameters["serverId"]!),
                    ),
                  ),
                ],
              ),
              GoRoute(
                path: '/login',
                builder: (context, state) => const LoginPage(),
                routes: [
                  GoRoute(
                    path: '/register',
                    builder: (context, state) => const RegisterPage(),
                  ),
                ],
              ),
              GoRoute(
                path: '/finish_discord_login',
                builder: (context, state) => FinishDiscordLoginPage(
                  code: state.uri.queryParameters["code"],
                ),
              ),
              GoRoute(
                path: '/reset_password',
                redirect: (context, state) {
                  if (!state.uri.queryParameters.containsKey("email") ||
                      !state.uri.queryParameters.containsKey("token")) {
                    return "/";
                  }
                  return null;
                },
                builder: (context, state) => ResetPasswordPage(
                  email: state.uri.queryParameters["email"]!,
                  token: state.uri.queryParameters["token"]!,
                ),
              ),
              GoRoute(
                path: '/help',
                builder: (context, state) => const HelpDialog(),
              ),
            ],
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
    ),
  );
}

class _SiteFooter extends StatelessWidget {
  const _SiteFooter();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            RichText(
              text: TextSpan(
                text: "Help",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
                recognizer: TapGestureRecognizer()
                  ..onTap = () => showDialog(
                    context: context,
                    builder: (context) => const HelpDialog(),
                  ),
              ),
            ),
            const Spacer(),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                var uri = Uri.parse(p2srDiscordInviteUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              icon: const Icon(Icons.discord),
            ),
            const SizedBox(width: 10),
            IconButton(
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
              onPressed: () async {
                var uri = Uri.parse(hosterGithubUrl);
                if (await canLaunchUrl(uri)) await launchUrl(uri);
              },
              icon: const Icon(SimpleIcons.github),
            ),
          ],
        ),
      ),
    );
  }
}
