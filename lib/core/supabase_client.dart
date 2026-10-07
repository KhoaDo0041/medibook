import 'package:supabase_flutter/supabase_flutter.dart';

/// Dùng ở mọi nơi trong app để gọi Supabase:
/// `supabase.auth...` cho tài khoản, `supabase.from('ten_bang')...` cho dữ liệu.
final supabase = Supabase.instance.client;
