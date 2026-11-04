import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/core/widgets/app_card.dart';
import 'package:attendance_app/core/widgets/app_page.dart';
import 'package:attendance_app/core/widgets/entity_tile.dart';
import 'package:attendance_app/core/widgets/section_header.dart';
import 'package:attendance_app/domain/repositories/location_repository.dart';
import 'package:attendance_app/domain/repositories/onboarding_repository.dart';
import 'package:attendance_app/features/admin/roster_parser.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Invite a whole team from an Excel or CSV sheet: pick → review → invite.
class BulkUploadScreen extends StatefulWidget {
  const BulkUploadScreen({super.key});

  @override
  State<BulkUploadScreen> createState() => _BulkUploadScreenState();
}

class _BulkUploadScreenState extends State<BulkUploadScreen> {
  String? _fileName;
  List<RosterRow>? _rows;
  bool _sending = false;
  ImportResult? _result;

  Future<void> _pick() async {
    final companyId = context.read<UserProvider>().company?.id ?? '';
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx'],
      withData: true,
    );
    final file = picked?.files.singleOrNull;
    if (file == null || file.bytes == null) return;
    try {
      final rows = RosterParser.parseFile(file.name, file.bytes!);
      final sites = await sl<LocationRepository>().getLocations(companyId);
      for (final r in rows) {
        r.checkLocations(sites.map((s) => s.name));
      }
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _rows = rows;
        _result = null;
      });
    } on FormatException catch (e) {
      _snack(e.message);
    } catch (_) {
      _snack('We couldn’t read that file. Save it as .xlsx or .csv and retry.');
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: context.colors.danger),
    );
  }

  Future<void> _send() async {
    final ok = _rows!.where((r) => r.ok).toList();
    final companyId =
        Provider.of<UserProvider>(context, listen: false).company?.id ?? '';
    setState(() => _sending = true);
    try {
      final result = await sl<OnboardingRepository>().importEmployees(
        companyId,
        [for (final r in ok) r.toJson()],
      );
      // Map the server's per-row errors back onto the sheet rows.
      result.errors.forEach((i, message) => ok[i].problem = message);
      setState(() => _result = result);
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t send the invites');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Scaffold(
      appBar: AppBar(title: const Text('Upload a list')),
      body: rows == null ? _intro(context) : _review(context, rows),
    );
  }

  Widget _intro(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text('Add your whole team at once', style: text.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(
          'Upload an Excel (.xlsx) or CSV file. The first row must have '
          'column headings; we need Name and Phone, and also read '
          'Department, Position, Location, Shift start and Shift end.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.lg),
        AppCard(
          child: Text(
            RosterParser.template.trim(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        const AppBanner(
          icon: Icons.lightbulb_outline_rounded,
          child: Text(
            'Location must match a location name exactly. Separate several '
            'with “;”. Leave it blank for your main location.',
          ),
        ),
        const SizedBox(height: AppSpacing.xl),
        AppButton(
          label: 'Choose file',
          icon: Icons.upload_file_rounded,
          onPressed: _pick,
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: 'Share the template',
          variant: AppButtonVariant.secondary,
          onPressed: () => SharePlus.instance.share(
            ShareParams(
              text: RosterParser.template,
              subject: 'PunchIn team list template',
            ),
          ),
        ),
      ],
    );
  }

  Widget _review(BuildContext context, List<RosterRow> rows) {
    final colors = context.colors;
    final result = _result;
    final good = rows.where((r) => r.ok).length;
    final bad = rows.where((r) => !r.ok).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              if (result != null)
                AppBanner(
                  icon: Icons.check_circle_outline_rounded,
                  child: Text(
                    '${result.created + result.updated} people invited. '
                    'They join by signing in with their phone number.'
                    '${bad.isEmpty ? '' : ' ${bad.length} rows need fixing.'}',
                  ),
                )
              else
                AppBanner(
                  icon: Icons.description_outlined,
                  child: Text(
                    '$_fileName: $good ready'
                    '${bad.isEmpty ? '' : ', ${bad.length} need fixing'}',
                  ),
                ),
              if (bad.isNotEmpty) ...[
                const SectionHeader(title: 'Needs fixing'),
                const SizedBox(height: AppSpacing.sm),
                AppGroup(
                  children: [
                    for (final r in bad)
                      EntityTile(
                        inGroup: true,
                        leading: IconChip(
                          icon: Icons.error_outline_rounded,
                          color: colors.danger,
                          background: colors.dangerSoft,
                        ),
                        title: r.name.isEmpty ? 'Row ${r.line}' : r.name,
                        subtitle: 'Row ${r.line} · ${r.problem}',
                      ),
                  ],
                ),
              ],
              if (result == null && good > 0) ...[
                const SectionHeader(title: 'Ready to invite'),
                const SizedBox(height: AppSpacing.sm),
                AppGroup(
                  children: [
                    for (final r in rows.where((r) => r.ok))
                      EntityTile(
                        inGroup: true,
                        title: r.name,
                        subtitle: [
                          r.phone,
                          r.department,
                          r.locationNames.isEmpty
                              ? null
                              : r.locationNames.join(', '),
                        ].whereType<String>().join(' · '),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: result != null
                ? AppButton(
                    label: 'Done',
                    onPressed: () => Navigator.pop(context),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          label: 'Other file',
                          variant: AppButtonVariant.secondary,
                          onPressed: _sending ? null : _pick,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        flex: 2,
                        child: AppButton(
                          label: 'Invite $good',
                          loading: _sending,
                          onPressed: good == 0 || _sending ? null : _send,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }
}
