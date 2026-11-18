// ignore: deprecated_member_use -- Flutter 3.50 prefers material_ui; keep the SDK-wide import until the project migrates.
import 'package:flutter/material.dart';
import '../models.dart';
import '../store.dart';
import '../ui.dart';

// ---------- RFQ list + detail ----------
class RfqsTab extends StatelessWidget {
  const RfqsTab({super.key, this.onBrowse});
  final VoidCallback? onBrowse;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isBuyer = store.role == Role.buyer;
    final list = store.myRfqs;
    return ListView(padding: const EdgeInsets.all(20), children: [
      PageTitle(
          isBuyer ? 'My RFQs' : 'RFQ inbox',
          isBuyer
              ? 'Track quote requests and compare supplier quotes.'
              : 'Buyer requests routed to your business.'),
      if (list.isEmpty)
        EmptyState(
            icon: Icons.request_quote_rounded,
            text: isBuyer
                ? 'Your quote requests will appear here.'
                : 'No RFQs yet.',
            actionLabel: isBuyer ? 'Browse products' : null,
            onAction: onBrowse),
      for (final r in list)
        AppCard(
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => RfqDetailScreen(rfq: r))),
          child: Row(children: [
            const Icon(Icons.request_quote_rounded, color: green),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(r.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(
                      '${r.ref} · ${_qty(r.quantity)} ${r.unit}${isBuyer ? ' · ${store.supplier(r.supplierId).name}' : ''}',
                      style: const TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 6, children: [
                    StatusChip(enumLabel(r.status), tone: rfqTone(r.status)),
                    if (r.quotes.isNotEmpty)
                      StatusChip(
                          '${r.quotes.length} quote${r.quotes.length == 1 ? '' : 's'}')
                  ]),
                ])),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
    ]);
  }
}

String _qty(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

class RfqDetailScreen extends StatelessWidget {
  const RfqDetailScreen({super.key, required this.rfq});
  final Rfq rfq;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isBuyer = store.role == Role.buyer;
    final open =
        rfq.status == RfqStatus.submitted || rfq.status == RfqStatus.quoted;
    return Scaffold(
      appBar: AppBar(title: Text(rfq.ref)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        PageTitle(rfq.productName),
        AppCard(
            child: Column(children: [
          LabelValue('Status', enumLabel(rfq.status)),
          LabelValue('Quantity', '${_qty(rfq.quantity)} ${rfq.unit}'),
          LabelValue(isBuyer ? 'Supplier' : 'Buyer',
              isBuyer ? store.supplier(rfq.supplierId).name : rfq.buyerName),
          LabelValue('Deliver to', rfq.district),
          LabelValue('Target date', rfq.target ?? 'Flexible'),
          LabelValue('Notes', rfq.notes.isEmpty ? '—' : rfq.notes),
        ])),
        const SizedBox(height: 4),
        const Text('Quotes',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 8),
        if (rfq.quotes.isEmpty)
          AppCard(
              child: Text(
                  isBuyer
                      ? 'Waiting for the supplier to quote. Tip: switch to the supplier persona from Business to reply in this demo.'
                      : 'No quote sent yet.',
                  style: const TextStyle(color: muted))),
        for (final q in rfq.quotes.reversed)
          AppCard(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                if (q.supplierName.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(q.supplierName,
                          style: const TextStyle(fontWeight: FontWeight.w700))),
                Row(children: [
                  Expanded(
                      child: Text(
                          '${money(q.unitPrice, q.currency)} per ${rfq.unit}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: green))),
                  StatusChip(enumLabel(q.status),
                      tone: q.status == QuoteStatus.accepted
                          ? ChipTone.good
                          : q.status == QuoteStatus.declined
                              ? ChipTone.bad
                              : ChipTone.warn)
                ]),
                const SizedBox(height: 6),
                Text(
                    'Total ${money(q.unitPrice * rfq.quantity, q.currency)} · lead time ${q.leadDays} days · valid ${q.validDays} days',
                    style: const TextStyle(fontSize: 12, color: muted)),
                if (q.terms.isNotEmpty)
                  Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(q.terms)),
                if (isBuyer &&
                    rfq.status == RfqStatus.quoted &&
                    q.status == QuoteStatus.submitted)
                  Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: FilledButton(
                          onPressed: () => _accept(context, store, q),
                          child: const Text('Accept quote'))),
              ])),
        if (!isBuyer && open)
          FilledButton.icon(
              onPressed: () => _quoteSheet(context, store),
              icon: const Icon(Icons.edit_note_rounded),
              label: Text(
                  rfq.quotes.isEmpty ? 'Send quote' : 'Send revised quote')),
        if (isBuyer && open)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: OutlinedButton(
                  onPressed: () => _cancel(context, store),
                  child: const Text('Cancel RFQ'))),
        const Disclaimer(
            'Quotes show an explicit currency and unit. Accepting a quote creates an order snapshot of these terms. $paymentNotice'),
      ]),
    );
  }

  Future<void> _accept(BuildContext context, AppStore store, Quote q) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
                title: const Text('Accept this quote?'),
                content: Text(
                    '${_qty(rfq.quantity)} ${rfq.unit} at ${money(q.unitPrice, q.currency)} per ${rfq.unit} (total ${money(q.unitPrice * rfq.quantity, q.currency)}). The supplier must then confirm the order.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(c, false),
                      child: const Text('Not yet')),
                  FilledButton(
                      onPressed: () => Navigator.pop(c, true),
                      child: const Text('Accept'))
                ]));
    if (ok != true || !context.mounted) return;
    final order = await guarded(context, () => store.acceptQuote(rfq, q));
    if (order == null || !context.mounted) return;
    Navigator.pushReplacement(
        context,
        MaterialPageRoute<void>(
            builder: (_) => OrderDetailScreen(order: order)));
  }

  Future<void> _cancel(BuildContext context, AppStore store) async {
    final ok = await showDialog<bool>(
        context: context,
        builder: (c) =>
            AlertDialog(title: const Text('Cancel this RFQ?'), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(c, false),
                  child: const Text('Keep')),
              FilledButton(
                  onPressed: () => Navigator.pop(c, true),
                  child: const Text('Cancel RFQ'))
            ]));
    if (ok != true || !context.mounted) return;
    await guarded(context, () => store.cancelRfq(rfq));
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> _quoteSheet(BuildContext context, AppStore store) =>
      showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          showDragHandle: true,
          builder: (c) => _QuoteForm(store: store, rfq: rfq));
}

