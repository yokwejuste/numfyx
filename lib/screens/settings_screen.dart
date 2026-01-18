import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/backup_service.dart';
import '../services/csv_export_service.dart';
import '../services/pdf_export_service.dart';
import '../services/restore_service.dart';
import '../services/settings_service.dart';
import '../services/theme_service.dart';
import '../widgets/common_widgets.dart';
import 'home_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _region = 'CM';
  bool _isSaving = false;
  bool _isGenerating = false;
  int _csvThreshold = 2500;
  bool _isSavingThreshold = false;
  List<BackupSession> _backups = [];
  bool _isLoadingBackups = false;
  bool _isRestoring = false;

  final Map<String, String> _countries = {
    'CM': 'Cameroon',
    'FR': 'France',
    'US': 'United States',
    'GB': 'United Kingdom',
    'DE': 'Germany',
    'IT': 'Italy',
    'ES': 'Spain',
    'CA': 'Canada',
    'NG': 'Nigeria',
    'GH': 'Ghana',
    'KE': 'Kenya',
    'ZA': 'South Africa',
    'EG': 'Egypt',
    'MA': 'Morocco',
    'TN': 'Tunisia',
    'DZ': 'Algeria',
    'CI': 'Ivory Coast',
    'SN': 'Senegal',
  };

  @override
  void initState() {
    super.initState();
    _loadRegion();
    _loadCsvThreshold();
    _loadBackups();
  }

  Future<void> _loadRegion() async {
    final region = await SettingsService.getDefaultRegion();
    setState(() {
      _region = region;
    });
  }

  Future<void> _saveRegion(String value) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSaving = true);
    await SettingsService.setDefaultRegion(value);
    setState(() {
      _region = value;
      _isSaving = false;
    });

    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Default region set to ${_countries[value]}'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _loadCsvThreshold() async {
    final t = await SettingsService.getCsvThreshold();
    setState(() {
      _csvThreshold = t;
    });
  }

  Future<void> _saveCsvThreshold(int value) async {
    final theme = Theme.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSavingThreshold = true);
    await SettingsService.setCsvThreshold(value);
    setState(() {
      _csvThreshold = value;
      _isSavingThreshold = false;
    });
    if (mounted) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('CSV threshold saved: $value'),
          backgroundColor: theme.colorScheme.primary,
        ),
      );
    }
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoadingBackups = true);
    final backups = await BackupService.getBackups();
    setState(() {
      _backups = backups;
      _isLoadingBackups = false;
    });
  }

  Future<void> _restoreFromBackup(BackupSession backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Contacts'),
        content: Text(
          'This will revert ${backup.totalChanges} phone number changes made on ${backup.formattedDate}.\n\nAre you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.tertiary),
            child: const Text('Restore'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _isRestoring = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: Text(
                'Restoring contacts...',
                style: TextStyle(color: Theme.of(dialogContext).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );

    final result = await RestoreService.restoreFromBackup(backup);

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }

    setState(() => _isRestoring = false);

    if (!mounted) return;

    if (result.restored > 0) {
      await BackupService.deleteBackup(backup.id);
      await _loadBackups();
    }

    if (!mounted) return;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(result.restored > 0 ? 'Restore Complete' : 'Restore Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Restored: ${result.restored}'),
            Text('Failed: ${result.failed}'),
            Text('Not found: ${result.notFound}'),
            if (result.restored > 0) ...[
              const SizedBox(height: 8),
              const Text('Backup has been removed.', style: TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteBackup(BackupSession backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Backup'),
        content: Text('Delete backup from ${backup.formattedDate}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await BackupService.deleteBackup(backup.id);
    await _loadBackups();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Backup deleted')),
      );
    }
  }

  Future<void> _downloadReport() async {
    if (HomeScreen.lastResults.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'No processing results available. Process contacts first.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    setState(() {
      _isGenerating = true;
    });
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: SizedBox(
          width: 64,
          height: 64,
          child: CircularProgressIndicator(),
        ),
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final navigator = Navigator.of(context, rootNavigator: true);

    final path = await PdfExportService.exportToPdf(
      HomeScreen.lastResults,
      onlyIncludeUpdated: true,
    );

    if (mounted) navigator.pop();
    setState(() {
      _isGenerating = false;
    });

    if (!mounted) return;
    if (path != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('PDF saved: ${path.split('/').last}'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: theme.colorScheme.onPrimary,
            onPressed: () async {
              try {
                await OpenFilex.open(path);
                return;
              } catch (e) {
                debugPrint(
                  'OpenFilex.open failed: $e; falling back to launchUrl',
                );
              }
              try {
                final uri = Uri.file(path);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                  return;
                }
              } catch (e) {
                debugPrint('launchUrl fallback failed: $e');
              }
              try {
                await Share.shareXFiles([XFile(path)], text: 'NumFyx report');
                return;
              } catch (e) {
                debugPrint('Share.shareXFiles failed: $e');
              }

              messenger.showSnackBar(
                SnackBar(
                  content: const Text('Unable to open file'),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            },
          ),
        ),
      );
    } else {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('PDF generation failed'),
            content: const Text(
              'Could not generate the PDF. Check storage permission and available space.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('OK'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  _downloadReport();
                },
                child: const Text('Retry'),
              ),
              if (kDebugMode)
                TextButton(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    final messenger = ScaffoldMessenger.of(context);
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Check logs for details (debug).'),
                      ),
                    );
                  },
                  child: const Text('Why failed'),
                ),
            ],
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeService = Provider.of<ThemeService>(context);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppHeader(
              title: 'Settings',
              logoPath: 'assets/logo/logo_96.png',
            ),
            const SizedBox(height: 32),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowColor.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      theme.brightness == Brightness.dark ? Icons.dark_mode : Icons.light_mode,
                      color: theme.colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Dark Mode',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          theme.brightness == Brightness.dark ? 'Dark theme active' : 'Light theme active',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: theme.brightness == Brightness.dark,
                    onChanged: (value) => themeService.toggleTheme(),
                    activeThumbColor: theme.colorScheme.primary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.public,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Default Country Region',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'For phone numbers without country code',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                    ),
                    child: DropdownButton<String>(
                      value: _region,
                      isExpanded: true,
                      underline: const SizedBox(),
                      dropdownColor: theme.cardColor,
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      items: _countries.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text('${entry.value} (${entry.key})'),
                        );
                      }).toList(),
                      onChanged: _isSaving
                          ? null
                          : (v) {
                              if (v != null) {
                                _saveRegion(v);
                              }
                            },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.picture_as_pdf,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PDF Report',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Generate report from last processing',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating ? null : _downloadReport,
                          icon: const Icon(Icons.download, size: 18),
                          label: const Text('Download Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _isGenerating
                              ? null
                              : () async {
                                  final messenger = ScaffoldMessenger.of(
                                    context,
                                  );
                                  final localTheme = Theme.of(context);
                                  final navigator = Navigator.of(
                                    context,
                                    rootNavigator: true,
                                  );
                                  if (HomeScreen.lastResults.isEmpty) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text(
                                          'No processing results available.',
                                        ),
                                        backgroundColor:
                                            localTheme.colorScheme.primary,
                                      ),
                                    );
                                    return;
                                  }
                                  setState(() {
                                    _isGenerating = true;
                                  });
                                  showDialog<void>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder: (_) => const Center(
                                      child: SizedBox(
                                        width: 64,
                                        height: 64,
                                        child: CircularProgressIndicator(),
                                      ),
                                    ),
                                  );
                                  final path = await CsvExportService.exportToCsv(
                                    HomeScreen.lastResults,
                                  );
                                  if (mounted) {
                                    navigator.pop();
                                  }
                                  setState(() {
                                    _isGenerating = false;
                                  });
                                  if (!mounted) return;
                                  if (path != null) {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'CSV saved: ${path.split('/').last}',
                                        ),
                                        backgroundColor:
                                            localTheme.colorScheme.primary,
                                        duration: const Duration(seconds: 4),
                                        action: SnackBarAction(
                                          label: 'Open',
                                          textColor: theme.colorScheme.onPrimary,
                                          onPressed: () async {
                                            try {
                                              await OpenFilex.open(path);
                                              return;
                                            } catch (e) {
                                              debugPrint(
                                                'OpenFilex.open failed: $e; falling back to launchUrl',
                                              );
                                            }
                                            try {
                                              final uri = Uri.file(path);
                                              if (await canLaunchUrl(uri)) {
                                                await launchUrl(
                                                  uri,
                                                  mode: LaunchMode
                                                      .externalApplication,
                                                );
                                                return;
                                              }
                                            } catch (e) {
                                              debugPrint(
                                                'launchUrl fallback failed: $e',
                                              );
                                            }

                                            messenger.showSnackBar(
                                              SnackBar(
                                                content: const Text(
                                                  'Unable to open file',
                                                ),
                                                backgroundColor: localTheme.colorScheme.error,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      SnackBar(
                                        content: const Text('CSV export failed'),
                                        backgroundColor: localTheme.colorScheme.error,
                                      ),
                                    );
                                  }
                                },
                          icon: const Icon(Icons.table_chart, size: 18),
                          label: const Text('Export as CSV'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.file_download,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CSV Threshold',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'If results exceed this number, exporter will fallback to CSV.',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          initialValue: '$_csvThreshold',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                          ),
                          onChanged: (v) {
                            final parsed = int.tryParse(v) ?? _csvThreshold;
                            _csvThreshold = parsed;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isSavingThreshold
                            ? null
                            : () {
                                final v = _csvThreshold.clamp(100, 100000);
                                _saveCsvThreshold(v);
                              },
                        child: _isSavingThreshold
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Save'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.restore,
                          color: theme.colorScheme.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restore Contacts',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Revert changes from previous runs',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.secondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _isLoadingBackups ? null : _loadBackups,
                        icon: _isLoadingBackups
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.refresh, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_backups.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          'No backups available',
                          style: TextStyle(
                            color: theme.colorScheme.secondary,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    )
                  else
                    ...List.generate(_backups.length, (index) {
                      final backup = _backups[index];
                      return Container(
                        margin: EdgeInsets.only(bottom: index < _backups.length - 1 ? 8 : 0),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    backup.formattedDate,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${backup.totalChanges} changes (${backup.region})',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.secondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: _isRestoring ? null : () => _restoreFromBackup(backup),
                              icon: const Icon(Icons.restore, size: 20),
                              tooltip: 'Restore',
                            ),
                            IconButton(
                              onPressed: _isRestoring ? null : () => _deleteBackup(backup),
                              icon: Icon(Icons.delete_outline, size: 20, color: theme.colorScheme.error),
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'About NumFyx',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '• Offline contact formatter\n• E.164 international format\n• No data collection\n• Version 1.2.4',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.colorScheme.secondary,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}
