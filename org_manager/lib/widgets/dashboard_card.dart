import 'package:flutter/material.dart';
import '../utils/responsive_breakpoints.dart';
import 'responsive_layout.dart';

class DashboardCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const DashboardCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ResponsiveCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(
            ResponsiveBreakpoints.getSpacing(context, mobile: 16, tablet: 20, desktop: 24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: ResponsiveBreakpoints.getSpacing(context, mobile: 32, tablet: 40, desktop: 48),
                color: color,
              ),
              ResponsiveSpacing(
                mobile: ResponsiveBreakpoints.getSpacing(context, mobile: 8, tablet: 12, desktop: 16),
              ),
              ResponsiveText(
                title,
                baseFontSize: 16,
                tabletFontSize: 18,
                desktopFontSize: 20,
                style: const TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              ResponsiveSpacing(
                mobile: ResponsiveBreakpoints.getSpacing(context, mobile: 4, tablet: 6, desktop: 8),
              ),
              ResponsiveText(
                subtitle,
                baseFontSize: 14,
                tabletFontSize: 15,
                desktopFontSize: 16,
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}