class _QuoteForm extends StatefulWidget {
  const _QuoteForm({required this.store, required this.rfq});
  final AppStore store;
  final Rfq rfq;
  @override
  State<_QuoteForm> createState() => _QuoteFormState();
}

class _QuoteFormState extends State<_QuoteForm> {
  final _form = GlobalKey<FormState>();
  final _price = TextEditingController(),
      _lead = TextEditingController(text: '3'),
      _valid = TextEditingController(text: '7'),
      _terms = TextEditingController();
  @override
  void dispose() {
    _price.dispose();
    _lead.dispose();
    _valid.dispose();
    _terms.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 20),
        child: Form(
            key: _form,
            child: SingleChildScrollView(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text('Quote for ${widget.rfq.productName}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 18)),
                  const SizedBox(height: 12),
                  TextFormField(
                      controller: _price,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                          labelText: 'Unit price (SLE per ${widget.rfq.unit})'),
                      validator: (v) => (double.tryParse(v ?? '') ?? 0) > 0
                          ? null
                          : 'Enter a price above zero'),
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                        child: TextFormField(
                            controller: _lead,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Lead time (days)'),
                            validator: (v) => (int.tryParse(v ?? '') ?? -1) >= 0
                                ? null
                                : 'Invalid')),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextFormField(
                            controller: _valid,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Valid for (days)'),
                            validator: (v) => (int.tryParse(v ?? '') ?? 0) > 0
                                ? null
                                : 'Invalid')),
                  ]),
                  const SizedBox(height: 10),
                  TextFormField(
                      controller: _terms,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Terms and exclusions')),
                  const SizedBox(height: 14),
                  SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                          onPressed: () async {
                            if (!_form.currentState!.validate()) return;
                            final q = await guarded(
                                context,
                                () => widget.store.submitQuote(widget.rfq,
                                    unitPrice: double.parse(_price.text),
                                    leadDays: int.parse(_lead.text),
                                    validDays: int.parse(_valid.text),
                                    terms: _terms.text.trim()));
                            if (q == null || !context.mounted) return;
                            Navigator.pop(context);
                            notice(context, 'Quote sent to buyer.');
                          },
                          child: const Text('Send quote'))),
                ]))),
      );
}

