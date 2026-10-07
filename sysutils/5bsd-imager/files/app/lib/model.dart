// SPDX-License-Identifier: BSD-3-Clause
String bytes(int n) => n >= 1073741824
    ? '${(n / 1073741824).toStringAsFixed(1)} GiB'
    : '${(n / 1048576).toStringAsFixed(1)} MiB';
String capacity(int n) => n >= 1000000000
    ? '${(n / 1000000000).toStringAsFixed(1)} GB'
    : '${(n / 1000000).toStringAsFixed(1)} MB';

class Partition {
  Partition(Map<String, dynamic> json)
    : name = json['name'] as String,
      size = json['bytes'] as int,
      type = json['type'] as String,
      label = json['label'] as String,
      busy = json['busy'] as bool;
  final String name, type, label;
  final int size;
  final bool busy;
}

class Drive {
  Drive(Map<String, dynamic> json)
    : name = json['name'] as String,
      description = json['description'] as String,
      serial = json['serial'] as String,
      size = json['bytes'] as int,
      sector = json['sector'] as int,
      token = json['token'] as String,
      busy = json['busy'] as bool,
      candidate = json['candidate'] as bool,
      reason = json['reason'] as String,
      partitions = (json['partitions'] as List)
          .map((p) => Partition(p as Map<String, dynamic>))
          .toList();
  final String name, description, serial, token, reason;
  final int size, sector;
  final bool busy, candidate;
  final List<Partition> partitions;
  String get title => description.isEmpty ? name : description;
  bool get available => candidate && !busy && reason.isEmpty && size > 0;
  int padded(int n) => ((n + sector - 1) ~/ sector) * sector;
  bool fits(int n) => n > 0 && sector > 0 && padded(n) <= size;
}

List<Drive> parseInventory(dynamic json) {
  if (json is! Map || json['version'] != 3 || json['drives'] is! List) {
    throw StateError(
      'The installed Imager helper needs updating. Install the helper from this build, then refresh.',
    );
  }
  return (json['drives'] as List)
      .map((v) => Drive(v as Map<String, dynamic>))
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));
}

enum JobPhase {
  queued,
  authorizing,
  writing,
  verifying,
  complete,
  failed,
  cancelled,
}

class WriteJob {
  WriteJob(this.drive, this.imageSize) : total = drive.padded(imageSize);
  final Drive drive;
  final int imageSize, total;
  JobPhase phase = JobPhase.queued;
  int written = 0, verified = 0;
  String? error;
  String? warning;
  bool get terminal =>
      [JobPhase.complete, JobPhase.failed, JobPhase.cancelled].contains(phase);
  double get progress => (written + verified) / (total * 2);
  String get label => switch (phase) {
    JobPhase.queued => 'Queued',
    JobPhase.authorizing => 'Waiting for authorization',
    JobPhase.writing => 'Writing',
    JobPhase.verifying => 'Verifying',
    JobPhase.complete =>
      warning == null ? 'Verified' : 'Verified · cache notice',
    JobPhase.failed => 'Failed',
    JobPhase.cancelled => 'Cancelled',
  };
  void event(Map<String, dynamic> e) {
    final done = e['done'];
    if (terminal ||
        e['total'] != total ||
        done is! int ||
        done < 0 ||
        done > total) {
      throw StateError('Invalid writer progress');
    }
    switch (e['phase']) {
      case 'ready':
        if (phase != JobPhase.authorizing || done != 0)
          throw StateError('Unexpected writer handshake');
        phase = JobPhase.writing;
      case 'writing':
        if (phase != JobPhase.writing || done < written)
          throw StateError('Invalid write sequence');
        written = done;
      case 'verifying':
        if (![JobPhase.writing, JobPhase.verifying].contains(phase) ||
            written != total ||
            done < verified) {
          throw StateError('Verification started before writing finished');
        }
        phase = JobPhase.verifying;
        verified = done;
      case 'complete':
        if (phase != JobPhase.verifying || verified != total || done != total) {
          throw StateError('Writer did not finish verification');
        }
        if (e['cacheFlushed'] is! bool) {
          throw StateError('Invalid cache flush result');
        }
        if (e['cacheFlushed'] == false) {
          warning = 'Read-back matches, but this drive does not support cache flushing. Persistence after unplugging cannot be confirmed.';
        }
      // Exit status and the source stream must also succeed before completion.
      default:
        throw StateError('Unknown writer phase');
    }
  }
}
