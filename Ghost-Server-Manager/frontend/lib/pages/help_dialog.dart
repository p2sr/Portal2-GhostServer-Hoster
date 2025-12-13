import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

const ghostServerGithubUrl = "https://github.com/p2sr/GhostServer";
const p2srDiscordInviteUrl = "https://discord.com/invite/hRwE4Zr";
const sarHomepageUrl = "https://sar.portal2.sr/";
const hosterGithubUrl = "https://github.com/p2sr/Portal2-GhostServer-Hoster";

class HelpDialog extends StatelessWidget {
  const HelpDialog({super.key});

  TextSpan hyperlinkSpanWithHandler({
    required String text,
    required void Function() onTap,
    required TextStyle style,
  }) => TextSpan(
    text: text,
    style: style,
    recognizer: TapGestureRecognizer()..onTap = onTap,
  );

  TextSpan hyperlinkSpan({
    required String text,
    required String url,
    required TextStyle style,
  }) => hyperlinkSpanWithHandler(
    text: text,
    style: style,
    onTap: () async {
      var uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      }
    },
  );

  @override
  Widget build(BuildContext context) {
    var bodyStyle = Theme.of(context).textTheme.bodyMedium!;
    var colorScheme = Theme.of(context).colorScheme;

    var headlineStyle = Theme.of(context).textTheme.titleLarge;
    var hyperlinkStyle = bodyStyle.copyWith(color: colorScheme.primary);

    return AlertDialog(
      title: const Text("Help"),
      content: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width / 2,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("What is this website?", style: headlineStyle),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(text: "This is a website for hosting "),
                    hyperlinkSpan(
                      text: "Portal 2 Ghost Servers",
                      url: ghostServerGithubUrl,
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(
                      text: ". Ghost Servers are a system developed by the ",
                    ),
                    hyperlinkSpan(
                      text: "Portal 2 Speedrunning Community",
                      url: p2srDiscordInviteUrl,
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(
                      text:
                          " that allows multiple players to speedrun the "
                          "singleplayer campaign simultaneously. Each player "
                          "plays the game on their own and the positions of the "
                          "other players are shown as little markers in the game. "
                          "At the end of each level, players can be synced, "
                          "such that all players begin the next level at the "
                          "same time. It is a fun way to race together and "
                          "compare times!",
                    ),
                  ],
                  style: bodyStyle,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                "Normally, to run a ghost race, you need a Ghost Server instance "
                "to run somewhere where it is accessible to the players you "
                "want to race with. This is not always easily possible, especially "
                "if the players live far away from each other. Therefore, this website "
                "was created. It provides an easy way to host Ghost Servers for anyone, "
                "and makes them accessible using a single command in the game. In "
                "addition, the website provides a webinterface to configure the server.",
              ),
              const SizedBox(height: 40),
              Text("How do I use this website?", style: headlineStyle),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text: "To get started, make sure you have ",
                    ),
                    hyperlinkSpan(
                      text: "SourceAutoRecord",
                      url: sarHomepageUrl,
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(
                      text:
                          " installed. SAR is a client-side modification for "
                          "the game that makes connecting to Ghost Servers possible.",
                    ),
                  ],
                  style: bodyStyle,
                ),
              ),
              const SizedBox(height: 20),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(
                      text:
                          "To use this website, you need an account. Head to ",
                    ),
                    hyperlinkSpanWithHandler(
                      text: "Register",
                      onTap: () {
                        Navigator.pop(context);
                        context.go("/login/register");
                      },
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(text: " to create an account, or "),
                    hyperlinkSpanWithHandler(
                      text: "Login",
                      onTap: () {
                        Navigator.pop(context);
                        context.go("/login");
                      },
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(
                      text:
                          " if you already have one. Once logged in, hit \"Create "
                          "Ghost Server\" at the bottom right of the screen and "
                          "follow the instructions. Then, you can connect to the "
                          "Ghost Server using the command shown. If you want to "
                          "further configure the Ghost Server, open the webinterface "
                          "using the button. There, you can also officially start "
                          "the race using the countdown.",
                    ),
                  ],
                  style: bodyStyle,
                ),
              ),
              const SizedBox(height: 40),
              Text("Helpful Resources", style: headlineStyle),
              const SizedBox(height: 10),
              RichText(
                text: TextSpan(
                  children: [
                    const TextSpan(text: "If you need help, visit the "),
                    hyperlinkSpan(
                      text: "Portal 2 Speedrunning Discord",
                      url: p2srDiscordInviteUrl,
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(text: " and take a look in the "),
                    TextSpan(
                      text: "#ghost-races",
                      style: bodyStyle.copyWith(
                        color: colorScheme.secondary,
                      ),
                    ),
                    const TextSpan(
                      text:
                          " channel.\nAdditionally, this website is open-source on "
                          "GitHub at ",
                    ),
                    hyperlinkSpan(
                      text: "Portal2-GhostServer-Hoster",
                      url: hosterGithubUrl,
                      style: hyperlinkStyle,
                    ),
                    const TextSpan(
                      text: " if you encounter any issues.",
                    ),
                  ],
                  style: bodyStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
