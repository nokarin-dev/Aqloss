part of 'settings_page.dart';

const _eqFreqs = [
  '32 Hz',
  '64 Hz',
  '125 Hz',
  '250 Hz',
  '500 Hz',
  '1 kHz',
  '2 kHz',
  '4 kHz',
  '8 kHz',
  '16 kHz',
];

Widget _settingsScroll(List<Widget> children) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(0, 0, 18, playerClearance),
    children: [
      for (final child in children)
        Align(
          alignment: Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _settingsWidth),
            child: child,
          ),
        ),
    ],
  );
}

void _note(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(message)));
}

Future<bool> _ask(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
}) async {
  final answer = await showLiquidGlassDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return LiquidGlassDialog(
        width: 340,
        child: DefaultTextStyle(
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.35,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(body),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _OutlineButton(
                    label: tr('integrations.cancel'),
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  const SizedBox(width: 8),
                  _OutlineButton(
                    label: action,
                    onPressed: () => Navigator.pop(dialogContext, true),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return answer ?? false;
}

class _OutputPane extends ConsumerStatefulWidget {
  const _OutputPane();

  @override
  ConsumerState<_OutputPane> createState() => _OutputPaneState();
}

class _OutputPaneState extends ConsumerState<_OutputPane> {
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.microtask(_scan);
  }

  Future<void> _scan() async {
    if (mounted) setState(() => _error = null);
    await ref.read(audioDeviceProvider.notifier).scan();
  }

  Future<void> _select(String id, AudioOutputMode mode) async {
    try {
      await ref.read(audioDeviceProvider.notifier).selectDevice(id, mode);
      if (mounted) setState(() => _error = null);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e'.replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(audioDeviceProvider);
    return devices.when(
      loading: () => _settingsScroll([Text(tr('output.scanning'))]),
      error: (error, _) => _settingsScroll([
        Text(
          trFill('output.scan_failed', {'error': '$error'}),
          style: const TextStyle(color: Color(0xFFFF453A), fontSize: 13),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: _OutlineButton(label: tr('output.rescan'), onPressed: _scan),
        ),
      ]),
      data: (state) {
        return _settingsScroll([
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF453A), fontSize: 13),
            ),
            const SizedBox(height: 12),
          ],
          if (state.isSwitching)
            Text(
              tr('output.switching'),
              style: const TextStyle(color: textMuted, fontSize: 13),
            )
          else if (state.devices.isEmpty)
            Text(
              tr('output.scanning'),
              style: const TextStyle(color: textMuted, fontSize: 13),
            )
          else
            _Rows(
              children: [
                for (final device in state.devices)
                  _ValueRow(
                    label: device.name.isEmpty ? device.id : device.name,
                    subtitle: device.isDefault ? tr('output.mixer') : null,
                    value: state.selectedId == device.id
                        ? (state.outputMode == AudioOutputMode.exclusive
                              ? tr('output.exclusive')
                              : tr('output.shared'))
                        : tr('output.select'),
                    enabled: !state.isSwitching,
                    onTap: () {
                      final selected = state.selectedId == device.id;
                      if (!selected) {
                        _select(device.id, AudioOutputMode.system);
                        return;
                      }
                      if (!device.supportsExclusive) return;
                      final next = state.outputMode == AudioOutputMode.exclusive
                          ? AudioOutputMode.system
                          : AudioOutputMode.exclusive;
                      _select(device.id, next);
                    },
                  ),
              ],
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: _OutlineButton(
              label: tr('output.rescan'),
              onPressed: state.isSwitching ? null : _scan,
            ),
          ),
          if (Platform.isLinux) ...[
            const SizedBox(height: 12),
            Text(
              tr('output.alsa'),
              style: const TextStyle(
                color: textMuted,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ]);
      },
    );
  }
}

class _DspPane extends ConsumerStatefulWidget {
  const _DspPane();

  @override
  ConsumerState<_DspPane> createState() => _DspPaneState();
}

class _DspPaneState extends ConsumerState<_DspPane> {
  final _presetName = TextEditingController();

  @override
  void dispose() {
    _presetName.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final locked = ref.watch(exclusiveModeProvider);
    final presets = [...kBuiltInEqPresets, ...settings.eqUserPresets];
    final current = matchingEqPresetName(
      settings.eqGains,
      settings.eqUserPresets,
    );
    return _settingsScroll([
      if (locked) ...[
        Text(
          tr('dsp.exclusive'),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 16),
      ],
      _Rows(
        children: [
          _SwitchRow(
            label: tr('eq.title'),
            value: settings.eqEnabled,
            enabled: !locked,
            onChanged: (_) => notifier.toggleEq(),
          ),
          if (settings.eqEnabled && !locked) ...[
            _ValueRow(
              label: tr('eq.presets'),
              value: current == null ? tr('eq.presets') : _eqName(current),
              onTap: () {
                final index = presets.indexWhere((p) => p.name == current);
                notifier.applyEqPreset(presets[(index + 1) % presets.length]);
              },
            ),
            for (var i = 0; i < _eqFreqs.length; i++)
              _LiveSlider(
                label: _eqFreqs[i],
                value: i < settings.eqGains.length ? settings.eqGains[i] : 0,
                min: kEqGainMin,
                max: kEqGainMax,
                divisions: 48,
                labelFor: (v) => '${v.toStringAsFixed(1)} dB',
                onCommit: (v) => notifier.setEqBand(i, v),
              ),
          ],
          _SwitchRow(
            label: tr('dsp.soft_clip'),
            value: settings.notchFilter,
            enabled: !locked,
            onChanged: (_) => notifier.toggleNotchFilter(),
          ),
          _LiveSlider(
            label: tr('dsp.width'),
            value: settings.stereoWidth,
            min: 0,
            max: 2,
            divisions: 40,
            enabled: !locked,
            labelFor: (v) => (v - 1).abs() < 0.025
                ? tr('playback.off')
                : v.toStringAsFixed(2),
            onCommit: (v) {
              notifier.setStereoWidth(v);
              AudioService.setStereoWidth(v);
            },
          ),
          _LiveSlider(
            label: tr('dsp.haas'),
            value: settings.haasMs,
            min: 0,
            max: 25,
            divisions: 50,
            enabled: !locked,
            labelFor: (v) =>
                v < 0.5 ? tr('playback.off') : '${v.toStringAsFixed(0)} ms',
            onCommit: (v) {
              notifier.setHaasMs(v);
              AudioService.setHaasMs(v);
            },
          ),
        ],
      ),
      if (settings.eqEnabled && !locked) ...[
        const SizedBox(height: 8),
        _field(controller: _presetName, hint: tr('eq.preset_name')),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _OutlineButton(
              label: tr('eq.save'),
              onPressed: () {
                final result = notifier.saveEqPreset(_presetName.text);
                final message = switch (result) {
                  EqPresetSaveResult.ok => tr('eq.saved'),
                  EqPresetSaveResult.emptyName => tr('eq.name_required'),
                  EqPresetSaveResult.builtInName => tr('eq.builtin'),
                  EqPresetSaveResult.full => tr('eq.remove_first'),
                };
                if (result == EqPresetSaveResult.ok) _presetName.clear();
                _note(context, message);
              },
            ),
            _OutlineButton(label: tr('eq.reset'), onPressed: notifier.resetEq),
          ],
        ),
        if (settings.eqUserPresets.isNotEmpty) ...[
          const SizedBox(height: 12),
          _Rows(
            children: [
              for (final preset in settings.eqUserPresets)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          preset.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      _OutlineButton(
                        label: tr('output.select'),
                        onPressed: () => notifier.applyEqPreset(preset),
                      ),
                      const SizedBox(width: 8),
                      _OutlineButton(
                        label: tr('playlists.remove'),
                        onPressed: () =>
                            notifier.deleteEqUserPreset(preset.name),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    ]);
  }
}

String _eqName(String name) => switch (name) {
  'Flat' => tr('eq.flat'),
  'Rock' => tr('eq.rock'),
  'Classical' => tr('eq.classical'),
  'Vocal' => tr('eq.vocal'),
  _ => name,
};

class _DisplayPane extends ConsumerWidget {
  const _DisplayPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final catalog = ref.watch(l10nCatalogProvider).asData?.value;
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    final codes = <String>['', 'en'];
    if (catalog != null) {
      final extra = catalog.codes.toList()..sort();
      for (final code in extra) {
        if (!codes.contains(code)) codes.add(code);
      }
    }
    if (settings.language.isNotEmpty && !codes.contains(settings.language)) {
      codes.add(settings.language);
    }
    return _settingsScroll([
      _Rows(
        children: [
          _ValueRow(
            label: tr('display.language'),
            value: _languageLabel(settings.language, catalog),
            onTap: () => _pickLanguage(
              context,
              notifier,
              codes,
              settings.language,
              catalog,
            ),
          ),
          _SwitchRow(
            label: tr('display.motion'),
            value: settings.reduceMotion,
            onChanged: (_) => notifier.toggleReduceMotion(),
          ),
          _SwitchRow(
            label: tr('display.art'),
            value: settings.showAlbumArtBackground,
            onChanged: (_) => notifier.toggleAlbumArtBackground(),
          ),
          if (desktop)
            _SwitchRow(
              label: tr('display.tray'),
              value: settings.closeToTray,
              onChanged: (_) => notifier.toggleCloseToTray(),
            ),
          _SwitchRow(
            label: tr('display.gpu'),
            value: settings.hardwareAcceleration,
            onChanged: (_) => notifier.toggleHardwareAcceleration(),
          ),
        ],
      ),
    ]);
  }
}

String _languageLabel(String code, L10nCatalog? catalog) {
  if (code.isEmpty) return tr('display.system');
  if (code == 'en') return tr('display.english');
  return catalog?.labelFor(code) ?? code;
}

Future<void> _pickLanguage(
  BuildContext context,
  SettingsNotifier notifier,
  List<String> codes,
  String current,
  L10nCatalog? catalog,
) async {
  final picked = await showLiquidGlassDialog<String>(
    context: context,
    barrierDismissible: true,
    builder: (dialogContext) {
      return LiquidGlassDialog(
        width: 340,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              tr('display.language'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 320),
              child: ListView(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                children: [
                  for (final code in codes)
                    _LanguageChoice(
                      label: _languageLabel(code, catalog),
                      selected: code == current,
                      onTap: () => Navigator.pop(dialogContext, code),
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  if (picked != null && picked != current) notifier.setLanguage(picked);
}

class _LanguageChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _LanguageChoice({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : textMuted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: selected ? const Color(0x14FFFFFF) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SizedBox(
              height: 36,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IntegrationsPane extends ConsumerStatefulWidget {
  const _IntegrationsPane();

  @override
  ConsumerState<_IntegrationsPane> createState() => _IntegrationsPaneState();
}

class _IntegrationsPaneState extends ConsumerState<_IntegrationsPane> {
  late final TextEditingController _user;
  late final TextEditingController _password;
  late final TextEditingController _apiKey;
  late final TextEditingController _secret;
  late final TextEditingController _token;
  var _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(settingsProvider);
    _user = TextEditingController(text: settings.lastFmUsername ?? '');
    _password = TextEditingController();
    _apiKey = TextEditingController();
    _secret = TextEditingController();
    _token = TextEditingController();
  }

  @override
  void dispose() {
    _user.dispose();
    _password.dispose();
    _apiKey.dispose();
    _secret.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    final desktop = Platform.isWindows || Platform.isLinux || Platform.isMacOS;
    return _settingsScroll([
      _Rows(
        children: [
          if (desktop)
            _SwitchRow(
              label: tr('integrations.discord'),
              value: settings.discordRpc,
              onChanged: (_) {
                final next = !settings.discordRpc;
                notifier.toggleDiscordRpc();
                DiscordService.enabled = next;
              },
            ),
          _SwitchRow(
            label: tr('integrations.lastfm'),
            value: settings.scrobbleLastFm,
            onChanged: (_) => notifier.toggleScrobble(),
          ),
          _SwitchRow(
            label: tr('integrations.listenbrainz'),
            value: settings.scrobbleListenBrainz,
            onChanged: (_) => notifier.toggleScrobbleListenBrainz(),
          ),
        ],
      ),
      if (settings.scrobbleLastFm) ...[
        const SizedBox(height: 18),
        if (settings.lastFmSessionKey != null)
          _Rows(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        trFill('integrations.signed_in', {
                          'name': settings.lastFmUsername ?? '',
                        }),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _OutlineButton(
                      label: tr('integrations.sign_out'),
                      onPressed: () {
                        notifier.clearLastFmSession();
                        notifier.setLastFmUsername(null);
                      },
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          Text(
            settings.needsUserKey
                ? tr('integrations.api_missing')
                : tr('integrations.builtin_key'),
            style: const TextStyle(color: textMuted, fontSize: 13),
          ),
          if (settings.needsUserKey) ...[
            _field(controller: _apiKey, hint: tr('integrations.api_key')),
            _field(
              controller: _secret,
              hint: tr('integrations.secret'),
              secret: true,
            ),
          ],
          _field(controller: _user, hint: tr('integrations.username')),
          _field(
            controller: _password,
            hint: tr('integrations.password'),
            secret: true,
          ),
          const SizedBox(height: 8),
          _OutlineButton(
            label: tr('integrations.sign_in'),
            onPressed: _busy ? null : () => _signIn(notifier, settings),
          ),
        ],
      ],
      if (settings.scrobbleListenBrainz) ...[
        const SizedBox(height: 18),
        if (settings.listenBrainzToken != null)
          _Rows(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 12, 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        settings.listenBrainzUsername ??
                            tr('integrations.lb_token'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    _OutlineButton(
                      label: tr('integrations.clear'),
                      onPressed: notifier.clearListenBrainz,
                    ),
                  ],
                ),
              ),
            ],
          )
        else ...[
          Text(
            tr('integrations.lb_create'),
            style: const TextStyle(color: textMuted, fontSize: 13),
          ),
          _field(controller: _token, hint: tr('integrations.lb_user_token')),
          const SizedBox(height: 8),
          _OutlineButton(
            label: tr('integrations.lb_add'),
            onPressed: _busy ? null : () => _addToken(notifier),
          ),
        ],
      ],
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          style: const TextStyle(color: Color(0xFFFF453A), fontSize: 13),
        ),
      ],
      if (settings.scrobbleReady || settings.listenBrainzReady) ...[
        const SizedBox(height: 18),
        Text(
          tr('integrations.sync_loved_sub'),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 8),
        _OutlineButton(
          label: tr('integrations.sync'),
          onPressed: _busy ? null : () => _syncLoved(settings),
        ),
      ],
    ]);
  }

  Future<void> _signIn(
    SettingsNotifier notifier,
    SettingsState settings,
  ) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    if (settings.needsUserKey) {
      notifier.setLastFmApiKey(_apiKey.text.trim());
      notifier.setLastFmApiSecret(_secret.text.trim());
    }
    final creds = LastFmService.resolve(
      userApiKey: settings.needsUserKey
          ? _apiKey.text.trim()
          : settings.lastFmApiKey,
      userApiSecret: settings.needsUserKey
          ? _secret.text.trim()
          : settings.lastFmApiSecret,
    );
    final session = await LastFmService.authenticate(
      username: _user.text.trim(),
      password: _password.text,
      creds: creds,
    );
    if (!mounted) return;
    if (session == null) {
      setState(() {
        _busy = false;
        _error = tr('integrations.sign_in_failed');
      });
      return;
    }
    notifier.setLastFmUsername(_user.text.trim());
    notifier.setLastFmSession(session);
    _password.clear();
    setState(() => _busy = false);
  }

  Future<void> _addToken(SettingsNotifier notifier) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    final user = await ListenBrainzService.validateToken(_token.text.trim());
    if (!mounted) return;
    if (user == null) {
      setState(() {
        _busy = false;
        _error = tr('integrations.lb_invalid');
      });
      return;
    }
    notifier.setListenBrainzToken(_token.text.trim(), username: user);
    _token.clear();
    setState(() => _busy = false);
  }

  Future<void> _syncLoved(SettingsState settings) async {
    setState(() => _busy = true);
    LastFmCredentials? creds;
    if (settings.scrobbleReady) {
      creds = LastFmService.resolve(
        userApiKey: settings.lastFmApiKey,
        userApiSecret: settings.lastFmApiSecret,
      );
    }
    LovedSync.configure(
      lastFmCreds: creds,
      lastFmSession: settings.scrobbleReady ? settings.lastFmSessionKey : null,
      lastFmUser: settings.scrobbleReady ? settings.lastFmUsername : null,
      listenBrainzToken: settings.listenBrainzReady
          ? settings.listenBrainzToken
          : null,
      listenBrainzUser: settings.listenBrainzReady
          ? settings.listenBrainzUsername
          : null,
    );
    final result = await LovedSync.importInto(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    final message = result.remoteCount == 0
        ? tr('integrations.loved_none')
        : trFill('integrations.loved_count', {
            'count': '${result.imported}',
            'total': '${result.remoteCount}',
          });
    _note(context, message);
  }
}

const _shortcutGroups = <String, List<ShortcutAction>>{
  'settings.playback': [
    ShortcutAction.playPause,
    ShortcutAction.skipNext,
    ShortcutAction.skipPrevious,
    ShortcutAction.volumeUp,
    ShortcutAction.volumeDown,
  ],
  'sidebar.navigate': [
    ShortcutAction.toggleSidebar,
    ShortcutAction.toggleQueue,
    ShortcutAction.navPlayer,
    ShortcutAction.navLibrary,
    ShortcutAction.navAlbums,
    ShortcutAction.navArtists,
    ShortcutAction.navHistory,
    ShortcutAction.navSettings,
    ShortcutAction.newPlaylist,
  ],
};

class _ShortcutsPane extends ConsumerStatefulWidget {
  const _ShortcutsPane();

  @override
  ConsumerState<_ShortcutsPane> createState() => _ShortcutsPaneState();
}

class _ShortcutsPaneState extends ConsumerState<_ShortcutsPane> {
  ShortcutAction? _capturing;
  late final bool Function(KeyEvent) _handler = _onCapture;

  @override
  void dispose() {
    _disarm();
    super.dispose();
  }

  void _arm(ShortcutAction action) {
    setState(() => _capturing = action);
    if (shortcutCapture) return;
    shortcutCapture = true;
    HardwareKeyboard.instance.addHandler(_handler);
  }

  void _disarm() {
    _capturing = null;
    if (!shortcutCapture) return;
    shortcutCapture = false;
    HardwareKeyboard.instance.removeHandler(_handler);
  }

  bool _onCapture(KeyEvent event) {
    if (event is! KeyDownEvent) return false;
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      setState(_disarm);
      return true;
    }
    final chord = shortcutChord(event);
    final action = _capturing;
    if (chord == null || action == null) return true;
    ref.read(settingsProvider.notifier).setShortcut(action, chord);
    setState(_disarm);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);
    return _settingsScroll([
      for (final group in _shortcutGroups.entries) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 6),
          child: Text(
            tr(group.key),
            style: const TextStyle(color: textMuted, fontSize: 12),
          ),
        ),
        _Rows(
          children: [
            for (final action in group.value)
              _ValueRow(
                label: action.label,
                value: _capturing == action
                    ? tr('shortcuts.press')
                    : settings.binding(action),
                onTap: () => _arm(action),
              ),
          ],
        ),
      ],
      const SizedBox(height: 12),
      Align(
        alignment: Alignment.centerLeft,
        child: _OutlineButton(
          label: tr('display.reset'),
          onPressed: () {
            _disarm();
            setState(notifier.resetAllShortcuts);
          },
        ),
      ),
    ]);
  }
}

class _PluginsPane extends ConsumerStatefulWidget {
  const _PluginsPane();

  @override
  ConsumerState<_PluginsPane> createState() => _PluginsPaneState();
}

class _PluginsPaneState extends ConsumerState<_PluginsPane> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    final plugins = ref.watch(pluginProvider);
    final notifier = ref.read(pluginProvider.notifier);
    return _settingsScroll([
      Align(
        alignment: Alignment.centerLeft,
        child: _OutlineButton(
          label: plugins.installing
              ? tr('plugins.installing')
              : tr('plugins.install_aqx'),
          onPressed: plugins.installing ? null : () => _install(notifier),
        ),
      ),
      if (_status != null) ...[
        const SizedBox(height: 10),
        Text(_status!, style: const TextStyle(color: textMuted, fontSize: 13)),
      ],
      const SizedBox(height: 16),
      if (plugins.manifests.isEmpty)
        _Rows(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Text(
                tr('plugins.empty'),
                style: const TextStyle(color: textMuted, fontSize: 14),
              ),
            ),
          ],
        )
      else
        _Rows(
          children: [
            for (final manifest in plugins.manifests)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                manifest.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                ),
                              ),
                              Text(
                                '${trFill('plugins.by', {'author': manifest.author})}  ${manifest.version}',
                                style: const TextStyle(
                                  color: textMuted,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _ShellSwitch(
                          value: plugins.isEnabled(manifest.id),
                          onChanged: (value) =>
                              notifier.setEnabled(manifest.id, enabled: value),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _OutlineButton(
                          label: tr('plugins.export_aqx'),
                          onPressed: () =>
                              PluginIOService.exportPlugin(manifest.id),
                        ),
                        const SizedBox(width: 8),
                        _OutlineButton(
                          label: tr('plugins.uninstall'),
                          onPressed: () => _uninstall(notifier, manifest),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
    ]);
  }

  Future<void> _install(PluginNotifier notifier) async {
    final preview = await notifier.previewInstall();
    if (!mounted || preview.cancelled) return;
    if (!preview.ok || preview.bytes == null || preview.manifest == null) {
      setState(() => _status = preview.userMessage);
      return;
    }
    final manifest = preview.manifest!;
    final perms = manifest.permissions.map(_permLabel).join('\n');
    final body = perms.isEmpty
        ? tr('plugins.no_permissions')
        : '${tr('plugins.permissions')}\n$perms';
    final ok = await _ask(
      context,
      title: trFill('plugins.install_ask', {'name': manifest.name}),
      body: body,
      action: tr('plugins.install'),
    );
    if (!ok || !mounted) return;
    final result = await notifier.installBytes(preview.bytes!);
    if (!mounted) return;
    setState(() => _status = result.userMessage);
  }

  Future<void> _uninstall(
    PluginNotifier notifier,
    PluginManifest manifest,
  ) async {
    final ok = await _ask(
      context,
      title: trFill('plugins.uninstall_title', {'name': manifest.name}),
      body: tr('plugins.uninstall_body'),
      action: tr('plugins.uninstall'),
    );
    if (!ok || !mounted) return;
    final removed = await notifier.uninstall(manifest.id);
    if (!mounted) return;
    setState(() {
      _status = trFill(
        removed ? 'plugins.uninstalled' : 'plugins.uninstall_failed',
        {'name': manifest.name},
      );
    });
  }
}

String _permLabel(PluginPermission permission) => switch (permission) {
  PluginPermission.network => tr('plugins.perm_http'),
  PluginPermission.filesystem => tr('plugins.perm_files'),
  PluginPermission.theme => tr('plugins.perm_titlebar'),
};

class _UpdatesPane extends StatefulWidget {
  const _UpdatesPane();

  @override
  State<_UpdatesPane> createState() => _UpdatesPaneState();
}

class _UpdatesPaneState extends State<_UpdatesPane> {
  var _checking = false;
  UpdateCheckResult? _result;

  @override
  Widget build(BuildContext context) {
    final result = _result;
    return _settingsScroll([
      _Rows(
        children: [
          _RowLine(
            label: tr('updates.installed'),
            value: appVersionLabel(kAppVersion),
          ),
          _RowLine(label: tr('updates.check'), value: _statusText(result)),
        ],
      ),
      if (kIsNightly) ...[
        const SizedBox(height: 12),
        Text(
          tr('updates.nightly_body'),
          style: const TextStyle(color: textMuted, fontSize: 13, height: 1.4),
        ),
      ],
      if (result?.notes != null) ...[
        const SizedBox(height: 16),
        Text(
          tr('updates.notes'),
          style: const TextStyle(color: textMuted, fontSize: 12),
        ),
        const SizedBox(height: 6),
        Text(
          result!.notes!,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _OutlineButton(
            label: _checking ? tr('updates.checking') : tr('updates.check'),
            onPressed: _checking ? null : _check,
          ),
          if (result?.url != null && result!.url!.isNotEmpty)
            _OutlineButton(
              label: trFill('updates.github', {
                'version': result.latestVersion ?? '',
              }),
              onPressed: () => openExternalUrl(result.url!),
            ),
        ],
      ),
    ]);
  }

  String _statusText(UpdateCheckResult? result) {
    if (_checking) return tr('updates.checking');
    if (result == null) return tr('updates.unchecked');
    return switch (result.status) {
      UpdateCheckStatus.upToDate => tr('updates.latest'),
      UpdateCheckStatus.available => trFill('updates.available', {
        'version': result.latestVersion ?? '',
      }),
      UpdateCheckStatus.error => result.error ?? tr('updates.failed_sentence'),
    };
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final result = await checkGithubLatest(currentVersion: kAppVersion);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _result = result;
    });
  }
}

class _RowLine extends StatelessWidget {
  final String label;
  final String value;

  const _RowLine({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 15),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(color: textMuted, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportPane extends StatelessWidget {
  const _SupportPane();

  @override
  Widget build(BuildContext context) {
    final groups = supportGroups(
      indonesiaFirst: preferIndonesianSupport(
        View.of(context).platformDispatcher.locale,
      ),
    );
    return _settingsScroll([
      Text(
        tr('support.body'),
        style: const TextStyle(color: textMuted, fontSize: 14, height: 1.4),
      ),
      for (final group in groups) ...[
        const SizedBox(height: 22),
        Text(
          tr(group.title),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          tr(group.subtitle),
          style: const TextStyle(color: textMuted, fontSize: 13),
        ),
        const SizedBox(height: 10),
        _Rows(
          children: [
            for (final link in group.links)
              _ValueRow(
                label: link.name,
                value: _supportHost(link.url),
                onTap: () => openExternalUrl(link.url),
              ),
          ],
        ),
      ],
    ]);
  }
}

String _supportHost(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.startsWith('www.') ? host.substring(4) : host;
}

class _AboutPane extends ConsumerWidget {
  const _AboutPane();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _settingsScroll([
      _Rows(
        children: [
          _RowLine(
            label: 'Aqloss',
            value: trFill('support.version', {
              'version': appVersionLabel(kAppVersion),
            }),
          ),
          _RowLine(
            label: tr('support.engine'),
            value: tr('support.engine_value'),
          ),
          _RowLine(
            label: tr('support.backends'),
            value: tr('support.backends_value'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _OutlineButton(
            label: Platform.isIOS
                ? tr('support.share_logs')
                : tr('support.open_logs'),
            onPressed: () => _openLogs(context),
          ),
          _OutlineButton(
            label: tr('support.export'),
            onPressed: () => _export(context, ref),
          ),
          _OutlineButton(
            label: tr('support.restore'),
            onPressed: () => _restore(context, ref),
          ),
        ],
      ),
    ]);
  }

  Future<void> _openLogs(BuildContext context) async {
    final logDir = await Logger.logDirectory();
    if (Platform.isIOS) {
      final files = [
        for (final entity in logDir.listSync(recursive: true))
          if (entity is File) entity.path,
      ];
      await IosFolderAccess.shareFiles(files);
      return;
    }
    await OpenFile.open(logDir.path);
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final result = await SettingsBackupService.export(
      settings: ref.read(settingsProvider),
      playlists: ref.read(playlistProvider),
      folders: ref.read(libraryProvider).folders,
    );
    if (!context.mounted || result.error == null) {
      if (context.mounted && result.success) {
        _note(context, tr(kBackupSavedMessage));
      }
      return;
    }
    _note(context, tr(result.error!));
  }

  Future<void> _restore(BuildContext context, WidgetRef ref) async {
    final picked = await SettingsBackupService.import();
    if (!context.mounted) return;
    if (!picked.success) {
      if (picked.error != null) _note(context, tr(picked.error!));
      return;
    }
    final payload = picked.payload;
    if (payload == null) return;
    final confirmed = await _ask(
      context,
      title: tr('support.restore_title'),
      body: tr('support.restore_body'),
      action: tr('support.restore'),
    );
    if (!confirmed || !context.mounted) return;
    final settings = settingsFromJson(
      payload.settings,
      defaultOutputMode: platformDefaultOutputMode(),
    );
    await ref.read(settingsProvider.notifier).applyBackup(settings);
    await ref.read(playlistProvider.notifier).replaceAll(payload.playlists);
    await ref.read(libraryProvider.notifier).restoreFolders(payload.folders);
    if (context.mounted) _note(context, tr(kBackupRestoredMessage));
  }
}

Widget _field({
  required TextEditingController controller,
  required String hint,
  bool secret = false,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 8),
    child: TextField(
      controller: controller,
      obscureText: secret,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      cursorColor: Colors.white,
      decoration: InputDecoration(
        isDense: true,
        hintText: hint,
        hintStyle: const TextStyle(color: textMuted, fontSize: 14),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2D2D2D)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8A8A8A)),
        ),
      ),
    ),
  );
}
