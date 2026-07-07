import 'dart:async';
import 'package:aqloss/models/track.dart';

// Manifest
enum PluginPermission { network, filesystem, libraryWrite }

enum PluginType { builtin, webhook, lua }

class PluginManifest {
  final String id;
  final String name;
  final String version;
  final String author;
  final String? description;
  final String minAqlossVersion;
  final Set<PluginPermission> permissions;
  final PluginType type;
  final String? entry;
  final String? webhookUrl;
  final Map<String, String>? webhookHeaders;
  final Set<WebhookEvent>? webhookEvents;

  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    this.description,
    required this.minAqlossVersion,
    this.permissions = const {},
    this.type = PluginType.builtin,
    this.entry,
    this.webhookUrl,
    this.webhookHeaders,
    this.webhookEvents,
  });

  factory PluginManifest.fromJson(Map<String, dynamic> json) {
    final typeStr = json['type'] as String? ?? 'lua';
    final type = switch (typeStr) {
      'webhook' => PluginType.webhook,
      'builtin' => PluginType.builtin,
      _ => PluginType.lua,
    };

    Set<WebhookEvent>? webhookEvents;
    if (json['webhook_events'] is List) {
      webhookEvents = (json['webhook_events'] as List)
          .map((e) => WebhookEvent.fromString(e as String))
          .whereType<WebhookEvent>()
          .toSet();
    }

    Map<String, String>? headers;
    if (json['webhook_headers'] is Map) {
      headers = Map<String, String>.from(
        (json['webhook_headers'] as Map).map(
          (k, v) => MapEntry(k.toString(), v.toString()),
        ),
      );
    }

    return PluginManifest(
      id: json['id'] as String,
      name: json['name'] as String,
      version: json['version'] as String,
      author: json['author'] as String,
      description: json['description'] as String?,
      minAqlossVersion: json['min_aqloss_version'] as String? ?? '0.4.0',
      permissions: ((json['permissions'] as List<dynamic>?) ?? [])
          .map(
            (p) => switch (p as String) {
              'network' => PluginPermission.network,
              'filesystem' => PluginPermission.filesystem,
              'library_write' => PluginPermission.libraryWrite,
              _ => null,
            },
          )
          .whereType<PluginPermission>()
          .toSet(),
      type: type,
      entry: json['entry'] as String?,
      webhookUrl: json['webhook_url'] as String?,
      webhookHeaders: headers,
      webhookEvents: webhookEvents,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    if (description != null) 'description': description,
    'min_aqloss_version': minAqlossVersion,
    'permissions': permissions.map((p) => p.name).toList(),
    'type': type.name,
    if (entry != null) 'entry': entry,
    if (webhookUrl != null) 'webhook_url': webhookUrl,
    if (webhookHeaders != null) 'webhook_headers': webhookHeaders,
    if (webhookEvents != null)
      'webhook_events': webhookEvents!.map((e) => e.name).toList(),
  };

  bool get isWebhook => type == PluginType.webhook;
  bool get isBuiltin => type == PluginType.builtin;
  bool get isLua => type == PluginType.lua;
}

// Webhook events
enum WebhookEvent {
  trackStart,
  trackStop,
  trackComplete,
  playPause,
  trackLoved,
  positionUpdate;

  static WebhookEvent? fromString(String s) => switch (s) {
    'track_start' => WebhookEvent.trackStart,
    'track_stop' => WebhookEvent.trackStop,
    'track_complete' => WebhookEvent.trackComplete,
    'play_pause' => WebhookEvent.playPause,
    'track_loved' => WebhookEvent.trackLoved,
    'position_update' => WebhookEvent.positionUpdate,
    _ => null,
  };

  String get name => switch (this) {
    WebhookEvent.trackStart => 'track_start',
    WebhookEvent.trackStop => 'track_stop',
    WebhookEvent.trackComplete => 'track_complete',
    WebhookEvent.playPause => 'play_pause',
    WebhookEvent.trackLoved => 'track_loved',
    WebhookEvent.positionUpdate => 'position_update',
  };
}

// Hook payloads
class TrackStartEvent {
  final Track track;
  const TrackStartEvent(this.track);
}

class TrackStopEvent {
  final Track? track;
  const TrackStopEvent(this.track);
}

class PlayPauseEvent {
  final bool isPlaying;
  final Duration position;
  const PlayPauseEvent({required this.isPlaying, required this.position});
}

class PositionUpdateEvent {
  final Duration position;
  final Duration duration;
  const PositionUpdateEvent({required this.position, required this.duration});
}

class TrackCompleteEvent {
  final Track track;
  const TrackCompleteEvent(this.track);
}

class LibraryScanEvent {
  final LibraryScanPhase phase;
  final int? count;
  const LibraryScanEvent({required this.phase, this.count});
}

enum LibraryScanPhase { started, complete }

class TrackLovedEvent {
  final Track track;
  final bool loved;
  const TrackLovedEvent({required this.track, required this.loved});
}

class AppForegroundEvent {
  const AppForegroundEvent();
}

// UI registration handles
class PluginSidebarItem {
  final String id;
  final String label;
  final dynamic icon;
  final dynamic Function() builder;
  const PluginSidebarItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.builder,
  });
}

class PluginSettingsPage {
  final String id;
  final String label;
  final dynamic Function() builder;
  const PluginSettingsPage({
    required this.id,
    required this.label,
    required this.builder,
  });
}

class PluginContextMenuItem {
  final String id;
  final String label;
  final void Function(Track track) onTap;
  const PluginContextMenuItem({
    required this.id,
    required this.label,
    required this.onTap,
  });
}

// Plugin context
abstract class PluginContext {
  Track? getCurrentTrack();
  Duration getPosition();
  List<Track> getQueue();
  void addToQueue(Track track);

  List<Track> queryTracks(bool Function(Track) predicate);
  List<Track> getLovedTracks();
  int getPlayCount(String path);

  void showToast(String message);
  void registerSidebarItem(PluginSidebarItem item);
  void registerSettingsPage(PluginSettingsPage page);
  void registerContextMenuItem(PluginContextMenuItem item);
}

abstract class BuiltinPlugin {
  late PluginContext context;
  late PluginManifest manifest;

  Future<void> onLoad() async {}
  Future<void> onUnload() async {}

  Future<void> onTrackStart(TrackStartEvent event) async {}
  Future<void> onTrackStop(TrackStopEvent event) async {}
  Future<void> onPlayPause(PlayPauseEvent event) async {}
  Future<void> onPositionUpdate(PositionUpdateEvent event) async {}
  Future<void> onTrackComplete(TrackCompleteEvent event) async {}
  Future<void> onLibraryScan(LibraryScanEvent event) async {}
  Future<void> onTrackLoved(TrackLovedEvent event) async {}
  Future<void> onAppForeground(AppForegroundEvent event) async {}
}

typedef AqlossPlugin = BuiltinPlugin;
