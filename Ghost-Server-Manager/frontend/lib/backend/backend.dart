import 'dart:convert';
import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:http/http.dart' as http;
import 'package:portal2_ghost_server_hoster/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'backend.freezed.dart';

part 'backend.g.dart';

// Prefer compile-time values provided with `--dart-define` and fall back
// to values from `flutter_dotenv` (useful for local/dev when dotenv is available).
const _hostBuild = String.fromEnvironment('HOST', defaultValue: '');
const _portBuild = String.fromEnvironment('SERVER_PORT', defaultValue: '');
const _protocolBuild = String.fromEnvironment('PROTOCOL', defaultValue: '');
const _discordClientIdBuild = String.fromEnvironment(
  'DISCORD_CLIENT_ID',
  defaultValue: '',
);
const _mailerUser = String.fromEnvironment('MAILER_USER', defaultValue: '');

String get _host =>
    _hostBuild.isNotEmpty ? _hostBuild : dotenv.env["HOST"] ?? 'localhost';

String get _port =>
    _portBuild.isNotEmpty ? _portBuild : dotenv.env["SERVER_PORT"] ?? '8080';

String get _protocol => _protocolBuild.isNotEmpty
    ? _protocolBuild
    : dotenv.env["PROTOCOL"] ?? 'http';

String get _baseUri => "$_protocol://$_host:$_port";

String get _baseAuthUri => "$_baseUri/api/auth";

String get _baseServerUri => "$_baseUri/api/server";

bool get kSupportsPasswordReset =>
    _mailerUser.isNotEmpty || dotenv.env.containsKey('MAILER_USER');

bool get kSupportsDiscordAuth =>
    _discordClientIdBuild.isNotEmpty ||
    dotenv.env.containsKey("DISCORD_CLIENT_ID");

typedef Json = Map<String, dynamic>;

@JsonEnum()
enum Role { user, admin }

@freezed
abstract class User with _$User {
  const factory User({
    required int id,
    required String email,
    required Role role,
  }) = _User;

  factory User.fromJson(Json json) => _$UserFromJson(json);
}

@freezed
abstract class GhostServer with _$GhostServer {
  const GhostServer._();

  const factory GhostServer({
    required int id,
    required String containerId,
    required int port,
    required int wsPort,
    required int userId,
    required String name,
    required String relativeRemainingDuration,
  }) = _GhostServer;

  factory GhostServer.fromJson(Json json) => _$GhostServerFromJson(json);

  String connectCommand() => "ghost_connect $_host $wsPort";
}

@freezed
abstract class GhostServerSettings with _$GhostServerSettings {
  const factory GhostServerSettings({
    required String preCountdownCommands,
    required String postCountdownCommands,
    required int countdownDuration,
    required bool acceptingPlayers,
    required bool acceptingSpectators,
  }) = _GhostServerSettings;

  factory GhostServerSettings.fromJson(Json json) =>
      _$GhostServerSettingsFromJson(json);
}

@freezed
abstract class Player with _$Player {
  const factory Player({
    required int id,
    required String name,
    required bool isSpectator,
    required bool isAdmin,
  }) = _Player;

  factory Player.fromJson(Json json) => _$PlayerFromJson(json);
}

@freezed
abstract class Whitelist with _$Whitelist {
  const factory Whitelist({
    required bool enabled,
    required List<WhitelistEntry> entries,
  }) = _Whitelist;

  factory Whitelist.fromJson(Json json) => _$WhitelistFromJson(json);
}

@JsonEnum()
enum WhitelistEntryType { name, ip }

@freezed
abstract class WhitelistEntry with _$WhitelistEntry {
  const factory WhitelistEntry({
    required WhitelistEntryType type,
    required String value,
  }) = _WhitelistEntry;

  factory WhitelistEntry.fromJson(Json json) => _$WhitelistEntryFromJson(json);
}

class _Backend {
  const _Backend();

  Future<bool> _haveAuthToken() async =>
      (await SharedPreferences.getInstance()).containsKey(spAuthTokenKey);

  Future<String> _getAuthToken() async =>
      (await SharedPreferences.getInstance()).getString(spAuthTokenKey) ??
      (throw "Please log in!");

