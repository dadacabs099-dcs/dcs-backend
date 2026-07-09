import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Container/Services/translation_service.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark;
    final currentLang = ref.watch(appLanguageProvider);

    return HeritageBackgroundWrapper(
      pageName: 'settings',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: IndianHeritageColors.primaryYellow,
          foregroundColor: IndianHeritageColors.charcoal,
          title: const TranslatedText(
            'Settings',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 20,
              color: IndianHeritageColors.charcoal,
            ),
          ),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TranslatedText(
                'Preferences',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'bold',
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                title: TranslatedText(
                  'App notifications',
                  style: TextStyle(
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
                subtitle: const TranslatedText('Receive alerts for rides and promotions'),
                value: _notificationsEnabled,
                activeColor: IndianHeritageColors.primaryYellow,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                title: TranslatedText(
                  'App Language',
                  style: TextStyle(
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
                subtitle: Text(
                  indianLanguages[currentLang] ?? 'English',
                  style: const TextStyle(color: Colors.grey),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: isDark ? Colors.grey : IndianHeritageColors.charcoal,
                ),
                onTap: () {
                  _showLanguagePicker(context, ref, isDark);
                },
              ),
              const SizedBox(height: 24),
              TranslatedText(
                'Support',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontFamily: 'bold',
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.help_outline, color: IndianHeritageColors.primaryYellow),
                title: TranslatedText(
                  'Help & Support',
                  style: TextStyle(
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
                subtitle: const TranslatedText('View FAQs or contact customer care'),
                trailing: Icon(
                  Icons.arrow_forward_ios, 
                  size: 16,
                  color: isDark ? Colors.grey : IndianHeritageColors.charcoal,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: TranslatedText('Support contact coming soon.')),
                  );
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: isDark ? Colors.grey[800]! : Colors.grey[400]!,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context, WidgetRef ref, bool isDark) {
    final currentLang = ref.read(appLanguageProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
                child: TranslatedText(
                  "Select Language",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    fontFamily: 'bold',
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: indianLanguages.length,
                  itemBuilder: (context, index) {
                    final code = indianLanguages.keys.elementAt(index);
                    final name = indianLanguages.values.elementAt(index);
                    final isSelected = currentLang == code;

                    return ListTile(
                      title: Text(
                        name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected 
                              ? IndianHeritageColors.primaryYellow 
                              : (isDark ? Colors.white : IndianHeritageColors.charcoal),
                        ),
                      ),
                      trailing: isSelected 
                          ? const Icon(Icons.check_circle_rounded, color: IndianHeritageColors.primaryYellow) 
                          : null,
                      onTap: () {
                        ref.read(appLanguageProvider.notifier).setLanguage(code);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
