import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../data/live_service.dart';
import '../../state/app_state.dart';
import '../../theme/tokens.dart';
import '../../widgets/bus_map.dart';
import '../../widgets/core.dart';
import '../../widgets/toast_host.dart';
import '../../widgets/transit.dart';
import 'wait_sheet.dart';

class RiderHome extends StatefulWidget {
  const RiderHome({super.key});
  @override
  State<RiderHome> createState() => _RiderHomeState();
}

class _RiderHomeState extends State<RiderHome> {
  String _tab = 'home';

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final nav = BWBottomNav(
      value: _tab,
      onChange: (t) => setState(() => _tab = t),
      items: [NavItem('home', 'map', app.t('Khariidad', 'Map')), NavItem('settings', 'settings', app.t('Dejinta', 'Settings'))],
    );
    return Scaffold(
      body: SafeArea(bottom: false, child: _tab == 'home' ? const _LiveTab() : const RiderSettings()),
      bottomNavigationBar: nav,
    );
  }
}

class _LiveTab extends StatefulWidget {
  const _LiveTab();
  @override
  State<_LiveTab> createState() => _LiveTabState();
}

class _LiveTabState extends State<_LiveTab> {
  String? _selected;
  bool _mapFailed = false;
  LatLng? _focus; // where to pan the map (GPS fix or a picked stop)

  /// Ask the phone where the rider is, show it on the map, and offer the nearest stop.
  Future<void> _locate(AppState app) async {
    final live = app.live;
    final err = await live.locateRider();
    if (!mounted) return;
    if (err != null) {
      showToast(ToastData(
        switch (err) {
          'denied' => app.t('Goobta waa la diiday. U oggolow BusWhere goobta dejinta browser-ka.', 'Location is blocked. Allow it for BusWhere in your browser settings.'),
          'unsupported' => app.t('Taleefankani goobta ma bixiyo', 'This phone cannot share location'),
          _ => app.t('Goobtaada lama helin. Isku day meel bannaan.', "Couldn't find you. Try again in the open."),
        },
        icon: 'circle-alert',
        tone: ToastTone.danger,
        seconds: 6,
      ));
      return;
    }
    setState(() {
      _focus = live.riderPos;
      _selected = null;
    });
  }

  void _pickStop(AppState app, String stopId) {
    app.setStop(stopId);
    final s = app.live.stopById(stopId);
    setState(() => _focus = s.pos);
    showToast(ToastData(app.t('Joogsigaaga: ${s.name}', 'Your stop: ${s.name}'), icon: 'map-pin', tone: ToastTone.success));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    return ListenableBuilder(
      listenable: live,
      builder: (context, _) {
        final from = live.villageOrNull(app.fromId), to = live.villageOrNull(app.toId);
        if (from == null || to == null) return const SizedBox.shrink();
        final myStop = live.stopOrNull(app.stopId) ?? live.stopsOf(from.id).firstOrNull;
        final here = myStop?.pos ?? from.center;
        final mine = live.myRequest;
        final waiting = mine != null && mine.villageId == from.id && mine.destinationVillageId == to.id;
        final views = live.busesFor(from.id, to.id, myStop?.id);
        final matching = views.where((v) => v.matching).toList();
        final others = views.where((v) => !v.matching).toList();
        final sel = views.where((v) => v.live.busId == _selected).firstOrNull ?? matching.firstOrNull;
        final noMap = !app.online || _mapFailed || app.saveData;
        final waitHere = myStop == null ? 0 : live.waitingCount(villageId: from.id, destId: to.id, stopId: myStop.id);
        final far = matching.isEmpty ? live.farBusesFor(from.id, to.id, myStop?.id) : const <BusView>[];
        // From the rider's GPS: nearest stop of their village, and whether they seem to be elsewhere.
        final gps = live.riderPos;
        final nearStop = gps == null ? null : live.nearestStopTo(gps, from.id);
        final nearVillage = gps == null ? null : live.nearestVillage(gps, districtId: from.districtId);
        String km(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

        String etaLabel(int m) => m == 0 ? app.t('Hadda', 'Now') : app.t('$m daq', '$m min');

        Widget top() {
          final pill = Pressable(
            onTap: () => context.go('/rider/from'),
            scale: false,
            builder: (p) => AnimatedContainer(
              duration: BW.fast,
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: p ? BW.sand200 : BW.white, borderRadius: BorderRadius.circular(BW.rMd), boxShadow: BW.shadowFloat),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(color: BW.teal, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${from.nameSo} → ${to.nameSo}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Text(
                    app.t('Beddel', 'Change'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: BW.teal),
                  ),
                ],
              ),
            ),
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: pill),
              const SizedBox(width: 8),
              BWIconButton(
                live.locating ? 'refresh-cw' : 'locate-fixed',
                label: app.t('Halkee baan joogaa?', 'Where am I?'),
                variant: IconBtnVariant.filled,
                float: true,
                onTap: live.locating
                    ? null
                    : () {
                        setState(() => _mapFailed = false);
                        _locate(app);
                      },
              ),
            ],
          );
        }

