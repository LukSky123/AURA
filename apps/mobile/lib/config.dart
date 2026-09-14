class AuraConfig {
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://nfinxqfjchveyvbkntex.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5maW54cWZqY2h2ZXl2YmtudGV4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkzODkwNzUsImV4cCI6MjEwNDk2NTA3NX0.WsDo7YOGPgAH4O8eWvhMlj9kwKcYYshx-fRgZchOQAs',
  );
}

