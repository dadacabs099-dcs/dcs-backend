import 'package:flutter/material.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/View/Widgets/heritage_background_wrapper.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static final List<Map<String, String>> _notifications = [
    {
      'title': 'Ride confirmed',
      'subtitle': 'Your driver is on the way to pickup.',
      'time': 'Just now',
    },
    {
      'title': 'Promo credit applied',
      'subtitle': '₹50 travel credit added to your wallet.',
      'time': '1h ago',
    },
    {
      'title': 'Safety tip',
      'subtitle': 'Please share your live location with trusted contacts.',
      'time': 'Yesterday',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return HeritageBackgroundWrapper(
      pageName: 'notifications',
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: IndianHeritageColors.saffron,
          title: const Text('Notifications'),
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _notifications.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: IndianHeritageColors.textSecondary,
                        ),
                  ),
                )
              : ListView.separated(
                  itemCount: _notifications.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = _notifications[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: IndianHeritageColors.darkSurface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: IndianHeritageColors.darkCard),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.notifications, color: Colors.blue),
                        title: Text(notification['title'] ?? ''),
                        subtitle: Text(notification['subtitle'] ?? ''),
                        trailing: Text(
                          notification['time'] ?? '',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: IndianHeritageColors.textSecondary,
                              ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}
