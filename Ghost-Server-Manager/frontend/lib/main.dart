import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_sever_hoster/pages/auth/finish_discord_login_page.dart';
import 'package:portal2_ghost_sever_hoster/pages/auth/login_page.dart';
import 'package:portal2_ghost_sever_hoster/pages/auth/register_page.dart';
import 'package:portal2_ghost_sever_hoster/pages/home_page.dart';
import 'package:portal2_ghost_sever_hoster/pages/webinterface/webinterface_page.dart';

const spAuthTokenKey = "auth_token";
const spAuthTokenExpiryKey = "auth_token_expiry";

void main() {
  usePathUrlStrategy();

  runApp(
    MaterialApp.router(
      routerConfig: GoRouter(
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
            builder: (context, state) =>
                FinishDiscordLoginPage(code: state.uri.queryParameters["code"]),
          ),
        ],
      ),
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
    ),
  );
}
