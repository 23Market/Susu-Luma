import 'package:flutter/material.dart';

const _green = Color(0xFF176B50);
const _deepGreen = Color(0xFF0D503B);
const _ink = Color(0xFF17251F);
const _muted = Color(0xFF68766F);
const _canvas = Color(0xFFF5F7F4);
const _line = Color(0xFFE1E8E3);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _section = 0;
  int _range = 1;
  String _query = '';

  static const _destinations = <_AdminDestination>[
    _AdminDestination('Overview', Icons.space_dashboard_outlined),
    _AdminDestination('Marketplace', Icons.storefront_outlined),
    _AdminDestination('Suppliers', Icons.verified_user_outlined),
    _AdminDestination('Revenue', Icons.payments_outlined),
    _AdminDestination('Operations', Icons.rule_folder_outlined),
  ];

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 980;
          return Scaffold(
            backgroundColor: _canvas,
            appBar: wide
                ? null
                : AppBar(
                    title: const _Brand(compact: true),
                    actions: [
                      IconButton(
                        tooltip: 'Notifications',
                        onPressed: _showPrototypeNotice,
                        icon: const Icon(Icons.notifications_none_rounded),
                      ),
                    ],
                  ),
            drawer: wide ? null : Drawer(child: _mobileNavigation()),
            body: Row(
              children: [
                if (wide) _desktopNavigation(),
                Expanded(
                  child: Column(
                    children: [
                      if (wide) _topBar(),
                      Expanded(child: _sectionBody()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _desktopNavigation() => Container(
        width: 248,
        color: _deepGreen,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Brand(onDark: true),
            const SizedBox(height: 30),
            for (var index = 0; index < _destinations.length; index++)
              _NavigationItem(
                destination: _destinations[index],
                selected: _section == index,
                onTap: () => setState(() => _section = index),
              ),
            const Spacer(),
            const _PrototypeCard(onDark: true),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.white70,
                alignment: Alignment.centerLeft,
              ),
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to marketplace'),
            ),
          ],
        ),
      );

  Widget _mobileNavigation() => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Brand(),
              const SizedBox(height: 24),
              for (var index = 0; index < _destinations.length; index++)
                ListTile(
                  selected: _section == index,
                  selectedColor: _green,
                  selectedTileColor: const Color(0xFFE5EEE6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  leading: Icon(_destinations[index].icon),
                  title: Text(_destinations[index].label),
                  onTap: () {
                    setState(() => _section = index);
                    Navigator.of(context).pop();
                  },
                ),
              const Spacer(),
              const _PrototypeCard(),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to marketplace'),
              ),
            ],
          ),
        ),
      );

  Widget _topBar() => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search suppliers, RFQs or orders',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 18),
            const _StatusPill(
              label: 'Demo workspace',
              color: Color(0xFFFFF3D6),
              foreground: Color(0xFF815A00),
              icon: Icons.science_outlined,
            ),
            const SizedBox(width: 10),
            IconButton(
              tooltip: 'Notifications',
              onPressed: _showPrototypeNotice,
              icon: const Icon(Icons.notifications_none_rounded),
            ),
            const SizedBox(width: 8),
            const CircleAvatar(
              backgroundColor: Color(0xFFE5EEE6),
              child: Text('SL', style: TextStyle(color: _green)),
            ),
          ],
        ),
      );

  Widget _sectionBody() {
    switch (_section) {
      case 1:
        return _marketplace();
      case 2:
        return _suppliers();
      case 3:
        return _revenue();
      case 4:
        return _operations();
      default:
        return _overview();
    }
  }

  Widget _overview() => _Page(
        title: 'Business overview',
        subtitle: 'Marketplace health and monetisation signals',
        trailing: _RangeSelector(
          selected: _range,
          onSelected: (value) => setState(() => _range = value),
        ),
        children: [
          const _NoticeBanner(),
          const SizedBox(height: 20),
          const _MetricGrid(
            metrics: [
              _Metric('Monthly revenue', 'SLE 32,500', '+12.4%',
                  Icons.trending_up_rounded, Color(0xFFE5EEE6)),
              _Metric('Marketplace GMV', 'SLE 1.26m', '+18.1%',
                  Icons.receipt_long_outlined, Color(0xFFE5EAF2)),
              _Metric('Qualified RFQs', '300', '+26 this month',
                  Icons.request_quote_outlined, Color(0xFFF2EAD7)),
              _Metric('RFQ → order', '18.7%', '+2.1 pts',
                  Icons.sync_alt_rounded, Color(0xFFECE4F2)),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 900;
              const chart = _Panel(
                title: 'Revenue momentum',
                subtitle: 'Illustrative monthly recurring revenue in SLE',
                child: SizedBox(height: 230, child: _RevenueChart()),
              );
              const mix = _Panel(
                title: 'Revenue mix',
                subtitle: 'Designed for diversified marketplace income',
                child: _RevenueMix(),
              );
              if (stacked) {
                return const Column(
                    children: [chart, SizedBox(height: 20), mix]);
              }
              return const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chart),
                  SizedBox(width: 20),
                  Expanded(flex: 2, child: mix),
                ],
              );
            },
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Priority actions',
            subtitle: 'Operational work that protects trust and conversion',
            child: _PriorityActions(),
          ),
        ],
      );

  Widget _marketplace() {
    final rows = _rfqRows.where((row) {
      final needle = _query.trim().toLowerCase();
      return needle.isEmpty ||
          '${row.reference} ${row.buyer} ${row.category}'
              .toLowerCase()
              .contains(needle);
    }).toList();
    return _Page(
      title: 'Marketplace activity',
      subtitle: 'RFQ quality, matching and order conversion',
      trailing: FilledButton.icon(
        onPressed: _showPrototypeNotice,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Create manual RFQ'),
      ),
      children: [
        const _MetricGrid(
          metrics: [
            _Metric('Open RFQs', '74', '18 need routing',
                Icons.mark_email_unread_outlined, Color(0xFFF2EAD7)),
            _Metric('Median responses', '3.2', 'Target: 4+',
                Icons.forum_outlined, Color(0xFFE5EEE6)),
            _Metric('Orders this month', '56', 'SLE 1.26m GMV',
                Icons.inventory_2_outlined, Color(0xFFE5EAF2)),
            _Metric('Disputed orders', '3', '5.4% of orders',
                Icons.report_problem_outlined, Color(0xFFFFE6E3)),
          ],
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Recent RFQs',
          subtitle: 'Qualified demand routed to relevant suppliers',
          child: _DataTableCard(
            columns: const [
              'Reference',
              'Buyer',
              'Category',
              'Value',
              'Status'
            ],
            rows: [
              for (final row in rows)
                [
                  row.reference,
                  row.buyer,
                  row.category,
                  row.value,
                  _StatusPill(
                    label: row.status,
                    color: row.statusColor,
                    foreground: _ink,
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _suppliers() => _Page(
        title: 'Supplier growth',
        subtitle: 'Verification, plans and marketplace quality',
        trailing: OutlinedButton.icon(
          onPressed: _showPrototypeNotice,
          icon: const Icon(Icons.download_outlined),
          label: const Text('Export'),
        ),
        children: [
          const _MetricGrid(
            metrics: [
              _Metric('Active suppliers', '100', '+14 this month',
                  Icons.store_mall_directory_outlined, Color(0xFFE5EEE6)),
              _Metric('Verified', '68%', 'Target: 80%', Icons.verified_outlined,
                  Color(0xFFE5EAF2)),
              _Metric('Pro conversion', '31%', '+4.6 pts',
                  Icons.workspace_premium_outlined, Color(0xFFF2EAD7)),
              _Metric('At-risk suppliers', '8', 'No response in 14d',
                  Icons.warning_amber_rounded, Color(0xFFFFE6E3)),
            ],
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Subscription design',
            subtitle: 'Plans align pricing with supplier value received',
            child: _PlanGrid(),
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Verification queue',
            subtitle: 'Decisions must be auditable and backed by evidence',
            child: _VerificationQueue(),
          ),
        ],
      );

  Widget _revenue() => _Page(
        title: 'Revenue model',
        subtitle: 'Recurring and usage-based income without holding funds',
        trailing: FilledButton.icon(
          onPressed: _showPrototypeNotice,
          icon: const Icon(Icons.tune_rounded),
          label: const Text('Edit pricing'),
        ),
        children: [
          const _NoticeBanner(
            title: 'Financial boundary',
            message:
                'Susu Luma does not operate a wallet, escrow or settlement service. Payment integrations must use approved providers and authoritative confirmation.',
            icon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Monthly revenue composition',
            subtitle: 'Illustrative launch economics',
            child: _RevenueTable(),
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Unit economics targets',
            subtitle: 'Thresholds to validate before scaling acquisition',
            child: _UnitEconomics(),
          ),
        ],
      );

  Widget _operations() => _Page(
        title: 'Operations centre',
        subtitle: 'Trust, moderation and service-level controls',
        trailing: OutlinedButton.icon(
          onPressed: _showPrototypeNotice,
          icon: const Icon(Icons.history_rounded),
          label: const Text('Audit log'),
        ),
        children: [
          const _MetricGrid(
            metrics: [
              _Metric('Verification backlog', '12', 'Oldest: 2 days',
                  Icons.fact_check_outlined, Color(0xFFF2EAD7)),
              _Metric('Listings in review', '19', '4 flagged',
                  Icons.inventory_outlined, Color(0xFFE5EAF2)),
              _Metric('Support cases', '7', '2 high priority',
                  Icons.support_agent_outlined, Color(0xFFFFE6E3)),
              _Metric('SLA met', '92%', '+3 pts', Icons.timer_outlined,
                  Color(0xFFE5EEE6)),
            ],
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Operations queue',
            subtitle: 'Human decisions remain explicit and reviewable',
            child: _OperationsQueue(),
          ),
        ],
      );

  void _showPrototypeNotice() => ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Prototype action only — connect authenticated Supabase admin RPCs before enabling changes.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
}

class _Page extends StatelessWidget {
  const _Page({
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  runSpacing: 14,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                                color: _ink,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -.7,
                              ),
                        ),
                        const SizedBox(height: 5),
                        Text(subtitle, style: const TextStyle(color: _muted)),
                      ],
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Brand extends StatelessWidget {
  const _Brand({this.onDark = false, this.compact = false});

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            decoration: BoxDecoration(
              color: onDark ? Colors.white : _green,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              Icons.storefront_rounded,
              color: onDark ? _green : Colors.white,
              size: compact ? 19 : 23,
            ),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'susu luma',
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: onDark ? Colors.white : _ink,
                    fontSize: compact ? 18 : 21,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -.5,
                  ),
                ),
                if (!compact)
                  Text(
                    'MARKETPLACE ADMIN',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onDark ? Colors.white60 : _muted,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1,
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
}

class _NavigationItem extends StatelessWidget {
  const _NavigationItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final _AdminDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Material(
          color: selected
              ? Colors.white.withValues(alpha: .14)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Icon(destination.icon,
                      color: selected ? Colors.white : Colors.white60,
                      size: 21),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      destination.label,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white70,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class _PrototypeCard extends StatelessWidget {
  const _PrototypeCard({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: onDark
              ? Colors.white.withValues(alpha: .09)
              : const Color(0xFFFFF3D6),
          borderRadius: BorderRadius.circular(14),
          border: onDark ? null : Border.all(color: const Color(0xFFF0D899)),
        ),
        child: Text(
          'Prototype data only\nConnect role-gated Supabase admin services before pilot.',
          style: TextStyle(
            color: onDark ? Colors.white70 : const Color(0xFF6B4A00),
            fontSize: 11,
            height: 1.45,
          ),
        ),
      );
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({
    this.title = 'Illustrative business metrics',
    this.message =
        'Values model the recommended subscription, qualified-lead and featured-listing strategy. They are not live financial results.',
    this.icon = Icons.insights_outlined,
  });

  final String title;
  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF3EE),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFCAE0D4)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: _green),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(message,
                      style: const TextStyle(color: _muted, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.metrics});

  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final count = constraints.maxWidth >= 1000
              ? 4
              : constraints.maxWidth >= 560
                  ? 2
                  : 1;
          const gap = 14.0;
          final width = (constraints.maxWidth - gap * (count - 1)) / count;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final metric in metrics)
                SizedBox(width: width, child: _MetricCard(metric))
            ],
          );
        },
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(this.metric);

  final _Metric metric;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: metric.color,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(metric.icon, color: _green, size: 20),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz_rounded, color: _muted, size: 19),
              ],
            ),
            const SizedBox(height: 18),
            Text(metric.value,
                style: const TextStyle(
                    color: _ink, fontSize: 24, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(metric.label,
                style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 9),
            Text(metric.context,
                style: const TextStyle(
                    color: _green, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _Panel extends StatelessWidget {
  const _Panel(
      {required this.title, required this.subtitle, required this.child});

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    color: _ink, fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: _muted, fontSize: 12)),
            const SizedBox(height: 20),
            child,
          ],
        ),
      );
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart();

  @override
  Widget build(BuildContext context) => const CustomPaint(
        painter: _BarChartPainter(
          values: [18, 21, 23, 26, 29, 32.5],
          labels: ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'],
        ),
        size: Size.infinite,
      );
}

