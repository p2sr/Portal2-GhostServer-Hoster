import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_server_hoster/backend/backend.dart';
import 'package:portal2_ghost_server_hoster/backend/sse_client.dart';
import 'package:portal2_ghost_server_hoster/pages/home_page.dart';
import 'package:portal2_ghost_server_hoster/pages/webinterface/players_tab.dart';

class WebinterfacePage extends StatefulWidget {
  const WebinterfacePage({super.key, required this.serverId});

  final int serverId;

  @override
  State<WebinterfacePage> createState() => _WebinterfacePageState();
}

class _WebinterfacePageState extends State<WebinterfacePage> {
  bool loading = true;

  GhostServer? server;
  late GhostServerSettings settings;

  List<Player> players = [];
  SseClient? playersStreamClient;

  int navigationRailSelectedIndex = 0;

  @override
  void initState() {
    super.initState();
    setup();
  }

  Future<void> setup() async {
    setState(() => loading = true);

    server = await Backend.getGhostServerById(widget.serverId);
    settings = await Backend.getGhostServerSettingsById(widget.serverId);
    players = await Backend.getPlayers(widget.serverId);

    if (playersStreamClient == null) {
      playersStreamClient = await SseClient.connect(
        url: Backend.playersStreamUrl(widget.serverId),
        headers: {
          HttpHeaders.authorizationHeader: await Backend.authHeader(),
        },
      );

      playersStreamClient!.stream.listen((event) {
        setState(() => players = Backend.parsePlayersJson(event.data!));
      });
    }

    setState(() => loading = false);
  }

  @override
  void dispose() {
    playersStreamClient?.close();
    super.dispose();
  }

  Future<void> updateSettings(GhostServerSettings settings) async {
    setState(() => loading = true);
    await Backend.updateGhostServerSettings(widget.serverId, settings);
    setState(() => this.settings = settings);
    setState(() => loading = false);
  }

  Future<void> deleteGhostServer() async {
    var didDelete = await showDialog<bool?>(
      context: context,
      builder: (context) => DeleteGhostServerDialog(server: server!),
      barrierDismissible: false,
    );
    if (didDelete ?? false) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Ghost Server successfully deleted!")),
      );
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(server?.name ?? "Loading..."),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: setup,
            icon: const Icon(Icons.refresh),
          ),
          if (!loading)
            IconButton(
              onPressed: deleteGhostServer,
              icon: const Icon(Icons.delete_outlined),
            ),
        ],
      ),
      body: !loading
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                NavigationRail(
                  selectedIndex: navigationRailSelectedIndex,
                  onDestinationSelected: (idx) =>
                      setState(() => navigationRailSelectedIndex = idx),
                  labelType: NavigationRailLabelType.all,
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: const Text("General"),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.people_outlined),
                      selectedIcon: const Icon(Icons.people),
                      label: const Text("Players"),
                    ),
                  ],
                ),
                const VerticalDivider(),
                Expanded(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: SizedBox(
                        width: 2 * MediaQuery.sizeOf(context).width / 3,
                        child: switch (navigationRailSelectedIndex) {
                          1 => PlayersTab(
                            serverId: widget.serverId,
                            players: players,
                            update: setup,
                          ),
                          _ => _GeneralTab(
                            serverId: widget.serverId,
                            server: server!,
                            settings: settings,
                            updateSettings: updateSettings,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Backend.startCountdown(widget.serverId);
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: const Text("Countdown started!")),
          );
          setup();
        },
        icon: const Icon(Icons.play_arrow_outlined),
        label: const Text("Start Countdown"),
      ),
    );
  }
}

class _GeneralTab extends StatelessWidget {
  const _GeneralTab({
    required this.serverId,
    required this.server,
    required this.settings,
    required this.updateSettings,
  });

