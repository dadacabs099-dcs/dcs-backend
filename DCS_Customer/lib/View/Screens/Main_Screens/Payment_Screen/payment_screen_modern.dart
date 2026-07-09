import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';

class PaymentScreenModern extends ConsumerStatefulWidget {
  const PaymentScreenModern({super.key});

  @override
  ConsumerState<PaymentScreenModern> createState() => _PaymentScreenModernState();
}

class _PaymentScreenModernState extends ConsumerState<PaymentScreenModern>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() => _selectedTabIndex = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: IndianHeritageColors.primaryYellow,
        elevation: 0,
        title: const TranslatedText(
          'Payments & Wallet',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 20,
            color: IndianHeritageColors.charcoal,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── Wallet Balance Card ────────────────────────────────────────
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  IndianHeritageColors.primaryYellow.withOpacity(0.9),
                  IndianHeritageColors.deepGold.withOpacity(0.7),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: IndianHeritageColors.primaryYellow.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  'Wallet Balance',
                  style: TextStyle(
                    fontSize: 14,
                    color: IndianHeritageColors.charcoal.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const TranslatedText(
                      '₹2,450',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w900,
                        color: IndianHeritageColors.charcoal,
                        letterSpacing: -1,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _showAddMoneyDialog(context, isDark),
                      icon: const Icon(Icons.add, size: 18),
                      label: const TranslatedText('Add Money'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: IndianHeritageColors.charcoal,
                        foregroundColor: IndianHeritageColors.primaryYellow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Tab Navigation ────────────────────────────────────────────
          Container(
            color: isDark ? IndianHeritageColors.darkSurface : Colors.white,
            child: TabBar(
              controller: _tabController,
              indicatorColor: IndianHeritageColors.primaryYellow,
              indicatorWeight: 3,
              labelColor: IndianHeritageColors.primaryYellow,
              unselectedLabelColor: Colors.grey[600],
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
              tabs: const [
                Tab(child: TranslatedText('Wallet')),
                Tab(child: TranslatedText('History')),
                Tab(child: TranslatedText('Methods')),
              ],
            ),
          ),

          // ── Tab Content ────────────────────────────────────────────────
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Wallet Tab
                _buildWalletTab(isDark),

                // History Tab
                _buildHistoryTab(isDark),

                // Payment Methods Tab
                _buildPaymentMethodsTab(isDark),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Wallet Tab Content ──────────────────────────────────────────────
  Widget _buildWalletTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Quick Add Buttons
        TranslatedText(
          'Quick Add',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _quickAddButton(context, 100, isDark),
              _quickAddButton(context, 250, isDark),
              _quickAddButton(context, 500, isDark),
              _quickAddButton(context, 1000, isDark),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Features
        TranslatedText(
          'Wallet Features',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _featureCard(Icons.flash_on_rounded, 'Instant Payments', 'Pay instantly without confirmation', isDark),
        _featureCard(Icons.shield_rounded, 'Secure & Safe', 'Your wallet is always protected', isDark),
        _featureCard(Icons.local_offer_rounded, 'Cashback Offers', 'Get rewards on every ride', isDark),
      ],
    );
  }

  Widget _quickAddButton(BuildContext context, int amount, bool isDark) {
    return Container(
      width: 80,
      margin: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => _showAddMoneyDialog(context, isDark, amount),
        child: Container(
          decoration: BoxDecoration(
            color: IndianHeritageColors.primaryYellow.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.3),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add, color: IndianHeritageColors.primaryYellow, size: 20),
              const SizedBox(height: 4),
              TranslatedText(
                '₹$amount',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: IndianHeritageColors.primaryYellow,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _featureCard(IconData icon, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: IndianHeritageColors.primaryYellow, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── History Tab Content ────────────────────────────────────────────
  Widget _buildHistoryTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _historyItem('Ride to Mall Road', '- ₹125', '2 hours ago', Icons.local_taxi_rounded, isDark),
        _historyItem('Wallet Topup', '+ ₹500', '5 hours ago', Icons.account_balance_wallet_rounded, isDark),
        _historyItem('Ride to Airport', '- ₹850', '1 day ago', Icons.local_taxi_rounded, isDark),
        _historyItem('Ride to Office', '- ₹230', '2 days ago', Icons.local_taxi_rounded, isDark),
        _historyItem('Cashback Received', '+ ₹50', '3 days ago', Icons.card_giftcard_rounded, isDark),
      ],
    );
  }

  Widget _historyItem(String title, String amount, String time, IconData icon, bool isDark) {
    bool isCredit = amount.startsWith('+');
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: (isCredit ? Colors.green : Colors.red).withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: isCredit ? Colors.green : Colors.red, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  time,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TranslatedText(
            amount,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: isCredit ? Colors.green : (isDark ? Colors.white : Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // ── Payment Methods Tab ────────────────────────────────────────────
  Widget _buildPaymentMethodsTab(bool isDark) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TranslatedText(
          'Saved Payment Methods',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        _paymentMethodCard('💳', 'Visa Card', '**** **** **** 4242', isDark),
        _paymentMethodCard('🏦', 'HDFC Bank Account', '******* 9876543210', isDark),
        _paymentMethodCard('📱', 'UPI', 'user@upi', isDark),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: TranslatedText('Add new payment method')),
              );
            },
            icon: const Icon(Icons.add),
            label: const TranslatedText('Add Payment Method'),
            style: ElevatedButton.styleFrom(
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: IndianHeritageColors.charcoal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _paymentMethodCard(String emoji, String title, String subtitle, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TranslatedText(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                TranslatedText(
                  subtitle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, color: Colors.grey[600], size: 16),
        ],
      ),
    );
  }

  // ── Add Money Dialog ────────────────────────────────────────────────
  void _showAddMoneyDialog(BuildContext context, bool isDark, [int? presetAmount]) {
    final controller = TextEditingController(text: presetAmount?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? IndianHeritageColors.darkSurface : Colors.white,
        title: const TranslatedText('Add Money to Wallet'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter amount',
                prefix: const Text('₹ '),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const TranslatedText('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: TranslatedText('₹${controller.text} added to wallet!'),
                ),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: IndianHeritageColors.charcoal,
            ),
            child: const TranslatedText('Add'),
          ),
        ],
      ),
    );
  }
}
