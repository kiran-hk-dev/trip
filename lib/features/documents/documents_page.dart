import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show FileOptions;
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/planning.dart';
import '../../data/supabase_service.dart';
import '../../router/providers.dart';
import '../../shared/widgets/common.dart';
import '../../shared/widgets/form_fields.dart';

/// Private document vault.
///
/// Files live in a private Supabase bucket and are only ever opened through a
/// short-lived signed URL generated after an authorisation check. No public
/// URL is stored or shown.
class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});

  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String? _tripFilter;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
      ),
      body: Column(
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: InlineBanner(
              message:
                  'Documents are stored in a private bucket. Downloads use short-lived links '
                  'and are never publicly accessible. Avoid uploading identity documents '
                  'unless you need to.',
              tone: StatusTone.info,
              icon: Icons.lock_outline,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Expanded(
            child: FutureBuilder<List<TravelDocument>>(
              future: ref
                  .watch(tripRepositoryProvider)
                  .documents
                  .list(tripId: _tripFilter),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<TravelDocument>> snapshot,
                  ) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<TravelDocument> docs = snapshot.data!;
                    if (docs.isEmpty) {
                      return EmptyState(
                        icon: Icons.folder_open,
                        title: 'No documents yet',
                        message:
                            'Upload your passport copy, insurance policy, tickets and visas. '
                            'Everything stays in private storage.',
                        action: FilledButton.icon(
                          onPressed: _upload,
                          icon: const Icon(Icons.upload_file),
                          label: const Text('Upload a document'),
                        ),
                      );
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      itemCount: docs.length,
                      itemBuilder: (BuildContext context, int i) =>
                          _DocumentCard(document: docs[i]),
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _upload() async {
    if (AppConfig.demoMode) {
      showFeedback(
        context,
        'Uploads are disabled in demo mode.',
        isError: true,
      );
      return;
    }

    final List<PlatformFile> picked = await FilePicker.pickFiles(
      dialogTitle: 'Choose a document',
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'jpg', 'jpeg', 'png', 'webp'],
    );
    if (picked.isEmpty) return;

    final PlatformFile file = picked.first;
    final Uint8List bytes = await file.readAsBytes();
    if (!mounted) return;
    final int size = bytes.length;
    if (size > 25 * 1024 * 1024) {
      showFeedback(context, 'That file is larger than 25 MB.', isError: true);
      return;
    }
    final ({String name, String docType, DateTime? expiry, String notes})?
    meta =
        await showAppSheet<
          ({String name, String docType, DateTime? expiry, String notes})
        >(
          context: context,
          builder: (BuildContext context) => _UploadSheet(filename: file.name),
        );
    if (meta == null || !mounted) return;

    final String? userId = SupabaseService.instance.currentUserId;
    if (userId == null) return;
    final String path =
        '$userId/${_tripFilter ?? 'personal'}/${DateTime.now().millisecondsSinceEpoch}'
        '-${file.name}';

    try {
      await SupabaseService.instance.client.storage
          .from('trip-documents')
          .uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(
              contentType: 'application/octet-stream',
            ),
          );
      await ref
          .read(tripRepositoryProvider)
          .documents
          .register(
            tripId: _tripFilter,
            name: meta.name,
            docType: meta.docType,
            storagePath: path,
            mimeType: _mimeFor(file.name),
            sizeBytes: size,
            expiryDate: meta.expiry,
            notes: meta.notes,
          );
      ref.invalidate(tripRepositoryProvider);
      if (mounted) showFeedback(context, 'Document uploaded.');
    } catch (err) {
      if (mounted) {
        showFeedback(
          context,
          err is RepositoryException ? err.message : 'Upload failed: $err',
          isError: true,
        );
      }
    }
  }

  static String _mimeFor(String name) {
    final String lower = name.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }
}

class _DocumentCard extends ConsumerWidget {
  const _DocumentCard({required this.document});

  final TravelDocument document;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    return AppCard(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                _iconFor(document.docType),
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(document.name, style: theme.textTheme.titleSmall),
                    Text(
                      '${_label(document.docType)} · ${(document.sizeBytes / 1024).round()} KB',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (document.sensitive)
                const Icon(
                  Icons.lock_outline,
                  size: 15,
                  color: AppColors.inkFaint,
                ),
            ],
          ),
          if (document.expiryDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                Icon(
                  document.expiryUrgent
                      ? Icons.warning_amber_rounded
                      : Icons.event_outlined,
                  size: 14,
                  color: document.expiryUrgent ? AppColors.danger : null,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  'Expires ${document.expiryDate!.toIso8601String().substring(0, 10)}'
                  '${document.daysUntilExpiry != null ? ' · ${document.daysUntilExpiry} days left' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: document.expiryUrgent ? AppColors.danger : null,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              TextButton.icon(
                onPressed: () => _open(context, ref),
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('Open'),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () async {
                  final bool ok = await confirmDestructive(
                    context,
                    title: 'Delete "${document.name}"?',
                    message:
                        'The record is removed and the stored file is deleted.',
                    confirmLabel: 'Delete',
                  );
                  if (!ok) return;
                  await ref
                      .read(tripRepositoryProvider)
                      .documents
                      .softDelete(document.id);
                  ref.invalidate(tripRepositoryProvider);
                },
                icon: const Icon(Icons.delete_outline, size: 16),
                label: const Text('Delete'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    try {
      final String url = await ref
          .read(tripRepositoryProvider)
          .documents
          .signedUrl(document.storagePath);
      if (!context.mounted) return;
      final Uri? uri = Uri.tryParse(url);
      if (uri == null) {
        showFeedback(context, 'That link is not valid.', isError: true);
        return;
      }
      // Opening a signed URL is a browser/share action; on device it launches
      // the platform viewer.
      showFeedback(context, 'Opening a 5-minute link to ${document.name}');
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (err) {
      if (context.mounted) {
        showFeedback(
          context,
          err is RepositoryException
              ? err.message
              : 'Could not open that document.',
          isError: true,
        );
      }
    }
  }

  static IconData _iconFor(String type) => switch (type) {
    'passport' => Icons.no_accounts_outlined,
    'visa' => Icons.assignment_outlined,
    'insurance' => Icons.shield_outlined,
    'ticket' => Icons.confirmation_number_outlined,
    'vaccination' => Icons.vaccines_outlined,
    _ => Icons.description_outlined,
  };

  static String _label(String type) => switch (type) {
    'passport' => 'Passport',
    'visa' => 'Visa',
    'insurance' => 'Insurance',
    'ticket' => 'Ticket',
    'vaccination' => 'Health',
    'identity' => 'Identity',
    _ => 'Other',
  };
}

class _UploadSheet extends StatefulWidget {
  const _UploadSheet({required this.filename});

  final String filename;

  @override
  State<_UploadSheet> createState() => _UploadSheetState();
}

class _UploadSheetState extends State<_UploadSheet> {
  late final TextEditingController _name = TextEditingController(
    text: widget.filename,
  );
  final TextEditingController _notes = TextEditingController();
  String _type = 'other';
  DateTime? _expiry;

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Document details',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: AppSpacing.md),
          DropdownButtonFormField<String>(
            initialValue: _type,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Type'),
            items: const <DropdownMenuItem<String>>[
              DropdownMenuItem<String>(
                value: 'passport',
                child: Text('Passport'),
              ),
              DropdownMenuItem<String>(
                value: 'visa',
                child: Text('Visa or authorisation'),
              ),
              DropdownMenuItem<String>(
                value: 'insurance',
                child: Text('Insurance'),
              ),
              DropdownMenuItem<String>(
                value: 'ticket',
                child: Text('Ticket or booking'),
              ),
              DropdownMenuItem<String>(
                value: 'vaccination',
                child: Text('Health document'),
              ),
              DropdownMenuItem<String>(
                value: 'identity',
                child: Text('Identity document'),
              ),
              DropdownMenuItem<String>(value: 'other', child: Text('Other')),
            ],
            onChanged: (String? v) => setState(() => _type = v ?? _type),
          ),
          if (_type == 'passport' ||
              _type == 'insurance' ||
              _type == 'visa') ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: <Widget>[
                Expanded(
                  child: DateField(
                    label: _expiry == null
                        ? 'Expiry date'
                        : 'Expires ${_expiry!.toIso8601String().substring(0, 10)}',
                    value:
                        _expiry ??
                        DateTime.now().add(const Duration(days: 365 * 3)),
                    firstDate: DateTime.now().subtract(
                      const Duration(days: 365 * 10),
                    ),
                    onChanged: (DateTime d) => setState(() => _expiry = d),
                  ),
                ),
                if (_expiry != null)
                  IconButton(
                    onPressed: () => setState(() => _expiry = null),
                    icon: const Icon(Icons.clear),
                  ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).pop((
              name: _name.text.trim(),
              docType: _type,
              expiry: _expiry,
              notes: _notes.text.trim(),
            )),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }
}
