import 'package:flutter/material.dart';
import 'package:portal2_ghost_server_hoster/backend/backend.dart';

class PlayersTab extends StatefulWidget {
  const PlayersTab({
    super.key,
    required this.serverId,
    required this.players,
    required this.update,
  });

  final int serverId;
  final List<Player> players;

  final void Function() update;

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const TabBar(
            tabs: [
              Tab(
                icon: Icon(Icons.people_outlined),
                child: Text("Connected Players"),
              ),
              Tab(
                icon: Icon(Icons.list_alt_outlined),
                child: Text("Whitelist"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: TabBarView(
              children: [
                _ConnectedPlayersTab(
                  serverId: widget.serverId,
                  players: widget.players,
                  update: widget.update,
                ),
                _WhitelistTab(
                  serverId: widget.serverId,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectedPlayersTab extends StatelessWidget {
  const _ConnectedPlayersTab({
    required this.serverId,
    required this.players,
    required this.update,
  });

  final int serverId;
  final List<Player> players;
  final void Function() update;

  Future<bool> showConfirmationDialog(BuildContext context,
      String title,
      String content,
      String confirmAction,) async =>
      (await showDialog<bool>(
        context: context,
        builder: (context) =>
            AlertDialog(
              title: Text(title),
              content: Text(content),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Cancel"),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(confirmAction),
                ),
              ],
            ),
      )) ??
          false;

  @override
  Widget build(BuildContext context) {
    if (players.isEmpty) return const Text("No players connected!");

    return ListView.builder(
      shrinkWrap: true,
      itemCount: players.length,
      itemBuilder: (context, i) {
        var player = players[i];
        return ListTile(
          title: Text(
            player.name,
          ),
          subtitle: Text(
            "ID: ${player.id}"
                "${player.isSpectator ? " • Spectator" : ""}",
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () async {
                  var shouldKick = await showConfirmationDialog(
                    context,
                    "Kick Player",
                    "Do you really want to kick the player ${player.name}",
                    "Kick",
                  );

                  if (shouldKick) {
                    await Backend.disconnectPlayerById(serverId, player.id);
                    update();
                  }
                },
                icon: const Icon(Icons.logout),
                label: const Text("Kick"),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: () async {
                  var shouldBan = await showConfirmationDialog(
                    context,
                    "Ban Player",
                    "Do you really want to ban the player ${player.name}",
                    "Ban",
                  );

                  if (shouldBan) {
                    await Backend.banPlayerById(serverId, player.id);
                    update();
                  }
                },
                icon: const Icon(Icons.remove_circle_outline),
                label: const Text("Ban"),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WhitelistTab extends StatefulWidget {
  const _WhitelistTab({required this.serverId});

  final int serverId;

  @override
  State<_WhitelistTab> createState() => _WhitelistTabState();
}

class _WhitelistTabState extends State<_WhitelistTab> {
  late Whitelist whitelist;

  bool loading = true;

  @override
  void initState() {
    super.initState();
    setup();
  }

  Future<void> setup() async {
    setState(() => loading = true);
    whitelist = await Backend.getWhitelist(widget.serverId);
    setState(() => loading = false);
  }

  Future<void> addToWhitelist() async {
    var entry = await showDialog<WhitelistEntry?>(
      context: context,
      builder: (context) => const _AddToWhitelistDialog(),
    );
    if (entry == null) return;

    setState(() => loading = true);
    await Backend.addToWhitelist(widget.serverId, entry);
    setup();
  }

  @override
  Widget build(BuildContext context) {
    return !loading
        ? SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SwitchListTile(
            value: whitelist.enabled,
            onChanged: (b) async {
              setState(() => loading = true);
              await Backend.setWhitelistStatus(widget.serverId, b);
              setup();
            },
            title: const Text("Enabled"),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.icon(
                onPressed: addToWhitelist,
                icon: const Icon(Icons.add),
                label: const Text("Add to whitelist"),
              ),
            ],
          ),
          const SizedBox(height: 20),
          whitelist.entries.isNotEmpty
              ? ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: whitelist.entries.length,
            itemBuilder: (context, i) =>
                ListTile(
                  title: Text(whitelist.entries[i].value),
                  subtitle: Text(switch (whitelist.entries[i].type) {
                    WhitelistEntryType.ip => "IP",
                    WhitelistEntryType.name => "Name",
                  }),
                  trailing: IconButton(
                    onPressed: () async {
                      setState(() => loading = true);
                      await Backend.removeFromWhitelist(
                        widget.serverId,
                        whitelist.entries[i],
                      );
                      setup();
                    },
                    icon: const Icon(Icons.close),
                  ),
                ),
          )
              : const Text("No players on whitelist"),
        ],
      ),
    )
        : const Center(child: CircularProgressIndicator());
  }
}

class _AddToWhitelistDialog extends StatefulWidget {
  const _AddToWhitelistDialog();

  @override
  State<_AddToWhitelistDialog> createState() => _AddToWhitelistDialogState();
}

class _AddToWhitelistDialogState extends State<_AddToWhitelistDialog> {
  final formKey = GlobalKey<FormState>();

  WhitelistEntryType type = WhitelistEntryType.name;
  String value = "";

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Add to whitelist"),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioGroup<WhitelistEntryType>(
              groupValue: type,
              onChanged: (v) =>
                  setState(() => type = v ?? WhitelistEntryType.name),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile(
                    value: WhitelistEntryType.name,
                    title: const Text("Name"),
                  ),
                  RadioListTile(
                    value: WhitelistEntryType.ip,
                    title: const Text("IP"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                labelText: "Value",
              ),
              validator: (s) {
                if (s == null || s.isEmpty) return "Please provide a value.";
                return null;
              },
              onChanged: (s) => value = s,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            if (!(formKey.currentState?.validate() ?? false)) return;
            Navigator.pop(context, WhitelistEntry(type: type, value: value));
          },
          child: const Text("Add"),
        ),
      ],
    );
  }
}
