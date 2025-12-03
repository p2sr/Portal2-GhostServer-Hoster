import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:portal2_ghost_server_hoster/backend/backend.dart';
import 'package:portal2_ghost_server_hoster/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool loading = true;

  late User currentUser;
  List<GhostServer> servers = [];

  bool showAllServers = false;

  @override
  void initState() {
    super.initState();
    setup();
  }

  Future<bool> checkLoggedIn() async {
    var sp = await SharedPreferences.getInstance();
    var authToken = sp.getString(spAuthTokenKey);
    if (authToken == null) {
      return false;
    }

    var expiry = DateTime.fromMillisecondsSinceEpoch(
      sp.getInt(spAuthTokenExpiryKey)!,
    );
    if (DateTime.now().isAtSameMomentAs(expiry) ||
        DateTime.now().isAfter(expiry)) {
      sp.remove(spAuthTokenKey);
      sp.remove(spAuthTokenExpiryKey);
      return false;
    }

    return true;
  }

  Future<void> setup() async {
    setState(() => loading = true);
    if (!await checkLoggedIn()) {
      if (!mounted) return;
      context.go("/login");
      return;
    }

    currentUser = await Backend.getCurrentUser();
    servers = await Backend.getGhostServers(showAll: showAllServers);

    setState(() => loading = false);
  }

  Future<void> deleteAccount() async {
    var shouldDelete =
        (await showDialog<bool>(
          context: context,
          builder: (context) => _DeleteAccountDialog(currentUser: currentUser),
        )) ??
        false;

    if (!shouldDelete) return;

    await Backend.deleteAccount();
    logout();
  }

  Future<void> logout() async {
    setState(() => loading = true);

    await Backend.revokeAuthToken();
    var sp = await SharedPreferences.getInstance();
    sp.remove(spAuthTokenKey);
    sp.remove(spAuthTokenExpiryKey);

    if (!mounted) return;
    context.go("/login");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ghost Servers"),
        centerTitle: true,
        actions: [
          IconButton(onPressed: setup, icon: const Icon(Icons.refresh)),
          PopupMenuButton(
            icon: const Icon(Icons.account_circle_outlined),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem(
                onTap: deleteAccount,
                child: const Text("Delete Account"),
              ),
              PopupMenuItem(onTap: logout, child: const Text("Logout")),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(10),
        child: !loading
            ? Center(
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width / 2,
                  child: Column(
                    children: [
                      if (currentUser.role == Role.admin) ...[
                        SwitchListTile(
                          value: showAllServers,
                          onChanged: (b) {
                            setState(() => showAllServers = b);
                            setup();
                          },
                          title: const Text("Show All"),
                        ),
                        const Divider(height: 20),
                      ],
                      servers.isNotEmpty
                          ? ListView.builder(
                              shrinkWrap: true,
                              itemCount: servers.length,
                              itemBuilder: (context, i) => _GhostServerCard(
                                server: servers[i],
                                currentUser: currentUser,
                                update: setup,
                              ),
                            )
                          : const Center(child: Text("Nothing to show")),
                    ],
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          var didCreate =
              (await showDialog<bool>(
                context: context,
                builder: (context) => _CreateGhostServerDialog(),
              )) ??
              false;

          if (didCreate) setup();
        },
        label: const Text("Create Ghost Server"),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

class _DeleteAccountDialog extends StatefulWidget {
  const _DeleteAccountDialog({required this.currentUser});

  final User currentUser;

  @override
  State<_DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<_DeleteAccountDialog> {
  final formKey = GlobalKey<FormState>();

  void delete() {
    if (!(formKey.currentState?.validate() ?? false)) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Delete Account"),
      content: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Do you really want to delete your account? This cannot be undone!",
            ),
            const Text("Enter your email below to confirm:"),
            const SizedBox(height: 20),
            TextFormField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                labelText: "Email",
                hintText: widget.currentUser.email,
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (s) {
                if (s == null || s.isEmpty) {
                  return "Please enter your email address.";
                }
                if (s != widget.currentUser.email) {
                  return "Email address is incorrect.";
                }
                return null;
              },
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
          onPressed: delete,
          child: const Text("Delete"),
        ),
      ],
    );
  }
}

class _GhostServerCard extends StatelessWidget {
  const _GhostServerCard({
    required this.server,
    required this.currentUser,
    required this.update,
  });

  final GhostServer server;
  final User currentUser;
  final void Function() update;

  @override
  Widget build(BuildContext context) {
    var content = Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    server.name,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(
                    "Expires ${server.relativeRemainingDuration}"
                    "${server.userId != currentUser.id ? " • Admin visible" : ""}",
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ),
              const Spacer(),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DeleteGhostServerDialog(
                      server: server,
                      update: update,
                    ),
                  );
                },
                icon: const Icon(Icons.delete_outlined),
              ),
            ],
          ),
          const Divider(height: 20),
          Text("Connecting:", style: Theme.of(context).textTheme.bodyLarge),
          Text(
            "To connect, paste the text below into your game's console and hit enter!",
          ),
          const SizedBox(height: 20),
          GhostServerConnectCommandField(command: server.connectCommand()),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FilledButton.tonal(
                onPressed: () => context.go("/webinterface/${server.id}"),
                child: const Text("Webinterface"),
              ),
            ],
          ),
        ],
      ),
    );

    if (server.userId == currentUser.id) {
      return Card(child: content);
    } else {
      return Card.outlined(child: content);
    }
  }
}

class GhostServerConnectCommandField extends StatelessWidget {
  const GhostServerConnectCommandField({super.key, required this.command});

  final String command;

  void copyConnectCommand(BuildContext context) {
    Clipboard.setData(ClipboardData(text: command));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: const Text("Copied!")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: TextEditingController(text: command),
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        suffixIcon: IconButton(
          onPressed: () => copyConnectCommand(context),
          icon: const Icon(Icons.copy),
        ),
      ),
      readOnly: true,
    );
  }
}

class DeleteGhostServerDialog extends StatelessWidget {
  const DeleteGhostServerDialog({
    super.key,
    required this.server,
    required this.update,
  });

  final GhostServer server;
  final void Function() update;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Delete Ghost Server"),
      content: Text(
        "Do you really want to delete the Ghost Server "
        "\"${server.name}\"? This cannot be reverted!",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () async {
            await Backend.deleteGhostServer(server.id);
            if (!context.mounted) return;
            Navigator.pop(context);
            update();
          },
          child: const Text("Delete"),
        ),
      ],
    );
  }
}

class _CreateGhostServerDialog extends StatefulWidget {
  const _CreateGhostServerDialog();

  @override
  State<_CreateGhostServerDialog> createState() =>
      _CreateGhostServerDialogState();
}

class _CreateGhostServerDialogState extends State<_CreateGhostServerDialog> {
  bool loading = false;
  String name = "";

  Future<void> createGhostServer() async {
    setState(() => loading = true);
    name = name.trim();
    await Backend.createGhostServer(name.isEmpty ? null : name);
    setState(() => loading = false);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Ghost Server"),
      content: !loading
          ? TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
                labelText: "Name (optional)",
              ),
              onChanged: (s) => name = s.trim(),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                const SizedBox(height: 10),
                const Text("Creating Ghost Server..."),
              ],
            ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: createGhostServer,
          child: const Text("Create"),
        ),
      ],
    );
  }
}
