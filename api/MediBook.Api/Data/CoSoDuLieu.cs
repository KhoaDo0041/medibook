using System.Security.Claims;
using System.Text.Json;
using Npgsql;

namespace MediBook.Api.Data;

/// <summary>
/// Lỗi nghiệp vụ trả về cho ứng dụng (HTTP 400) kèm thông báo tiếng Việt.
/// </summary>
public class LoiNghiepVu(string thongBao) : Exception(thongBao);

/// <summary>
/// Chạy câu lệnh SQL trên PostgreSQL (Supabase) THAY MẶT người dùng đang gọi API.
///
/// Mỗi yêu cầu mở một giao dịch, chuyển sang vai trò <c>authenticated</c> và gắn
/// thông tin token (sub = id người dùng) vào <c>request.jwt.claims</c>. Nhờ vậy các
/// hàm SQL dùng <c>auth.uid()</c> và chính sách Row Level Security vẫn hoạt động y hệt
/// như khi ứng dụng gọi Supabase trực tiếp.
/// </summary>
public class CoSoDuLieu(NpgsqlDataSource nguon, ILogger<CoSoDuLieu> log)
{
    /// <summary>Chạy truy vấn trả về đúng 1 giá trị JSON (dạng văn bản).</summary>
    public async Task<string> LayJsonAsync(ClaimsPrincipal? nguoiDung, string sql, object? thamSo = null)
    {
        var kq = await ChayAsync(nguoiDung, async (ket, gd) =>
        {
            await using var lenh = TaoLenh(ket, gd, sql, thamSo);
            var giaTri = await lenh.ExecuteScalarAsync();
            return giaTri is null or DBNull ? "null" : giaTri.ToString()!;
        });
        return kq;
    }

    /// <summary>Chạy câu lệnh không cần kết quả (gọi hàm SQL trả về void).</summary>
    public Task ThucThiAsync(ClaimsPrincipal? nguoiDung, string sql, object? thamSo = null) =>
        ChayAsync(nguoiDung, async (ket, gd) =>
        {
            await using var lenh = TaoLenh(ket, gd, sql, thamSo);
            await lenh.ExecuteNonQueryAsync();
            return 0;
        });

    private async Task<T> ChayAsync<T>(ClaimsPrincipal? nguoiDung, Func<NpgsqlConnection, NpgsqlTransaction, Task<T>> viec)
    {
        await using var ket = await nguon.OpenConnectionAsync();
        await using var gd = await ket.BeginTransactionAsync();
        try
        {
            await GanNguoiDungAsync(ket, gd, nguoiDung);
            var kq = await viec(ket, gd);
            await gd.CommitAsync();
            return kq;
        }
        catch (PostgresException e)
        {
            log.LogWarning("SQL {Code}: {Msg}", e.SqlState, e.MessageText);
            throw new LoiNghiepVu(DichLoi(e));
        }
    }

    private static async Task GanNguoiDungAsync(NpgsqlConnection ket, NpgsqlTransaction gd, ClaimsPrincipal? nguoiDung)
    {
        var id = nguoiDung?.FindFirstValue(ClaimTypes.NameIdentifier) ?? nguoiDung?.FindFirstValue("sub");
        var claims = JsonSerializer.Serialize(new
        {
            sub = id,
            role = id is null ? "anon" : "authenticated",
            email = nguoiDung?.FindFirstValue(ClaimTypes.Email) ?? nguoiDung?.FindFirstValue("email"),
        });
        await using var lenh = new NpgsqlCommand(
            $"""
            set local role {(id is null ? "anon" : "authenticated")};
            select set_config('request.jwt.claims', @claims::text, true),
                   set_config('request.jwt.claim.sub', coalesce(@sub::text, ''), true);
            """, ket, gd);
        lenh.Parameters.AddWithValue("claims", claims);
        lenh.Parameters.AddWithValue("sub", (object?)id ?? DBNull.Value);
        await lenh.ExecuteNonQueryAsync();
    }

    private static NpgsqlCommand TaoLenh(NpgsqlConnection ket, NpgsqlTransaction gd, string sql, object? thamSo)
    {
        var lenh = new NpgsqlCommand(sql, ket, gd);
        if (thamSo != null)
            foreach (var p in thamSo.GetType().GetProperties())
                lenh.Parameters.AddWithValue(p.Name, p.GetValue(thamSo) ?? DBNull.Value);
        return lenh;
    }

    /// <summary>Lỗi do hàm SQL raise đã là tiếng Việt; lỗi ràng buộc thì dịch lại.</summary>
    private static string DichLoi(PostgresException e)
    {
        var m = e.MessageText ?? "";
        var rang = e.ConstraintName ?? "";
        if (rang.Contains("luot_kham_mot_lan_moi_ca") || m.Contains("luot_kham_mot_lan_moi_ca")) return "Bạn đã đặt ca này rồi";
        if (rang.Contains("luot_kham_stt_duy_nhat") || m.Contains("luot_kham_stt_duy_nhat")) return "Có người vừa đặt cùng lúc, vui lòng thử lại";
        if (rang.Contains("ca_kham_hop_le") || m.Contains("ca_kham_hop_le")) return "Ca khám đã hết chỗ";
        if (System.Text.RegularExpressions.Regex.IsMatch(m, "[À-ỹ]")) return m;
        if (e.SqlState == "42501") return "Bạn không có quyền thực hiện thao tác này";
        return "Có lỗi xảy ra, vui lòng thử lại";
    }
}
