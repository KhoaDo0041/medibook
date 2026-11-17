using MediBook.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace MediBook.Api.Controllers;

public record GuiChiDinhYeuCau(int[] DichVuIds);

/// <summary>
/// Cận lâm sàng (X-quang, xét nghiệm…) và sơ đồ bệnh viện để chỉ đường trong viện.
/// Bác sĩ gửi chỉ định → bệnh nhân thanh toán, đi từng khu, quay lại phòng khám.
/// </summary>
[Route("api")]
public class CanLamSangController(CoSoDuLieu db) : CoSoController(db)
{
    /// <summary>Danh mục dịch vụ cận lâm sàng (kèm khu thực hiện, giá, hướng dẫn chuẩn bị).</summary>
    [HttpGet("dich-vu-cls")]
    public Task<IActionResult> DichVu() => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', d.id, 'ma', d.ma, 'ten', d.ten, 'gia', d.gia, 'thoi_gian_phut', d.thoi_gian_phut,
                 'can_nhin_an', d.can_nhin_an, 'muc_dich', d.muc_dich, 'chuan_bi', d.chuan_bi,
                 'ma_khu', d.ma_khu, 'ten_khu', k.ten, 'tang', k.tang)
               order by k.tang, d.ma_khu, d.id), '[]')
        from dich_vu_cls d join khu_vuc k on k.ma = d.ma_khu
        """);

    /// <summary>Sơ đồ bệnh viện: các khu (nút) và lối đi (cạnh có độ dài, mét). Ứng dụng tự chạy Dijkstra.</summary>
    [HttpGet("so-do")]
    public Task<IActionResult> SoDo() => JsonTuSql("""
        select json_build_object(
          'khu', (select coalesce(json_agg(json_build_object(
                    'ma', ma, 'ten', ten, 'mo_ta', mo_ta, 'loai', loai, 'tang', tang,
                    'x', x, 'y', y, 'hx', hx, 'hy', hy, 'hw', hw, 'hh', hh) order by tang, ma), '[]')
                  from khu_vuc),
          'loi_di', (select coalesce(json_agg(json_build_object('tu', tu, 'den', den, 'do_dai', do_dai)), '[]')
                     from loi_di))
        """);

    /// <summary>Lộ trình cận lâm sàng của một lượt khám (bệnh nhân của lượt hoặc bác sĩ của ca mới xem được).</summary>
    [HttpGet("luot-kham/{id:int}/lo-trinh")]
    public Task<IActionResult> LoTrinh(int id) => JsonTuSql("""
        select json_build_object(
          'luot_kham_id', l.id, 'trang_thai', l.trang_thai, 'so_thu_tu', l.so_thu_tu,
          'da_thanh_toan_cls', l.da_thanh_toan_cls,
          'so_phong', c.so_phong, 'tang', c.tang, 'ten_bac_si', hs.ho_ten,
          'tong_tien', (select coalesce(sum(d.gia), 0) from chi_dinh_cls cd
                        join dich_vu_cls d on d.id = cd.dich_vu_id where cd.luot_kham_id = l.id),
          'chi_dinh', (select coalesce(json_agg(json_build_object(
                         'id', cd.id, 'thu_tu', cd.thu_tu, 'trang_thai', cd.trang_thai,
                         'ket_qua', cd.ket_qua, 'thoi_diem_xong', cd.thoi_diem_xong,
                         'dich_vu_id', d.id, 'ten', d.ten, 'gia', d.gia, 'thoi_gian_phut', d.thoi_gian_phut,
                         'can_nhin_an', d.can_nhin_an, 'muc_dich', d.muc_dich, 'chuan_bi', d.chuan_bi,
                         'ma_khu', d.ma_khu, 'ten_khu', k.ten, 'tang_khu', k.tang)
                       order by cd.thu_tu), '[]')
                       from chi_dinh_cls cd
                       join dich_vu_cls d on d.id = cd.dich_vu_id
                       join khu_vuc k on k.ma = d.ma_khu
                       where cd.luot_kham_id = l.id))
        from luot_kham l
        join ca_kham c on c.id = l.ca_kham_id
        left join ho_so hs on hs.id = c.bac_si_id
        where l.id = @id
        """, new { id });

    /// <summary>Bác sĩ gửi chỉ định cận lâm sàng cho bệnh nhân đang khám.</summary>
    [HttpPost("bac-si/luot-kham/{id:int}/chi-dinh")]
    public async Task<IActionResult> GuiChiDinh(int id, [FromBody] GuiChiDinhYeuCau yc)
    {
        await Db.ThucThiAsync(User, "select gui_chi_dinh_cls(@id, @ds)", new { id, ds = yc.DichVuIds ?? [] });
        return NoContent();
    }

    /// <summary>Bệnh nhân thanh toán chi phí cận lâm sàng (mô phỏng). Trả về số tiền.</summary>
    [HttpPost("luot-kham/{id:int}/thanh-toan-cls")]
    public Task<IActionResult> ThanhToan(int id) => JsonTuSql(
        "select json_build_object('so_tien', thanh_toan_cls(@id))", new { id });

    /// <summary>Bệnh nhân đã đến khu và làm xong một chỉ định (mô phỏng: gắn kết quả mẫu).</summary>
    [HttpPost("chi-dinh/{id:long}/hoan-thanh")]
    public async Task<IActionResult> HoanThanh(long id)
    {
        await Db.ThucThiAsync(User, "select hoan_thanh_chi_dinh(@id)", new { id });
        return NoContent();
    }

    /// <summary>Bệnh nhân đã làm xong mọi chỉ định và quay lại phòng khám.</summary>
    [HttpPost("luot-kham/{id:int}/quay-lai")]
    public async Task<IActionResult> QuayLai(int id)
    {
        await Db.ThucThiAsync(User, "select quay_lai_phong_kham(@id)", new { id });
        return NoContent();
    }
}