class _BarChartPainter extends CustomPainter {
  const _BarChartPainter({required this.values, required this.labels});

  final List<double> values;
  final List<String> labels;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 12.0;
    const bottom = 28.0;
    final usableHeight = size.height - top - bottom;
    final slot = size.width / values.length;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final gridPaint = Paint()..color = _line;
    final barPaint = Paint()..color = _green;
    final labelPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i <= 4; i++) {
      final y = top + usableHeight * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }
    for (var index = 0; index < values.length; index++) {
      final height = usableHeight * values[index] / maxValue;
      final left = index * slot + slot * .22;
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top + usableHeight - height, slot * .56, height),
        const Radius.circular(8),
      );
      canvas.drawRRect(rect, barPaint);
      labelPainter.text = TextSpan(
        text: labels[index],
        style: const TextStyle(color: _muted, fontSize: 10),
      );
      labelPainter.layout();
      labelPainter.paint(
        canvas,
        Offset(
            index * slot + (slot - labelPainter.width) / 2, size.height - 18),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.labels != labels;
}

class _RevenueMix extends StatelessWidget {
  const _RevenueMix();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _MixRow('Pro subscriptions', 'SLE 20,000', .615, _green),
          SizedBox(height: 18),
          _MixRow('Qualified RFQ access', 'SLE 7,500', .231, Color(0xFF4D77A8)),
          SizedBox(height: 18),
          _MixRow('Featured placement', 'SLE 5,000', .154, Color(0xFFB48B3C)),
          SizedBox(height: 20),
          Divider(color: _line),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Modelled MRR', style: TextStyle(color: _muted)),
              Text('SLE 32,500',
                  style: TextStyle(fontWeight: FontWeight.w800, color: _ink)),
            ],
          ),
        ],
      );
}

