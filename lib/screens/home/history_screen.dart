import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/history_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/models/trip_model.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoryProvider>().fetchHistory();
      context.read<NotificationProvider>().fetchNotifications();
    });
  }

  Map<String, List<Trip>> _groupTripsByMonth(List<Trip> trips) {
    final Map<String, List<Trip>> grouped = {};
    for (final trip in trips) {
      final monthYear = trip.createdAt != null 
          ? DateFormat('MMMM yyyy').format(trip.createdAt!)
          : 'RECENTLY';
      if (!grouped.containsKey(monthYear)) {
        grouped[monthYear] = [];
      }
      grouped[monthYear]!.add(trip);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Consumer<HistoryProvider>(
        builder: (context, provider, child) {
          final groupedTrips = _groupTripsByMonth(provider.trips);
          final months = groupedTrips.keys.toList();

          return RefreshIndicator(
            edgeOffset: 20,
            color: const Color(0xFFEEBD2B),
            backgroundColor: const Color(0xFF24211C),
            onRefresh: provider.fetchHistory,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: const _HistoryHeader(),
                ),
                SliverToBoxAdapter(
                  child: const SizedBox(height: 24),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.zero,
                    child: const Text(
                      'Ride History',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 42,
                        fontWeight: FontWeight.w600,
                        height: 1.05,
                      ),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(
                  child: SizedBox(height: 24),
                ),
                if (provider.isLoading && provider.trips.isEmpty)
                  _buildSkeletonSliver()
                else if (provider.errorMessage != null && provider.trips.isEmpty)
                  SliverFillRemaining(
                    child: _buildErrorState(provider.errorMessage!),
                  )
                else if (provider.trips.isEmpty)
                  SliverFillRemaining(
                    child: _buildEmptyState(),
                  )
                else
                  ...List.generate(months.length, (index) {
                    final month = months[index];
                    final trips = groupedTrips[month]!;
                    return SliverPadding(
                      padding: EdgeInsets.zero,
                      sliver: SliverMainAxisGroup(
                        slivers: [
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 16, top: 8),
                              child: Text(
                                month.toUpperCase(),
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF94A3B8),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 1.5,
                                ),
                              ),
                            ),
                          ),
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, tripIndex) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: _HistoryRideCard(trip: trips[tripIndex]),
                                );
                              },
                              childCount: trips.length,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SliverPadding(padding: EdgeInsets.only(bottom: 100)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonSliver() {
    return SliverPadding(
      padding: EdgeInsets.zero,
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Shimmer.fromColors(
              baseColor: const Color(0xFF24211C),
              highlightColor: const Color(0xFF2D2A24),
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          childCount: 3,
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history, size: 64, color: Colors.white.withOpacity(0.05)),
          const SizedBox(height: 16),
          Text(
            'No rides found',
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your ride history will appear here',
            style: GoogleFonts.inter(
              color: const Color(0xFF64748B),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Color(0xFFF87171)),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFFE2E8F0), fontSize: 16),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.read<HistoryProvider>().fetchHistory(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEEBD2B),
                foregroundColor: Colors.black,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Try Again', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'SaaradhiGo',
            style: TextStyle(
              color: Color(0xFFEEBD2B),
              fontSize: 23,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.6,
            ),
          ),
        ),
        Consumer<NotificationProvider>(
          builder: (context, provider, child) => GestureDetector(
            onTap: () => context.push('/notifications'),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 3, right: 3),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0x14FFFFFF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications,
                      color: Color(0xFFE2E8F0),
                      size: 21,
                    ),
                  ),
                ),
                if (provider.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFEF4444),
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${provider.unreadCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HistoryRideCard extends StatelessWidget {
  final Trip trip;

  const _HistoryRideCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final dateStr = trip.createdAt != null 
        ? DateFormat('MMM dd, yyyy \u2022 hh:mm a').format(trip.createdAt!)
        : 'Recently';
    
    final fare = trip.finalFare ?? trip.estimatedFare ?? '0.00';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF24211C),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (trip.vehicleType ?? 'Premium Car'),
                    style: GoogleFonts.inter(
                      color: const Color(0xFFEEBD2B),
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dateStr,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF64748B),
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Text(
                '₹$fare',
                style: GoogleFonts.inter(
                  color: const Color(0xFFEEBD2B),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _TimelineRoute(
            pickup: trip.pickupAddress,
            destination: trip.destinationAddress,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFF8D468),
                    side: BorderSide(color: const Color(0xFF8B6508).withOpacity(0.4)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Rate', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B6508).withOpacity(0.4),
                    foregroundColor: const Color(0xFFF8D468),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Rebook', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TimelineRoute extends StatelessWidget {
  final String pickup;
  final String destination;

  const _TimelineRoute({required this.pickup, required this.destination});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEBD2B),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pickup,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            SizedBox(
              width: 24,
              child: Column(
                children: List.generate(3, (index) => 
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    width: 2,
                    height: 4,
                    color: Colors.white.withOpacity(0.1),
                  )
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        Row(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: Icon(
                Icons.location_on,
                color: Color(0xFFEEBD2B),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                destination,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
