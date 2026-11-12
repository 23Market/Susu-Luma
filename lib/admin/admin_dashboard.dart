import 'package:flutter/material.dart';

/// Production adapters must authorize every read on the server.
abstract interface class AdminRepository {
  Future<AdminSnapshot> load();
}

class AdminSnapshot {
  const AdminSnapshot({required this.updatedAt, required this.records});
  final DateTime updatedAt;
  final List<AdminRecord> records;
}

class AdminRecord {
  const AdminRecord(
      {required this.reference,
      required this.section,
      required this.title,
      required this.status});
  final String reference, section, title, status;
}

class UnconfiguredAdminRepository implements AdminRepository {
  const UnconfiguredAdminRepository();
  @override
  Future<AdminSnapshot> load() => Future.error(StateError(
      'Secure admin service is not configured. No live records are available.'));
}

const adminSections = <String>[
  'Overview',
  'Supplier verification',
  'Listings',
  'RFQs',
  'Quotations',
  'Orders',
  'Payment status',
  'Fulfilment',
  'Support',
  'Reviews & reports',
  'Audit log',
];

class AdminDashboard extends StatefulWidget {
  const AdminDashboard(
      {super.key, this.repository = const UnconfiguredAdminRepository()});
  final AdminRepository repository;
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late Future<AdminSnapshot> _snapshot;
  String _section = adminSections.first;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _snapshot = widget.repository.load();
  }

  @override
  void didUpdateWidget(covariant AdminDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.repository != widget.repository) {
      _snapshot = widget.repository.load();
    }
  }

  void _select(int index) => setState(() {
        _section = adminSections[index];
        _query = '';
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Luma administration')),
        body: Column(children: [
          const MaterialBanner(
            content: Text(
                'Development console. Live authentication, permissions and data are not connected.'),
            actions: [SizedBox.shrink()],
          ),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 1000;
            return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (wide)
                SizedBox(
                    width: 240,
                    child: ListView(
                      children: [
                        for (var i = 0; i < adminSections.length; i++)
                          ListTile(
                              title: Text(adminSections[i]),
                              selected: _section == adminSections[i],
                              onTap: () => _select(i)),
                      ],
                    )),
              Expanded(
                  child: Column(children: [
                if (!wide)
                  Padding(
                      padding: const EdgeInsets.all(16),
                      child: DropdownButtonFormField<String>(
                        initialValue: _section,
                        isExpanded: true,
                        decoration:
                            const InputDecoration(labelText: 'Admin section'),
                        items: [
                          for (final section in adminSections)
                            DropdownMenuItem(
                                value: section, child: Text(section))
                        ],
                        onChanged: (value) =>
                            _select(adminSections.indexOf(value!)),
                      )),
                Expanded(
                    child: FutureBuilder<AdminSnapshot>(
                        future: _snapshot,
                        builder: (context, state) {
                          if (state.connectionState != ConnectionState.done) {
                            return const Center(
                                child: CircularProgressIndicator(
                                    semanticsLabel: 'Loading admin records'));
                          }
                          if (state.hasError) {
                            return Center(
                                child: Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Text(
                                              'Admin records unavailable',
                                              style: TextStyle(fontSize: 22)),
                                          const SizedBox(height: 12),
                                          const Text(
                                              'Check the secure service configuration or sign in again. No changes have been made.',
                                              textAlign: TextAlign.center),
                                          const SizedBox(height: 16),
                                          FilledButton(
                                              onPressed: () => setState(() {
                                                    _snapshot = widget
                                                        .repository
                                                        .load();
                                                  }),
                                              child: const Text('Retry')),
                                        ])));
                          }
                          final snapshot = state.requireData;
                          final scoped = snapshot.records
                              .where((record) =>
                                  _section == 'Overview' ||
                                  record.section == _section)
                              .toList();
                          final records = scoped
                              .where((record) =>
                                  '${record.reference} ${record.title} ${record.status}'
                                      .toLowerCase()
                                      .contains(_query.toLowerCase()))
                              .toList();
                          return ListView(
                              padding: const EdgeInsets.all(24),
                              children: [
                                Text(_section,
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium),
                                Text(
                                    'Updated ${snapshot.updatedAt.toUtc().toIso8601String()} (UTC)'),
                                const SizedBox(height: 16),
                                TextField(
                                    key: ValueKey(_section),
                                    decoration: const InputDecoration(
                                        labelText: 'Filter loaded records',
                                        prefixIcon: Icon(Icons.search)),
                                    onChanged: (value) =>
                                        setState(() => _query = value)),
                                const SizedBox(height: 16),
                                Text('${records.length} records'),
                                if (records.isEmpty)
                                  const Padding(
                                      padding:
                                          EdgeInsets.symmetric(vertical: 24),
                                      child: Text(
                                          'No records match this section and filter.')),
                                for (final record in records)
                                  Card(
                                      child: ListTile(
                                          title: Text(record.title),
                                          subtitle: Text(
                                              '${record.reference} · ${record.section}'),
                                          trailing: Text(record.status))),
                                if (_section == 'Payment status')
                                  const Text(
                                      'Reported payments remain unverified until authoritative evidence is reviewed. Luma does not hold or settle funds.'),
                              ]);
                        })),
              ])),
            ]);
          })),
        ]),
      );
}