class _MixRow extends StatelessWidget {
  const _MixRow(this.label, this.value, this.progress, this.color);

  final String label;
  final String value;
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label, style: const TextStyle(fontSize: 12))),
              Text(value,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: LinearProgressIndicator(
              minHeight: 8,
              value: progress,
              color: color,
              backgroundColor: _line,
            ),
          ),
        ],
      );
}

class _PriorityActions extends StatelessWidget {
  const _PriorityActions();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _ActionRow(
              Icons.verified_user_outlined,
              'Review 12 supplier applications',
              'Protect marketplace trust · oldest case 2 days',
              'Review'),
          Divider(color: _line),
          _ActionRow(
              Icons.route_outlined,
              'Route 18 qualified RFQs',
              'Construction demand has fewer than 3 matching suppliers',
              'Route'),
          Divider(color: _line),
          _ActionRow(Icons.support_agent_outlined, 'Resolve 2 priority cases',
              'One delivery exception and one quote dispute', 'Open'),
        ],
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow(this.icon, this.title, this.subtitle, this.action);

  final IconData icon;
  final String title;
  final String subtitle;
  final String action;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: const Color(0xFFE5EEE6),
              child: Icon(icon, color: _green, size: 20),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            TextButton(onPressed: () {}, child: Text(action)),
          ],
        ),
      );
}

