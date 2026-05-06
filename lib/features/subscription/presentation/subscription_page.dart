import 'package:flutter/material.dart';
import 'package:nova3d_frontend/core/theme.dart';
import 'package:nova3d_frontend/features/api_keys/presentation/api_keys_section.dart';

class SubscriptionPage extends StatelessWidget {
  const SubscriptionPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBgDark,
    body: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1000),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: kAccentBlue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: kAccentBlue.withValues(alpha: 0.25),
                  ),
                ),
                child: const Text(
                  'Coming soon',
                  style: TextStyle(
                    color: kAccentBlue,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Subscriptions are coming soon',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For now, Nova3D uses provider keys you already own.',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              const _PlanGrid(),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: kBgSecondary,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderColor),
                ),
                child: const ApiKeysSection(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Plan {
  const _Plan({
    required this.name,
    required this.label,
    required this.description,
    required this.features,
    this.highlighted = false,
    this.accentColor,
  });

  final String name;
  final String label;
  final String description;
  final List<String> features;
  final bool highlighted;
  final Color? accentColor;
}

const _plans = [
  _Plan(
    name: 'Free',
    label: 'Included for now',
    description:
        'Use Nova3D with your own provider key while billing is offline.',
    features: [
      'Bring your own provider key',
      'Text and image inputs',
      'GLB model preview',
      'Local browser key storage',
    ],
  ),
  _Plan(
    name: 'Standard',
    label: 'Coming soon',
    description: 'Higher generation limits and richer export options.',
    highlighted: true,
    accentColor: kAccentBlue,
    features: [
      'Higher monthly limits',
      'Priority generation',
      'GLB + OBJ + STL export',
      'Parametric editing tools',
      'Email support',
    ],
  ),
  _Plan(
    name: 'Pro',
    label: 'Coming soon',
    description: 'A workspace for professional and studio workflows.',
    accentColor: Color(0xFF8B5CF6),
    features: [
      'Team collaboration',
      'Expanded export formats',
      'API access',
      'Advanced model controls',
      'Dedicated support',
    ],
  ),
];

class _PlanGrid extends StatelessWidget {
  const _PlanGrid();

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 760;
    if (isMobile) {
      return Column(
        children: _plans
            .map(
              (plan) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _PlanCard(plan: plan),
              ),
            )
            .toList(),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _plans
          .map(
            (plan) => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: _PlanCard(plan: plan),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PlanCard extends StatefulWidget {
  const _PlanCard({required this.plan});
  final _Plan plan;

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final accent = plan.accentColor ?? kBorderColor;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: kBgSecondary,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: plan.highlighted
                ? accent
                : _hovering
                ? kTextMuted
                : kBorderColor,
            width: plan.highlighted ? 1.5 : 1,
          ),
          boxShadow: plan.highlighted
              ? [
                  BoxShadow(
                    color: accent.withValues(alpha: 0.15),
                    blurRadius: 24,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (plan.highlighted)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Planned',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            Text(
              plan.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: plan.accentColor ?? kTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan.label,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              plan.description,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            const Divider(color: kBorderColor),
            const SizedBox(height: 18),
            ...plan.features.map(
              (feature) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: plan.accentColor ?? kSuccessGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature,
                        style: const TextStyle(
                          color: kTextSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: null,
                child: Text(plan.name == 'Free' ? 'Active' : 'Coming soon'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
