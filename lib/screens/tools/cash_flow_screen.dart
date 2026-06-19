import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/models.dart';
import '../../core/tokens.dart';
import '../../core/widgets/common.dart';
import '../../services/app_logger.dart';
import '../../services/cash_flow_service.dart';
import '../../state/app_state.dart';
import 'invoice_detail_screen.dart';
import 'invoices_screen.dart';

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
    try {
      final forecast = await CashFlowService.calculateForecast(businessId: bizId);
      final recs = CashFlowService.generateRecommendations(forecast);
      if (!mounted) return;
      setState(() {
        _forecast = forecast;
        _recommendations = recs;
        _loading = false;
      });
    } catch (e, st) {
      log.error('CashFlowForecastScreen._load failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _forecast = CashFlowForecastData.empty;
        _recommendations = [];
        _loading = false;
      });
    }
  }

  void _navigateToInvoices() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const InvoicesScreen(),
      ),
    );
  }

  void _navigateToInvoiceDetail(Invoice inv) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(initialInvoice: inv),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: _loading
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation(c.teal)),
                    ),
                    const SizedBox(height: 12),
                    Text('Calculating forecast…',
                        style: AppType.body(size: 13, color: c.textMuted)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    SubScreenHeader('Cash Flow Forecast',
                        onBack: () => Navigator.pop(context)),

                    // ── Hero card ──
                    _ForecastHero(forecast: _forecast),
                    const SizedBox(height: 20),

                    // ── Chart ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader('30-Day Projection'),
                          const SizedBox(height: 10),
                          _MiniChart(forecast: _forecast),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Pipeline card ──
                    if (_forecast.pipelineValue > 0) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _PipelineCard(
                          pipelineValue: _forecast.pipelineValue,
                          proformaCount: context
                              .read<AppState>()
                              .invoices
                              .where((i) => i.isProforma)
                              .length,
                          onConvert: _navigateToInvoices,
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // ── Quick stats summary ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: _StatTile(
                              label: 'Inflows (30d)',
                              amount: _forecast.accountsReceivableDue + _forecast.pipelineValue,
                              color: c.green,
                              icon: Icons.arrow_downward_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _StatTile(
                              label: 'Outflows (30d)',
                              amount: _forecast.fixedOperatingCosts,
                              color: c.rose,
                              icon: Icons.arrow_upward_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ── Breakdown ──
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader('Breakdown'),
                          FadeInSlide(
                            index: 0,
                            child: _BreakdownTile(
                              label: 'Current cash',
                              amount: _forecast.currentCash,
                              color: c.teal,
                              icon: Icons.account_balance_wallet_outlined,
                            ),
                          ),
                          FadeInSlide(
                            index: 1,
                            child: _BreakdownTile(
                              label: 'Receivables due (30d)',
                              amount: _forecast.accountsReceivableDue,
                              color: c.green,
                              icon: Icons.receipt_long_outlined,
                              positive: true,
                            ),
                          ),
                          FadeInSlide(
                            index: 2,
                            child: _BreakdownTile(
                              label: 'Operating costs (30d)',
                              amount: _forecast.fixedOperatingCosts,
                              color: c.rose,
                              icon: Icons.trending_down,
                              positive: false,
                            ),
                          ),
                          if (_forecast.pipelineValue > 0)
                            FadeInSlide(
                              index: 3,
                              child: _BreakdownTile(
                                label: 'Pipeline (${context.read<AppState>().invoices.where((i) => i.isProforma).length} proformas)',
                                amount: _forecast.pipelineValue,
                                color: c.amber,
                                icon: Icons.description_outlined,
                                positive: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // ── Data quality card ──
                    if (_forecast.dataQuality == 'low')
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: FadeInSlide(
                          index: 0,
                          child: AppCard(
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(Icons.info_outline, size: 16, color: c.amber),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Improve forecast accuracy',
                                          style: AppType.body(size: 13, weight: FontWeight.w600, color: c.text)),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Record your regular expenses and log sales consistently to get more accurate cash flow predictions.',
                                        style: AppType.body(size: 12, color: c.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (_forecast.dataQuality == 'low')
                      const SizedBox(height: 16),

                    // ── Recommendations ──
                    if (_recommendations.isNotEmpty || _forecast.pipelineValue > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Recommendations'),
                            // Pipeline conversion recommendation
                            if (_forecast.pipelineValue > 0)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: FadeInSlide(
                                  index: -1,
                                  child: _RecCard(
                                    rec: ForecastRecommendation(
                                      type: 'pipeline',
                                      title: 'Convert proformas to invoices',
                                      description:
                                          '${context.read<AppState>().invoices.where((i) => i.isProforma).length} proforma${context.read<AppState>().invoices.where((i) => i.isProforma).length == 1 ? '' : 's'} worth ${formatGHS(_forecast.pipelineValue.round())} awaiting approval — converting them could improve your cash position by ${formatGHS((_forecast.pipelineValue * 0.7).round())}.',
                                      actionLabel: 'View Proformas',
                                      impact: _forecast.pipelineValue,
                                      urgency: 'medium',
                                    ),
                                    onTap: _navigateToInvoices,
                                  ),
                                ),
                              ),
                            ..._recommendations.asMap().entries.map((e) => Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: FadeInSlide(
                                    index: e.key,
                                    child: _RecCard(
                                      rec: e.value,
                                      onTap: e.value.type == 'collection'
                                          ? _navigateToInvoices
                                          : null,
                                    ),
                                  ),
                                )),
                          ],
                        ),
                      ),

                    // ── Overdue invoices ──
                    if (_forecast.overdueInvoices.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SectionHeader('Overdue Invoices'),
                            ..._forecast.overdueInvoices.asMap().entries.map((entry) {
                              final inv = entry.value;
                              final matching = context
                                  .read<AppState>()
                                  .invoices
                                  .where((i) =>
                                      i.id == inv.invoiceNumber ||
                                      i.backendId == inv.id)
                                  .firstOrNull;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: FadeInSlide(
                                  index: entry.key,
                                  child: _OverdueRow(
                                    invoice: inv,
                                    onTap: matching != null
                                        ? () =>
                                            _navigateToInvoiceDetail(matching)
                                        : null,
                                  ),
                                ),
                              );
                            }),
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
            style: AppType.label(size: 10, color: Colors.white.withValues(alpha: 0.6))),
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

    final maxVal = points.fold(0.0, (m, p) => (p.projected > m ? p.projected : p.withPipeline > m ? p.withPipeline : m));
    final minVal = points.fold(0.0, (m, p) => (p.projected < m ? p.projected : p.withPipeline < m ? p.withPipeline : m));
    final range = (maxVal - minVal).abs().clamp(1, double.infinity);

    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Legend
          Row(
            children: [
              _LegendDot(color: c.amber, label: 'With pipeline'),
              const SizedBox(width: 12),
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
                amber: c.amber,
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
  final double safetyLine, minVal, range;    final Color teal, rose, green, amber, surfaceColor;

  _ChartPainter({
    required this.points,
    required this.safetyLine,
    required this.minVal,
    required this.range,
    required this.teal,
    required this.rose,
    required this.green,
    required this.amber,
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

    Offset toPosPipeline(DailyForecastPoint p, int i) {
      final x = i * xStep;
      final y = h - 10 - ((p.withPipeline - minVal) * yScale);
      return Offset(x, y);
    }

    // Build pipeline line path (dashed, amber)
    final pipelinePaint = Paint()
      ..color = amber.withValues(alpha: 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    final pipelinePath = Path();
    for (int i = 0; i < points.length; i++) {
      final pos = toPosPipeline(points[i], i);
      if (i == 0) {
        pipelinePath.moveTo(pos.dx, pos.dy);
      } else {
        pipelinePath.lineTo(pos.dx, pos.dy);
      }
    }
    canvas.drawPath(pipelinePath, pipelinePaint);

    // Build projection line path
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

    // Draw gradient fill below the line
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          teal.withValues(alpha: 0.25),
          teal.withValues(alpha: 0.02),
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final fillPath = Path.from(path);
    final lastPos = toPos(points.last, points.length - 1);
    fillPath.lineTo(lastPos.dx, h - 10);
    fillPath.lineTo(toPos(points.first, 0).dx, h - 10);
    fillPath.close();
    canvas.drawPath(fillPath, fillPaint);

    // Draw the line
    canvas.drawPath(path, linePaint);

    // Draw dots on start, middle, end
    for (final i in [0, (points.length ~/ 2), points.length - 1]) {
      final pos = toPos(points[i], i);
      canvas.drawCircle(pos, 4, Paint()..color = Colors.white);
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

// ── Quick stat tile ─────────────────────────────────────────────────────────

class _StatTile extends StatelessWidget {
  final String label;
  final num amount;
  final Color color;
  final IconData icon;
  const _StatTile({
    required this.label,
    required this.amount,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(label,
                  style: AppType.label(size: 11, color: c.textMuted)),
            ],
          ),
          const SizedBox(height: 6),
          Text(formatGHS(amount.toInt()),
              style: AppType.heading(size: 18, color: color)),
        ],
      ),
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

// ── Pipeline Card ───────────────────────────────────────────────────────────

class _PipelineCard extends StatelessWidget {
  final double pipelineValue;
  final int proformaCount;
  final VoidCallback onConvert;

  const _PipelineCard({
    required this.pipelineValue,
    required this.proformaCount,
    required this.onConvert,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final conversionEstimate = (pipelineValue * 0.7).round();

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child:
                    Icon(Icons.description_outlined, size: 18, color: c.amber),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pipeline — $proformaCount proforma${proformaCount == 1 ? '' : 's'}',
                        style: AppType.heading(
                            size: 13.5,
                            color: c.text)),
                    const SizedBox(height: 2),
                    Text(
                      '${formatGHS(pipelineValue.round())} awaiting client approval',
                      style: AppType.body(size: 12, color: c.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('If approved, you could add',
                        style: AppType.body(
                            size: 11, color: c.textMuted)),
                    const SizedBox(height: 2),
                    Text('+${formatGHS(conversionEstimate)}',
                        style: AppType.heading(
                            size: 18, color: c.green)),
                    const SizedBox(height: 1),
                    Text('to your projected cash (est. 70% conversion)',
                        style: AppType.body(
                            size: 10, color: c.textFaint)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AppBtn(
                'Convert',
                icon: 'north_east',
                fontSize: 12.5,
                onTap: onConvert,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Recommendation Card ─────────────────────────────────────────────────────

class _RecCard extends StatelessWidget {
  final ForecastRecommendation rec;
  final VoidCallback? onTap;
  const _RecCard({required this.rec, this.onTap});

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
      onTap: onTap,
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
                if (onTap != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('View details',
                          style: AppType.body(size: 12, weight: FontWeight.w600, color: c.teal)),
                      Icon(Icons.chevron_right, size: 14, color: c.teal),
                    ],
                  ),
                ],
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
  final VoidCallback? onTap;
  const _OverdueRow({required this.invoice, this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      onTap: onTap,
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
