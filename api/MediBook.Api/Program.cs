using MediBook.Api.Data;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.OpenApi;
using Npgsql;

var builder = WebApplication.CreateBuilder(args);

// Render cấp cổng qua biến môi trường PORT
var cong = Environment.GetEnvironmentVariable("PORT");
if (!string.IsNullOrEmpty(cong)) builder.WebHost.UseUrls($"http://0.0.0.0:{cong}");

// ---- Cấu hình (đặt trong biến môi trường, KHÔNG ghi vào mã nguồn) ----
//   SUPABASE_URL   : https://<project>.supabase.co
//   DB_CONNECTION  : chuỗi kết nối Postgres (Session pooler của Supabase)
var supabaseUrl = (builder.Configuration["SUPABASE_URL"] ?? "https://ckiddvvryeduwnmopgik.supabase.co").TrimEnd('/');
var chuoiKetNoi = builder.Configuration["DB_CONNECTION"]
    ?? throw new InvalidOperationException("Thiếu biến môi trường DB_CONNECTION");

builder.Services.AddSingleton(new NpgsqlDataSourceBuilder(chuoiKetNoi).Build());
builder.Services.AddScoped<CoSoDuLieu>();

// ---- Xác thực: dùng chính token đăng nhập của Supabase Auth (ES256, khoá công khai JWKS) ----
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(o =>
    {
        o.Authority = $"{supabaseUrl}/auth/v1";
        o.MetadataAddress = $"{supabaseUrl}/auth/v1/.well-known/openid-configuration";
        o.TokenValidationParameters.ValidAudience = "authenticated";
        o.TokenValidationParameters.ValidIssuer = $"{supabaseUrl}/auth/v1";
        o.MapInboundClaims = false;

        // Chỉ dùng khi chạy thử trên máy (không đặt biến này trên Render)
        var khoaThu = builder.Configuration["JWT_TEST_KEY"];
        if (!string.IsNullOrEmpty(khoaThu) && builder.Environment.IsDevelopment())
        {
            o.Authority = null;
            o.MetadataAddress = null!;
            o.RequireHttpsMetadata = false;
            o.TokenValidationParameters.IssuerSigningKey =
                new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(System.Text.Encoding.UTF8.GetBytes(khoaThu));
        }
    });
builder.Services.AddAuthorization();

builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod()));
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "MediBook API", Version = "v1", Description = "Web API đặt lịch khám bệnh MediBook" });
    var xml = Path.Combine(AppContext.BaseDirectory, "MediBook.Api.xml");
    if (File.Exists(xml)) c.IncludeXmlComments(xml);
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Type = SecuritySchemeType.Http, Scheme = "bearer", BearerFormat = "JWT",
        Description = "Dán access token Supabase của người dùng đã đăng nhập",
    });
    c.AddSecurityRequirement(doc => new OpenApiSecurityRequirement { [new OpenApiSecuritySchemeReference("Bearer", doc)] = [] });
});

var app = builder.Build();

// Lỗi nghiệp vụ (từ hàm SQL) → HTTP 400 kèm thông báo tiếng Việt
app.Use(async (ctx, next) =>
{
    try { await next(); }
    catch (LoiNghiepVu e)
    {
        ctx.Response.StatusCode = 400;
        await ctx.Response.WriteAsJsonAsync(new { message = e.Message });
    }
});

app.UseCors();
app.UseSwagger();
app.UseSwaggerUI(c => c.DocumentTitle = "MediBook API");
app.UseAuthentication();
app.UseAuthorization();

app.MapGet("/", () => Results.Redirect("/swagger")).ExcludeFromDescription();
app.MapGet("/api/health", () => Results.Ok(new { trangThai = "ok", thoiGian = DateTime.UtcNow })).AllowAnonymous();
app.MapControllers();

app.Run();
