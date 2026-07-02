import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum StartupStatus { pending, running, success, failed, skipped }

class StartupStep {
  StartupStep(this.name)
    : status = StartupStatus.pending.obs,
      message = RxnString();

  final String name;
  final Rx<StartupStatus> status;
  final RxnString message;
  DateTime? startedAt;
  DateTime? finishedAt;
}

class StartupDiagnosticsController extends GetxController {
  final steps = <String, StartupStep>{}.obs;
  final visible = kDebugMode.obs; // default show on debug mode

  StartupStep _ensure(String name) {
    return steps.putIfAbsent(name, () => StartupStep(name));
  }

  void start(String name) {
    final s = _ensure(name);
    s.status.value = StartupStatus.running;
    s.startedAt = DateTime.now();
  }

  void success(String name, {String? note}) {
    final s = _ensure(name);
    s.status.value = StartupStatus.success;
    s.message.value = note;
    s.finishedAt = DateTime.now();
  }

  void fail(String name, Object error, {StackTrace? stackTrace}) {
    final s = _ensure(name);
    s.status.value = StartupStatus.failed;
    s.message.value = error.toString();
    s.finishedAt = DateTime.now();
  }

  void skip(String name, {String? reason}) {
    final s = _ensure(name);
    s.status.value = StartupStatus.skipped;
    s.message.value = reason;
    s.finishedAt = DateTime.now();
  }

  void toggle() => visible.value = !visible.value;
}

class StartupDiagnosticsOverlay extends StatelessWidget {
  const StartupDiagnosticsOverlay({super.key});

  Color _colorFor(StartupStatus st, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (st) {
      case StartupStatus.pending:
        return cs.outline;
      case StartupStatus.running:
        return cs.primary;
      case StartupStatus.success:
        return Colors.green;
      case StartupStatus.failed:
        return cs.error;
      case StartupStatus.skipped:
        return cs.tertiary;
    }
  }

  String _label(StartupStatus st) {
    switch (st) {
      case StartupStatus.pending:
        return 'pending';
      case StartupStatus.running:
        return 'running';
      case StartupStatus.success:
        return 'ok';
      case StartupStatus.failed:
        return 'failed';
      case StartupStatus.skipped:
        return 'skipped';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<StartupDiagnosticsController>();
    return Obx(() {
      if (!ctrl.visible.value) {
        // Show a tiny toggle in the corner
        return Positioned(
          top: 8,
          right: 8,
          child: _ToggleChip(onTap: ctrl.toggle),
        );
      }
      return Positioned(
        top: 8,
        right: 8,
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.95),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360, maxHeight: 380),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      const Text(
                        'Startup Diagnostics',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: ctrl.toggle,
                        icon: const Icon(Icons.close, size: 18),
                        tooltip: 'Hide diagnostics',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Obx(() {
                      final entries = ctrl.steps.values.toList();
                      return ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const Divider(height: 8),
                        itemBuilder: (context, i) {
                          final s = entries[i];
                          return Obx(() {
                            final st = s.status.value;
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  margin: const EdgeInsets.only(top: 6),
                                  decoration: BoxDecoration(
                                    color: _colorFor(st, context),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _label(st),
                                        style:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodySmall,
                                      ),
                                      if (s.message.value != null &&
                                          s.message.value!.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 2,
                                          ),
                                          child: Text(
                                            s.message.value!,
                                            style: Theme.of(
                                              context,
                                            ).textTheme.bodySmall?.copyWith(
                                              color:
                                                  Theme.of(context)
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          });
                        },
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }
}

class _ToggleChip extends StatelessWidget {
  const _ToggleChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      shape: const StadiumBorder(),
      elevation: 4,
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Text('Diagnostics', style: TextStyle(fontSize: 12)),
        ),
      ),
    );
  }
}
