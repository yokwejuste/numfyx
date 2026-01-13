import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/excel_service.dart';
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

    final path = await ExcelService.exportResults(
      HomeScreen.lastResults,
      forcePdf: true,
      onlyIncludeUpdated: true,
    );

    if (mounted) navigator.pop();
    setState(() {
      _isGenerating = false;
    });

    if (!mounted) return;
    if (path != null) {
      final isPdf = path.toLowerCase().endsWith('.pdf');
      final label = isPdf ? 'PDF saved' : 'CSV saved';
      messenger.showSnackBar(
        SnackBar(
          content: Text('$label: ${path.split('/').last}'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
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
                const SnackBar(
                  content: Text('Unable to open file'),
                  backgroundColor: Colors.red,
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
    final isDark = theme.brightness == Brightness.dark;
    final themeService = Provider.of<ThemeService>(context);

    return SafeArea(
      child: Padding(
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
                    color: Colors.black.withValues(alpha: 0.05),
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
                      color: isDark ? Colors.grey[850] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
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
                          isDark ? 'Dark theme active' : 'Light theme active',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: isDark,
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
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
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
                      color: isDark
                          ? const Color(0xFF1A1A1A)
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
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
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
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
                                  final path = await ExcelService.exportCsv(
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
                                          textColor: Colors.white,
                                          onPressed: () async {
                                            // Try OpenFilex first for local files, then fallback to url_launcher
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
                                              const SnackBar(
                                                content: Text(
                                                  'Unable to open file',
                                                ),
                                                backgroundColor: Colors.red,
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('CSV export failed'),
                                        backgroundColor: Colors.red,
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
                          color: isDark ? Colors.grey[850] : Colors.grey[200],
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

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
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
                    '• Offline contact formatter\n• E.164 international format\n• No data collection\n• Version 1.0.0',
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
