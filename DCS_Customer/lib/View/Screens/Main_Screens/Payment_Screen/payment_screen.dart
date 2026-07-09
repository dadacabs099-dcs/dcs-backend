import 'package:flutter/material.dart' hide Text;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Screens/Nav_Screens/navigation_providers.dart';

import 'package:intl/intl.dart';
import 'package:Dadacabs/Container/Repositories/payment_repo.dart';
import 'package:Dadacabs/Container/Repositories/user_repo.dart';
import 'package:Dadacabs/Model/payment_model.dart';
import 'package:Dadacabs/Model/user_model.dart';
import 'package:Dadacabs/Container/Services/phonepe_service.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'dart:math';

import 'package:Dadacabs/Container/Providers/user_data_provider.dart';

final userPaymentsProvider = StreamProvider<List<PaymentModel>>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value([]);
  return ref.read(globalPaymentRepoProvider).getUserPayments(user.uid);
});

final walletTransactionsProvider = StreamProvider<List<PaymentModel>>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value([]);
  return ref.read(globalPaymentRepoProvider).getWalletTransactions(user.uid);
});

final userProfileProvider = StreamProvider<UserModel?>((ref) {
  final user = ref.watch(userDataProvider);
  if (user == null) return Stream.value(null);
  return ref.read(globalUserRepoProvider).streamUserProfile(user.uid);
});

class PaymentScreen extends ConsumerStatefulWidget {
  const PaymentScreen({super.key});

