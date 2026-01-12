import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/contact_result.dart';
import '../services/contact_processing_service.dart';
import '../services/excel_service.dart';
import '../services/phone_formatter_service.dart';
import '../services/settings_service.dart';
import '../widgets/buttons.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static List<ContactResult> lastResults = [];

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isProcessing = false;
  bool _hasPermission = false;
  double _progress = 0.0;
  bool _isGenerating = false;

  int _totalContacts = 0;
  int _contactsWithoutPhones = 0;
  int _scannedNumbers = 0;
  int _updatedNumbers = 0;
  int _skippedNumbers = 0;
  int _failedNumbers = 0;

  String _statusMessage = 'Ready to format contacts';
  String _currentRegion = 'CM';
  final List<ContactResult> _results = [];
  final List<String> _logMessages = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    await _checkPermission();
    await _loadRegion();
  }

  Future<void> _loadRegion() async {
    final region = await SettingsService.getDefaultRegion();
    setState(() {
      _currentRegion = region;
    });
  }

  Future<void> _checkPermission() async {
    final status = await Permission.contacts.status;
    setState(() {
      _hasPermission = status.isGranted;
      if (!_hasPermission) {
        _statusMessage = 'Contacts permission required';
      }
    });
  }

  Future<void> _requestPermission() async {
    final status = await Permission.contacts.request();
    setState(() {
      _hasPermission = status.isGranted;
      if (_hasPermission) {
        _statusMessage = 'Permission granted. Ready to format contacts';
      } else {
        _statusMessage = 'Permission denied. Cannot access contacts';
      }
    });
  }

  void _addLog(String message) {
    setState(() {
      _logMessages.add(message);
      if (_logMessages.length > 50) {
        _logMessages.removeAt(0);
      }
    });
  }

  Future<void> _previewAndConfirmProcessing() async {
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return const Center(
          child: SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(),
          ),
        );
      },
    );

    List<Contact> contacts;
    try {
      contacts = await FlutterContacts.getContacts(
        withProperties: true,
        withPhoto: false,
        withAccounts: false,
      );

      final preview = await ContactProcessingService.computePreview(
        contacts,
        _currentRegion,
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      final skip = await Navigator.of(context).push<Set<String>?>(
        MaterialPageRoute(
          builder: (_) => _PreviewScreen(
            contacts: contacts,
            region: _currentRegion,
            servicePreview: preview,
          ),
        ),
      );
      if (skip != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _processContacts(contacts, skip);
        });
      }
      return;
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      _addLog('Error loading/previewing contacts: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load/preview contacts: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }
  }

  Future<void> _processContacts([
    List<Contact>? contactsParam,
    Set<String>? skipSet,
  ]) async {
    if (!_hasPermission) {
      await _requestPermission();
      return;
    }

    await _loadRegion();

    setState(() {
      _isProcessing = true;
      _progress = 0.0;
      _totalContacts = 0;
      _contactsWithoutPhones = 0;
      _scannedNumbers = 0;
      _updatedNumbers = 0;
      _skippedNumbers = 0;
      _failedNumbers = 0;
      _statusMessage = 'Loading contacts...';
      _results.clear();
      _logMessages.clear();
    });

    _addLog('Starting contact processing...');
    _addLog('Using region: $_currentRegion');
    try {
      final contacts =
          contactsParam ??
          await FlutterContacts.getContacts(
            withProperties: true,
            withPhoto: true,
            withAccounts: true,
          );

      final result = await ContactProcessingService.processContacts(
        contacts,
        _currentRegion,
        skipSet: skipSet,
        onProgress: (p) => setState(() {
          _progress = p;
        }),
        onLog: (m) => _addLog(m),
      );

      setState(() {
        _isProcessing = false;
        _progress = 1.0;
        _statusMessage = 'Completed successfully';
        _results.clear();
        _results.addAll(result.results);
        _totalContacts = result.totalProcessed;
        _updatedNumbers = result.updated;
        _skippedNumbers = result.skipped;
        _failedNumbers = result.failed;
      });

      HomeScreen.lastResults = List.from(_results);
      _addLog('Processing complete. Generate report from Settings.');
    } catch (e) {
      setState(() {
        _statusMessage = 'Error: ${e.toString()}';
        _isProcessing = false;
      });
      _addLog('Error: ${e.toString()}');
      debugPrint('\nERROR: ${e.toString()}');
    }
  }

  void _resetStats() {
    setState(() {
      _progress = 0.0;
      _totalContacts = 0;
      _contactsWithoutPhones = 0;
      _scannedNumbers = 0;
      _updatedNumbers = 0;
      _skippedNumbers = 0;
      _failedNumbers = 0;
      _statusMessage = 'Ready to format contacts';
      _results.clear();
      _logMessages.clear();
    });
  }

  Future<void> _downloadReportFromHome() async {
    if (_results.isEmpty) {
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

    String? path;
    try {
      path = await ExcelService.exportResults(_results);
    } catch (e) {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _isGenerating = false;
      });
      _addLog('Failed to generate report: ${e.toString()}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate report: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
      setState(() {
        _isGenerating = false;
      });
    }

    if (!mounted) return;
    final theme = Theme.of(context);
    if (path != null) {
      _addLog('Report saved to $path');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report saved: ${path.split('/').last}'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 5),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () { _openFile(path); },
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to generate PDF report'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _openFile(String filePath) async {
    try {
      final uri = Uri.file(filePath);
      // Try launching externally; some platforms may not support canLaunch for file URIs
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      } catch (_) {
        // fallback to plain launch
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
          return;
        }
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open file'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to open file: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/logo_96.png',
                    width: 32,
                    height: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'NumFyx',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Text(
                        'Region: $_currentRegion',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

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
                  Icon(
                    _hasPermission ? Icons.check_circle : Icons.info_outline,
                    color: _hasPermission ? Colors.green : Colors.orange,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_isProcessing) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      height: 120,
                      alignment: Alignment.center,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          Icon(
                            Icons.phone_android,
                            size: 36,
                            color: theme.colorScheme.primary,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _progress,
                        backgroundColor: isDark
                            ? Colors.grey[800]
                            : Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          theme.colorScheme.primary,
                        ),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(_progress * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_totalContacts > 0) ...[
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
                    Text(
                      'Statistics',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildStatRow('Contacts', _totalContacts.toString(), theme),
                    _buildStatRow(
                      'Without Phones',
                      _contactsWithoutPhones.toString(),
                      theme,
                    ),
                    _buildStatRow('Scanned', _scannedNumbers.toString(), theme),
                    _buildStatRow('Updated', _updatedNumbers.toString(), theme),
                    _buildStatRow('Skipped', _skippedNumbers.toString(), theme),
                    _buildStatRow('Failed', _failedNumbers.toString(), theme),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],

            if (_logMessages.isNotEmpty) ...[
              Text(
                'Activity Log',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A1A) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListView.builder(
                    itemCount: _logMessages.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Text(
                          _logMessages[index],
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.secondary,
                            fontFamily: 'monospace',
                            height: 1.4,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (!_isProcessing)
              const Spacer(),

            if (!_hasPermission)
              PrimaryButton(
                onPressed: _isProcessing ? null : _requestPermission,
                icon: Icons.check_circle_outline,
                label: 'Grant Permission',
              )
            else
              PrimaryButton(
                onPressed: _isProcessing ? null : _previewAndConfirmProcessing,
                icon: _isProcessing ? Icons.hourglass_empty : Icons.play_arrow,
                label: _isProcessing ? 'Processing...' : 'Start Formatting',
                isLoading: _isProcessing,
              ),

            if (_totalContacts > 0 && !_isProcessing) ...[
              const SizedBox(height: 12),
              SecondaryButton(
                onPressed: _resetStats,
                icon: Icons.refresh,
                label: 'Reset Statistics',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _downloadReportFromHome,
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Download Report'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 13, color: theme.colorScheme.secondary),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? Colors.grey[850]
                  : Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewItem {
  final String contactId;
  final String contactName;
  final String original;
  final String predicted;
  String status;
  bool selected;

  _PreviewItem({
    required this.contactId,
    required this.contactName,
    required this.original,
    required this.predicted,
    required this.status,
    this.selected = true,
  });
}

class _PreviewScreen extends StatefulWidget {
  final List<Contact> contacts;
  final String region;
  final List<ServicePreviewItem>? servicePreview;

  const _PreviewScreen({
    required this.contacts,
    required this.region,
    this.servicePreview,
  });

  @override
  State<_PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<_PreviewScreen> {
  final List<_PreviewItem> _items = [];
  bool _isWorking = true;
  double _progress = 0.0;
  String _filter = 'All';
  bool _fastPreview = false;
  String _search = '';
  final _pageSize = 200;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _computePreview();
  }

  Future<void> _computePreview() async {
    final contacts = widget.contacts;
    final totalContacts = contacts.length;
    int processed = 0;

    if (widget.servicePreview != null) {
      for (final sp in widget.servicePreview!) {
        _items.add(
          _PreviewItem(
            contactId: sp.contactId,
            contactName: sp.contactName,
            original: sp.original,
            predicted: sp.predicted,
            status: sp.status,
            selected: sp.status == 'Will Update',
          ),
        );
      }
      setState(() {
        _progress = 1.0;
        _isWorking = false;
      });
      return;
    }

    for (final contact in contacts) {
      if (!mounted) return;
      final name = contact.displayName.isNotEmpty
          ? contact.displayName
          : 'Unknown';
      if (contact.phones.isEmpty) {
        processed++;
        setState(() {
          _progress = processed / totalContacts;
        });
        continue;
      }

      for (final phone in contact.phones) {
        final orig = phone.number.trim();
        final normalized = orig.replaceAll(RegExp(r'\s+'), '');
        String status;
        String predicted = '';

        if (orig.isEmpty || orig.length < 4) {
          status = 'Will Skip';
          predicted = orig;
        } else if (normalized.startsWith('+') || normalized.startsWith('00')) {
          if (!PhoneFormatterService.isNumberFromRegion(orig, widget.region)) {
            continue;
          }

          if (normalized.startsWith('+')) {
            status = 'Will Skip';
            predicted = orig;
          } else {
            final without00 = normalized.substring(2);
            status = 'Will Update';
            predicted = '+$without00';
          }
        } else {
          final matches = PhoneFormatterService.matchesCountryStructure(
            orig,
            widget.region,
          );
          if (!matches) {
            status = 'Will Fail';
            predicted = 'invalid structure';
          } else {
            if (_fastPreview) {
              status = 'Will Update';
              predicted = 'will attempt E.164';
            } else {
              final formatted = await PhoneFormatterService.formatToE164(
                orig,
                widget.region,
              );
              if (formatted != null && formatted != orig) {
                status = 'Will Update';
                predicted = formatted;
              } else {
                status = 'Will Fail';
                predicted = 'invalid';
              }
            }
          }
        }

        final cid = contact.id;
        _items.add(
          _PreviewItem(
            contactId: cid,
            contactName: name,
            original: orig,
            predicted: predicted,
            status: status,
            selected: status == 'Will Update',
          ),
        );
      }

      processed++;
      if (processed % 5 == 0) {
        setState(() {
          _progress = processed / totalContacts;
        });
        await Future.delayed(Duration(milliseconds: 1));
      }
    }

    if (!mounted) return;
    setState(() {
      _progress = 1.0;
      _isWorking = false;
    });
  }

  List<_PreviewItem> get _filteredItems {
    var list = _items;
    if (_filter != 'All') {
      list = list.where((i) => i.status == _filter).toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = _search.toLowerCase();
      list = list
          .where(
            (i) =>
                i.contactName.toLowerCase().contains(q) ||
                i.original.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final total = _filteredItems.length;
    final start = _page * _pageSize;
    final end = (_page + 1) * _pageSize;
    final pageItems = _filteredItems.skip(start).take(_pageSize).toList();

    final allFilteredSelected =
        _filteredItems.isNotEmpty && _filteredItems.every((i) => i.selected);

    return Scaffold(
      appBar: AppBar(title: const Text('Preview Changes')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Items: ${_items.length}  Filter: $_filter'),
                ),
                if (_isWorking)
                  SizedBox(
                    width: 160,
                    child: LinearProgressIndicator(value: _progress),
                  )
                else
                  Text(
                    'Ready',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                DropdownButton<String>(
                  value: _filter,
                  items: ['All', 'Will Update', 'Will Skip', 'Will Fail']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() {
                      _filter = v;
                      _page = 0;
                    });
                  },
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 200,
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search name or number',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 8,
                      ),
                    ),
                    onChanged: (v) => setState(() {
                      _search = v;
                      _page = 0;
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Page: ${_page + 1} / ${(_filteredItems.length / _pageSize).ceil().clamp(1, 999999)}',
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: end < total ? () => setState(() => _page++) : null,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final it in _filteredItems) {
                        it.selected = !allFilteredSelected;
                      }
                    });
                  },
                  child: Text(
                    allFilteredSelected ? 'Unselect All' : 'Select All',
                  ),
                ),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () {
                    setState(() {
                      for (final it in _filteredItems) {
                        it.selected = false;
                      }
                    });
                  },
                  child: const Text('Clear Selection'),
                ),
                const Spacer(),
                Row(
                  children: [
                    const Text('Fast preview'),
                    Switch(
                      value: _fastPreview,
                      onChanged: (v) {
                        setState(() {
                          _fastPreview = v;
                          _items.clear();
                          _isWorking = true;
                          _progress = 0.0;
                          _computePreview();
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: pageItems.isEmpty
                  ? Center(
                      child: Text(
                        _isWorking ? 'Computing preview...' : 'No items',
                      ),
                    )
                  : ListView.builder(
                      itemCount: pageItems.length,
                      itemBuilder: (context, idx) {
                        final it = pageItems[idx];
                        return CheckboxListTile(
                          value: it.selected,
                          onChanged: (v) {
                            setState(() {
                              it.selected = v ?? false;
                            });
                          },
                          title: Text(it.contactName),
                          subtitle: Text('${it.original} -> ${it.predicted}'),
                          secondary: Text(
                            it.status,
                            style: TextStyle(
                              color: it.status == 'Will Update'
                                  ? Colors.green
                                  : (it.status == 'Will Fail'
                                        ? Colors.red
                                        : Colors.grey),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: () {
                    final navigator = Navigator.of(context);
                    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) navigator.pop(null); });
                  },
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isWorking
                      ? null
                      : () {
                          final skip = <String>{};
                          for (final it in _items) {
                            if (!it.selected) {
                              skip.add('${it.contactId}|${it.original}');
                            }
                          }
                          final navigator = Navigator.of(context);
                          WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) navigator.pop(skip); });
                        },
                  child: const Text('Confirm and Apply'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
