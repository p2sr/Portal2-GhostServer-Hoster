import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_server_hoster/backend/backend.dart';
import 'package:portal2_ghost_server_hoster/backend/sse_client.dart';
import 'package:portal2_ghost_server_hoster/main.dart';
import 'package:portal2_ghost_server_hoster/pages/home_page.dart';
import 'package:portal2_ghost_server_hoster/pages/webinterface/players_tab.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _commandsPresets = [
  _CommandsPreset(
    name: "Fullgame",
    preCountdownCommands:
        "ghost_sync 1\n"
        "ghost_sync_countdown 3\n"
        "svar_set sp_use_save 2\n"
        "ghost_leaderboard_mode 1\n"
        "ghost_leaderboard_reset\n"
        "sar_on_load conds map=sp_a1_wakeup \"ghost_sync 0\" map=sp_a2_intro \"ghost_sync 1\"",
    postCountdownCommands:
        "sar_speedrun_skip_cutscenes 1\n"
        "sar_speedrun_offset 18980\n"
        "sar_speedrun_reset\n"
        "stop\n"
        "sv_allow_mobile_portals 0\n"
        "load vault",
  ),
  _CommandsPreset(
    name: "Speedrun Mod",
    preCountdownCommands:
        "ghost_sync 1\n"
        "ghost_sync_countdown 3\n"
        "svar_set sp_use_save 2\n"
        "ghost_leaderboard_mode 1\n"
        "ghost_leaderboard_reset",
    postCountdownCommands:
        "sar_speedrun_offset 0\n"
        "sar_speedrun_reset\n"
        "stop\n"
        "sv_allow_mobile_portals 0\n"
        "map sp_a1_intro1",
  ),
  _CommandsPreset(
    name: "Portal Stories: Mel",
    preCountdownCommands:
        "ghost_sync 1\n"
        "ghost_sync_countdown 3\n"
        "ghost_leaderboard_mode 1\n"
        "ghost_leaderboard_reset\n"
        "sar_ent_slot_serial 838 16301",
    postCountdownCommands:
        "sar_speedrun_reset\n"
        "map st_a1_tramride",
  ),
];

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

class _CommandsPreset {
  const _CommandsPreset({
    required this.name,
    required this.preCountdownCommands,
    required this.postCountdownCommands,
  });

  final String name;
  final String preCountdownCommands;
  final String postCountdownCommands;
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

    var settings = newSettings();

    var sp = await SharedPreferences.getInstance();
    sp.setString(spLastPreCountdownCommands, settings.preCountdownCommands);
    sp.setString(spLastPostCountdownCommands, settings.postCountdownCommands);

    widget.updateSettings(settings);
  }

  Widget commandsTextField({
    required String labelText,
    required TextEditingController controller,
  }) => TextFormField(
    controller: controller,
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
      labelText: labelText,
      suffixIcon: controller.text.isNotEmpty
          ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => controller.clear()),
            )
          : null,
    ),
    maxLines: null,
    onChanged: (_) => setState(() {}),
  );

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
                child: commandsTextField(
                  controller: preCommandsController,
                  labelText: "Pre-Countdown Commands",
                ),
              ),
              const SizedBox(width: 20),
              Flexible(
                child: commandsTextField(
                  controller: postCommandsController,
                  labelText: "Post-Countdown Commands",
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
          Row(
            children: [
              FilledButton.icon(
                onPressed: isDirty() ? saveSettings : null,
                icon: const Icon(Icons.save_outlined),
                label: const Text("Save"),
              ),
              const SizedBox(width: 10),
              TextButton(
                onPressed: () async {
                  var preset = await showDialog<_CommandsPreset>(
                    context: context,
                    builder: (context) => const _SelectPresetDialog(),
                  );
                  if (preset == null) return;
                  preCommandsController.clear();
                  preCommandsController.text = preset.preCountdownCommands;
                  postCommandsController.clear();
                  postCommandsController.text = preset.postCountdownCommands;
                  setState(() {});
                },
                child: const Text("Use Preset"),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SelectPresetDialog extends StatefulWidget {
  const _SelectPresetDialog();

  @override
  State<_SelectPresetDialog> createState() => _SelectPresetDialogState();
}

class _SelectPresetDialogState extends State<_SelectPresetDialog> {
  bool loading = true;

  _CommandsPreset? lastSavedPreset;

  @override
  void initState() {
    super.initState();
    setup();
  }

  Future<void> setup() async {
    var sp = await SharedPreferences.getInstance();
    var pre = sp.getString(spLastPreCountdownCommands) ?? "";
    var post = sp.getString(spLastPostCountdownCommands) ?? "";

    lastSavedPreset = _CommandsPreset(
      name: "Last Saved",
      preCountdownCommands: pre,
      postCountdownCommands: post,
    );
    setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    List<_CommandsPreset> presets = [..._commandsPresets];
    if (lastSavedPreset != null) presets.add(lastSavedPreset!);

    return AlertDialog(
      title: const Text("Presets"),
      content: SizedBox(
        width: MediaQuery.sizeOf(context).width / 2,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: !loading
                ? presets
                      .map(
                        (preset) => _PresetTile(
                          preset: preset,
                          onSelected: () => Navigator.pop(context, preset),
                        ),
                      )
                      .toList()
                : const [CircularProgressIndicator()],
          ),
        ),
      ),
    );
  }
}

class _PresetTile extends StatelessWidget {
  const _PresetTile({required this.preset, required this.onSelected});

  final _CommandsPreset preset;
  final void Function() onSelected;

  Widget commandsField({
    required String labelText,
    required String text,
  }) => TextField(
    controller: TextEditingController(text: text),
    decoration: InputDecoration(
      border: const OutlineInputBorder(),
      alignLabelWithHint: true,
      labelText: labelText,
    ),
    readOnly: true,
    maxLines: null,
  );

  double getMaxLineWidth(String text, TextStyle style) {
    return text
        .split("\n")
        .map((line) {
          var painter = TextPainter(
            text: TextSpan(text: line, style: style),
            textDirection: TextDirection.ltr,
          );
          painter.layout(maxWidth: double.infinity);
          return painter.width;
        })
        .reduce((max, el) => el > max ? el : max);
  }

  @override
  Widget build(BuildContext context) {
    var preCountdownCommands = preset.preCountdownCommands.isNotEmpty
        ? preset.preCountdownCommands
        : "<none>";
    var postCountdownCommands = preset.postCountdownCommands.isNotEmpty
        ? preset.postCountdownCommands
        : "<none>";

    var textTheme = Theme.of(context).textTheme.bodyLarge!;
    var maxWidth = max(
      getMaxLineWidth(preCountdownCommands, textTheme),
      getMaxLineWidth(postCountdownCommands, textTheme),
    );

    return ExpansionTile(
      title: Text(preset.name),
      expandedAlignment: Alignment.topLeft,
      controlAffinity: ListTileControlAffinity.leading,
      trailing: TextButton(
        onPressed: onSelected,
        child: const Text("Select"),
      ),
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth + 40),
            child: Column(
              children: [
                const SizedBox(height: 10),
                commandsField(
                  labelText: "Pre-Countdown Commands",
                  text: preCountdownCommands,
                ),
                const SizedBox(height: 20),
                commandsField(
                  labelText: "Post-Countdown Commands",
                  text: postCountdownCommands,
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ],
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
