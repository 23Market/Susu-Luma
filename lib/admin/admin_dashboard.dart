import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../widgets/luma_brand.dart';
import 'admin_dashboard_data.dart';

const _green = Color(0xFF195C43);
const _deepGreen = Color(0xFF103D30);
const _ink = Color(0xFF17231E);
const _muted = Color(0xFF66736D);
const _line = Color(0xFFE2E8E4);
const _canvas = Color(0xFFF6F8F6);

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({
    super.key,
    this.dataSource = const LiveAdminDashboardDataSource(),
    this.initialSnapshot,
  });

  final AdminDashboardDataSource dataSource;
  final AdminDashboardSnapshot? initialSnapshot;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _section = 0;
  String _query = '';
  AdminDashboardSnapshot? _snapshot;
  bool _loading = false;
  String? _busyId;

  static const _destinations = [
    ('Overview', Icons.space_dashboard_outlined),
    ('Marketplace', Icons.swap_horiz_rounded),
    ('Suppliers', Icons.storefront_outlined),
    ('Revenue', Icons.payments_outlined),
    ('Operations', Icons.fact_check_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _snapshot = widget.initialSnapshot;
    if (_snapshot == null) _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final result = await widget.dataSource.fetch();
      if (mounted) setState(() => _snapshot = result);
    } on Object {
      if (mounted) setState(() => _snapshot = null);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final desktop = constraints.maxWidth >= 920;
          return Scaffold(
            backgroundColor: _canvas,
            drawer: desktop ? null : Drawer(child: _navigation(false)),
            body: Row(
              children: [
                if (desktop) SizedBox(width: 244, child: _navigation(true)),
                Expanded(
                  child: Column(
                    children: [
                      _topBar(desktop),
                      Expanded(child: _body()),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      );

  Widget _navigation(bool dark) => Container(
        color: dark ? _deepGreen : Colors.white,
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Brand(dark: dark),
              const SizedBox(height: 28),
              for (var i = 0; i < _destinations.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      onTap: () {
                        setState(() => _section = i);
                        if (!dark) Navigator.of(context).pop();
                      },
                      selected: _section == i,
                      selectedTileColor:
                          dark ? Colors.white12 : const Color(0xFFE5EEE6),
                      selectedColor: dark ? Colors.white : _green,
                      textColor: dark ? Colors.white70 : _ink,
                      iconColor: dark ? Colors.white70 : _ink,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      leading: Icon(_destinations[i].$2),
                      title: Text(_destinations[i].$1),
                    ),
                  ),
                ),
              const Spacer(),
              if (dark) const _SecurityCard(),
            ],
          ),
        ),
      );

  Widget _topBar(bool desktop) => Container(
        height: 76,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _line)),
        ),
        child: Row(
          children: [
            if (!desktop)
              Builder(
                builder: (context) => IconButton(
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                ),
              ),
            Expanded(
              child: TextField(
                onChanged: (value) => setState(() => _query = value),
                decoration: const InputDecoration(
                  hintText: 'Search current queue',
                  prefixIcon: Icon(Icons.search_rounded),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 14),
            const _Pill(
              label: 'Live backend',
              color: Color(0xFFE5EEE6),
              foreground: _green,
              icon: Icons.cloud_done_outlined,
            ),
            IconButton(
              onPressed: _loading ? null : _reload,
              tooltip: 'Refresh',
              icon: _loading
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
      );

  Widget _body() {
    final data = _snapshot;
    if (data == null && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) return _ErrorState(onRetry: _reload);
    return switch (_section) {
      1 => _marketplace(data),
      2 => _suppliers(data),
      3 => _revenue(data),
      4 => _operations(data),
      _ => _overview(data),
    };
  }

  Widget _overview(AdminDashboardSnapshot data) => _Page(
        title: 'Business overview',
        subtitle: 'Marketplace health as of ${_dateTime(data.generatedAt)}',
        children: [
          _MetricGrid([
            _Metric('Monthly revenue', _money(data.overview.monthlyRevenue),
                'Recognized this month', Icons.trending_up_rounded),
            _Metric('Marketplace GMV', _money(data.overview.marketplaceGmv),
                'Accepted order value', Icons.receipt_long_outlined),
            _Metric('Qualified RFQs', '${data.overview.qualifiedRfqs}',
                'Submitted this month', Icons.request_quote_outlined),
            _Metric(
                'RFQ to order',
                '${data.overview.conversionRate.toStringAsFixed(1)}%',
                'Monthly conversion',
                Icons.sync_alt_rounded),
          ]),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              final chart = _Panel(
                title: 'Revenue momentum',
                subtitle: 'Recognized revenue for the last six months',
                child: SizedBox(
                  height: 235,
                  child: _RevenueChart(data.revenue.history),
                ),
              );
              final priorities = _Panel(
                title: 'Priority actions',
                subtitle: 'Queues requiring an administrator',
                child: _PriorityActions(data.operations),
              );
              if (constraints.maxWidth < 850) {
                return Column(children: [
                  chart,
                  const SizedBox(height: 20),
                  priorities,
                ]);
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: chart),
                  const SizedBox(width: 20),
                  Expanded(flex: 2, child: priorities),
                ],
              );
            },
          ),
        ],
      );

  Widget _marketplace(AdminDashboardSnapshot data) {
    final rows = data.marketplace.recentRfqs
        .where((item) => _matches(
            '${item.referenceCode} ${item.buyer} ${item.category} ${item.status}'))
        .toList();
    return _Page(
      title: 'Marketplace activity',
      subtitle: 'RFQ demand and order conversion from the live database',
      children: [
        _MetricGrid([
          _Metric('Open RFQs', '${data.marketplace.openRfqs}',
              'Submitted, open or quoted', Icons.mark_email_unread_outlined),
          _Metric('Orders this month', '${data.marketplace.ordersThisMonth}',
              _money(data.overview.marketplaceGmv), Icons.inventory_2_outlined),
          _Metric('Disputed orders', '${data.marketplace.disputedOrders}',
              'Needs resolution', Icons.report_problem_outlined),
          _Metric(
              'Conversion',
              '${data.overview.conversionRate.toStringAsFixed(1)}%',
              'RFQ to order',
              Icons.insights_outlined),
        ]),
        const SizedBox(height: 20),
        _Panel(
          title: 'Recent RFQs',
          subtitle: '${rows.length} matching requests',
          child: _Table(
            columns: const [
              'Reference',
              'Buyer',
              'Category',
              'Status',
              'Created'
            ],
            rows: rows
                .map((row) => [
                      Text(row.referenceCode),
                      Text(row.buyer),
                      Text(row.category),
                      _Pill(label: _label(row.status)),
                      Text(_date(row.createdAt)),
                    ])
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _suppliers(AdminDashboardSnapshot data) {
    final rows = data.suppliers.verificationQueue
        .where((item) => _matches(
            '${item.supplier} ${item.district} ${item.scope} ${item.status}'))
        .toList();
    final rate = data.suppliers.activeSuppliers == 0
        ? 0
        : data.suppliers.verifiedSuppliers *
            100 /
            data.suppliers.activeSuppliers;
    return _Page(
      title: 'Supplier growth',
      subtitle: 'Verification, subscriptions and marketplace quality',
      children: [
        _MetricGrid([
          _Metric('Active suppliers', '${data.suppliers.activeSuppliers}',
              'With published listings', Icons.storefront_outlined),
          _Metric('Verified', '${data.suppliers.verifiedSuppliers}',
              '${rate.toStringAsFixed(0)}% of active', Icons.verified_outlined),
          _Metric('Pro suppliers', '${data.suppliers.proSuppliers}',
              'Active or trialing', Icons.workspace_premium_outlined),
          _Metric('At risk', '${data.suppliers.atRiskSuppliers}',
              'Past due subscriptions', Icons.warning_amber_rounded),
        ]),
        const SizedBox(height: 20),
        const _Panel(
          title: 'Subscription model',
          subtitle: 'Commercial plan design',
          child: _PlanGrid(),
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Verification queue',
          subtitle: '${rows.length} decisions awaiting review',
          child: _Table(
            columns: const [
              'Supplier',
              'District',
              'Scope',
              'Status',
              'Actions'
            ],
            rows: rows
                .map((row) => [
                      Text(row.supplier),
                      Text(row.district.isEmpty ? '—' : row.district),
                      Text(row.scope.isEmpty ? 'General' : row.scope),
                      _Pill(label: _label(row.status)),
                      _ActionButtons(
                        busy: _busyId == row.id,
                        onApprove: () => _supplierDecision(row, 'approved'),
                        onReject: () => _supplierDecision(row, 'rejected'),
                        onReview: row.status == 'pending'
                            ? () => _supplierDecision(row, 'in_review')
                            : null,
                      ),
                    ])
                .toList(),
          ),
        ),
      ],
    );
  }

  Widget _revenue(AdminDashboardSnapshot data) => _Page(
        title: 'Revenue model',
        subtitle:
            'Recognized platform income without custody of customer funds',
        children: [
          const _Notice(
            title: 'Financial boundary',
            message:
                'Susu Luma records its own fees and subscriptions. Buyer and supplier payments remain with approved payment providers.',
          ),
          const SizedBox(height: 20),
          _Panel(
            title: 'Monthly revenue composition',
            subtitle: 'Total ${_money(data.revenue.monthlyTotal)}',
            child: _Table(
              columns: const ['Revenue stream', 'Transactions', 'Amount'],
              rows: data.revenue.streams
                  .map((row) => [
                        Text(_label(row.stream)),
                        Text('${row.volume}'),
                        Text(_money(row.amount),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                      ])
                  .toList(),
            ),
          ),
          const SizedBox(height: 20),
          const _Panel(
            title: 'Unit economics guardrails',
            subtitle: 'Business targets to validate before scaling',
            child: _UnitEconomics(),
          ),
        ],
      );

  Widget _operations(AdminDashboardSnapshot data) {
    final listings = data.operations.listingQueue
        .where((item) =>
            _matches('${item.title} ${item.supplier} ${item.category}'))
        .toList();
    final support = data.operations.supportQueue
        .where((item) =>
            _matches('${item.subject} ${item.organization} ${item.priority}'))
        .toList();
    return _Page(
      title: 'Operations centre',
      subtitle: 'Server-authorized moderation and support workflows',
      children: [
        _MetricGrid([
          _Metric(
              'Verification backlog',
              '${data.operations.verificationBacklog}',
              'Pending or in review',
              Icons.fact_check_outlined),
          _Metric('Listings in review', '${data.operations.listingsInReview}',
              'Pending publication', Icons.inventory_outlined),
          _Metric(
              'Support cases',
              '${data.operations.supportCases}',
              '${data.operations.highPriorityCases} high priority',
              Icons.support_agent_outlined),
          const _Metric('Audit trail', 'Enabled', 'Every decision recorded',
              Icons.policy_outlined),
        ]),
        const SizedBox(height: 20),
        _Panel(
          title: 'Listing moderation',
          subtitle: '${listings.length} listings await a decision',
          child: _Table(
            columns: const [
              'Listing',
              'Supplier',
              'Category',
              'Submitted',
              'Actions'
            ],
            rows: listings
                .map((row) => [
                      Text(row.title),
                      Text(row.supplier),
                      Text(row.category),
                      Text(_date(row.createdAt)),
                      _ActionButtons(
                        busy: _busyId == row.id,
                        onApprove: () => _listingDecision(row, 'published'),
                        onReject: () => _listingDecision(row, 'rejected'),
                      ),
                    ])
                .toList(),
          ),
        ),
        const SizedBox(height: 20),
        _Panel(
          title: 'Support queue',
          subtitle: '${support.length} open cases',
          child: _Table(
            columns: const [
              'Priority',
              'Organization',
              'Subject',
              'Opened',
              'Action'
            ],
            rows: support
                .map((row) => [
                      _Pill(
                        label: _label(row.priority),
                        color:
                            row.priority == 'urgent' || row.priority == 'high'
                                ? const Color(0xFFFFE6E3)
                                : const Color(0xFFF2EAD7),
                      ),
                      Text(row.organization.isEmpty
                          ? 'Unassigned'
                          : row.organization),
                      Text(row.subject),
                      Text(_date(row.createdAt)),
                      FilledButton.tonal(
                        onPressed: _busyId == row.id
                            ? null
                            : () => _resolveSupport(row),
                        child: const Text('Resolve'),
                      ),
                    ])
                .toList(),
          ),
        ),
      ],
    );
  }

  bool _matches(String text) =>
      _query.trim().isEmpty ||
      text.toLowerCase().contains(_query.trim().toLowerCase());

  Future<void> _supplierDecision(
      AdminVerificationCase item, String decision) async {
    final reason = decision == 'rejected'
        ? await _askForNote('Reject supplier', 'Reason for rejection')
        : null;
    if (decision == 'rejected' && reason == null) return;
    await _run(
      item.id,
      () => widget.dataSource.reviewSupplier(item.id, decision, reason: reason),
      'Supplier review saved',
    );
  }

  Future<void> _listingDecision(
      AdminListingReview item, String decision) async {
    final reason = decision == 'rejected'
        ? await _askForNote('Reject listing', 'Reason for rejection')
        : null;
    if (decision == 'rejected' && reason == null) return;
    await _run(
      item.id,
      () => widget.dataSource.reviewListing(item.id, decision, reason: reason),
      'Listing review saved',
    );
  }

  Future<void> _resolveSupport(AdminSupportCase item) async {
    final resolution =
        await _askForNote('Resolve support case', 'Resolution note');
    if (resolution == null) return;
    await _run(
      item.id,
      () => widget.dataSource.resolveSupportCase(item.id, resolution),
      'Support case resolved',
    );
  }

  Future<String?> _askForNote(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          decoration: InputDecoration(labelText: label),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final value = controller.text.trim();
              if (value.length >= 3) Navigator.pop(context, value);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _run(
      String id, Future<void> Function() action, String success) async {
    setState(() => _busyId = id);
    try {
      await action();
      await _reload();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(success), behavior: SnackBarBehavior.floating),
        );
      }
    } on Object {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('The server could not complete this action.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }
}

class _Page extends StatelessWidget {
  const _Page(
      {required this.title, required this.subtitle, required this.children});
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1240),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .headlineMedium
                        ?.copyWith(color: _ink, fontWeight: FontWeight.w800)),
                const SizedBox(height: 5),
                Text(subtitle, style: const TextStyle(color: _muted)),
                const SizedBox(height: 24),
                ...children,
              ],
            ),
          ),
        ),
      );
}

