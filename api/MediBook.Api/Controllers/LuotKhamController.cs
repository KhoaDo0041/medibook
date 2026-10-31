using System.Text.Json;
using MediBook.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace MediBook.Api.Controllers;

public record DatLuotKhamYeuCau(int CaKhamId, string? TrieuChung, JsonElement? PhieuTienKham);

/// <summary>Lượt khám phía bệnh nhân: đặt, huỷ, xem lịch hẹn, hàng chờ, đơn thuốc.</summary>
[Route("api/luot-kham")]
public class LuotKhamController(CoSoDuLieu db) : CoSoController(db)
{
    /// <summary>Đặt lượt khám. Database khoá dòng ca khám và tự cấp số thứ tự.</summary>
    [HttpPost]
    public Task<IActionResult> Dat([FromBody] DatLuotKhamYeuCau yc)
    {
        var phieu = yc.PhieuTienKham is { ValueKind: JsonValueKind.Object } p ? p.GetRawText() : null;
        return JsonTuSql("select to_json(dat_luot_kham(@ca, @tc::text, @phieu::jsonb))",
            new { ca = yc.CaKhamId, tc = yc.TrieuChung, phieu });
    }

    /// <summary>Huỷ lượt khám đang "chờ khám".</summary>
    [HttpPost("{id:int}/huy")]
    public async Task<IActionResult> Huy(int id)
    {
        await Db.ThucThiAsync(User, "select huy_luot_kham(@id)", new { id });
        return NoContent();
    }

    /// <summary>Toàn bộ lịch hẹn của bệnh nhân đang đăng nhập (mới nhất trước), đã ghép sẵn ca, bệnh viện, khoa, bác sĩ.</summary>
    [HttpGet("cua-toi")]
    public Task<IActionResult> CuaToi() => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', l.id, 'so_thu_tu', l.so_thu_tu, 'trang_thai', l.trang_thai,
                 'trieu_chung', l.trieu_chung, 'chan_doan', l.chan_doan, 'ghi_chu_bac_si', l.ghi_chu_bac_si,
                 'ly_do_huy', l.ly_do_huy, 'ngay_tai_kham', l.ngay_tai_kham, 'phieu_tien_kham', l.phieu_tien_kham,
                 'ca', json_build_object(
                     'id', c.id, 'bac_si_id', c.bac_si_id, 'ngay_kham', c.ngay_kham,
                     'gio_bat_dau', c.gio_bat_dau, 'gio_ket_thuc', c.gio_ket_thuc,
                     'so_luong_toi_da', c.so_luong_toi_da, 'so_da_dang_ky', c.so_da_dang_ky,
                     'so_phong', c.so_phong, 'tang', c.tang),
                 'benh_vien', to_json(bv),
                 'ten_khoa', ck.ten_khoa,
                 'hoc_vi', bs.hoc_vi,
                 'ten_bac_si', hs.ho_ten)
               order by c.ngay_kham desc, c.gio_bat_dau desc), '[]')
        from luot_kham l
        join ca_kham c on c.id = l.ca_kham_id
        left join khoa_benh_vien k on k.id = c.khoa_benh_vien_id
        left join chuyen_khoa ck on ck.id = k.chuyen_khoa_id
        left join benh_vien bv on bv.id = k.benh_vien_id
        left join bac_si bs on bs.id = c.bac_si_id
        left join ho_so hs on hs.id = c.bac_si_id
        where l.benh_nhan_id = auth.uid()
        """);

    /// <summary>Số đang khám và số người còn chờ trước lượt này.</summary>
    [HttpGet("{id:int}/hang-cho")]
    public Task<IActionResult> HangCho(int id) => JsonTuSql(
        "select row_to_json(h) from hang_cho_cua_toi(@id) h limit 1", new { id });

    /// <summary>Đơn thuốc của một lượt khám (bệnh nhân của lượt hoặc bác sĩ của ca mới xem được).</summary>
    [HttpGet("{id:int}/don-thuoc")]
    public Task<IActionResult> DonThuoc(int id) => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'lieu_moi_lan', d.lieu_moi_lan, 'so_lan_ngay', d.so_lan_ngay, 'thoi_diem', d.thoi_diem,
                 'so_ngay', d.so_ngay, 'ghi_chu', d.ghi_chu,
                 'danh_muc_thuoc', json_build_object('id', t.id, 'ten', t.ten, 'don_vi', t.don_vi))
               order by d.id), '[]')
        from don_thuoc_chi_tiet d join danh_muc_thuoc t on t.id = d.thuoc_id
        where d.luot_kham_id = @id
        """, new { id });
}
