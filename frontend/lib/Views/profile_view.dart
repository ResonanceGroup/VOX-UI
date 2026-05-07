import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../Controllers/profile_controller.dart';
import '../models/llm_profile.dart';
import '../models/app_preferences_notifier.dart';
import 'theme_manager.dart';

/// LLM Profiles management view
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => ProfileController(
        preferencesNotifier: context.read<AppPreferencesNotifier>(),
      ),
      child: const _ProfileViewContent(),
    );
  }
}

class _ProfileViewContent extends StatelessWidget {
  const _ProfileViewContent();

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppPreferencesNotifier>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scale = settings.uiScale;
    final profiles = settings.llmProfiles;
    final activeId = settings.activeProfileId;

    return Container(
      color: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      child: Scaffold(
        body: profiles.isEmpty
            ? _buildEmptyState(isDark, scale, context)
            : _buildProfileList(profiles, activeId, isDark, scale, context),
        floatingActionButton: FloatingActionButton(
          onPressed: () => _showAddProfileDialog(context, null),
          tooltip: 'Add LLM Profile',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, double scale, BuildContext context) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32 * scale),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.psychology_outlined,
              size: 80 * scale,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
            SizedBox(height: 24 * scale),
            Text(
              'No LLM Profiles',
              style: TextStyle(
                fontSize: 24 * scale,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            SizedBox(height: 16 * scale),
            Text(
              'Tap + to add your first LLM profile.\nEach profile configures a base URL and model name.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16 * scale,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileList(
    List<LlmProfile> profiles,
    String? activeId,
    bool isDark,
    double scale,
    BuildContext context,
  ) {
    return ListView.builder(
      padding: EdgeInsets.all(16 * scale),
      itemCount: profiles.length,
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final isActive = profile.id == activeId;
        return _buildProfileCard(profile, isActive, isDark, scale, context);
      },
    );
  }

  Widget _buildProfileCard(
    LlmProfile profile,
    bool isActive,
    bool isDark,
    double scale,
    BuildContext context,
  ) {
    final settings = context.read<AppPreferencesNotifier>();

    return Dismissible(
      key: ValueKey(profile.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: 24 * scale),
        color: AppColors.error,
        child: Icon(Icons.delete, color: Colors.white, size: 32 * scale),
      ),
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete Profile?'),
            content: Text('Delete "${profile.name}"? This cannot be undone.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(foregroundColor: AppColors.error),
                child: const Text('Delete'),
              ),
            ],
          ),
        );
      },
      onDismissed: (_) => settings.deleteLlmProfile(profile.id),
      child: Card(
        elevation: isActive ? 4 : 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16 * scale),
          side: BorderSide(
            color: isActive
                ? AppColors.primaryBlue
                : (isDark ? Colors.white12 : Colors.black12),
            width: isActive ? 2 : 1,
          ),
        ),
        color: isDark ? AppColors.cardDark : AppColors.cardLight,
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 20 * scale,
            vertical: 8 * scale,
          ),
          leading: Icon(
            isActive ? Icons.check_circle : Icons.radio_button_unchecked,
            color: isActive ? AppColors.primaryBlue : (isDark ? Colors.white38 : Colors.black38),
            size: 28 * scale,
          ),
          title: Text(
            profile.name,
            style: TextStyle(
              fontSize: 18 * scale,
              fontWeight: FontWeight.w600,
              color: isActive
                  ? AppColors.primaryBlue
                  : (isDark ? Colors.white : Colors.black87),
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4 * scale),
              _buildInfoRow('Model', profile.modelName, isDark, scale),
              SizedBox(height: 2 * scale),
              _buildInfoRow('URL', profile.baseUrl, isDark, scale),
            ],
          ),
          isThreeLine: true,
          onTap: () => settings.setActiveProfileId(profile.id),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  color: isDark ? Colors.white54 : Colors.black45,
                  size: 22 * scale,
                ),
                onPressed: () => _showAddProfileDialog(context, profile),
              ),
              IconButton(
                icon: Icon(
                  Icons.delete_outline,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: 22 * scale,
                ),
                onPressed: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete Profile?'),
                      content: Text('Delete "${profile.name}"?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    settings.deleteLlmProfile(profile.id);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, bool isDark, double scale) {
    return Row(
      children: [
        SizedBox(
          width: 48 * scale,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12 * scale,
              color: isDark ? Colors.white38 : Colors.black38,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13 * scale,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  void _showAddProfileDialog(BuildContext context, LlmProfile? existing) {
    final settings  = context.read<AppPreferencesNotifier>();
    final nameCtrl  = TextEditingController(text: existing?.name ?? '');
    final urlCtrl   = TextEditingController(text: existing?.baseUrl ?? 'http://localhost:8642/v1');
    final modelCtrl = TextEditingController(text: existing?.modelName ?? '');
    final apiKeyCtrl = TextEditingController(text: existing?.apiKey ?? '');

    // Use a bottom sheet instead of a dialog so it naturally pushes above
    // the keyboard on mobile (isScrollControlled + viewInsets padding).
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // allows sheet to resize when keyboard appears
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          // viewInsets.bottom = keyboard height; sheet content floats above it
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle pill
              Center(
                child: Container(
                  width: 40, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black26,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text(
                existing != null ? 'Edit Profile' : 'Add LLM Profile',
                style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameCtrl,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Profile Name',
                  hintText: 'e.g. Hermes, Local Ollama',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: urlCtrl,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  labelText: 'Base URL',
                  hintText: 'e.g. http://localhost:8642/v1',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: modelCtrl,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Model Name',
                  hintText: 'e.g. Qwen3.6-35B-A3B-AWQ',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyCtrl,
                textInputAction: TextInputAction.done,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: 'Leave blank if not required',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  final name  = nameCtrl.text.trim();
                  final url   = urlCtrl.text.trim();
                  final model = modelCtrl.text.trim();
                  if (name.isNotEmpty && url.isNotEmpty && model.isNotEmpty) {
                    _saveProfile(ctx, settings, existing, name, url, model,
                        apiKey: apiKeyCtrl.text.trim());
                  }
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      final name  = nameCtrl.text.trim();
                      final url   = urlCtrl.text.trim();
                      final model = modelCtrl.text.trim();
                      if (name.isEmpty || url.isEmpty || model.isEmpty) return;
                      _saveProfile(ctx, settings, existing, name, url, model,
                          apiKey: apiKeyCtrl.text.trim());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryBlue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(existing != null ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _saveProfile(
    BuildContext ctx,
    AppPreferencesNotifier settings,
    LlmProfile? existing,
    String name, String url, String model, {
    String apiKey = '',
  }) {
    if (existing != null) {
      settings.updateLlmProfile(existing.copyWith(
        name: name, baseUrl: url, modelName: model, apiKey: apiKey,
      ));
    } else {
      final profile = LlmProfile(
        id: const Uuid().v4(),
        name: name, baseUrl: url, modelName: model, apiKey: apiKey,
      );
      settings.addLlmProfile(profile);
      if (settings.llmProfiles.length == 1) {
        settings.setActiveProfileId(profile.id);
      }
    }
    Navigator.pop(ctx);
  }
}