class _Metric {
  const _Metric(this.label, this.value, this.note, this.icon);
  final String label;
  final String value;
  final String note;
  final IconData icon;
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid(this.metrics);
  final List<_Metric> metrics;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth < 620
              ? 1
              : constraints.maxWidth < 1000
                  ? 2
                  : 4;
          final width = (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: metrics
                .map((metric) =>
                    SizedBox(width: width, child: _MetricCard(metric: metric)))
                .toList(),
          );
        },
      );
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: _boxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                  color: const Color(0xFFE5EEE6),
                  borderRadius: BorderRadius.circular(11)),
              child: Icon(metric.icon, color: _green),
            ),
            const SizedBox(height: 15),
            Text(metric.label, style: const TextStyle(color: _muted)),
            const SizedBox(height: 5),
            Text(metric.value,
                style: const TextStyle(
                    fontSize: 25, fontWeight: FontWeight.w800, color: _ink)),
            Text(metric.note,
                style: const TextStyle(fontSize: 12, color: _muted)),
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
        decoration: _boxDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w800, color: _ink)),
            Text(subtitle, style: const TextStyle(color: _muted)),
            const SizedBox(height: 18),
            child,
          ],
        ),
      );
}

class _Table extends StatelessWidget {
  const _Table({required this.columns, required this.rows});
  final List<String> columns;
  final List<List<Widget>> rows;
  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const _EmptyState();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 28,
        columns: columns
            .map((column) => DataColumn(
                label: Text(column,
                    style: const TextStyle(fontWeight: FontWeight.w700))))
            .toList(),
        rows: rows
            .map((row) =>
                DataRow(cells: row.map((cell) => DataCell(cell)).toList()))
            .toList(),
      ),
    );
  }
}