// ---------- Orders ----------
class OrdersTab extends StatelessWidget {
  const OrdersTab({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.myOrders;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const PageTitle('Orders', 'Confirmed purchases and delivery progress.'),
      if (list.isEmpty)
        const EmptyState(
            icon: Icons.local_shipping_outlined,
            text: 'Accepted quotes become orders here.'),
      for (final o in list)
        AppCard(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute<void>(
                  builder: (_) => OrderDetailScreen(order: o))),
          child: Row(children: [
            const Icon(Icons.local_shipping_outlined, color: green),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(o.productName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('${o.ref} · ${money(o.total, o.currency)}',
                      style: const TextStyle(color: muted, fontSize: 12)),
                  const SizedBox(height: 6),
                  StatusChip(enumLabel(o.status), tone: orderTone(o.status)),
                ])),
            const Icon(Icons.chevron_right_rounded, color: muted),
          ]),
        ),
    ]);
  }
}

class OrderDetailScreen extends StatelessWidget {
  const OrderDetailScreen({super.key, required this.order});
  final Order order;
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final o = order, isBuyer = store.role == Role.buyer;
    final active = o.status == OrderStatus.confirmed ||
        o.status == OrderStatus.inFulfilment;
    return Scaffold(
      appBar: AppBar(title: Text(o.ref)),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        PageTitle(o.productName),
        AppCard(
            child: Column(children: [
          LabelValue('Status', enumLabel(o.status)),
          LabelValue(isBuyer ? 'Supplier' : 'Buyer',
              isBuyer ? store.supplier(o.supplierId).name : o.buyerName),
          LabelValue('Quantity', '${_qty(o.quantity)} ${o.unit}'),
          LabelValue(
              'Unit price', '${money(o.unitPrice, o.currency)} per ${o.unit}'),
          LabelValue('Total', money(o.total, o.currency)),
          LabelValue('Lead time', '${o.leadDays} days'),
          LabelValue('From RFQ', o.rfqRef),
          LabelValue('Payment', snakeLabel(o.paymentStatus)),
        ])),
        const Disclaimer(paymentNotice),
        const SizedBox(height: 8),
        const Text('Delivery timeline',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
        const SizedBox(height: 8),
        if (o.events.isEmpty)
          const AppCard(
              child: Text('No updates yet.', style: TextStyle(color: muted))),
        for (final e in o.events.reversed)
          AppCard(
              margin: const EdgeInsets.only(bottom: 8),
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.check_circle_outline_rounded,
                    color: green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text(snakeLabel(e.type),
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (e.note.isNotEmpty) Text(e.note),
                      Text(shortDate(e.at),
                          style: const TextStyle(fontSize: 11, color: muted))
                    ])),
              ])),
        const SizedBox(height: 8),
        if (!isBuyer && o.status == OrderStatus.awaitingSellerConfirmation)
          FilledButton(
              onPressed: () async {
                await guarded(context, () => store.confirmOrder(o));
                if (context.mounted) notice(context, 'Order confirmed.');
              },
              child: const Text('Confirm order')),
        if (!isBuyer && active) ...[
          const Text('Add delivery update',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: [
            for (final s in AppStore.deliverySteps)
              OutlinedButton(
                  onPressed: () =>
                      guarded(context, () => store.addDeliveryEvent(o, s, '')),
                  child: Text(snakeLabel(s)))
          ]),
        ],
        if (isBuyer && (active || o.status == OrderStatus.delivered))
          OutlinedButton(
              onPressed: () => _report(context, store),
              child: const Text('Report a problem')),
        if (o.status == OrderStatus.disputed)
          const AppCard(
              child: Text(
                  'A problem was reported. Susu Luma support will review and contact both parties.',
                  style: TextStyle(color: muted))),
      ]),
    );
  }

  Future<void> _report(BuildContext context, AppStore store) async {
    final c = TextEditingController();
    final text = await showDialog<String>(
        context: context,
        builder: (d) => AlertDialog(
                title: const Text('Report a problem'),
                content: TextField(
                    controller: c,
                    maxLines: 3,
                    decoration:
                        const InputDecoration(hintText: 'What went wrong?')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(d),
                      child: const Text('Cancel')),
                  FilledButton(
                      onPressed: () => Navigator.pop(d, c.text.trim()),
                      child: const Text('Submit'))
                ]));
    c.dispose();
    if (text != null && text.isNotEmpty && context.mounted) {
      await guarded(context, () => store.reportProblem(order, text));
    }
  }
}

