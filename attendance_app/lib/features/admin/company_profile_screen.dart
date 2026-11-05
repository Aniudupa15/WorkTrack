import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import 'package:attendance_app/core/di/injection.dart';
import 'package:attendance_app/core/error/app_exception.dart';
import 'package:attendance_app/core/theme/app_colors.dart';
import 'package:attendance_app/core/theme/app_spacing.dart';
import 'package:attendance_app/core/widgets/app_button.dart';
import 'package:attendance_app/domain/repositories/company_repository.dart';
import 'package:attendance_app/features/onboarding/company_setup_screen.dart';
import 'package:attendance_app/features/shared/user_provider.dart';

/// Name, logo, industry and GSTIN — what shows on invites and invoices.
class CompanyProfileScreen extends StatefulWidget {
  const CompanyProfileScreen({super.key});

  @override
  State<CompanyProfileScreen> createState() => _CompanyProfileScreenState();
}

class _CompanyProfileScreenState extends State<CompanyProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _company = Provider.of<UserProvider>(
    context,
    listen: false,
  ).company;
  late final _name = TextEditingController(text: _company?.name ?? '');
  late final _gstin = TextEditingController(text: _company?.gstin ?? '');
  late String? _industry = companyIndustries.contains(_company?.industry)
      ? _company?.industry
      : null;
  Uint8List? _logo;
  String? _logoUrl;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final path = _company?.logoUrl;
    if (path != null && path.isNotEmpty) {
      FirebaseStorage.instance
          .ref(path)
          .getDownloadURL()
          .then((u) {
            if (mounted) setState(() => _logoUrl = u);
          })
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _gstin.dispose();
    super.dispose();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _pickLogo() async {
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    setState(() => _logo = bytes);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final prov = Provider.of<UserProvider>(context, listen: false);
    final id = prov.company?.id;
    if (id == null) return;
    setState(() => _busy = true);
    try {
      final gstin = _gstin.text.trim().toUpperCase();
      final fields = <String, dynamic>{
        'companyName': _name.text.trim(),
        'industry': _industry,
        'gstin': gstin.isEmpty ? null : gstin,
      };
      if (_logo != null) {
        final path = 'logos/$id/logo.png';
        await FirebaseStorage.instance
            .ref(path)
            .putData(_logo!, SettableMetadata(contentType: 'image/png'));
        fields['logoUrl'] = path;
      }
      await sl<CompanyRepository>().updateProfile(id, fields);
      await prov.refreshUser();
      if (!mounted) return;
      _snack('Saved');
      Navigator.pop(context);
    } catch (e) {
      _snack(e is AppException ? e.message : 'Couldn’t save');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final ImageProvider? logo = _logo != null
        ? MemoryImage(_logo!)
        : (_logoUrl != null ? NetworkImage(_logoUrl!) : null);
    return Scaffold(
      appBar: AppBar(title: const Text('Company profile')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Row(
              children: [
                InkWell(
                  onTap: _pickLogo,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Container(
                    width: 64,
                    height: 64,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: colors.surfaceMuted,
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: colors.borderStrong),
                      image: logo == null
                          ? null
                          : DecorationImage(image: logo, fit: BoxFit.cover),
                    ),
                    child: logo == null
                        ? Icon(
                            Icons.add_photo_alternate_outlined,
                            color: colors.textSecondary,
                          )
                        : null,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Company logo',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 32),
                        ),
                        onPressed: _pickLogo,
                        child: Text(logo == null ? 'Upload' : 'Change'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Company name'),
              validator: (v) => (v ?? '').trim().length < 2
                  ? 'Enter your company’s name'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            DropdownButtonFormField<String>(
              initialValue: _industry,
              decoration: const InputDecoration(labelText: 'Industry'),
              items: [
                for (final i in companyIndustries)
                  DropdownMenuItem(value: i, child: Text(i)),
              ],
              onChanged: (v) => setState(() => _industry = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _gstin,
              textCapitalization: TextCapitalization.characters,
              maxLength: 15,
              decoration: const InputDecoration(
                labelText: 'GSTIN (optional, for invoices)',
                counterText: '',
              ),
              validator: (v) {
                final g = (v ?? '').trim().toUpperCase();
                if (g.isEmpty) return null;
                return RegExp(
                      r'^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][1-9A-Z]Z[0-9A-Z]$',
                    ).hasMatch(g)
                    ? null
                    : 'That GSTIN doesn’t look right';
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: AppButton(
            label: 'Save',
            loading: _busy,
            onPressed: _busy ? null : _save,
          ),
        ),
      ),
    );
  }
}