class _DataTableCard extends StatelessWidget {
  const _DataTableCard({required this.columns, required this.rows});

  final List<String> columns;
  final List<List<Object>> rows;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAF8)),
          columnSpacing: 34,
          columns: [
            for (final column in columns) DataColumn(label: Text(column))
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  for (final cell in row)
                    DataCell(cell is Widget ? cell : Text(cell.toString())),
                ],
              ),
          ],
        ),
      );
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid();

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth >= 860
              ? (constraints.maxWidth - 36) / 4
              : constraints.maxWidth >= 500
                  ? (constraints.maxWidth - 12) / 2
                  : constraints.maxWidth;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children: const [
              _PlanCard('Basic', 'Free', 'Limited listings', '39 suppliers'),
              _PlanCard('Verified', 'Annual fee', 'Trust badge + review',
                  '30 suppliers'),
              _PlanCard(
                  'Pro', 'SLE 200/mo', 'RFQ alerts + analytics', '31 suppliers',
                  featured: true),
              _PlanCard('Enterprise', 'Custom', 'Teams + procurement', 'Pilot'),
            ].map((plan) => SizedBox(width: width, child: plan)).toList(),
          );
        },
      );
}

class _PlanCard extends StatelessWidget {
  const _PlanCard(this.name, this.price, this.benefit, this.usage,
      {this.featured = false});

