import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/ids_time.dart';
import '../data/expense_repository.dart';
import '../data/models/expense.dart';
import 'common.dart';
import 'live_query.dart';

IconData _iconFor(String category) {
  switch (category) {
    case 'Marchandises':
      return Icons.shopping_basket_outlined;
    case 'Transport':
      return Icons.local_shipping_outlined;
    case 'Loyer':
      return Icons.home_work_outlined;
    case 'Électricité / Eau':
      return Icons.bolt_outlined;
    case 'Salaires':
      return Icons.groups_outlined;
    default:
      return Icons.receipt_long_outlined;
  }
}

class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  Future<void> _openForm(BuildContext context) async {
    final repo = context.read<ExpenseRepository>();
    final draft = await showModalBottomSheet<_ExpenseDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ExpenseForm(),
    );
    if (draft != null) {
      await repo.create(category: draft.category, amount: draft.amount, note: draft.note);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.read<ExpenseRepository>();
    return Scaffold(
      body: LiveQuery<List<Expense>>(
        load: () => repo.recent(),
        builder: (context, expenses) {
          if (expenses.isEmpty) {
            return const EmptyState(
              icon: Icons.receipt_long,
              message: 'Aucune dépense enregistrée.\nNotez vos achats et frais pour suivre votre bénéfice.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 88),
            itemCount: expenses.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final expense = expenses[index];
              final date = formatDateTime(parseLocal(expense.spentAt));
              return ListTile(
                leading: Icon(_iconFor(expense.category)),
                title: Text(formatFcfa(expense.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                  expense.note == null
                      ? '${expense.category} • $date'
                      : '${expense.category} • ${expense.note}\n$date',
                ),
                isThreeLine: expense.note != null,
                trailing: IconButton(
                  tooltip: 'Supprimer',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await confirmDelete(context, 'Supprimer cette dépense ?')) {
                      await repo.delete(expense);
                    }
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-expenses',
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Nouvelle dépense'),
      ),
    );
  }
}

class _ExpenseDraft {
  const _ExpenseDraft(this.category, this.amount, this.note);

  final String category;
  final int amount;
  final String? note;
}

class _ExpenseForm extends StatefulWidget {
  const _ExpenseForm();

  @override
  State<_ExpenseForm> createState() => _ExpenseFormState();
}

class _ExpenseFormState extends State<_ExpenseForm> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _category = ExpenseCategories.all.first;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = int.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0) return;
    Navigator.pop(context, _ExpenseDraft(_category, amount, _note.text));
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nouvelle dépense', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in ExpenseCategories.all)
                ChoiceChip(
                  label: Text(category),
                  selected: category == _category,
                  onSelected: (_) => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(9),
            ],
            decoration: const InputDecoration(labelText: 'Montant (FCFA)'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(labelText: 'Note (facultatif)'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(onPressed: _submit, child: const Text('Enregistrer')),
          ),
        ],
      ),
    );
  }
}