class _RevenueChart extends StatelessWidget {
  const _RevenueChart(this.points);
  final List<AdminRevenuePoint> points;
  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return const _EmptyState(
          message: 'Revenue history appears after the first recognized event.');
    }
    final maximum =
        points.map((point) => point.amount).fold<double>(0, math.max);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: points
          .map((point) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(_compactMoney(point.amount),
                          style: const TextStyle(fontSize: 11, color: _muted)),
                      const SizedBox(height: 6),
                      Container(
                        height:
                            maximum == 0 ? 4 : 150 * point.amount / maximum + 4,
                        decoration: BoxDecoration(
                            color: _green,
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      const SizedBox(height: 8),
                      Text(_month(point.month),
                          style: const TextStyle(fontSize: 11, color: _muted)),
                    ],
                  ),
                ),
              ))
          .toList(),
    );
  }
}

class _PriorityActions extends StatelessWidget {
  const _PriorityActions(this.operations);
  final AdminOperations operations;
  @override
  Widget build(BuildContext context) => Column(children: [
        _Priority('Supplier verification', operations.verificationBacklog,
            Icons.verified_user_outlined),
        _Priority('Listing moderation', operations.listingsInReview,
            Icons.inventory_outlined),
        _Priority('High priority support', operations.highPriorityCases,
            Icons.support_agent_outlined),
      ]);
}

