import 'package:flutter/material.dart';

import '../../core/app_theme.dart';
import 'dich_vu_cls.dart';
import 'so_do.dart';

/// Sơ đồ bệnh viện: tô đường đi ngắn nhất (Dijkstra) từ [maTu] tới [maDen].
/// Chạm vào khu bạn đang đứng để vẽ lại đường. Có nút "Tôi đã đến" khi [coNutDaDen]
/// (màn hình trả về true nếu người dùng bấm nút đó).
class ManHinhSoDo extends StatefulWidget {
  final String maTu;
  final String maDen;
  final String? nhanDen; // VD "Phòng 215"
  final String? viec; // VD "Chụp X-quang ngực thẳng"
  final bool coNutDaDen;

  const ManHinhSoDo({
    super.key,
    required this.maTu,
    required this.maDen,
    this.nhanDen,
    this.viec,
    this.coNutDaDen = false,
  });

  @override
  State<ManHinhSoDo> createState() => _ManHinhSoDoState();
}

class _ManHinhSoDoState extends State<ManHinhSoDo> {
  late Future<SoDoBenhVien> _soDo = DichVuCls.soDo();
  late String _tu = widget.maTu;
  int? _tang;

  void _doiViTri(SoDoBenhVien soDo, KhuVuc k) {
    if (k.ma == _tu) return;
    setState(() => _tu = k.ma);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã đặt vị trí của bạn: ${k.ten}. Đường đi được vẽ lại.'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sơ đồ bệnh viện')),
      body: FutureBuilder<SoDoBenhVien>(
        future: _soDo,
        builder: (_, snap) {
          if (snap.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${snap.error}', textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: () => setState(() => _soDo = DichVuCls.soDo()),
                      child: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          final soDo = snap.data;
          if (soDo == null) return const Center(child: CircularProgressIndicator());
          return _noiDung(soDo);
        },
      ),
    );
  }

  Widget _noiDung(SoDoBenhVien soDo) {
    final chu = Theme.of(context).textTheme;
    final duong = soDo.timDuong(_tu, widget.maDen);
    final tu = soDo.khu[_tu];
    final den = soDo.khu[widget.maDen];
    final tangCoDuong = {
      if (duong != null) for (final m in duong.nut) soDo.khu[m]!.tang,
    };
    final tang = _tang ?? tu?.tang ?? 1;
    final tenDen = widget.nhanDen ?? den?.ten ?? '';

    return Column(
      children: [
        // Chọn tầng
        SizedBox(
          height: 52,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            children: [
              for (final t in soDo.cacTang)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text('Tầng $t'),
                    selected: t == tang,
                    avatar: tangCoDuong.contains(t) && t != tang
                        ? const Icon(Icons.route, size: 16, color: AppTheme.mauNhan)
                        : null,
                    onSelected: (_) => setState(() => _tang = t),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppTheme.boGocThe),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.mauVien),
                    borderRadius: BorderRadius.circular(AppTheme.boGocThe),
                  ),
                  child: BanDoTang(
                    soDo: soDo,
                    tang: tang,
                    duong: duong,
                    maTu: _tu,
                    maDen: widget.maDen,
                    nhanDen: widget.nhanDen,
                    onChamKhu: (k) => _doiViTri(soDo, k),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.touch_app_outlined, size: 16, color: AppTheme.mauChuNhat),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Bị lạc? Chạm vào khu bạn đang đứng để vẽ lại đường.',
                      style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                    ),
                  ),
                ],
              ),
              if (duong != null) ...[
                const SizedBox(height: 14),
                Text(
                  'HƯỚNG DẪN ĐI',
                  style: chu.labelMedium?.copyWith(
                    color: AppTheme.mauChuNhat,
                    letterSpacing: 0.6,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                for (final (i, b) in soDo.huongDan(duong).indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 11,
                          backgroundColor: AppTheme.mauChinhNhat,
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.mauChinh,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(b, style: chu.bodyMedium)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        // Thẻ điểm đến
        SafeArea(
          top: false,
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: AppTheme.mauNhanNhat,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.place_rounded, color: AppTheme.mauNhan),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.viec == null ? tenDen : '$tenDen · ${widget.viec}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: chu.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            duong == null
                                ? 'Không tìm được đường đi'
                                : duong.tongMet == 0
                                ? 'Bạn đang ở khu này'
                                : 'Tầng ${den?.tang} · ${duong.tongMet.round()} m · khoảng ${duong.soPhut} phút đi bộ',
                            style: chu.bodySmall?.copyWith(color: AppTheme.mauChuNhat),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (widget.coNutDaDen) ...[
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: AppTheme.mauNhan),
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.where_to_vote_rounded),
                    label: const Text('Tôi đã đến nơi'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
