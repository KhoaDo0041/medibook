using System.Text.Json;
using MediBook.Api.Data;
using Microsoft.AspNetCore.Mvc;

namespace MediBook.Api.Controllers;

public record HoanTatKhamYeuCau(string ChanDoan, string? LoiDan, JsonElement? DonThuoc, DateOnly? NgayTaiKham);

/// <summary>Nghiệp vụ của bác sĩ. RLS bảo đảm bác sĩ chỉ thấy ca và bệnh nhân của mình.</summary>
[Route("api/bac-si")]
public class BacSiController(CoSoDuLieu db) : CoSoController(db)
{
    /// <summary>Nơi công tác: tên khoa và bệnh viện của bác sĩ đang đăng nhập.</summary>
    [HttpGet("noi-cong-tac")]
    public Task<IActionResult> NoiCongTac() => JsonTuSql("""
        select json_build_object('ten_khoa', c.ten_khoa, 'ten_benh_vien', bv.ten_benh_vien)
        from bac_si b
        left join chuyen_khoa c on c.id = b.chuyen_khoa_id
        left join benh_vien bv on bv.id = b.benh_vien_id
        where b.id = auth.uid()
        """);

    /// <summary>Các ca trong một ngày (yyyy-MM-dd), mỗi ca kèm danh sách lượt khám và thông tin bệnh nhân.</summary>
    [HttpGet("ca")]
    public async Task<IActionResult> CaTrongNgay([FromQuery] DateOnly ngay)
    {
        // Ca đã hết giờ: người còn chờ / tạm hoãn chuyển thành vắng mặt
        try { await Db.ThucThiAsync(User, "select chot_ca_qua_han()"); } catch (LoiNghiepVu) { }

        return await JsonTuSql("""
            select coalesce(json_agg(json_build_object(
                     'id', c.id, 'ngay_kham', c.ngay_kham, 'gio_bat_dau', c.gio_bat_dau, 'gio_ket_thuc', c.gio_ket_thuc,
                     'so_luong_toi_da', c.so_luong_toi_da, 'so_phong', c.so_phong, 'tang', c.tang,
                     'luot', (
                        select coalesce(json_agg(json_build_object(
                                 'id', l.id, 'benh_nhan_id', l.benh_nhan_id, 'so_thu_tu', l.so_thu_tu,
                                 'trang_thai', l.trang_thai, 'trieu_chung', l.trieu_chung, 'chan_doan', l.chan_doan,
                                 'ghi_chu_bac_si', l.ghi_chu_bac_si, 'ngay_tao', l.ngay_tao,
                                 'phieu_tien_kham', l.phieu_tien_kham,
                                 'ho_ten', h.ho_ten, 'gioi_tinh', h.gioi_tinh, 'ngay_sinh', h.ngay_sinh)
                               order by l.so_thu_tu), '[]')
                        from luot_kham l left join ho_so h on h.id = l.benh_nhan_id
                        where l.ca_kham_id = c.id))
                   order by c.gio_bat_dau), '[]')
            from ca_kham c
            where c.bac_si_id = auth.uid() and c.ngay_kham = @ngay
            """, new { ngay });
    }

    /// <summary>Những lần đã khám xong của một bệnh nhân với bác sĩ này.</summary>
    [HttpGet("benh-nhan/{benhNhanId:guid}/lich-su")]
    public Task<IActionResult> LichSu(Guid benhNhanId, [FromQuery] int? boQua) => JsonTuSql("""
        select coalesce(json_agg(json_build_object('ngay_kham', c.ngay_kham, 'chan_doan', l.chan_doan)
               order by c.ngay_kham desc), '[]')
        from luot_kham l join ca_kham c on c.id = l.ca_kham_id
        where l.benh_nhan_id = @bn and l.trang_thai = 'da_kham' and c.bac_si_id = auth.uid()
          and (@boQua::int is null or l.id <> @boQua::int)
        """, new { bn = benhNhanId, boQua });

    /// <summary>Mọi lượt đã khám / vắng mặt của bác sĩ, kèm ca và thông tin bệnh nhân (ứng dụng tự gom theo bệnh nhân).</summary>
    [HttpGet("benh-nhan")]
    public Task<IActionResult> BenhNhan() => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', l.id, 'benh_nhan_id', l.benh_nhan_id, 'trang_thai', l.trang_thai,
                 'trieu_chung', l.trieu_chung, 'chan_doan', l.chan_doan, 'ghi_chu_bac_si', l.ghi_chu_bac_si,
                 'ngay_kham', c.ngay_kham, 'gio_bat_dau', c.gio_bat_dau,
                 'ho_ten', h.ho_ten, 'gioi_tinh', h.gioi_tinh, 'ngay_sinh', h.ngay_sinh)), '[]')
        from luot_kham l
        join ca_kham c on c.id = l.ca_kham_id
        left join ho_so h on h.id = l.benh_nhan_id
        where c.bac_si_id = auth.uid() and l.trang_thai in ('da_kham', 'vang_mat')
        """);

    /// <summary>Gọi số nhỏ nhất đang chờ trong ca vào khám.</summary>
    [HttpPost("ca/{caKhamId:int}/goi-so-tiep-theo")]
    public Task<IActionResult> GoiSo(int caKhamId) =>
        JsonTuSql("select to_json(goi_so_tiep_theo(@id))", new { id = caKhamId });

    /// <summary>Mời một bệnh nhân cụ thể vào khám (người tạm hoãn vừa đến, hoặc gọi vượt số).</summary>
    [HttpPost("luot-kham/{id:int}/bat-dau")]
    public async Task<IActionResult> BatDau(int id)
    {
        await Db.ThucThiAsync(User, "select bat_dau_kham(@id)", new { id });
        return NoContent();
    }

    /// <summary>Bệnh nhân chưa có mặt: tạm hoãn, vẫn giữ số đến hết ca.</summary>
    [HttpPost("luot-kham/{id:int}/tam-hoan")]
    public async Task<IActionResult> TamHoan(int id)
    {
        await Db.ThucThiAsync(User, "select tam_hoan_kham(@id)", new { id });
        return NoContent();
    }

    /// <summary>Hoàn tất khám: chẩn đoán, lời dặn, đơn thuốc mẫu, ngày tái khám. Kết quả bị khoá sau đó.</summary>
    [HttpPost("luot-kham/{id:int}/hoan-tat")]
    public async Task<IActionResult> HoanTat(int id, [FromBody] HoanTatKhamYeuCau yc)
    {
        var don = yc.DonThuoc is { ValueKind: JsonValueKind.Array } d ? d.GetRawText() : "[]";
        await Db.ThucThiAsync(User,
            "select hoan_tat_kham(@id, @cd::text, @ld::text, @don::jsonb, @ntk::date)",
            new { id, cd = yc.ChanDoan, ld = yc.LoiDan, don, ntk = yc.NgayTaiKham });
        return NoContent();
    }
}
