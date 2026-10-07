// SPDX-License-Identifier: BSD-3-Clause
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:macos_ui/macos_ui.dart';

import 'design.dart';

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'model.dart';
import 'image_source.dart';
import 'writer.dart';

const channel = MethodChannel('5bsd/imager');

void main(List<String> args) => runApp(
  Imager(
    smoke: args.contains('--smoke-test'),
    preview:
        args.contains('--smoke-test') && args.contains('--preview-progress'),
    confirmation:
        args.contains('--smoke-test') &&
        args.contains('--preview-confirmation'),
  ),
);

class Imager extends StatelessWidget {
  const Imager({
    super.key,
    this.smoke = false,
    this.preview = false,
    this.confirmation = false,
  });
  final bool smoke, preview, confirmation;
  @override
  Widget build(BuildContext context) => MacosApp(
    title: '5BSD Imager',
    color: accent,
    debugShowCheckedModeBanner: false,
    theme: MacosThemeData(
      brightness: Brightness.light,
      primaryColor: accent,
      accentColor: AccentColor.red,
      canvasColor: canvas,
      dividerColor: line,
      typography: MacosTypography(
        color: ink,
        body: desktopText,
        headline: desktopText.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    darkTheme: MacosThemeData(
      brightness: Brightness.light,
      primaryColor: accent,
      accentColor: AccentColor.red,
      canvasColor: canvas,
      dividerColor: line,
      typography: MacosTypography(
        color: ink,
        body: desktopText,
        headline: desktopText.copyWith(fontWeight: FontWeight.w600),
      ),
    ),
    builder: (context, child) =>
        DefaultTextStyle(style: desktopText, child: child!),
    home: Workspace(smoke: smoke, preview: preview, confirmation: confirmation),
  );
}

class Workspace extends StatefulWidget {
  const Workspace({
    super.key,
    required this.smoke,
    required this.preview,
    required this.confirmation,
  });
  final bool smoke, preview, confirmation;
  @override
  State<Workspace> createState() => _WorkspaceState();
}

class _WorkspaceState extends State<Workspace> {
  final previewKey = GlobalKey();
  late final BatchWriter batch;
  Timer? refreshTimer;
  List<Drive> drives = [];
  Set<String> selected = {};
  final Set<String> expanded = {};
  String? path, error, scanError;
  int imageSize = 0;
  ImageSource? source;
  bool inspecting = false, showProtected = false;
  String get imageDetail => source?.compressed == true
      ? "${bytes(source!.storedSize)} XZ → ${bytes(imageSize)} on drive"
      : bytes(imageSize);
  bool scanning = false, scanned = false, confirming = false;
  bool get locked => batch.running || confirming || inspecting;
  List<Drive> get targets =>
      drives.where((d) => selected.contains(d.token)).toList();
  bool get active => batch.running || widget.preview;
  bool get allVerified =>
      batch.jobs.isNotEmpty && batch.successes == batch.jobs.length;
  bool get cacheNotice => batch.jobs.any((j) => j.warning != null);

  @override
  void initState() {
    super.initState();
    batch = BatchWriter(
      changed: () {
        if (mounted) setState(() {});
      },
    );
    if (widget.preview || widget.confirmation) {
      // Explicit design preview: all disk actions are disabled, and no helper runs.
      drives = [
        for (int i = 0; i < 2; i++)
          Drive({
            'name': 'preview$i',
            'description': i == 0 ? 'SanDisk Ultra' : 'Kingston DataTraveler',
            'serial': 'DESIGN-PREVIEW-$i',
            'bytes': i == 0 ? 123010547712 : 64000000000,
            'sector': 512,
            'token': 'preview-$i',
            'busy': false,
            'candidate': true,
            'reason': '',
            'partitions': [
              {
                'name': 'preview${i}p1',
                'bytes': 2147483648,
                'type': 'EFI',
                'label': 'BOOT',
                'busy': false,
              },
            ],
          }),
      ];
      imageSize = 4294967296;
      path = '5BSD-16.0-amd64.img.xz';
      source = ImageSource(path!, imageSize, 973078528, true);
      selected = drives.map((d) => d.token).toSet();
      scanned = true;
      if (!widget.confirmation)
        for (final drive in drives) {
          final job = WriteJob(drive, imageSize)..phase = JobPhase.verifying;
          job.written = job.total;
          job.verified = (job.total * (batch.jobs.isEmpty ? .66 : .42)).round();
          batch.jobs.add(job);
        }
    } else {
      unawaited(scan());
      refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
        if (!locked) unawaited(scan());
      });
    }
    if (widget.smoke) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await Future<void>.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        final boundary =
            previewKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage();
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = await Directory.systemTemp.createTemp(
          '5bsd-imager-preview-',
        );
        final file = File('${directory.path}/preview.png');
        await file.writeAsBytes(png!.buffer.asUint8List());
        image.dispose();
        stdout.writeln('5BSD_IMAGER_PREVIEW=${file.path}');
      });
    }
  }

  @override
  void dispose() {
    refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> scan() async {
    if (scanning || locked || widget.preview) return;
    setState(() => scanning = true);
    try {
      // Public GEOM metadata only: no pkexec and no device-node permissions.
      final result = await Process.run(helper, ['--list']);
      if (!mounted) return;
      if (result.exitCode != 0)
        throw StateError('Cannot read disk inventory. ${result.stderr}'.trim());
      final found = parseInventory(jsonDecode(result.stdout as String));
      setState(() {
        drives = found;
        scanned = true;
        scanError = null;
        selected = selected.intersection(
          found
              .where(
                (d) => d.available && (imageSize == 0 || d.fits(imageSize)),
              )
              .map((d) => d.token)
              .toSet(),
        );
      });
    } catch (e) {
      if (mounted)
        setState(() {
          scanError = e.toString();
          selected.clear();
          drives = [];
        });
    } finally {
      if (mounted) setState(() => scanning = false);
    }
  }

  Future<void> pick() async {
    if (locked || widget.smoke) return;
    setState(() => inspecting = true);
    try {
      final chosen = await channel.invokeMethod<String>('pickImage');
      if (chosen == null || !mounted) return;
      final inspected = await ImageSource.inspect(chosen);
      if (!mounted) return;
      setState(() {
        path = chosen;
        source = inspected;
        imageSize = inspected.size;
        error = null;
        batch.jobs.clear();
        selected.removeWhere(
          (token) => !drives.any(
            (d) => d.token == token && d.available && d.fits(imageSize),
          ),
        );
      });
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => inspecting = false);
    }
  }

  Widget confirmationPanel(
    BuildContext context,
    List<Drive> snapshot,
  ) => ConfirmPanel(
    title: Text(
      snapshot.length == 1
          ? 'Erase this drive?'
          : 'Erase ${snapshot.length} drives?',
    ),
    content: SizedBox(
      width: 510,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            caption('IMAGE TO WRITE'),
            const SizedBox(height: 8),
            Text(
              path!.split('/').last,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            Text(imageDetail, style: const TextStyle(color: muted)),
            const SizedBox(height: 22),
            caption('EVERY DRIVE BELOW WILL BE ERASED'),
            const SizedBox(height: 10),
            for (final d in snapshot)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: canvas,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.title,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${capacity(d.size)} (${bytes(d.size)}) · /dev/${d.name}',
                    ),
                    Text(
                      'Serial: ${d.serial.isEmpty ? 'not reported' : d.serial}',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                    Text(
                      '${d.partitions.length} existing partitions',
                      style: const TextStyle(color: muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'All existing data and partitions on these drives will be overwritten. Each drive will be verified after writing.',
              style: TextStyle(color: red),
            ),
            const SizedBox(height: 10),
            const Text(
              'You may be asked to authorize each drive. Only USB targets are accepted by the writer.',
              style: TextStyle(color: muted, fontSize: 12),
            ),
          ],
        ),
      ),
    ),
    actions: [
      AppButton.quiet(
        autofocus: true,
        onPressed: () => Navigator.pop(context, false),
        child: const Text('Go back'),
      ),
      AppButton(
        primary: true,
        onPressed: () => Navigator.pop(context, true),

        child: Text(
          snapshot.length == 1
              ? 'Erase & write image'
              : 'Erase & write ${snapshot.length} drives',
        ),
      ),
    ],
  );

  Future<void> confirm() async {
    if (locked || widget.smoke || path == null || targets.isEmpty) return;
    final snapshot = List<Drive>.of(targets);
    setState(() => confirming = true);
    final approved = await showConfirmation<bool>(
      context: context,
      builder: (context) => confirmationPanel(context, snapshot),
    );
    if (!mounted) return;
    setState(() => confirming = false);
    if (approved != true) return;
    await channel.invokeMethod<void>('busy', true);
    try {
      setState(() => error = null);
      await batch.run(path!, imageSize, snapshot);
    } catch (e) {
      setState(() => error = e.toString());
    } finally {
      selected.clear();
      await channel.invokeMethod<void>('busy', false);
      if (mounted) {
        setState(() {});
        await scan();
      }
    }
  }

  Widget caption(String s, {Color color = muted}) => Text(
    s,
    style: TextStyle(
      color: color,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.3,
    ),
  );
  Widget badge(String s, Mark icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Glyph(icon, size: 13, color: color),
        const SizedBox(width: 6),
        Text(
          s,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );

  Widget titlebar() => Container(
    height: 48,
    decoration: const BoxDecoration(
      color: chrome,
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        const SizedBox(width: 14),
        for (final action in [
          ('close', 'Close', const Color(0xffff6058)),
          ('minimize', 'Minimize', const Color(0xffffbd2e)),
          ('maximize', 'Maximize', const Color(0xff28c840)),
        ])
          SizedBox(
            width: 28,
            child: Center(
              child: KeyboardControl(
                activate: action.$1 == 'close' && locked
                    ? null
                    : () => channel.invokeMethod<void>(action.$1),
                child: MacosIconButton(
                  semanticLabel: action.$2,
                  onPressed: action.$1 == 'close' && locked
                      ? null
                      : () => channel.invokeMethod<void>(action.$1),
                  shape: BoxShape.circle,
                  padding: EdgeInsets.zero,
                  backgroundColor: action.$3,
                  hoverColor: action.$3,
                  boxConstraints: const BoxConstraints.tightFor(
                    width: 12,
                    height: 12,
                  ),
                  icon: const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        const Spacer(),
        const Glyph(Mark.drive, size: 16, color: accent),
        const SizedBox(width: 8),
        const Text(
          '5BSD Imager',
          style: TextStyle(
            color: ink,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (widget.preview || widget.confirmation)
          const Text(
            'PREVIEW · WRITING DISABLED',
            style: TextStyle(color: muted, fontSize: 9),
          )
        else
          const SizedBox(width: 98),
        const SizedBox(width: 14),
      ],
    ),
  );

  Widget sourceCard() => Container(
    padding: const EdgeInsets.all(19),
    decoration: BoxDecoration(
      color: paper,
      border: Border.all(color: line),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 54,
          decoration: BoxDecoration(
            color: const Color(0xfffaece8),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Glyph(Mark.image, size: 27, color: accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              caption('Disk image'),
              const SizedBox(height: 5),
              Text(
                path == null ? 'Choose your image' : path!.split('/').last,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                path == null
                    ? 'IMG, ISO, RAW or XZ · decompressed automatically'
                    : imageDetail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: muted, fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        AppButton(
          onPressed: locked || widget.smoke ? null : pick,
          child: Text(
            inspecting
                ? 'Reading…'
                : path == null
                ? 'Choose image'
                : 'Change',
          ),
        ),
      ],
    ),
  );

  Widget driveCard(Drive d) {
    final checked = selected.contains(d.token);
    final selectable = d.available && (imageSize == 0 || d.fits(imageSize));
    final reason = d.reason.isNotEmpty
        ? d.reason
        : imageSize > 0 && !d.fits(imageSize)
        ? 'Too small for this image'
        : 'Ready';
    final open = expanded.contains(d.name);
    final jobs = batch.jobs.where((j) => j.drive.token == d.token);
    final job = jobs.isEmpty ? null : jobs.first;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: checked ? const Color(0xfffff4f3) : paper,
        border: Border.all(
          color: checked ? accent : line,
          width: checked ? 1.5 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          SurfaceAction(
            checked: checked,
            label: '${d.title}, ${capacity(d.size)}, /dev/${d.name}',
            onTap: locked || widget.smoke || !selectable
                ? null
                : () => setState(() {
                    checked ? selected.remove(d.token) : selected.add(d.token);
                    batch.jobs.clear();
                  }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 18, 12),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: d.candidate
                        ? Center(
                            child: TickBox(
                              value: checked,
                              onChanged: locked || widget.smoke || !selectable
                                  ? null
                                  : (value) => setState(() {
                                      value
                                          ? selected.add(d.token)
                                          : selected.remove(d.token);
                                      batch.jobs.clear();
                                    }),
                            ),
                          )
                        : const Glyph(Mark.lock, color: muted, size: 19),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: d.candidate ? const Color(0xfff9ecdf) : canvas,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Glyph(
                      d.candidate ? Mark.usb : Mark.drive,
                      color: d.candidate ? accent : muted,
                      size: 23,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '/dev/${d.name} · ${d.serial.isEmpty ? 'No serial reported' : d.serial}',
                          style: const TextStyle(color: muted, fontSize: 11),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          reason,
                          style: TextStyle(
                            color: selectable ? muted : const Color(0xff96632d),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        capacity(d.size),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -.5,
                        ),
                      ),
                      Text(
                        bytes(d.size),
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (job != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text(
                        job.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: job.phase == JobPhase.failed ? red : green,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${(job.progress * 100).round()}%',
                        style: const TextStyle(color: muted, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ProgressTrack(
                    value: job.phase == JobPhase.authorizing
                        ? null
                        : job.progress,
                    minHeight: 4,
                    color: job.phase == JobPhase.verifying ? gold : accent,
                  ),
                  if (job.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        job.error!,
                        style: const TextStyle(color: red, fontSize: 11),
                      ),
                    ),
                  if (job.warning != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        job.warning!,
                        style: const TextStyle(color: gold, fontSize: 11),
                      ),
                    ),
                ],
              ),
            ),
          SurfaceAction(
            onTap: () => setState(() {
              open ? expanded.remove(d.name) : expanded.add(d.name);
            }),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 18, 10),
              child: Row(
                children: [
                  Glyph(open ? Mark.up : Mark.down, size: 16, color: muted),
                  const SizedBox(width: 5),
                  Text(
                    '${d.partitions.length} partitions · details only',
                    style: const TextStyle(color: muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (open)
            Container(
              width: double.infinity,
              color: canvas,
              padding: const EdgeInsets.fromLTRB(26, 12, 20, 12),
              child: Column(
                children: [
                  if (d.partitions.isEmpty)
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'No partition table detected.',
                        style: TextStyle(color: muted, fontSize: 12),
                      ),
                    ),
                  for (final p in d.partitions)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(
                        children: [
                          const Glyph(Mark.branch, size: 15, color: muted),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${p.name} · ${p.type}${p.label.isEmpty ? '' : ' · ${p.label}'}${p.busy ? ' · in use' : ''}',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 11,
                              ),
                            ),
                          ),
                          Text(
                            bytes(p.size),
                            style: const TextStyle(color: muted, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget driveList() {
    final candidates = drives.where((d) => d.candidate).toList();
    final protected = drives.where((d) => !d.candidate).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Destination drives',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0,
              ),
            ),
            const SizedBox(width: 12),
            if (selected.isNotEmpty)
              badge('${selected.length} selected', Mark.check, accent),
            const Spacer(),
            AppButton.icon(
              quiet: true,
              onPressed: locked || widget.smoke || scanning ? null : scan,
              icon: const Glyph(Mark.refresh, size: 17),
              label: const Text('Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Choose one or more drives.',
          style: TextStyle(color: muted, fontSize: 12),
        ),
        const SizedBox(height: 14),
        Expanded(
          child: ListView(
            children: [
              if (scanError != null) message(scanError!, red),
              if (scanned && candidates.isEmpty)
                Container(
                  padding: const EdgeInsets.all(23),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: paper,
                    border: Border.all(color: line),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Glyph(Mark.usb, color: Color(0xffab9b8b), size: 33),
                      const SizedBox(width: 17),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Waiting for a USB drive',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '5BSD reports ${drives.length} whole drive${drives.length == 1 ? '' : 's'}, with no USB candidates. Connect a drive directly to this machine; this list updates automatically.',
                              style: const TextStyle(
                                color: muted,
                                fontSize: 12,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              if (!scanned && scanError == null)
                const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(
                    child: Text(
                      'Reading drive inventory…',
                      style: TextStyle(color: muted),
                    ),
                  ),
                ),
              for (final d in candidates) driveCard(d),
              if (protected.isNotEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppButton.icon(
                    quiet: true,
                    onPressed: () =>
                        setState(() => showProtected = !showProtected),
                    icon: Glyph(showProtected ? Mark.up : Mark.down, size: 18),
                    label: Text(
                      '${protected.length} protected drive${protected.length == 1 ? '' : 's'}',
                    ),
                  ),
                ),
              if (showProtected)
                for (final d in protected) driveCard(d),
              if (error != null) message(error!, red),
              if (!active)
                for (final job in batch.jobs)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: message(
                      '${job.drive.title}: ${job.label}${job.error == null ? '' : ' — ${job.error}'}${job.warning == null ? '' : ' — ${job.warning}'}',
                      job.phase == JobPhase.complete
                          ? (job.warning == null ? green : gold)
                          : red,
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget message(String text, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .07),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      text,
      style: TextStyle(color: color, fontSize: 12, height: 1.5),
    ),
  );

  Widget progressDock() {
    final jobs = batch.jobs;
    final total = jobs.fold<int>(0, (n, j) => n + j.total);
    final write = total == 0
        ? 0.0
        : jobs.fold<int>(0, (n, j) => n + j.written) / total;
    final verify = total == 0
        ? 0.0
        : jobs.fold<int>(0, (n, j) => n + j.verified) / total;
    final waiting =
        active &&
        jobs.every(
          (j) => [JobPhase.queued, JobPhase.authorizing].contains(j.phase),
        );
    final String title = batch.cancelled && batch.running
        ? 'Stopping safely…'
        : waiting
        ? 'Authorize your selected drives'
        : active
        ? write < 1
              ? 'Writing your image'
              : 'Verifying every byte'
        : allVerified
        ? cacheNotice
              ? 'Verified · check the drive notice'
              : '${batch.successes} drive${batch.successes == 1 ? '' : 's'} ready to go'
        : jobs.isNotEmpty
        ? '${batch.successes} of ${jobs.length} drives verified'
        : 'Ready to write & verify';
    final detail = active
        ? 'Keep every drive connected until its verification finishes.'
        : allVerified
        ? cacheNotice
              ? 'Read-back matches. Cache flushing is unavailable on a selected drive.'
              : 'Written, flushed, and verified with SHA-256.'
        : 'The selected drives will be erased. You’ll confirm before writing.';
    return Container(
      padding: const EdgeInsets.fromLTRB(26, 19, 26, 21),
      decoration: const BoxDecoration(
        color: paper,
        border: Border(top: BorderSide(color: line)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 39,
                height: 39,
                decoration: BoxDecoration(
                  color: (allVerified ? green : accent).withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Glyph(
                  allVerified ? Mark.check : Mark.bolt,
                  color: allVerified ? green : accent,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detail,
                      style: const TextStyle(color: muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              if (active)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${(batch.progress * 100).round()}%',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                      ),
                    ),
                    AppButton.quiet(
                      onPressed: widget.smoke || batch.cancelled
                          ? null
                          : batch.cancel,
                      child: const Text(
                        'Cancel all',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                )
              else
                AppButton.icon(
                  primary: true,
                  onPressed:
                      locked ||
                          scanning ||
                          widget.smoke ||
                          path == null ||
                          targets.isEmpty
                      ? null
                      : confirm,
                  icon: const Glyph(Mark.arrow, size: 18, color: paper),
                  label: Text(
                    targets.length > 1
                        ? 'Write ${targets.length} drives'
                        : 'Write image',
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: phaseBar('WRITE', write, accent, waiting)),
              const SizedBox(width: 12),
              Expanded(child: phaseBar('VERIFY', verify, gold, false)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Glyph(Mark.shield, color: green, size: 13),
              const SizedBox(width: 6),
              const Text(
                'Read-back verification is always on',
                style: TextStyle(color: green, fontSize: 10),
              ),
              const Spacer(),
              Text(
                active
                    ? '${jobs.length} drive${jobs.length == 1 ? '' : 's'} in this batch'
                    : 'SHA-256 · whole-drive images',
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget phaseBar(
    String label,
    double value,
    Color color,
    bool indeterminate,
  ) => Column(
    children: [
      Row(
        children: [
          caption(label),
          const Spacer(),
          Text(
            '${(value * 100).round()}%',
            style: const TextStyle(color: muted, fontSize: 10),
          ),
        ],
      ),
      const SizedBox(height: 7),
      ClipRRect(
        borderRadius: BorderRadius.circular(1),
        child: TweenAnimationBuilder<double>(
          tween: Tween(end: value),
          duration: const Duration(milliseconds: 240),
          builder: (_, progress, __) => ProgressTrack(
            value: indeterminate ? null : progress,
            minHeight: 7,
            backgroundColor: line,
            color: color,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    key: previewKey,
    child: Stack(
      children: [
        MacosWindow(
          disableWallpaperTinting: true,
          backgroundColor: canvas,
          child: Column(
            children: [
              titlebar(),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1050),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 26, 28, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          sourceCard(),
                          const SizedBox(height: 22),
                          Expanded(child: driveList()),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              progressDock(),
              Container(
                height: 40,
                alignment: Alignment.center,
                child: const Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: 'Built for 5BSD '),
                      TextSpan(
                        text: '❤️',
                        style: TextStyle(
                          color: accent,
                          fontFamily: 'Noto Color Emoji',
                        ),
                      ),
                      TextSpan(text: '   ·   #livefreeordie'),
                    ],
                  ),
                  style: TextStyle(color: muted, fontSize: 11),
                ),
              ),
            ],
          ),
        ),
        if (widget.confirmation)
          Positioned.fill(
            child: ColoredBox(
              color: const Color(0x9930151a),
              child: confirmationPanel(context, targets),
            ),
          ),
      ],
    ),
  );
}
