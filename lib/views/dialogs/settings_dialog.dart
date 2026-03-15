// Widget that displays the settings panel (slides in from right)
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/settings.dart';
import '../../managers/settings_manager.dart';
import '../../managers/photo_manager.dart';
import '../../managers/tag_manager.dart';
import '../../managers/quick_move_manager.dart';
import '../widgets/keyboard_shortcuts_guide.dart';
import 'tag_dialogs.dart';
import 'quick_move_dialogs.dart';

class SettingsPanel extends StatelessWidget {
  final VoidCallback onClose;
  const SettingsPanel({super.key, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E1E),
        border: Border(
          left: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPanelHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const KeyboardShortcutsGuide(),
                  const SizedBox(height: 16),
                  _buildItemSizeSection(),
                  const SizedBox(height: 16),
                  _buildGridAspectSection(),
                  const SizedBox(height: 16),
                  _buildTagManagementSection(context),
                  const SizedBox(height: 16),
                  _buildQuickMoveSection(context),
                  const SizedBox(height: 16),
                  _buildViewedStatusSection(context),
                  const SizedBox(height: 16),
                  _buildDataManagementSection(context),
                  const SizedBox(height: 16),
                  _buildResetSection(context),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPanelHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(
          bottom: BorderSide(color: Color(0xFF2A2A2A), width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.settings, color: Colors.white70, size: 18),
          const SizedBox(width: 10),
          const Text(
            'Settings',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: onClose,
              child: const Padding(
                padding: EdgeInsets.all(6.0),
                child: Icon(Icons.close, color: Colors.white54, size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, [Color? iconColor]) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor ?? Colors.white70),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemSizeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Item Size', Icons.photo_size_select_large),
        Consumer<SettingsManager>(
          builder: (context, settingsManager, child) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF252525),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Text('50', style: TextStyle(fontSize: 11, color: Colors.white38)),
                      Expanded(
                        child: SliderTheme(
                          data: SliderThemeData(
                            trackHeight: 3,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                            activeTrackColor: Colors.blue,
                            inactiveTrackColor: const Color(0xFF383838),
                            thumbColor: Colors.blue,
                            overlayColor: Colors.blue.withAlpha(30),
                          ),
                          child: Slider(
                            value: settingsManager.itemSize,
                            min: 50.0,
                            max: 600.0,
                            divisions: 11,
                            onChanged: (value) {
                              settingsManager.setItemSize(value);
                            },
                          ),
                        ),
                      ),
                      const Text('600', style: TextStyle(fontSize: 11, color: Colors.white38)),
                    ],
                  ),
                  Text(
                    '${settingsManager.itemSize.toInt()} px',
                    style: const TextStyle(fontSize: 12, color: Colors.white54),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildGridAspectSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Grid Aspect Mode', Icons.aspect_ratio),
        Consumer<SettingsManager>(
          builder: (context, settingsManager, child) {
            return SizedBox(
              width: double.infinity,
              child: SegmentedButton<GridAspectMode>(
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.blue.withAlpha(40);
                    }
                    return const Color(0xFF252525);
                  }),
                  foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                    if (states.contains(WidgetState.selected)) {
                      return Colors.blue;
                    }
                    return Colors.white54;
                  }),
                  side: WidgetStateProperty.all(
                    const BorderSide(color: Color(0xFF383838)),
                  ),
                  shape: WidgetStateProperty.all(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  textStyle: WidgetStateProperty.all(
                    const TextStyle(fontSize: 12),
                  ),
                ),
                segments: const [
                  ButtonSegment(value: GridAspectMode.square, label: Text('Kare')),
                  ButtonSegment(value: GridAspectMode.portrait, label: Text('Dikey')),
                  ButtonSegment(value: GridAspectMode.landscape, label: Text('Yatay')),
                ],
                selected: {settingsManager.gridAspectMode},
                onSelectionChanged: (Set<GridAspectMode> newSelection) {
                  settingsManager.setGridAspectMode(newSelection.first);
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildTagManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.label, size: 15, color: Colors.white70),
            const SizedBox(width: 8),
            const Text(
              'Tag Management',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const Spacer(),
            SizedBox(
              height: 28,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => showDialog(context: context, builder: (_) => const AddTagDialog()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Consumer<TagManager>(
          builder: (context, tagManager, child) {
            final tags = tagManager.tags;
            if (tags.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No tags created yet',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              children: tags.map((tag) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: tag.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tag.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              tag.shortcutKey.keyLabel,
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                          padding: EdgeInsets.zero,
                          onPressed: () => showDialog(context: context, builder: (_) => EditTagDialog(tag: tag)),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          onPressed: () => tagManager.deleteTag(tag),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuickMoveSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.drive_file_move, size: 15, color: Colors.white70),
            const SizedBox(width: 8),
            const Text(
              'Quick Move',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white),
            ),
            const Spacer(),
            SizedBox(
              height: 28,
              child: TextButton.icon(
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add', style: TextStyle(fontSize: 12)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
                onPressed: () => showDialog(context: context, builder: (_) => const AddQuickMoveDialog()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Consumer<QuickMoveManager>(
          builder: (context, quickMoveManager, child) {
            final destinations = quickMoveManager.destinations;
            if (destinations.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF252525),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'No quick move destinations created yet',
                  style: TextStyle(color: Colors.white38, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              );
            }
            return Column(
              children: destinations.map((dest) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF252525),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: dest.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dest.name,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                            Text(
                              dest.path,
                              style: const TextStyle(fontSize: 11, color: Colors.white38),
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              dest.shortcutKey.keyLabel,
                              style: const TextStyle(fontSize: 10, color: Colors.white30),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.edit, size: 14, color: Colors.white54),
                          padding: EdgeInsets.zero,
                          onPressed: () => showDialog(context: context, builder: (_) => EditQuickMoveDialog(destination: dest)),
                        ),
                      ),
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: IconButton(
                          icon: const Icon(Icons.delete_outline, size: 14, color: Colors.white38),
                          padding: EdgeInsets.zero,
                          onPressed: () => quickMoveManager.deleteDestination(dest),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildViewedStatusSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Viewed Status', Icons.visibility),
        Consumer2<SettingsManager, PhotoManager>(
          builder: (context, settingsManager, photoManager, child) {
            return SizedBox(
              width: double.infinity,
              height: 36,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.refresh, size: 15),
                label: const Text('Clear viewed status (mark all as NEW)', style: TextStyle(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF252525),
                  foregroundColor: Colors.white70,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                onPressed: () async {
                  final cleared = await settingsManager.clearViewedStatus();
                  photoManager.refresh();
                  if (!context.mounted) return;
                  if (cleared >= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Cleared viewed status for $cleared photos'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Failed to clear viewed status'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagementSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Data Management', Icons.storage),
        Consumer<SettingsManager>(
          builder: (context, settingsManager, child) {
            return Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.file_download, size: 15),
                      label: const Text('Export', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF252525),
                        foregroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        final result = await settingsManager.exportData();
                        if (result && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Data exported successfully'), backgroundColor: Colors.green),
                          );
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to export data'), backgroundColor: Colors.red),
                          );
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 36,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.file_upload, size: 15),
                      label: const Text('Import', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF252525),
                        foregroundColor: Colors.white70,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () async {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Import Data', style: TextStyle(fontSize: 16)),
                            content: const Text(
                              'This will replace all your existing data with the imported data. Continue?',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  Navigator.pop(context);
                                  final result = await settingsManager.importData();
                                  if (result && context.mounted) {
                                    showDialog(
                                      context: context,
                                      barrierDismissible: false,
                                      builder: (context) => AlertDialog(
                                        backgroundColor: const Color(0xFF1E1E1E),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        title: const Text('Import Successful', style: TextStyle(fontSize: 16)),
                                        content: const Text(
                                          'Data has been imported successfully. The application will now close. Please restart the application to see the changes.',
                                          style: TextStyle(fontSize: 13, color: Colors.white70),
                                        ),
                                        actions: [
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.blue,
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                            ),
                                            onPressed: () => exit(0),
                                            child: const Text('Close Application'),
                                          ),
                                        ],
                                      ),
                                    );
                                  } else if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Failed to import data or import cancelled'), backgroundColor: Colors.red),
                                    );
                                  }
                                },
                                child: const Text('Import'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildResetSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader('Reset Application', Icons.warning_amber_rounded, Colors.red),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.withAlpha(40)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'This will delete all your data including folders, photos, tags, and settings. This action cannot be undone.',
                style: TextStyle(color: Colors.red, fontSize: 11),
              ),
              const SizedBox(height: 10),
              Consumer<SettingsManager>(
                builder: (context, settingsManager, child) {
                  return SizedBox(
                    width: double.infinity,
                    height: 34,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete_forever, size: 15),
                      label: const Text('Reset All Data', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withAlpha(40),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: const Color(0xFF1E1E1E),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            title: const Text('Reset All Data?', style: TextStyle(fontSize: 16)),
                            content: const Text(
                              'This will delete all your data including folders, photos, tags, and settings. The application will close after reset and you will need to restart it. This action cannot be undone.',
                              style: TextStyle(fontSize: 13, color: Colors.white70),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                style: TextButton.styleFrom(foregroundColor: Colors.white54),
                                child: const Text('Cancel'),
                              ),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                                onPressed: () async {
                                  final result = await settingsManager.resetAllData();
                                  if (result) {
                                    if (context.mounted) {
                                      showDialog(
                                        context: context,
                                        barrierDismissible: false,
                                        builder: (context) => AlertDialog(
                                          backgroundColor: const Color(0xFF1E1E1E),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          title: const Text('Reset Complete', style: TextStyle(fontSize: 16)),
                                          content: const Text(
                                            'All data has been reset. The application will now close. Please restart the application.',
                                            style: TextStyle(fontSize: 13, color: Colors.white70),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.blue,
                                                foregroundColor: Colors.white,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                              ),
                                              onPressed: () => exit(0),
                                              child: const Text('Close Application'),
                                            ),
                                          ],
                                        ),
                                      );
                                    }
                                  } else {
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('Failed to reset data. Please try again.'), backgroundColor: Colors.red),
                                      );
                                    }
                                  }
                                },
                                child: const Text('Reset', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
