/// Thông tin kết nối Supabase của MediBook.
///
/// Khoá "anon" được phép nằm trong app vì quyền truy cập dữ liệu
/// do phân quyền (RLS) trên Supabase quyết định.
/// KHÔNG đặt khoá bí mật khác (Gemini, MoMo, service_role) vào đây.
class SupabaseConfig {
  static const String url = 'https://ckiddvvryeduwnmopgik.supabase.co';
  static const String anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImNraWRkdnZyeWVkdXdubW9wZ2lrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODk1NzIzOTAsImV4cCI6MjEwNTE0ODM5MH0.CwPuFjgZwsrgXuKIN0TnA7eOIczrFC_pdrlHWdhpiL0';
}
