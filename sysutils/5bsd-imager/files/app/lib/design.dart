// SPDX-License-Identifier: BSD-3-Clause
// macos_ui controls with 5BSD accents and keyboard activation adapters.

import 'package:flutter/widgets.dart';
import 'package:flutter/cupertino.dart' show CupertinoIcons;
import 'package:macos_ui/macos_ui.dart';
import 'package:flutter/services.dart';

const chrome = Color(0xffededf0),
    accent = Color(0xffb7313b),
    ink = Color(0xff26262a);
const muted = Color(0xff717177),
    canvas = Color(0xfff5f5f7),
    line = Color(0xffdcdce1);
const gold = Color(0xffb68529),
    green = Color(0xff25816b),
    red = Color(0xffb64939);
const paper = Color(0xffffffff);
const desktopText = TextStyle(
  color: ink,
  fontFamily: 'Noto Sans',
  fontFamilyFallback: ['Roboto'],
  fontSize: 13,
  height: 1.4,
  decoration: TextDecoration.none,
);

enum Mark {
  usb,
  image,
  lock,
  drive,
  check,
  up,
  down,
  branch,
  refresh,
  close,
  minimize,
  maximize,
  arrow,
  bolt,
  shield,
}

class Glyph extends StatelessWidget {
  const Glyph(this.mark, {super.key, this.size = 20, this.color = ink});
  final Mark mark;
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => MacosIcon(
    switch (mark) {
      Mark.usb => CupertinoIcons.tray_arrow_down,
      Mark.image => CupertinoIcons.doc,
      Mark.lock => CupertinoIcons.lock,
      Mark.drive => CupertinoIcons.tray,
      Mark.check => CupertinoIcons.check_mark,
      Mark.up => CupertinoIcons.chevron_up,
      Mark.down => CupertinoIcons.chevron_down,
      Mark.branch => CupertinoIcons.arrow_turn_down_right,
      Mark.refresh => CupertinoIcons.refresh,
      Mark.close => CupertinoIcons.xmark,
      Mark.minimize => CupertinoIcons.minus,
      Mark.maximize => CupertinoIcons.fullscreen,
      Mark.arrow => CupertinoIcons.arrow_right,
      Mark.bolt => CupertinoIcons.bolt,
      Mark.shield => CupertinoIcons.shield_lefthalf_fill,
    },
    size: size,
    color: color,
  );
}

// macos_ui's push buttons handle pointer input. Add desktop keyboard focus
// without replacing their native-look drawing or press behavior.
class KeyboardControl extends StatefulWidget {
  const KeyboardControl({
    super.key,
    required this.child,
    this.activate,
    this.autofocus = false,
  });
  final Widget child;
  final VoidCallback? activate;
  final bool autofocus;
  @override
  State<KeyboardControl> createState() => _KeyboardControlState();
}

class _KeyboardControlState extends State<KeyboardControl> {
  bool focused = false;
  @override
  Widget build(BuildContext context) => FocusableActionDetector(
    enabled: widget.activate != null,
    autofocus: widget.autofocus,
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
    },
    actions: {
      ActivateIntent: CallbackAction<ActivateIntent>(
        onInvoke: (_) {
          widget.activate?.call();
          return null;
        },
      ),
    },
    onShowFocusHighlight: (value) => setState(() => focused = value),
    child: DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: focused ? gold : const Color(0x00000000),
          width: 2,
        ),
      ),
      child: Padding(padding: const EdgeInsets.all(2), child: widget.child),
    ),
  );
}

// Pointer and keyboard activation share the same callback, including its guards.
class SurfaceAction extends StatefulWidget {
  const SurfaceAction({
    super.key,
    required this.child,
    this.onTap,
    this.label,
    this.autofocus = false,
    this.checked,
    this.padding = EdgeInsets.zero,
    this.background = const Color(0x00000000),
    this.border = const Color(0x00000000),
    this.hoverColor = const Color(0x0db68529),
  });
  final Widget child;
  final VoidCallback? onTap;
  final String? label;
  final bool autofocus;
  final bool? checked;
  final EdgeInsetsGeometry padding;
  final Color background, border, hoverColor;
  @override
  State<SurfaceAction> createState() => _SurfaceActionState();
}

