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
          trailing: IconButton(
            icon: Icon(
              Icons.edit_outlined,
              color: isDark ? Colors.white54 : Colors.black45,
              size: 22 * scale,
            ),
            onPressed: () => _showAddProfileDialog(context, profile),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.read<AppPreferencesNotifier>();
    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final urlCtrl = TextEditingController(text: existing?.baseUrl ?? 'http://localhost:8642/v1');
    final modelCtrl = TextEditingController(text: existing?.modelName ?? '');

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(existing != null ? 'Edit Profile' : 'Add LLM Profile'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Profile Name',
                    hintText: 'e.g. Hermes, Local Ollama',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Base URL',
                    hintText: 'e.g. http://localhost:8642/v1',
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Model Name',
                    hintText: 'e.g. qwen3-30b-a3b-instruct',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameCtrl.text.trim();
                final url = urlCtrl.text.trim();
                final model = modelCtrl.text.trim();
                if (name.isEmpty || url.isEmpty || model.isEmpty) return;

                if (existing != null) {
                  settings.updateLlmProfile(existing.copyWith(
                    name: name,
                    baseUrl: url,
                    modelName: model,
                  ));
                } else {
                  final profile = LlmProfile(
                    id: const Uuid().v4(),
                    name: name,
                    baseUrl: url,
                    modelName: model,
                  );
                  settings.addLlmProfile(profile);
                  // If this is the first profile, make it active
                  if (settings.llmProfiles.length == 1) {
                    settings.setActiveProfileId(profile.id);
                  }
                }
                Navigator.pop(ctx);
              },
              child: Text(existing != null ? 'Save' : 'Add'),
            ),
          ],
        );
      },
    );
  }
}