  final String name;
  final String price;
  final String benefit;
  final String usage;
  final bool featured;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: featured ? const Color(0xFFEAF3EE) : const Color(0xFFF8FAF8),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: featured ? _green : _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
                if (featured) ...[
                  const Spacer(),
                  const Icon(Icons.star_rounded, color: _green, size: 17),
                ],
              ],
            ),
            const SizedBox(height: 10),
            Text(price,
                style: const TextStyle(
                    color: _green, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Text(benefit, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 14),
            Text(usage,
                style:
                    const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _VerificationQueue extends StatelessWidget {
  const _VerificationQueue();

  @override
  Widget build(BuildContext context) => const _DataTableCard(
        columns: ['Supplier', 'District', 'Submitted', 'Scope', 'Status'],
        rows: [
          [
            'Makeni Agro Hub',
            'Bombali',
            'Today',
            'Business + owner',
            _StatusPill(
                label: 'New', color: Color(0xFFE5EAF2), foreground: _ink)
          ],
          [
            'Lion Mountain Tools',
            'Western Area',
            'Yesterday',
            'Business',
            _StatusPill(
                label: 'In review', color: Color(0xFFF2EAD7), foreground: _ink)
          ],
          [
            'Bo Fresh Produce',
            'Bo',
            '2 days ago',
            'Renewal',
            _StatusPill(
                label: 'Needs evidence',
                color: Color(0xFFFFE6E3),
                foreground: _ink)
          ],
        ],
      );
}

class _RevenueTable extends StatelessWidget {
  const _RevenueTable();

  @override
  Widget build(BuildContext context) => const _DataTableCard(
        columns: ['Stream', 'Volume', 'Price', 'Monthly revenue', 'Share'],
        rows: [
          [
            'Pro subscriptions',
            '100 suppliers',
            'SLE 200',
            'SLE 20,000',
            '61.5%'
          ],
          [
            'Qualified RFQ access',
            '300 responses',
            'SLE 25',
            'SLE 7,500',
            '23.1%'
          ],
          ['Featured placement', '10 slots', 'SLE 500', 'SLE 5,000', '15.4%'],
          ['Total modelled MRR', '', '', 'SLE 32,500', '100%'],
        ],
      );
}

class _UnitEconomics extends StatelessWidget {
  const _UnitEconomics();

  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _TargetCard('Supplier CAC', '< SLE 450', 'Recover within 3 months'),
          _TargetCard(
              'Monthly churn', '< 4%', 'Retain suppliers with real demand'),
          _TargetCard(
              'Lead acceptance', '> 60%', 'Only charge for qualified demand'),
          _TargetCard('Repeat buyers', '> 45%', 'Measure marketplace utility'),
        ],
      );
}

class _TargetCard extends StatelessWidget {
  const _TargetCard(this.label, this.target, this.context);

  final String label;
  final String target;
  final String context;

  @override
  Widget build(BuildContext context) => Container(
        width: 220,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF8),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(height: 6),
            Text(target,
                style: const TextStyle(
                    color: _green, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 5),
            Text(this.context,
                style: const TextStyle(color: _muted, fontSize: 10)),
          ],
        ),
      );
}