class _SurfaceActionState extends State<SurfaceAction> {
  bool hover = false, focus = false, pressed = false;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: widget.checked == null,
      checked: widget.checked,
      enabled: enabled,
      label: widget.label,
      onTap: widget.onTap,
      child: FocusableActionDetector(
        enabled: enabled,
        autofocus: widget.autofocus,
        mouseCursor: enabled
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        shortcuts: const {
          SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        },
        actions: {
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onTap?.call();
              return null;
            },
          ),
        },
        onShowFocusHighlight: (value) => setState(() => focus = value),
        onShowHoverHighlight: (value) => setState(() => hover = value),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: widget.onTap,
          onTapDown: enabled ? (_) => setState(() => pressed = true) : null,
          onTapUp: (_) => setState(() => pressed = false),
          onTapCancel: () => setState(() => pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 90),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: enabled && (hover || pressed)
                  ? Color.alphaBlend(widget.hoverColor, widget.background)
                  : widget.background,
              border: Border.all(
                color: focus && enabled ? gold : widget.border,
                width: 1,
              ),
              borderRadius: BorderRadius.circular(3),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.child,
    this.onPressed,
    this.primary = false,
    this.autofocus = false,
  }) : quiet = false,
       label = null;
  const AppButton.quiet({
    super.key,
    required this.child,
    this.onPressed,
    this.autofocus = false,
  }) : primary = false,
       quiet = true,
       label = null;
  AppButton.icon({
    super.key,
    required Widget icon,
    required Widget label,
    this.onPressed,
    this.primary = false,
    this.quiet = false,
    this.autofocus = false,
  }) : label = null,
       child = Row(
         mainAxisSize: MainAxisSize.min,
         children: [icon, const SizedBox(width: 9), label],
       );
  const AppButton.iconOnly({
    super.key,
    required Widget icon,
    required this.label,
    this.onPressed,
  }) : child = icon,
       primary = false,
       quiet = true,
       autofocus = false;
  final Widget child;
  final VoidCallback? onPressed;
  final bool primary, quiet, autofocus;
  final String? label;
  @override
  Widget build(BuildContext context) => KeyboardControl(
    activate: onPressed,
    autofocus: autofocus,
    child: label != null
        ? MacosIconButton(
            icon: child,
            onPressed: onPressed,
            semanticLabel: label,
            backgroundColor: const Color(0x00000000),
            hoverColor: const Color(0x15000000),
            boxConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
              maxWidth: 40,
              maxHeight: 40,
            ),
          )
        : PushButton(
            onPressed: onPressed,
            controlSize: ControlSize.large,
            secondary: !primary,
            color: primary ? accent : null,
            mouseCursor: onPressed == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            padding: EdgeInsets.symmetric(
              horizontal: quiet ? 10 : 18,
              vertical: 6,
            ),
            child: child,
          ),
  );
}

class TickBox extends StatelessWidget {
  const TickBox({super.key, required this.value, this.onChanged});
  final bool value;
  final ValueChanged<bool>? onChanged;
  @override
  Widget build(BuildContext context) => MacosCheckbox(
    value: value,
    size: 16,
    activeColor: accent,
    onChanged: onChanged,
  );
}

class ProgressTrack extends StatefulWidget {
  const ProgressTrack({
    super.key,
    this.value,
    this.minHeight = 6,
    this.color = accent,
    this.backgroundColor = line,
  });
  final double? value;
  final double minHeight;
  final Color color, backgroundColor;
  @override
  State<ProgressTrack> createState() => _ProgressTrackState();
}

class _ProgressTrackState extends State<ProgressTrack>
    with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  @override
  void initState() {
    super.initState();
    if (widget.value == null) animation.repeat();
  }

  @override
  void didUpdateWidget(ProgressTrack old) {
    super.didUpdateWidget(old);
    if (widget.value == null && !animation.isAnimating) animation.repeat();
    if (widget.value != null) animation.stop();
  }

  @override
  void dispose() {
    animation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.value != null)
      return SizedBox(
        width: double.infinity,
        child: ProgressBar(
          value: widget.value!.clamp(0, 1) * 100,
          height: widget.minHeight,
          trackColor: widget.color,
          backgroundColor: widget.backgroundColor,
        ),
      );
    return Semantics(
      label: 'Waiting for authorization',
      child: SizedBox(
        height: widget.minHeight,
        child: ClipRect(
          child: LayoutBuilder(
            builder: (_, limits) => AnimatedBuilder(
              animation: animation,
              builder: (_, __) => Stack(
                children: [
                  Positioned.fill(
                    child: ColoredBox(color: widget.backgroundColor),
                  ),
                  Positioned(
                    left: limits.maxWidth * (animation.value * 1.3 - .3),
                    top: 0,
                    bottom: 0,
                    width: limits.maxWidth * .3,
                    child: ColoredBox(color: widget.color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ConfirmPanel extends StatelessWidget {
  const ConfirmPanel({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
  });
  final Widget title, content;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: 580,
        maxHeight: MediaQuery.sizeOf(context).height - 60,
      ),
      child: MacosSheet(
        insetPadding: EdgeInsets.zero,
        backgroundColor: canvas,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: DefaultTextStyle(
            style: desktopText,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 22),
                  child: Glyph(Mark.drive, size: 44, color: accent),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                  child: DefaultTextStyle.merge(
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                    child: title,
                  ),
                ),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: content,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: actions,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

Future<T?> showConfirmation<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) => showGeneralDialog<T>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Dismiss confirmation',
  barrierColor: const Color(0x9930151a),
  transitionDuration: const Duration(milliseconds: 140),
  pageBuilder: (context, _, __) => Shortcuts(
    shortcuts: const {
      SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
    },
    child: Actions(
      actions: {
        DismissIntent: CallbackAction<DismissIntent>(
          onInvoke: (_) {
            Navigator.of(context).pop();
            return null;
          },
        ),
      },
      child: FocusTraversalGroup(child: builder(context)),
    ),
  ),
);