class _Priority extends StatelessWidget {
  const _Priority(this.label, this.count, this.icon);
  final String label;
  final int count;
  final IconData icon;
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
            backgroundColor: const Color(0xFFE5EEE6),
            child: Icon(icon, color: _green)),
        title: Text(label),
        trailing: Text('$count',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );
}

class _ActionButtons extends StatelessWidget {
  const _ActionButtons({
    required this.busy,
    required this.onApprove,
    required this.onReject,
    this.onReview,
  });
  final bool busy;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback? onReview;
  @override
  Widget build(BuildContext context) => busy
      ? const SizedBox.square(
          dimension: 22, child: CircularProgressIndicator(strokeWidth: 2))
      : Wrap(spacing: 6, children: [
          if (onReview != null)
            TextButton(onPressed: onReview, child: const Text('Review')),
          IconButton(
              onPressed: onApprove,
              tooltip: 'Approve',
              color: _green,
              icon: const Icon(Icons.check_circle_outline)),
          IconButton(
              onPressed: onReject,
              tooltip: 'Reject',
              color: const Color(0xFF9A3E34),
              icon: const Icon(Icons.cancel_outlined)),
        ]);
}

class _PlanGrid extends StatelessWidget {
  const _PlanGrid();
  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _Plan('Basic', 'Free', 'Listings and standard RFQs'),
          _Plan('Verified', 'SLE 250/mo', 'Trust badge and priority matching'),
          _Plan('Pro', 'SLE 650/mo', 'Insights and featured placement'),
        ],
      );
}