  final int serverId;
  final GhostServer server;
  final GhostServerSettings settings;
  final void Function(GhostServerSettings settings) updateSettings;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Connect",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          Text(
            "To connect, paste the text below into your game's console and hit enter!",
          ),
          const SizedBox(height: 20),
          GhostServerConnectCommandField(command: server.connectCommand()),
          const SizedBox(height: 80),
          Text("Settings", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 10),
          _SettingsSection(
            serverId: serverId,
            settings: settings,
            updateSettings: updateSettings,
          ),
          const SizedBox(height: 80),
          Text(
            "Server Message",
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 10),
          _ServerMessageSection(serverId: serverId),
        ],
      ),
    );
  }
}

class _SettingsSection extends StatefulWidget {
  const _SettingsSection({
    required this.serverId,
    required this.settings,
    required this.updateSettings,
  });

  final int serverId;
  final GhostServerSettings settings;
  final void Function(GhostServerSettings settings) updateSettings;

  @override
  State<_SettingsSection> createState() => _SettingsSectionState();
}

class _SettingsSectionState extends State<_SettingsSection> {
  final formKey = GlobalKey<FormState>();

  final countdownDurationController = TextEditingController();
  final preCommandsController = TextEditingController();
  final postCommandsController = TextEditingController();

  bool acceptingPlayers = true;
  bool acceptingSpectators = true;

  @override
  void initState() {
    super.initState();
    countdownDurationController.text = "${widget.settings.countdownDuration}";
    preCommandsController.text = widget.settings.preCountdownCommands;
    postCommandsController.text = widget.settings.postCountdownCommands;

    acceptingPlayers = widget.settings.acceptingPlayers;
    acceptingSpectators = widget.settings.acceptingSpectators;
  }

  GhostServerSettings newSettings() => GhostServerSettings(
    preCountdownCommands: preCommandsController.text.trim(),
    postCountdownCommands: postCommandsController.text.trim(),
    countdownDuration: int.tryParse(countdownDurationController.text) ?? 1,
    acceptingPlayers: acceptingPlayers,
    acceptingSpectators: acceptingSpectators,
  );

  bool isDirty() => newSettings() != widget.settings;

  Future<void> saveSettings() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    widget.updateSettings(newSettings());
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: acceptingPlayers,
                  title: const Text("Accept Players"),
                  onChanged: (v) => setState(() => acceptingPlayers = v),
                ),
                SwitchListTile(
                  value: acceptingSpectators,
                  title: const Text("Accept Spectators"),
                  onChanged: (v) => setState(() => acceptingSpectators = v),
                ),
                const SizedBox(height: 40),
                TextFormField(
                  controller: countdownDurationController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Countdown Duration",
                    suffixText: "s",
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (_) => setState(() {}),
                  validator: (s) {
                    if (s == null || s.isEmpty) {
                      return "Please provide the countdown duration.";
                    }
                    var d = int.tryParse(s);
                    if (d == null || d < 1) {
                      return "Please provide an integer greater than 0.";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Flex(
            direction: Axis.horizontal,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Flexible(
                child: TextFormField(
                  controller: preCommandsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Pre-Countdown Commands",
                  ),
                  maxLines: null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: TextFormField(
                  controller: postCommandsController,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    alignLabelWithHint: true,
                    labelText: "Post-Countdown Commands",
                  ),
                  maxLines: null,
                  onChanged: (_) => setState(() {}),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          FilledButton.icon(
            onPressed: isDirty() ? saveSettings : null,
            icon: const Icon(Icons.save_outlined),
            label: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class _ServerMessageSection extends StatefulWidget {
  const _ServerMessageSection({required this.serverId});

  final int serverId;

  @override
  State<_ServerMessageSection> createState() => _ServerMessageSectionState();
}

class _ServerMessageSectionState extends State<_ServerMessageSection> {
  final formKey = GlobalKey<FormState>();

  String message = "";

  Future<void> sendMessage() async {
    if (!(formKey.currentState?.validate() ?? false)) return;

    await Backend.sendServerMessage(widget.serverId, message.trim());
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Form(
          key: formKey,
          child: TextFormField(
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
              labelText: "Message",
            ),
            onChanged: (s) => message = s,
            validator: (s) {
              if (s == null || s.isEmpty) return "Please provide a message.";
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: sendMessage,
          icon: const Icon(Icons.send_outlined),
          label: const Text("Send"),
        ),
      ],
    );
  }
}