  Future<void> logout() async {
    if (!await _haveAuthToken()) return;
    await revokeAuthToken();
    var sp = await SharedPreferences.getInstance();
    sp.remove(spAuthTokenKey);
    sp.remove(spAuthTokenExpiryKey);
  }

  Future<String> authHeader() async => "Bearer ${await _getAuthToken()}";

  String playersStreamUrl(int id) => "$_baseServerUri/$id/listPlayers/stream";

  Future<http.Response> _postJson(
    String uri, {
    Json body = const {},
    bool authenticated = false,
  }) async => http.post(
    Uri.parse(uri),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
      if (authenticated) HttpHeaders.authorizationHeader: await authHeader(),
    },
    body: jsonEncode(body),
  );

  Future<http.Response> _put(
    String uri, {
    Json body = const {},
    bool authenticated = false,
  }) async => http.put(
    Uri.parse(uri),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
      if (authenticated) HttpHeaders.authorizationHeader: await authHeader(),
    },
    body: jsonEncode(body),
  );

  Future<http.Response> _get(
    String uri, {
    bool authenticated = false,
  }) async => http.get(
    Uri.parse(uri),
    headers: {
      if (authenticated) HttpHeaders.authorizationHeader: await authHeader(),
    },
  );

  Future<http.Response> _delete(
    String uri, {
    Json body = const {},
    bool authenticated = false,
  }) async => http.delete(
    Uri.parse(uri),
    headers: {
      HttpHeaders.contentTypeHeader: "application/json",
      if (authenticated) HttpHeaders.authorizationHeader: await authHeader(),
    },
    body: jsonEncode(body),
  );

  Future<String> getDiscordOauth2Url() =>
      _get("$_baseAuthUri/discordOauth2Url").then((r) => r.body);

  Future<(String, DateTime)> login(String email, String password) async {
    var response = await _postJson(
      "$_baseAuthUri/login",
      body: {"email": email, "password": password},
    );
    if (response.statusCode != 200) throw response.body;
    var json = jsonDecode(response.body);
    return (
      json["token"] as String,
      DateTime.fromMillisecondsSinceEpoch(json["expires"]),
    );
  }

  Future<(String, DateTime)> finishDiscordOauth2Login(String authCode) async {
    var response = await _postJson(
      "$_baseAuthUri/finishDiscordOauth2Login",
      body: {"code": authCode},
    );
    if (response.statusCode != 200) throw response.body;
    var json = jsonDecode(response.body);
    return (
      json["token"] as String,
      DateTime.fromMillisecondsSinceEpoch(json["expires"]),
    );
  }

  Future<void> register(String email, String password) async {
    var response = await _postJson(
      "$_baseAuthUri/register",
      body: {"email": email, "password": password},
    );
    if (response.statusCode != 201) throw response.body;
  }

  Future<bool> requestPasswordReset(String email) async {
    var response = await _postJson(
      "$_baseAuthUri/requestPasswordReset",
      body: {"email": email},
    );
    return response.statusCode == 200;
  }

  Future<bool> validatePasswordResetCredentials(
    String email,
    String token,
  ) async {
    var response = await _postJson(
      "$_baseAuthUri/validatePasswordResetCredentials",
      body: {
        "email": email,
        "token": token,
      },
    );
    return response.statusCode == 200;
  }

  Future<void> resetPassword(
    String email,
    String token,
    String newPassword,
  ) async {
    var response = await _postJson(
      "$_baseAuthUri/resetPassword",
      body: {"email": email, "token": token, "newPassword": newPassword},
    );
    if (response.statusCode != 200) throw response.body;
  }

  Future<User> getCurrentUser() async {
    var response = await _get("$_baseAuthUri/user", authenticated: true);
    if (response.statusCode != 200) throw response.body;
    return User.fromJson(jsonDecode(response.body));
  }

  Future<void> deleteAccount() =>
      _delete("$_baseAuthUri/user", authenticated: true);

  Future<void> revokeAuthToken() =>
      _postJson("$_baseAuthUri/revokeToken", authenticated: true);

  Future<void> createGhostServer(String? name) => _postJson(
    "$_baseServerUri/create${name != null ? "?name=$name" : ""}",
    authenticated: true,
  );

  Future<List<GhostServer>> getGhostServers({bool showAll = false}) async {
    var response = await _get(
      "$_baseServerUri/list?showAll=${showAll ? "1" : "0"}",
      authenticated: true,
    );
    if (response.statusCode != 200) throw response.body;
    var json = jsonDecode(response.body) as List<dynamic>;
    return json.cast<Json>().map(GhostServer.fromJson).toList();
  }

  Future<GhostServer> getGhostServerById(int id) async {
    var response = await _get("$_baseServerUri/$id", authenticated: true);
    if (response.statusCode != 200) throw response.body;
    return GhostServer.fromJson(jsonDecode(response.body));
  }

  Future<GhostServerSettings> getGhostServerSettingsById(int id) async {
    var response = await _get(
      "$_baseServerUri/$id/settings",
      authenticated: true,
    );
    if (response.statusCode != 200) throw response.body;
    return GhostServerSettings.fromJson(jsonDecode(response.body));
  }

  Future<void> updateGhostServerSettings(
    int id,
    GhostServerSettings settings,
  ) => _put(
    "$_baseServerUri/$id/settings",
    body: settings.toJson(),
    authenticated: true,
  );

  Future<void> sendServerMessage(int id, String message) => _postJson(
    "$_baseServerUri/$id/serverMessage?message=$message",
    authenticated: true,
  );

  Future<void> startCountdown(int id) =>
      _postJson("$_baseServerUri/$id/startCountdown", authenticated: true);

  List<Player> parsePlayersJson(String json) {
    var list = jsonDecode(json) as List<dynamic>;
    return list.cast<Json>().map(Player.fromJson).toList();
  }

  Future<List<Player>> getPlayers(int id) async {
    var response = await _get(
      "$_baseServerUri/$id/listPlayers",
      authenticated: true,
    );
    return parsePlayersJson(response.body);
  }

  Future<void> makeAdminById(int serverId, int playerId) => _put(
    "$_baseServerUri/$serverId/makeAdmin",
    body: {"id": playerId},
    authenticated: true,
  );

  Future<void> removeAdminById(int serverId, int playerId) => _put(
    "$_baseServerUri/$serverId/removeAdmin",
    body: {"id": playerId},
    authenticated: true,
  );

  Future<void> disconnectPlayerById(int serverId, int playerId) => _put(
    "$_baseServerUri/$serverId/disconnectPlayer",
    body: {"id": playerId},
    authenticated: true,
  );

  Future<void> banPlayerById(int serverId, int playerId) => _put(
    "$_baseServerUri/$serverId/banPlayer",
    body: {"id": playerId},
    authenticated: true,
  );

  Future<Whitelist> getWhitelist(int serverId) async {
    var response = await _get(
      "$_baseServerUri/$serverId/whitelist",
      authenticated: true,
    );
    return Whitelist.fromJson(jsonDecode(response.body));
  }

  Future<void> setWhitelistStatus(int serverId, bool enabled) => _put(
    "$_baseServerUri/$serverId/whitelist/status",
    body: {"enabled": enabled},
    authenticated: true,
  );

  Future<void> addToWhitelist(int serverId, WhitelistEntry entry) => _put(
    "$_baseServerUri/$serverId/whitelist",
    body: switch (entry.type) {
      WhitelistEntryType.name => {"name": entry.value},
      WhitelistEntryType.ip => {"ip": entry.value},
    },
    authenticated: true,
  );

  Future<void> removeFromWhitelist(int serverId, WhitelistEntry entry) =>
      _delete(
        "$_baseServerUri/$serverId/whitelist",
        body: switch (entry.type) {
          WhitelistEntryType.name => {"name": entry.value},
          WhitelistEntryType.ip => {"ip": entry.value},
        },
        authenticated: true,
      );

  Future<void> deleteGhostServer(int id) =>
      _delete("$_baseServerUri/$id", authenticated: true);
}

// ignore: constant_identifier_names
const Backend = _Backend();
