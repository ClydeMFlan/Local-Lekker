-- Check chat database structure and data

-- 1. Verify tables exist
SELECT table_name, column_name, data_type, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name IN ('chat_conversations', 'chat_messages')
ORDER BY table_name, ordinal_position;

-- 2. Check chat_conversations structure
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'chat_conversations'
ORDER BY ordinal_position;

-- 3. Check chat_messages structure
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'chat_messages'
ORDER BY ordinal_position;

-- 4. Check if there's any data
SELECT 'chat_conversations' AS table_name, COUNT(*) AS row_count
FROM public.chat_conversations
UNION ALL
SELECT 'chat_messages', COUNT(*)
FROM public.chat_messages;

-- 5. View sample conversations (if any)
SELECT id, created_at, is_admin, participant_ids
FROM public.chat_conversations
LIMIT 10;

-- 6. View sample messages (if any)
SELECT m.id, m.conversation_id, m.sender_id, 
       LEFT(m.content, 50) AS content_preview,
       m.created_at
FROM public.chat_messages m
ORDER BY m.created_at DESC
LIMIT 10;

-- 7. Check RLS policies
SELECT schemaname, tablename, policyname, permissive, roles, cmd, qual
FROM pg_policies
WHERE schemaname = 'public'
  AND tablename IN ('chat_conversations', 'chat_messages')
ORDER BY tablename, policyname;

-- 8. Verify RLS is enabled
SELECT tablename, rowsecurity
FROM pg_tables
WHERE schemaname = 'public'
  AND tablename IN ('chat_conversations', 'chat_messages');

-- 9. Check current authenticated user
SELECT auth.uid() AS current_user_id;

-- 10. Check if current user is a participant in any conversation
SELECT c.id, c.is_admin, c.participant_ids,
       CASE WHEN auth.uid() = ANY(c.participant_ids) THEN 'YES' ELSE 'NO' END AS is_participant
FROM public.chat_conversations c;

-- 11. Check profiles for participant names
SELECT p.id, p.name, p.surname, p.email
FROM public.profiles p
WHERE p.id IN (
  '1916d77f-596f-4e9f-825f-dedf7a11bbf8',
  '857a6e51-c965-4fec-890c-61a08b1224c6'
);
