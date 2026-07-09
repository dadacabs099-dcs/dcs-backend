import 'package:flutter/material.dart' hide Text;
import 'package:Dadacabs/View/Widgets/translated_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:Dadacabs/View/Routes/routes.dart';
import 'package:Dadacabs/View/Themes/indian_heritage_theme.dart';
import 'package:Dadacabs/Container/Providers/theme_provider.dart';
import 'package:Dadacabs/Model/trip_model.dart';

class BookingSummaryScreenModern extends ConsumerStatefulWidget {
  final TripModel? trip;

  const BookingSummaryScreenModern({
    super.key,
    this.trip,
  });

  @override
  ConsumerState<BookingSummaryScreenModern> createState() => _BookingSummaryScreenModernState();
}

class _BookingSummaryScreenModernState extends ConsumerState<BookingSummaryScreenModern>
    with TickerProviderStateMixin {
  late AnimationController _scaleController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );
    _scaleController.forward();
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = ref.watch(themeModeProvider) == ThemeMode.dark;
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: isDark ? IndianHeritageColors.darkBackground : IndianHeritageColors.marbleWhite,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const TranslatedText('Confirm Ride'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Progress Indicator ──────────────────────────────────────
              _buildProgressIndicator(isDark),

              const SizedBox(height: 24),

              // ── Route Card ───────────────────────────────────────────────
              _buildRouteCard(isDark),

              const SizedBox(height: 24),

              // ── Trip Details Grid ────────────────────────────────────────
              _buildTripDetailsGrid(isDark),

              const SizedBox(height: 24),

              // ── Pricing Breakdown ────────────────────────────────────────
              _buildPricingBreakdown(isDark),

              const SizedBox(height: 24),

              // ── Estimated Fare Card ──────────────────────────────────────
              _buildEstimatedFareCard(isDark),

              const SizedBox(height: 24),

              // ── Confirm & Cancel Buttons ──────────────────────────────────
              _buildActionButtons(context, isDark),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Progress Indicator ──────────────────────────────────────────────
  Widget _buildProgressIndicator(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          _progressStep(1, 'Pickup', true, isDark),
          _progressDivider(true, isDark),
          _progressStep(2, 'Confirm', true, isDark),
          _progressDivider(false, isDark),
          _progressStep(3, 'Payment', false, isDark),
        ],
      ),
    );
  }

  Widget _progressStep(int step, String label, bool completed, bool isDark) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: completed
                  ? IndianHeritageColors.primaryYellow
                  : (isDark ? Colors.grey[800] : Colors.grey[200]),
            ),
            child: Center(
              child: completed
                  ? const Icon(Icons.check, color: IndianHeritageColors.charcoal, size: 20)
                  : TranslatedText(
                      '$step',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          TranslatedText(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _progressDivider(bool filled, bool isDark) {
    return Expanded(
      child: Container(
        height: 2,
        margin: const EdgeInsets.only(top: 20, bottom: 20),
        color: filled
            ? IndianHeritageColors.primaryYellow
            : (isDark ? Colors.grey[800] : Colors.grey[200]),
      ),
    );
  }

  // ── Route Card ──────────────────────────────────────────────────────
  Widget _buildRouteCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? IndianHeritageColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Pickup
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      'Pickup',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      widget.trip?.pickupAddress ?? 'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Container(
              width: 2,
              height: 32,
              color: isDark ? Colors.grey[800] : Colors.grey[300],
            ),
          ),

          // Destination
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: IndianHeritageColors.primaryYellow,
                  border: Border.all(color: IndianHeritageColors.primaryYellow, width: 2),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TranslatedText(
                      'Destination',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TranslatedText(
                      widget.trip?.dropoffAddress ?? 'Loading...',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Trip Details Grid ──────────────────────────────────────────────
  Widget _buildTripDetailsGrid(bool isDark) {
    return Row(
      children: [
        Expanded(
          child: _detailCard(
            context,
            icon: Icons.route_rounded,
            label: 'Distance',
            value: '${widget.trip?.distanceKm?.toStringAsFixed(1) ?? "0"} km',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _detailCard(
            context,
            icon: Icons.schedule_rounded,
            label: 'Duration',
            value: '${widget.trip?.durationMinutes ?? "0"} min',
            isDark: isDark,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _detailCard(
            context,
            icon: Icons.local_taxi_rounded,
            label: 'Vehicle',
            value: widget.trip?.carType ?? 'Sedan',
            isDark: isDark,
          ),
        ),
      ],
    );
  }

  Widget _detailCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: IndianHeritageColors.primaryYellow, size: 24),
          const SizedBox(height: 8),
          TranslatedText(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          TranslatedText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ── Pricing Breakdown ──────────────────────────────────────────────
  Widget _buildPricingBreakdown(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        children: [
          _pricingRow('Base Fare', '₹${widget.trip?.estimatedFare?.toStringAsFixed(0) ?? "0"}', isDark),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
          ),
          _pricingRow('Distance', '₹${(widget.trip?.distanceKm ?? 0) * 8}', isDark),
          const SizedBox(height: 8),
          _pricingRow('Time', '₹${(widget.trip?.durationMinutes ?? 0) * 2}', isDark, isSmall: true),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: isDark ? Colors.grey[800] : Colors.grey[300]),
          ),
          _pricingRow(
            'Total',
            '₹${widget.trip?.estimatedFare?.toStringAsFixed(0) ?? "0"}',
            isDark,
            isBold: true,
          ),
        ],
      ),
    );
  }

  Widget _pricingRow(String label, String value, bool isDark, {bool isBold = false, bool isSmall = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        TranslatedText(
          label,
          style: TextStyle(
            fontSize: isSmall ? 12 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        TranslatedText(
          value,
          style: TextStyle(
            fontSize: isSmall ? 12 : 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w600,
            color: isBold ? IndianHeritageColors.primaryYellow : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  // ── Estimated Fare Card ────────────────────────────────────────────
  Widget _buildEstimatedFareCard(bool isDark) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              IndianHeritageColors.primaryYellow.withOpacity(0.9),
              IndianHeritageColors.deepGold.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: IndianHeritageColors.primaryYellow.withOpacity(0.3),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Column(
          children: [
            TranslatedText(
              'Estimated Fare',
              style: TextStyle(
                fontSize: 13,
                color: IndianHeritageColors.charcoal.withOpacity(0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              '₹${widget.trip?.estimatedFare?.toStringAsFixed(0) ?? "0"}',
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: IndianHeritageColors.charcoal,
                letterSpacing: -1,
              ),
            ),
            const SizedBox(height: 8),
            TranslatedText(
              'May increase on traffic',
              style: TextStyle(
                fontSize: 12,
                color: IndianHeritageColors.charcoal.withOpacity(0.7),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Action Buttons ────────────────────────────────────────────────
  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => context.pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(
                color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
              ),
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: TranslatedText(
              'Back',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton(
            onPressed: () {
              // Confirm booking logic
              context.pushNamed(Routes().activeTripModern, extra: widget.trip);
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: IndianHeritageColors.primaryYellow,
              foregroundColor: IndianHeritageColors.charcoal,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 8,
              shadowColor: IndianHeritageColors.primaryYellow.withOpacity(0.4),
            ),
            child: const TranslatedText(
              'Confirm Booking',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
