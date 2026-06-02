import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/cash_flow_service.dart';
import '../../state/app_state.dart';

/// Cash Flow Forecast screen — 30-day projection with a line chart,
/// recommended actions, and breakdown of inflows/outflows.
class CashFlowForecastScreen extends StatefulWidget {
  const CashFlowForecastScreen({super.key});

  @override
  State<CashFlowForecastScreen> createState() => _CashFlowForecastScreenState();
}

class _CashFlowForecastScreenState extends State<CashFlowForecastScreen> {
  CashFlowForecastData _forecast = CashFlowForecastData.empty;
  List<ForecastRecommendation> _recommendations = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bizId = context.read<AppState>().business.id;
    if (bizId == null) return;
    setState(() => _loading = true);
    final forecast = await CashFlowService.calculateForecast(businessId: bizId);
    final recs = CashFlowService.generateRecommendations(forecast);
    if (!mounted) return;
    setState(() {
      _forecast = forecast;
      _recommendations = recs;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    SubScreenHeader('Cash Flow Forecast',
                        onBack: () => Navigator.pop(context)),
                    // Hero card
                    _ForecastHero(forecast: _forecast),
                    const SizedBox(height: 20),

                    // Chart
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader('30-Day Projection'),
                          _MiniChart(forecast: _forecast),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Breakdown
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader('Breakdown'),
                          _BreakdownTile(
                            label: 'Current cash',
                            amount: _forecast.currentCash,
                            color: c.teal,
                            icon: Icons.account_balance_wallet_outlined,
                          ),
                          _BreakdownTile(
                            label: 'Receivables due (30d)',
                            amount: _forecast.accountsReceivableDue,
                            color: c.green,
                            icon: Icons.receipt_long_outlined,
                            positive: true,
                          ),
                          _BreakdownTile(
                            label: 'Operating costs (30d)',
                            amount: _forecast.fixedOperatingCosts,
                            color: c.rose,
                            icon: Icons.trending_down,
                            positive: false,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Recommendations
                    if (_recommendations.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Recommendations'),
                            ..._recommendations.map((r) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: _RecCard(rec: r),
                                )),
                          ],
                        ),
                      ),