// ---------- Messages ----------
class MessagesTab extends StatelessWidget {
  const MessagesTab({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final list = store.myThreads;
    return ListView(padding: const EdgeInsets.all(20), children: [
      const PageTitle('Messages', 'Conversations about RFQs and orders.'),
      if (list.isEmpty)
        const EmptyState(
            icon: Icons.forum_outlined,
            text: 'Conversations start when you request a quote.'),
      for (final t in list)
        AppCard(
          onTap: () => Navigator.push(context,
              MaterialPageRoute<void>(builder: (_) => ChatScreen(thread: t))),
          child: Row(children: [
            const CircleAvatar(
                backgroundColor: Color(0xFFE5EEE6),
                child: Icon(Icons.business_rounded, color: green)),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(
                      store.role == Role.buyer
                          ? store.supplier(t.supplierId).name
                          : t.buyerName,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(t.title,
                      style: const TextStyle(fontSize: 12, color: green)),
                  if (t.messages.isNotEmpty)
                    Text(t.messages.last.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: muted, fontSize: 12)),
                ])),
          ]),
        ),
    ]);
  }
}

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key, required this.thread});
  final Thread thread;
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _c = TextEditingController();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final msgs = widget.thread.messages;
    return Scaffold(
      appBar: AppBar(title: Text(widget.thread.title)),
      body: Column(children: [
        Expanded(
            child: ListView(padding: const EdgeInsets.all(16), children: [
          for (final m in msgs)
            Align(
              alignment: m.from == store.role
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  constraints: const BoxConstraints(maxWidth: 290),
                  decoration: BoxDecoration(
                      color: m.from == store.role ? green : Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: Text(m.text,
                      style: TextStyle(
                          color: m.from == store.role ? Colors.white : ink))),
            ),
        ])),
        SafeArea(
            child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(children: [
                  Expanded(
                      child: TextField(
                          controller: _c,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(store),
                          decoration: const InputDecoration(
                              hintText: 'Write a message'))),
                  const SizedBox(width: 8),
                  IconButton.filled(
                      tooltip: 'Send',
                      onPressed: () => _send(store),
                      icon: const Icon(Icons.send_rounded)),
                ]))),
      ]),
    );
  }

  Future<void> _send(AppStore store) async {
    final text = _c.text;
    _c.clear();
    await guarded(context, () => store.send(widget.thread, text));
  }
}

// ---------- Business profile ----------
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final isBuyer = store.role == Role.buyer;
    final name = store.myBusiness.name;
    return Scaffold(
      appBar: AppBar(title: const Text('Business')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        AppCard(
            child: Column(children: [
          const CircleAvatar(
              radius: 32,
              backgroundColor: Color(0xFFE5EEE6),
              child: Icon(Icons.business_rounded, size: 32, color: green)),
          const SizedBox(height: 12),
          Text(name,
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          Text(isBuyer ? 'Buyer account (demo)' : 'Supplier account (demo)',
              style: const TextStyle(color: muted)),
          if (!isBuyer)
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StatusChip('Verification: ${store.verificationStatus}',
                    tone: ChipTone.good)),
        ])),
        if (!isBuyer)
          const Disclaimer(
              'Verification confirms the evidence reviewed within a stated scope and period. It is not an endorsement or guarantee of any product or transaction.'),
        if (isBuyer)
          AppCard(
              child: Row(children: [
            const Icon(Icons.bookmarks_outlined, color: green),
            const SizedBox(width: 12),
            Text('${store.saved.length} saved products',
                style: const TextStyle(fontWeight: FontWeight.w700))
          ])),
        AppCard(
            onTap: () => notice(context,
                'Support contact and escalation policy must be configured before pilot.'),
            child: const Row(children: [
              Icon(Icons.help_outline_rounded, color: green),
              SizedBox(width: 12),
              Text('Help & support',
                  style: TextStyle(fontWeight: FontWeight.w700))
            ])),
        const SizedBox(height: 8),
        OutlinedButton.icon(
            onPressed: () {
              Navigator.popUntil(context, (r) => r.isFirst);
              store.signOut();
            },
            icon: const Icon(Icons.swap_horiz_rounded),
            label: Text(isBuyer
                ? 'Sign out / switch to supplier demo'
                : 'Sign out / switch to buyer demo')),
        const Disclaimer(
            'Susu Luma is a marketplace and does not itself sell the listed products. No payments, escrow or wallet services are enabled.'),
      ]),
    );
  }
}