class _Plan extends StatelessWidget {
  const _Plan(this.name, this.price, this.detail);
  final String name;
  final String price;
  final String detail;
  @override
  Widget build(BuildContext context) => Container(
        width: 230,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _canvas,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _line)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(price,
              style: const TextStyle(
                  fontSize: 19, color: _green, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: _muted)),
        ]),
      );
}

class _UnitEconomics extends StatelessWidget {
  const _UnitEconomics();
  @override
  Widget build(BuildContext context) => const Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          _Target('Gross margin', '> 75%'),
          _Target('CAC payback', '< 6 months'),
          _Target('Supplier churn', '< 4% / mo'),
          _Target('RFQ response', '> 70%'),
        ],
      );
}

class _Target extends StatelessWidget {
  const _Target(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 180,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(value,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w800, color: _green)),
          subtitle: Text(label),
        ),
      );
}

class _Notice extends StatelessWidget {
  const _Notice({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
            color: const Color(0xFFEAF2ED),
            borderRadius: BorderRadius.circular(16)),
        child: Row(children: [
          const Icon(Icons.account_balance_outlined, color: _green),
          const SizedBox(width: 14),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                Text(message, style: const TextStyle(color: _muted)),
              ])),
        ]),
      );
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    this.color = const Color(0xFFE5EEE6),
    this.foreground = _ink,
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
            color: color, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, size: 15, color: foreground),
            const SizedBox(width: 5),
          ],
          Text(label,
              style: TextStyle(
                  color: foreground,
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ]),
      );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.dark});
  final bool dark;
  @override
  Widget build(BuildContext context) => Container(
        height: 58,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: dark ? null : Border.all(color: _line),
        ),
        child: const LumaBrand(height: 46),
      );
}

class _SecurityCard extends StatelessWidget {
  const _SecurityCard();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: Colors.white10, borderRadius: BorderRadius.circular(14)),
        child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.admin_panel_settings_outlined, color: Colors.white70),
              SizedBox(height: 8),
              Text('Protected workspace',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
              Text('Server authorization and 2FA required',
                  style: TextStyle(color: Colors.white60, fontSize: 12)),
            ]),
      );
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({this.message = 'No records match this view.'});
  final String message;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 30),
        child: Center(
          child: Column(children: [
            const Icon(Icons.inbox_outlined, color: _muted),
            const SizedBox(height: 8),
            Text(message, style: const TextStyle(color: _muted)),
          ]),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 42, color: _muted),
          const SizedBox(height: 12),
          const Text('Dashboard data is unavailable',
              style: TextStyle(fontWeight: FontWeight.w800)),
          const Text('Check your session and try again.',
              style: TextStyle(color: _muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry')),
        ]),
      );
}

final _boxDecoration = BoxDecoration(
  color: Colors.white,
  border: Border.all(color: _line),
  borderRadius: BorderRadius.circular(18),
);

String _money(double value) =>
    'SLE ${value.toStringAsFixed(value % 1 == 0 ? 0 : 2)}';
String _compactMoney(double value) => value >= 1000000
    ? 'SLE ${(value / 1000000).toStringAsFixed(1)}m'
    : value >= 1000
        ? 'SLE ${(value / 1000).toStringAsFixed(1)}k'
        : 'SLE ${value.toStringAsFixed(0)}';
String _label(String value) => value
    .split('_')
    .map((word) =>
        word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');
String _date(DateTime? value) => value == null
    ? '—'
    : '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _dateTime(DateTime value) =>
    '${_date(value)} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
String _month(DateTime? value) => value == null
    ? '—'
    : const [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ][value.month - 1];
