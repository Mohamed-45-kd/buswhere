import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../state/app_state.dart';
import '../../widgets/core.dart';

class CityScreen extends StatefulWidget {
  const CityScreen({super.key});
  @override
  State<CityScreen> createState() => _CityScreenState();
}

class _CityScreenState extends State<CityScreen> {
  String? _city;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    // Active cities first, last choice on top.
    final cities = [...live.cities]..sort((a, b) {
        if (a.id == app.cityId) return -1;
        if (b.id == app.cityId) return 1;
        return (b.isActive ? 1 : 0) - (a.isActive ? 1 : 0);
      });
    final city = _city ?? app.cityId ?? cities.firstWhere((c) => c.isActive, orElse: () => cities.first).id;
    final districts = live.districtsOf(city);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          BWTopBar(title: app.t('Magaalada iyo degmada', 'City and district'), subtitle: app.sub('Magaalada iyo degmada', 'City and district'), onBack: () => context.go('/')),
          const StepBar(1),
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [
              SectionLabel(app.t('Magaalo', 'City'), app.sub('Magaalo', 'City')),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final c in cities)
                  BWTag(
                    '${app.en ? c.nameEn : c.nameSo}${c.isActive ? '' : app.t(' · Dhowaan', ' · Soon')}',
                    selected: c.id == city && c.isActive,
                    disabled: !c.isActive,
                    onTap: () => setState(() => _city = c.id),
                  ),
              ]),
              const SizedBox(height: 16),
              SectionLabel(app.t('Degmo', 'District'), app.sub('Degmo', 'District')),
              const SizedBox(height: 8),
              BWCard(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (final (i, d) in districts.indexed)
                    BWListItem(
                      icon: 'map',
                      tone: d.isActive ? Tone.yellow : Tone.neutral,
                      title: d.name,
                      subtitle: d.isActive
                          ? app.t('${live.villagesOf(d.id).length} tuulo · ${live.villagesOf(d.id).length} villages', '${live.villagesOf(d.id).length} villages · ${live.villagesOf(d.id).length} tuulo')
                          : app.t('Dhowaan · Coming soon', 'Coming soon · Dhowaan'),
                      chevron: d.isActive,
                      dim: !d.isActive,
                      divider: i < districts.length - 1,
                      trailing: d.isActive ? BWBadge(app.t('Toos', 'Live'), tone: BadgeTone.live, dot: true, small: true) : null,
                      onTap: d.isActive
                          ? () {
                              app.setDistrict(city, d.id);
                              context.go('/rider/from');
                            }
                          : null,
                    ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}