                    // Overdue invoices
                    if (_forecast.overdueInvoices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Overdue Invoices'),
                            ..._forecast.overdueInvoices.map((inv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: _OverdueRow(invoice: inv),
                                )),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

// ── Forecast Hero ───────────────────────────────────────────────────────────

class _ForecastHero extends StatelessWidget {
  final CashFlowForecastData forecast;
  const _ForecastHero({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final projected = forecast.projectedCash30Days;
    final safety = forecast.safetyLine;
    final isAtRisk = forecast.isAtRisk;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isAtRisk ? [c.rose.withValues(alpha: 0.8), c.roseInk] : [c.navyDeep, c.navy],
            ),
            boxShadow: AppShadows.navy,
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(isAtRisk ? Icons.warning_amber_rounded : Icons.trending_up,
                      size: 18, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('${isAtRisk ? 'WARNING' : 'ON TRACK'} · 30-DAY FORECAST',
                      style: AppType.label(size: 10, color: Colors.white.withValues(alpha: 0.7))),
                ],
              ),
              const SizedBox(height: 14),
              Text(formatGHS(projected.round()),
                  style: AppType.display(size: 32, color: Colors.white)),
              const SizedBox(height: 4),
              Text(
                isAtRisk
                    ? 'Below safety line of ${formatGHS(safety.round())}'
                    : 'Above safety line of ${formatGHS(safety.round())}',
                style: AppType.body(size: 12, color: Colors.white.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 14),
              // Mini stat row
              Row(
                children: [
                  _MiniStat(
                    label: 'Confidence',
                    value: '${(forecast.overallConfidence * 100).round()}%',
                    color: c.green,
                  ),
                  const SizedBox(width: 16),
                  _MiniStat(
                    label: 'Data quality',
                    value: forecast.dataQuality.toUpperCase(),
                    color: forecast.dataQuality == 'high' ? c.green :
                           forecast.dataQuality == 'medium' ? c.amber : c.textMuted,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  final Color color;
  const _MiniStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppType.body(size: 10, weight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.6))),
        const SizedBox(height: 2),
        Text(value,
            style: AppType.body(size: 13, weight: FontWeight.w700, color: color)),
      ],
    );
  }
}

// ── Mini Chart ──────────────────────────────────────────────────────────────

class _MiniChart extends StatelessWidget {
  final CashFlowForecastData forecast;
  const _MiniChart({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final points = forecast.dailyForecast;
    if (points.isEmpty) return const SizedBox.shrink();

    final maxVal = points.fold(0.0, (m, p) => p.projected > m ? p.projected : m);
    final minVal = points.fold(0.0, (m, p) => p.projected < m ? p.projected : m);
    final range = (maxVal - minVal).abs().clamp(1, double.infinity);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _LegendDot(color: c.teal, label: 'Projected'),
              const SizedBox(width: 12),
              _LegendDot(color: c.rose, label: 'Safety line'),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: CustomPaint(
              size: Size(double.infinity, 140),
              painter: _ChartPainter(
                points: points,
                safetyLine: forecast.safetyLine.toDouble(),
                minVal: minVal,
                range: range.toDouble(),
                teal: c.teal,
                rose: c.rose,
                green: c.green,
                surfaceColor: c.tealSurface,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Date labels
          Builder(builder: (context) {
            final step = (points.length / 4).ceil();
            return Row(
              children: [
                for (int i = 0; i < points.length; i += step)
                  Expanded(
                    child: Text(points[i].date,
                        textAlign: TextAlign.center,
                        style: AppType.body(size: 9, color: c.textFaint)),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  final List<DailyForecastPoint> points;
  final double safetyLine, minVal, range;
  final Color teal, rose, green, surfaceColor;

  _ChartPainter({
    required this.points,
    required this.safetyLine,
    required this.minVal,
    required this.range,
    required this.teal,
    required this.rose,
    required this.green,
    required this.surfaceColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final w = size.width;
    if (points.isEmpty) return;

    final yScale = (h - 20) / range;
    final xStep = w / (points.length - 1);

    Offset toPos(DailyForecastPoint p, int i) {
      final x = i * xStep;
      final y = h - 10 - ((p.projected - minVal) * yScale);
      return Offset(x, y);
    }

    // Draw safety line
    final safetyY = h - 10 - ((safetyLine - minVal) * yScale);
    if (safetyY > 0 && safetyY < h) {
      final dashPaint = Paint()
        ..color = rose.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(0, safetyY), Offset(w, safetyY), dashPaint);
    }

    // Draw projection line
    final linePaint = Paint()
      ..color = teal
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (int i = 0; i < points.length; i++) {
      final pos = toPos(points[i], i);
      if (i == 0) {
        path.moveTo(pos.dx, pos.dy);
      } else {
        path.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(path, linePaint);

    // Draw dots on start, middle, end
    for (final i in [0, (points.length ~/ 2), points.length - 1]) {
      final pos = toPos(points[i], i);
      canvas.drawCircle(pos, 3, Paint()..color = teal);
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.points != points;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: AppType.body(size: 10, color: c.textMuted)),
      ],
    );
  }
}

// ── Breakdown Tile ──────────────────────────────────────────────────────────

class _BreakdownTile extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  final IconData icon;
  final bool positive;
  const _BreakdownTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
    this.positive = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final prefix = positive ? '+' : (amount > 0 ? '-' : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: AppType.body(size: 13, color: c.text)),
            ),
            Text('$prefix${formatGHS(amount.toInt())}',
                style: AppType.body(size: 13.5, weight: FontWeight.w600,
                    color: positive ? c.green : (amount > 0 ? c.rose : c.text))),
          ],
        ),
      ),
    );
  }
}

// ── Recommendation Card ─────────────────────────────────────────────────────

class _RecCard extends StatelessWidget {
  final ForecastRecommendation rec;
  const _RecCard({required this.rec});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (tone, dotColor) = switch (rec.urgency) {
      'critical' => (PillTone.rose, c.rose),
      'high' => (PillTone.orange, c.orange),
      'medium' => (PillTone.amber, c.amber),
      _ => (PillTone.teal, c.teal),
    };

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8, height: 8, margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(rec.title,
                    style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
                const SizedBox(height: 4),
                Text(rec.description,
                    style: AppType.body(size: 12, color: c.textMuted)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    AppPill(rec.urgency.toUpperCase(), tone: tone, small: true),
                    const SizedBox(width: 8),
                    Text('+GHS ${rec.impact.round()} impact',
                        style: AppType.body(size: 11, weight: FontWeight.w600, color: c.green)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Overdue Row ─────────────────────────────────────────────────────────────

class _OverdueRow extends StatelessWidget {
  final OverdueInvoice invoice;
  const _OverdueRow({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(invoice.clientName,
                    style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                Text(invoice.invoiceNumber,
                    style: AppType.mono(size: 10, color: c.textMuted)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatGHS(invoice.amount.round()),
                  style: AppType.body(size: 13.5, weight: FontWeight.w600, color: c.text)),
              Text('${invoice.daysPastDue}d overdue',
                  style: AppType.body(size: 11, color: c.rose)),
            ],
          ),
        ],
      ),
    );
  }
}