class _OperationsQueue extends StatelessWidget {
  const _OperationsQueue();

  @override
  Widget build(BuildContext context) => const Column(
        children: [
          _QueueRow('High', 'Order SL-4F72D · delivery exception',
              'Buyer reported partial delivery · Western Area', '18 min'),
          Divider(color: _line),
          _QueueRow('High', 'Quote dispute · unit mismatch',
              'RFQ requested bags; supplier quoted kilograms', '43 min'),
          Divider(color: _line),
          _QueueRow('Review', 'Listing flagged for prohibited claim',
              'Automated rule requires human classification', '2 hr'),
          Divider(color: _line),
          _QueueRow('Normal', 'Supplier verification renewal',
              'Bo Fresh Produce · evidence expires in 14 days', '1 day'),
        ],
      );
}

class _QueueRow extends StatelessWidget {
  const _QueueRow(this.priority, this.title, this.subtitle, this.age);

  final String priority;
  final String title;
  final String subtitle;
  final String age;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(
          children: [
            _StatusPill(
              label: priority,
              color: priority == 'High'
                  ? const Color(0xFFFFE6E3)
                  : const Color(0xFFE5EAF2),
              foreground: _ink,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle,
                      style: const TextStyle(color: _muted, fontSize: 11)),
                ],
              ),
            ),
            Text(age, style: const TextStyle(color: _muted, fontSize: 11)),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: _muted),
          ],
        ),
      );
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
        segments: const [
          ButtonSegment(value: 0, label: Text('7d')),
          ButtonSegment(value: 1, label: Text('30d')),
          ButtonSegment(value: 2, label: Text('90d')),
        ],
        selected: {selected},
        onSelectionChanged: (value) => onSelected(value.first),
      );
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.label,
    required this.color,
    required this.foreground,
    this.icon,
  });

  final String label;
  final Color color;
  final Color foreground;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: color, borderRadius: BorderRadius.circular(30)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 5),
            ],
            Text(label,
                style: TextStyle(
                    color: foreground,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      );
}

class _AdminDestination {
  const _AdminDestination(this.label, this.icon);
  final String label;
  final IconData icon;
}

class _Metric {
  const _Metric(this.label, this.value, this.context, this.icon, this.color);
  final String label;
  final String value;
  final String context;
  final IconData icon;
  final Color color;
}

class _RfqRow {
  const _RfqRow(this.reference, this.buyer, this.category, this.value,
      this.status, this.statusColor);
  final String reference;
  final String buyer;
  final String category;
  final String value;
  final String status;
  final Color statusColor;
}

const _rfqRows = <_RfqRow>[
  _RfqRow('SL-8E91A', 'Kallon & Sons', 'Construction', 'SLE 84,000', 'Open',
      Color(0xFFE5EAF2)),
  _RfqRow('SL-3BD24', 'Bo Retail Network', 'Agriculture', 'SLE 42,500',
      'Quoted', Color(0xFFE5EEE6)),
  _RfqRow('SL-91FC2', 'Makeni Works', 'Equipment', 'SLE 128,000',
      'Needs routing', Color(0xFFF2EAD7)),
  _RfqRow('SL-5A110', 'Freetown Traders', 'Metals', 'SLE 66,400', 'Accepted',
      Color(0xFFE5EEE6)),
];
