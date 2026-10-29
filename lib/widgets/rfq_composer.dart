import 'package:flutter/material.dart';

import '../models/rfq_draft.dart';

/// A local-only RFQ composer. The parent decides what to do with a valid draft.
class RfqComposer extends StatefulWidget {
  const RfqComposer({
    super.key,
    required this.productName,
    required this.supplierName,
    required this.suggestedUnit,
  });

  final String productName;
  final String supplierName;
  final String suggestedUnit;

  @override
  State<RfqComposer> createState() => _RfqComposerState();
}

class _RfqComposerState extends State<RfqComposer> {
  final _formKey = GlobalKey<FormState>();
  final _quantityController = TextEditingController(text: '1');
  final _unitController = TextEditingController();
  final _locationController = TextEditingController();
  final _notesController = TextEditingController();
  String? _error;

  @override
  void initState() {
    super.initState();
    _unitController.text = widget.suggestedUnit;
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _unitController.dispose();
    _locationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = double.tryParse(_quantityController.text.trim());
    final draft = RfqDraft(
      items: [
        RfqLineItem(
          productName: widget.productName,
          quantity: quantity ?? double.nan,
          unit: _unitController.text,
        ),
      ],
      deliveryLocation: _locationController.text,
      notes: _notesController.text.trim(),
    );
    final errors = draft.validate();
    if (errors.isNotEmpty) {
      setState(() => _error = errors.join('\n'));
      return;
    }
    Navigator.of(context).pop(draft);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Request a quote'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.productName,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('Supplier: ${widget.supplierName}'),
                const SizedBox(height: 16),
                TextField(
                  controller: _quantityController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Quantity',
                    helperText: 'Enter a number greater than zero',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _unitController,
                  decoration: const InputDecoration(
                    labelText: 'Unit of measure',
                    hintText: 'e.g. bag, kg, length',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Delivery location',
                    hintText: 'District, town or area',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Additional requirements (optional)',
                    alignLabelWithHint: true,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 8),
                const Text(
                  'Local draft only. This does not contact the supplier or submit an RFQ.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: _submit, child: const Text('Save draft')),
        ],
      );
}