        // The map runs 16px under the sheet so the sheet's round corners sit on the map.
        final mapArea = SizedBox(
          height: noMap ? null : 244,
          child: noMap
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 28),
                  child: Column(
                    children: [
                      top(),
                      const SizedBox(height: 12),
                      if (!app.online || _mapFailed)
                        BWBanner(
                          tone: BannerTone.offline,
                          title: app.online ? app.t('Khariidadda lama helin', 'Map unavailable') : app.t('Internet ma jiro', 'No internet'),
                          message: app.t('Liiska basaska ayaa weli shaqeynaya', 'The bus list still works'),
                          actionLabel: app.online ? app.t('Isku day', 'Retry') : null,
                          onAction: () => setState(() => _mapFailed = false),
                        ),
                    ],
                  ),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 260,
                      child: BusMap(
                        center: here,
                        focus: _selected != null ? sel?.live.position : _focus,
                        route: sel == null ? const [] : [sel.live.position!, here, if (sel.matching) to.center],
                        onTilesFailed: () => setState(() => _mapFailed = true),
                        onBusTap: (id) => setState(() => _selected = id),
                        // Tap a stop (or near one) to make it yours.
                        onPlaceTap: (id) => _pickStop(app, id),
                        onMapTap: (p) {
                          final n = live.nearestStopTo(p, from.id);
                          if (n != null && n.m < 800) _pickStop(app, n.stop.id);
                        },
                        places: [
                          for (final s in live.stopsOf(from.id))
                            if (s.id != myStop?.id) MapPlace(s.pos, s.name, kind: PlaceKind.stop, id: s.id),
                          MapPlace(here, myStop?.name ?? from.nameSo, kind: PlaceKind.me),
                          MapPlace(to.center, to.nameSo),
                          if (gps != null) MapPlace(gps, app.t('Adiga', 'You'), kind: PlaceKind.gps, accuracyM: live.riderAccuracyM),
                        ],
                        buses: [
                          for (final v in views) MapBus(id: v.live.busId, pos: v.live.position!, label: etaLabel(v.eta), selected: v.live.busId == sel?.live.busId, muted: !v.matching || v.live.stale),
                        ],
                      ),
                    ),
                    Positioned(top: 12, left: 12, right: 12, child: top()),
                  ],
                ),
        );

        return Column(
          children: [
            mapArea,
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: BW.sand,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(BW.rXl)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.fromLTRB(0, 10, 0, 4),
                      decoration: BoxDecoration(color: BW.night300, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(app.t('Basaska u socda ${to.nameSo}', 'Buses to ${to.nameEn}'), style: BWText.h3),
                                Text(app.t('Buses heading there', 'Basaska u socda halkaas'), style: BWText.small.copyWith(color: BW.textSecondary)),
                              ],
                            ),
                          ),
                          BWBadge(
                            live.connected ? '${app.t('Toos', 'Live')} · ${freshness(live.lastUpdate, app.en)}' : app.t('Xiriir la\'aan', 'Reconnecting'),
                            tone: live.connected ? BadgeTone.neutral : BadgeTone.danger,
                            dot: true,
                            small: true,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        children: [
                          if (waiting) ...[
                            BWCard(
                              variant: CardVariant.info,
                              padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                              child: Row(
                                children: [
                                  const BWIcon('circle-check', size: 24, color: BW.teal700),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(app.t('Darawalladu way ku arkaan', 'Drivers can see you'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                                        Text(
                                          '${live.stopOrNull(mine.stopId)?.name ?? ''} · ${app.t('${mine.expiresAt.difference(DateTime.now()).inMinutes + 1} daqiiqo ayaa hadhay', '${mine.expiresAt.difference(DateTime.now()).inMinutes + 1} min left')}',
                                          style: BWText.small.copyWith(color: BW.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  WaitingCount(count: waitHere, label: ''),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          // GPS says the rider is in another village: offer to switch.
                          if (nearVillage != null && nearVillage.village.id != from.id && nearVillage.m < 1500 && (nearStop?.m ?? 1e9) > 1500) ...[
                            BWBanner(
                              tone: BannerTone.info,
                              title: app.t('Waxaad u egtahay inaad joogto ${nearVillage.village.nameSo}', 'You seem to be in ${nearVillage.village.nameEn}'),
                              message: app.t('${km(nearStop?.m ?? 0)} ayaad u jirtaa ${from.nameSo}.', 'You are ${km(nearStop?.m ?? 0)} from ${from.nameEn}.'),
                              actionLabel: app.t('Beddel', 'Switch'),
                              onAction: () {
                                app.setFrom(nearVillage.village.id);
                                final n = live.nearestStopTo(gps!, nearVillage.village.id);
                                if (n != null) app.setStop(n.stop.id);
                                if (app.toId == null) context.go('/rider/to');
                              },
                            ),
                            const SizedBox(height: 8),
                          ]
                          // GPS found a closer stop in this village than the one chosen.
                          else if (nearStop != null && nearStop.stop.id != myStop?.id && nearStop.m < 1500) ...[
                            BWBanner(
                              tone: BannerTone.info,
                              title: app.t('Joogsiga kuugu dhow: ${nearStop.stop.name}', 'Nearest stop: ${nearStop.stop.name}'),
                              message: app.t('${km(nearStop.m)} ayuu kaa jiraa.', "It's ${km(nearStop.m)} from you."),
                              actionLabel: app.t('Dooro', 'Use it'),
                              onAction: () => _pickStop(app, nearStop.stop.id),
                            ),
                            const SizedBox(height: 8),
                          ]
                          else if (gps != null && nearStop != null && nearStop.m > 1500) ...[
                            BWBanner(
                              tone: BannerTone.warning,
                              title: app.t('Kama dhowid ${from.nameSo}', "You're not near ${from.nameEn}"),
                              message: app.t('${km(nearStop.m)} ayaad u jirtaa joogsiga ugu dhow. Hubi tuuladaada.', "You're ${km(nearStop.m)} from its nearest stop. Check your village."),
                              actionLabel: app.t('Beddel', 'Change'),
                              onAction: () => context.go('/rider/from'),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (matching.isEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: BWBanner(
                                tone: BannerTone.warning,
                                title: app.t('Bas lama heli karo hadda', 'No bus available right now'),
                                message: far.isNotEmpty
                                    ? app.t(
                                        'Bas ${far.first.live.busNumber} wuu ka fog yahay (${km(far.first.distanceM)}). Taabo "Waan sugayaa" si darawalladu u ogaadaan inaad sugayso.',
                                        "Bus ${far.first.live.busNumber} is too far away (${km(far.first.distanceM)}). Tap \"I'm waiting\" so drivers know you are here.",
                                      )
                                    : app.t(
                                        'Bas kuuma dhowa. Taabo "Waan sugayaa" si darawalladu u ogaadaan inaad sugayso.',
                                        "No bus is near you. Tap \"I'm waiting\" so drivers know you are here.",
                                      ),
                              ),
                            ),
                          for (final v in matching) ...[_busCard(context, app, v, sel), const SizedBox(height: 8)],
                          if (others.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                              child: SectionLabel(app.t('Meelo kale u socda', 'Going elsewhere'), app.sub('Meelo kale u socda', 'Going elsewhere')),
                            ),
                            for (final v in others) ...[_busCard(context, app, v, sel), const SizedBox(height: 8)],
                          ],
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                      child: BWButton(
                        waiting ? app.t('Waad sugaysaa', "You're waiting") : app.t('Waan sugayaa', "I'm waiting"),
                        subLabel: waiting ? app.t("You're waiting · tap to stop", 'Waad sugaysaa · taabo si aad u joojiso') : app.sub('Waan sugayaa', "I'm waiting"),
                        icon: waiting ? 'circle-check' : 'hand',
                        variant: waiting ? BtnVariant.secondary : BtnVariant.primary,
                        onTap: myStop == null ? null : () => waiting ? showStopWaitSheet(context) : showWaitSheet(context),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _busCard(BuildContext context, AppState app, BusView v, BusView? sel) {
    final live = app.live;
    final near = live.nearestStop(v.live);
    final dest = live.villageOrNull(v.live.destinationId);
    final status = v.live.full
        ? (app.t('Buuxa', 'Full'), StatusTone.danger)
        : v.live.stale
        ? (app.t('Xogtii ${freshness(v.live.updatedAt, false)}', 'Last seen ${freshness(v.live.updatedAt, true)}'), StatusTone.neutral)
        : v.matching
        ? (app.t('Wuu socdaa', 'On the way'), StatusTone.teal)
        : (app.t('U socda ${dest?.nameSo ?? ''}', 'To ${dest?.nameEn ?? ''}'), StatusTone.neutral);
    return BusCard(
      route: 'Bas ${v.live.busNumber} · ${v.live.driverName}',
      detail: near == null
          ? null
          : () {
              final m = live.distance(near.pos, v.live.position!);
              if (m < 400) return app.t('Wuxuu ag joogaa ${near.name}', 'Near ${near.name}');
              final km = (m / 1000).toStringAsFixed(1);
              return app.t('$km km u jira ${near.name}', '$km km from ${near.name}');
            }(),
      status: status.$1,
      statusTone: status.$2,
      waiting: live.waitingCount(villageId: v.live.villageId, destId: v.live.destinationId),
      minutes: v.eta,
      unit: app.t('daqiiqo', 'min'),
      nowLabel: app.t('Hadda', 'Now'),
      muted: !v.matching,
      selected: v.live.busId == sel?.live.busId,
      onTap: () {
        if (v.live.busId == sel?.live.busId) {
          context.push('/rider/bus/${v.live.busId}');
        } else {
          setState(() => _selected = v.live.busId);
        }
      },
    );
  }
}

class RiderSettings extends StatelessWidget {
  const RiderSettings({super.key});
  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final live = app.live;
    return Column(
      children: [
        BWTopBar(title: app.t('Dejinta', 'Settings'), subtitle: app.sub('Dejinta', 'Settings')),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              BWCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Luqadda · Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    BWRadioGroup(value: app.lang, onChange: app.setLang, options: const [RadioOption('so', 'Soomaali'), RadioOption('en', 'English')]),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BWCard(
                child: Column(
                  children: [
                    BWSwitchRow(
                      label: app.t('Kaydi xogta', 'Save data'),
                      subLabel: app.t('Save data — qari khariidadda, liiska oo keliya', 'Hide the map, list only'),
                      value: app.saveData,
                      onChanged: app.setSaveData,
                    ),
                    const Divider(height: 16, color: BW.borderSubtle),
                    BWSwitchRow(
                      label: app.t('Ogeysiis', 'Alerts'),
                      subLabel: app.t('Alert me when the bus is 2 min away', 'Alert me when the bus is 2 min away'),
                      value: app.notify,
                      onChanged: (v) => app.setNotify(v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BWCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    BWListItem(
                      icon: 'route',
                      tone: Tone.teal,
                      title: app.t('Beddel safarka', 'Change trip'),
                      subtitle: app.t('Change from / to village', 'Beddel tuulada'),
                      chevron: true,
                      divider: true,
                      onTap: () => context.go('/rider/from'),
                    ),
                    BWListItem(
                      icon: 'map',
                      tone: Tone.neutral,
                      title: app.t('Beddel degmada', 'Change district'),
                      subtitle: app.t('City and district', 'Magaalada iyo degmada'),
                      chevron: true,
                      divider: true,
                      onTap: () => context.go('/rider/city'),
                    ),
                    BWListItem(
                      icon: 'bus',
                      tone: Tone.yellow,
                      title: app.t('Darawal ma tahay?', 'Are you a driver?'),
                      subtitle: app.t('Driver sign in', 'Gal sida darawal'),
                      chevron: true,
                      onTap: () {
                        app.setRole('driver');
                        context.go('/driver');
                      },
                    ),
                  ],
                ),
              ),
              if (app.favourites.any((id) => live.villageOrNull(id) != null)) ...[
                const SizedBox(height: 12),
                BWCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SectionLabel(app.t('Tuulooyinka aad jeceshahay', 'Favourite villages'), app.sub('Tuulooyinka aad jeceshahay', 'Favourites')),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final id in app.favourites)
                            if (live.villageOrNull(id) != null) BWTag(live.villageById(id).nameSo, icon: 'heart', onTap: () => app.toggleFavourite(id)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: BWLogo(variant: LogoVariant.wordmark, height: 24),
                ),
              ),
              Center(
                child: BWButton(
                  app.t('Bilow bogga', 'Start page'),
                  variant: BtnVariant.ghost,
                  small: true,
                  fullWidth: false,
                  onTap: () {
                    toastBus.value = null;
                    context.go('/');
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