  @override
  ConsumerState<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends ConsumerState<PaymentScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initPhonePe();
  }

  void _initPhonePe() {
    ref.read(phonePeServiceProvider).initSDK().then((isInitialized) {
      debugPrint("PhonePe SDK Initialized: $isInitialized");
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userAsync = ref.watch(userProfileProvider);
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.menu_rounded, 
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
          onPressed: () => ref.read(navigationScaffoldKeyProvider).currentState?.openDrawer(),
        ),
        title: TranslatedText(
          'Payments & Wallet',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontFamily: "bold",
            fontSize: 20,
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: IndianHeritageColors.primaryYellow,
          labelColor: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal,
          unselectedLabelColor: Colors.grey,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          tabs: [
            Tab(child: TranslatedText('Wallet')),
            Tab(child: TranslatedText('History')),
            Tab(child: TranslatedText('Methods')),
          ],
        ),
      ),
      body: userAsync.when(
        data: (user) => user != null
            ? TabBarView(
                controller: _tabController,
                children: [
                  _buildWalletTab(context, ref, user, isDark),
                  _buildHistoryTab(context, ref, isDark),
                  _buildMethodsTab(context, ref, user, isDark),
                ],
              )
            : _buildNoUserContent(context, isDark),
        loading: () => const Center(child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow)),
        error: (err, stack) => Center(
          child: Text(
            "Error: $err", 
            style: TextStyle(color: isDark ? Colors.white : IndianHeritageColors.charcoal),
          ),
        ),
      ),
    );
  }

  Widget _buildWalletTab(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    final walletAsync = ref.watch(walletTransactionsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Wallet Balance Card (Heritage Saffron/Gold design)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [IndianHeritageColors.primaryYellow, IndianHeritageColors.deepGold],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: IndianHeritageColors.primaryYellow.withOpacity(0.25),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Wallet Balance",
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: IndianHeritageColors.charcoal.withOpacity(0.8),
                        fontSize: 16,
                        fontFamily: "bold",
                      ),
                    ),
                    const Icon(
                      Icons.account_balance_wallet,
                      color: IndianHeritageColors.charcoal,
                      size: 30,
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Text(
                  "₹${user.walletBalance?.toStringAsFixed(2) ?? '0.00'}",
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontFamily: "bold",
                    fontSize: 36,
                    color: IndianHeritageColors.charcoal,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _showAddMoneyDialog(context, ref, user, isDark),
                        icon: const Icon(Icons.add, color: IndianHeritageColors.primaryYellow),
                        label: TranslatedText('Add Money'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: IndianHeritageColors.charcoal,
                          foregroundColor: IndianHeritageColors.primaryYellow,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontFamily: "bold", fontSize: 14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.send),
                        label: TranslatedText('Send'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: IndianHeritageColors.charcoal,
                          side: const BorderSide(color: IndianHeritageColors.charcoal, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          textStyle: const TextStyle(fontFamily: "bold", fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          
          // Recent Wallet Transactions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TranslatedText(
                'Recent Transactions',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  fontFamily: "bold",
                  fontSize: 18,
                  color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                ),
              ),
              TextButton(
                onPressed: () {
                  _tabController.animateTo(1);
                },
                child: TranslatedText(
                  'View All',
                  style: const TextStyle(color: IndianHeritageColors.primaryYellow, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          
          walletAsync.when(
            data: (transactions) {
              if (transactions.isEmpty) {
                return _buildEmptyTransactions(context, isDark);
              }
              return Column(
                children: transactions.take(5).map((payment) {
                  return _buildTransactionItem(context, payment, isDark);
                }).toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow)),
            error: (err, stack) => Text(
              "Error: $err",
              style: TextStyle(color: isDark ? Colors.white : IndianHeritageColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(BuildContext context, WidgetRef ref, bool isDark) {
    final paymentsAsync = ref.watch(userPaymentsProvider);

    return paymentsAsync.when(
      data: (payments) {
        if (payments.isEmpty) {
          return _buildEmptyTransactions(context, isDark);
        }
        return ListView.builder(
          padding: const EdgeInsets.all(15),
          itemCount: payments.length,
          itemBuilder: (context, index) {
            final payment = payments[index];
            return _buildPaymentCard(context, payment, isDark);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator(color: IndianHeritageColors.primaryYellow)),
      error: (err, stack) => Center(
        child: Text(
          "Error: $err", 
          style: TextStyle(color: isDark ? Colors.white : IndianHeritageColors.charcoal),
        ),
      ),
    );
  }

  Widget _buildMethodsTab(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TranslatedText(
            'Payment Methods',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: "bold",
              fontSize: 18,
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          const SizedBox(height: 20),
          
          // Cash Option
          _buildPaymentMethodCard(
            context,
            icon: Icons.money,
            title: "Cash",
            subtitle: "Pay with cash after ride",
            isSelected: user.preferredPaymentMethod == 'cash',
            isDark: isDark,
            onTap: () => ref.read(globalUserRepoProvider).updatePreferredPaymentMethod(user.uid, 'cash', context),
          ),
          const SizedBox(height: 15),
          
          // Wallet Option
          _buildPaymentMethodCard(
            context,
            icon: Icons.account_balance_wallet,
            title: "Wallet",
            subtitle: "Balance: ₹${user.walletBalance?.toStringAsFixed(0) ?? '0'}",
            isSelected: user.preferredPaymentMethod == 'wallet',
            isDark: isDark,
            onTap: () => ref.read(globalUserRepoProvider).updatePreferredPaymentMethod(user.uid, 'wallet', context),
          ),
          const SizedBox(height: 15),
          
          // UPI App Option
          _buildPaymentMethodCard(
            context,
            icon: Icons.app_shortcut,
            title: "UPI App",
            subtitle: "Google Pay, PhonePe, Paytm",
            isSelected: user.preferredPaymentMethod == 'upi_app',
            isDark: isDark,
            onTap: () => ref.read(globalUserRepoProvider).updatePreferredPaymentMethod(user.uid, 'upi_app', context),
          ),
          const SizedBox(height: 15),

          // UPI VPA Option
          _buildPaymentMethodCard(
            context,
            icon: Icons.qr_code,
            title: "UPI ID (VPA)",
            subtitle: "Enter your UPI ID manually",
            isSelected: user.preferredPaymentMethod == 'upi_vpa',
            isDark: isDark,
            onTap: () => _showAddVpaDialog(context, ref, user, isDark),
          ),
          const SizedBox(height: 15),
          
          // Card Option
          _buildPaymentMethodCard(
            context,
            icon: Icons.credit_card,
            title: "Credit/Debit Card",
            subtitle: "Add a card",
            isSelected: user.preferredPaymentMethod == 'card',
            isDark: isDark,
            onTap: () => ref.read(globalUserRepoProvider).updatePreferredPaymentMethod(user.uid, 'card', context),
            onAdd: () => _showAddCardDialog(context, isDark),
          ),
          const SizedBox(height: 30),
          
          // Add Method Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.add),
              label: TranslatedText('Add Payment Method'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal,
                side: BorderSide(color: isDark ? IndianHeritageColors.primaryYellow : IndianHeritageColors.charcoal),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(BuildContext context, PaymentModel payment, bool isDark) {
    final dateFormat = DateFormat('MMM dd, yyyy • hh:mm a');
    final isWalletTopup = payment.tripId.isEmpty;
    final isCompleted = payment.status == PaymentStatus.completed;

    return Card(
      color: isDark ? IndianHeritageColors.darkCard : Colors.white,
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(15),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isWalletTopup 
                ? Colors.green.withOpacity(0.15) 
                : IndianHeritageColors.primaryYellow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isWalletTopup ? Icons.add_circle : Icons.payment,
            color: isWalletTopup ? Colors.green : IndianHeritageColors.primaryYellow,
          ),
        ),
        title: Text(
          isWalletTopup ? "Wallet Top-up" : "Trip Payment",
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontFamily: "bold",
            fontSize: 15,
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 5),
            Text(
              dateFormat.format(payment.createdAt),
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isCompleted 
                    ? Colors.green.withOpacity(0.15) 
                    : Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                payment.statusDisplay,
                style: TextStyle(
                  color: isCompleted ? Colors.green : Colors.orange,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              isWalletTopup && payment.amount < 0
                  ? "+₹${(-payment.amount).toStringAsFixed(0)}"
                  : "₹${payment.finalAmount.toStringAsFixed(0)}",
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                fontFamily: "bold",
                fontSize: 16,
                color: isWalletTopup && payment.amount < 0 
                    ? Colors.green 
                    : (isDark ? Colors.white : IndianHeritageColors.charcoal),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              payment.methodDisplay,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, PaymentModel payment, bool isDark) {
    final isWalletTopup = payment.tripId.isEmpty;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isWalletTopup 
                ? Colors.green.withOpacity(0.15) 
                : IndianHeritageColors.primaryYellow.withOpacity(0.15),
            child: Icon(
              isWalletTopup ? Icons.add : Icons.arrow_outward,
              color: isWalletTopup ? Colors.green : IndianHeritageColors.primaryYellow,
              size: 20,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isWalletTopup ? "Added to Wallet" : "Trip Payment",
                  style: TextStyle(
                    fontFamily: "bold",
                    fontSize: 14,
                    color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('MMM dd, hh:mm a').format(payment.createdAt),
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: Colors.grey,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            isWalletTopup && payment.amount < 0
                ? "+₹${(-payment.amount).toStringAsFixed(0)}"
                : "-₹${payment.finalAmount.toStringAsFixed(0)}",
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: "bold",
              fontSize: 15,
              color: isWalletTopup && payment.amount < 0 
                  ? Colors.green 
                  : (isDark ? Colors.white : IndianHeritageColors.charcoal),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSelected,
    required bool isDark,
    VoidCallback? onTap,
    VoidCallback? onAdd,
  }) {
    return Card(
      color: isDark ? IndianHeritageColors.darkCard : Colors.white,
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
        side: BorderSide(
          color: isSelected 
              ? IndianHeritageColors.primaryYellow 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[200]!),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: ListTile(
          contentPadding: const EdgeInsets.all(15),
          leading: Icon(icon, color: IndianHeritageColors.primaryYellow, size: 30),
          title: TranslatedText(
            title,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontFamily: "bold",
              fontSize: 15,
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          subtitle: TranslatedText(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey,
              fontSize: 12,
            ),
          ),
          trailing: isSelected
              ? const Icon(Icons.check_circle, color: Colors.green)
              : onAdd != null
                  ? TextButton(
                      onPressed: onAdd,
                      child: TranslatedText(
                        'Add',
                        style: const TextStyle(color: IndianHeritageColors.primaryYellow, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
        ),
      ),
    );
  }

  Widget _buildEmptyTransactions(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            color: isDark ? Colors.grey[800] : Colors.grey[400],
            size: 80,
          ),
          const SizedBox(height: 20),
          TranslatedText(
            'No transactions yet',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              fontSize: 18,
              fontFamily: "bold",
              color: isDark ? Colors.grey : IndianHeritageColors.charcoal,
            ),
          ),
          const SizedBox(height: 10),
          TranslatedText(
            'Your payment history will appear here',
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMoneyDialog(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    final amounts = [100, 200, 500, 1000];
    int selectedAmount = 500;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          title: TranslatedText(
            'Add Money to Wallet',
            style: TextStyle(
              fontFamily: "bold",
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TranslatedText(
                'Select Amount',
                style: TextStyle(
                  color: isDark ? Colors.grey : IndianHeritageColors.charcoal.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 15),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: amounts.map((amount) {
                  final isSelected = selectedAmount == amount;
                  return ChoiceChip(
                    label: Text("₹$amount"),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        selectedAmount = amount;
                      });
                    },
                    backgroundColor: isDark ? Colors.grey[850] : Colors.grey[200],
                    selectedColor: IndianHeritageColors.primaryYellow,
                    labelStyle: TextStyle(
                      color: isSelected 
                          ? Colors.black 
                          : (isDark ? Colors.grey : IndianHeritageColors.charcoal),
                      fontFamily: isSelected ? "bold" : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              TextField(
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                ),
                decoration: InputDecoration(
                  hint: TranslatedText('Or enter custom amount', style: const TextStyle(color: Colors.grey)),
                  prefixIcon: const Icon(Icons.currency_rupee, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onChanged: (value) {
                  if (value.isNotEmpty) {
                    setState(() {
                      selectedAmount = int.tryParse(value) ?? selectedAmount;
                    });
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: TranslatedText('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final phonePeService = ref.read(phonePeServiceProvider);
                final repo = ref.read(globalPaymentRepoProvider);
                final userRepo = ref.read(globalUserRepoProvider);

                String transactionId = "TXN${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(1000)}";
                
                final response = await phonePeService.startTransaction(
                  transactionId: transactionId,
                  amount: selectedAmount.toDouble(),
                  userId: user.uid,
                  mobileNumber: user.phone,
                );

                if (response != null && response['status'] == 'SUCCESS') {
                  await userRepo.updateWalletBalance(
                    user.uid,
                    selectedAmount.toDouble(),
                    context,
                  );
                  
                  await repo.addToWallet(
                    user.uid,
                    selectedAmount.toDouble(),
                    'PhonePe',
                    context,
                  );
                  
                    if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text("₹$selectedAmount added via PhonePe!"),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: TranslatedText('Payment Failed or Cancelled'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianHeritageColors.primaryYellow,
                foregroundColor: Colors.black,
              ),
              child: Text("Add ₹$selectedAmount"),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCardDialog(BuildContext context, bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        title: TranslatedText(
          'Add Card',
          style: TextStyle(
            fontFamily: "bold",
            color: isDark ? Colors.white : IndianHeritageColors.charcoal,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              style: TextStyle(
                color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              ),
                    decoration: InputDecoration(
                      hint: TranslatedText('Card Number', style: const TextStyle(color: Colors.grey)),
                      hintStyle: const TextStyle(color: Colors.grey),
                      prefixIcon: const Icon(Icons.credit_card, color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
            ),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    style: TextStyle(
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: "MM/YY",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: TextField(
                    style: TextStyle(
                      color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                    ),
                    decoration: InputDecoration(
                      hintText: "CVV",
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: TranslatedText('Card added successfully!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: Colors.black,
            ),
            child: TranslatedText('Add Card'),
          ),
        ],
      ),
    );
  }

  void _showAddVpaDialog(BuildContext context, WidgetRef ref, UserModel user, bool isDark) {
    final vpaController = TextEditingController();
    bool isValidating = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
          title: TranslatedText(
            'Enter UPI ID',
            style: TextStyle(
              fontFamily: "bold",
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: vpaController,
                style: TextStyle(
                  color: isDark ? Colors.white : IndianHeritageColors.charcoal,
                ),
                decoration: InputDecoration(
                  hint: TranslatedText('e.g. username@upi', style: const TextStyle(color: Colors.grey)),
                  hintStyle: const TextStyle(color: Colors.grey),
                  prefixIcon: const Icon(Icons.alternate_email, color: Colors.grey),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              TranslatedText(
                'A secure request will be sent to this UPI ID when you make a payment.',
                style: const TextStyle(color: Colors.grey, fontSize: 12),
                textAlign: TextAlign.center,
              )
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel"),
            ),
            ElevatedButton(
              onPressed: isValidating ? null : () async {
                final vpa = vpaController.text.trim();
                if (vpa.isEmpty || !vpa.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: TranslatedText('Please enter a valid UPI ID'), backgroundColor: Colors.red),
                  );
                  return;
                }

                setState(() => isValidating = true);
                await Future.delayed(const Duration(seconds: 1)); 

                if (context.mounted) {
                  ref.read(globalUserRepoProvider).updatePreferredPaymentMethod(user.uid, 'upi_vpa', context);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: TranslatedText('UPI ID Saved Successfully!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: IndianHeritageColors.primaryYellow,
                foregroundColor: Colors.black,
              ),
              child: isValidating 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : TranslatedText('Verify & Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoUserContent(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, color: Colors.grey, size: 60),
          const SizedBox(height: 20),
          TranslatedText(
            'Please login to view payments',
            style: TextStyle(
              color: isDark ? Colors.white : IndianHeritageColors.charcoal,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}
