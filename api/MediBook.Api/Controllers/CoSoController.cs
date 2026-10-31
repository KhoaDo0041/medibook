using MediBook.Api.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace MediBook.Api.Controllers;

/// <summary>Lớp cha: trả JSON do PostgreSQL dựng sẵn (giữ nguyên định dạng ngày/giờ như Supabase).</summary>
[ApiController]
[Authorize]
[Produces("application/json")]
public abstract class CoSoController(CoSoDuLieu db) : ControllerBase
{
    protected CoSoDuLieu Db => db;

    protected async Task<IActionResult> JsonTuSql(string sql, object? thamSo = null) =>
        Content(await db.LayJsonAsync(User, sql, thamSo), "application/json; charset=utf-8");
}

/// <summary>Danh mục: bệnh viện, chuyên khoa, bác sĩ, ca khám, thuốc mẫu.</summary>
[Route("api")]
public class DanhMucController(CoSoDuLieu db) : CoSoController(db)
{
    /// <summary>Tất cả bệnh viện (sắp theo tên). Khoảng cách do ứng dụng tự tính theo GPS.</summary>
    [HttpGet("benh-vien")]
    public Task<IActionResult> BenhVien() => JsonTuSql(
        "select coalesce(json_agg(b order by b.ten_benh_vien), '[]') from benh_vien b");

    /// <summary>Danh sách chuyên khoa (dùng cho trợ lý AI).</summary>
    [HttpGet("chuyen-khoa")]
    public Task<IActionResult> ChuyenKhoa() => JsonTuSql(
        "select coalesce(json_agg(json_build_object('id', id, 'ten_khoa', ten_khoa) order by id), '[]') from chuyen_khoa");

    /// <summary>Id các bệnh viện có chuyên khoa này.</summary>
    [HttpGet("chuyen-khoa/{id:int}/benh-vien")]
    public Task<IActionResult> BenhVienCoKhoa(int id) => JsonTuSql(
        "select coalesce(json_agg(benh_vien_id), '[]') from khoa_benh_vien where chuyen_khoa_id = @id", new { id });

    /// <summary>Các khoa của một bệnh viện.</summary>
    [HttpGet("benh-vien/{id:int}/khoa")]
    public Task<IActionResult> Khoa(int id) => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', k.id, 'chuyen_khoa_id', k.chuyen_khoa_id, 'ten_khoa', c.ten_khoa) order by c.ten_khoa), '[]')
        from khoa_benh_vien k join chuyen_khoa c on c.id = k.chuyen_khoa_id
        where k.benh_vien_id = @id
        """, new { id });

    /// <summary>Bác sĩ đang làm việc của một bệnh viện (kèm họ tên, tên khoa).</summary>
    [HttpGet("benh-vien/{id:int}/bac-si")]
    public Task<IActionResult> BacSi(int id) => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', b.id, 'ho_ten', coalesce(h.ho_ten, 'Bác sĩ'), 'hoc_vi', b.hoc_vi,
                 'so_nam_kinh_nghiem', b.so_nam_kinh_nghiem, 'gioi_thieu', b.gioi_thieu,
                 'chuyen_khoa_id', b.chuyen_khoa_id, 'ten_khoa', c.ten_khoa, 'benh_vien_id', b.benh_vien_id)
               order by h.ho_ten), '[]')
        from bac_si b
        left join ho_so h on h.id = b.id
        left join chuyen_khoa c on c.id = b.chuyen_khoa_id
        where b.benh_vien_id = @id and b.trang_thai = 'da_duyet'
        """, new { id });

    /// <summary>Ca khám của các bác sĩ trong khoảng ngày (yyyy-MM-dd).</summary>
    [HttpGet("ca-kham")]
    public Task<IActionResult> CaKham([FromQuery] string bacSiIds, [FromQuery] DateOnly tuNgay, [FromQuery] DateOnly denNgay) => JsonTuSql("""
        select coalesce(json_agg(json_build_object(
                 'id', c.id, 'bac_si_id', c.bac_si_id, 'ngay_kham', c.ngay_kham, 'gio_bat_dau', c.gio_bat_dau,
                 'gio_ket_thuc', c.gio_ket_thuc, 'so_luong_toi_da', c.so_luong_toi_da,
                 'so_da_dang_ky', c.so_da_dang_ky, 'so_phong', c.so_phong, 'tang', c.tang)
               order by c.ngay_kham, c.gio_bat_dau), '[]')
        from ca_kham c
        where c.bac_si_id = any(string_to_array(@ids, ',')::uuid[])
          and c.ngay_kham between @tu and @den
        """, new { ids = bacSiIds, tu = tuNgay, den = denNgay });

    /// <summary>Danh mục thuốc mẫu (Thuốc A – E) dùng khi kê đơn.</summary>
    [HttpGet("danh-muc-thuoc")]
    public Task<IActionResult> DanhMucThuoc() => JsonTuSql(
        "select coalesce(json_agg(json_build_object('id', id, 'ten', ten, 'don_vi', don_vi) order by id), '[]') from danh_muc_thuoc");
}

/// <summary>Tài khoản đang đăng nhập (đăng nhập / đăng ký / OTP vẫn do Supabase Auth đảm nhiệm).</summary>
[Route("api/tai-khoan")]
public class TaiKhoanController(CoSoDuLieu db) : CoSoController(db)
{
    /// <summary>Hồ sơ của người đang đăng nhập.</summary>
    [HttpGet("ho-so")]
    public Task<IActionResult> HoSo() => JsonTuSql(
        "select row_to_json(h) from (select id, ho_ten, vai_tro from ho_so where id = auth.uid()) h");

    /// <summary>Bác sĩ đang đăng nhập còn làm việc hay đã nghỉ.</summary>
    [HttpGet("con-hoat-dong")]
    public Task<IActionResult> ConHoatDong() => JsonTuSql("select to_json(bac_si_con_hoat_dong())");
}
