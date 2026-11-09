-- DESTROYS every account and all app, website and billing data (schema untouched); run once on the correct project just before launch.
begin;

truncate billing.settlements, billing.payments, billing.payment_events, billing.entitlements,
  billing.subscription_transitions, billing.subscriptions, billing.checkout_sessions;
delete from billing.provider_plan_mappings where provider = 'flutterwave';
truncate enchiridion_web.activities, enchiridion_web.payouts, enchiridion_web.milestones, enchiridion_web.leads,
  enchiridion_web.reviews, enchiridion_web.payments, enchiridion_web.purchase_orders, enchiridion_web.broadcasts,
  enchiridion_web.audit_logs, enchiridion_web.email_outbox cascade;
delete from auth.users;

commit;

-- Every count must be 0; empty the avatars bucket from the dashboard, because Supabase blocks SQL deletes on storage.objects.
select 'auth.users' as tbl, count(*) from auth.users
union all select 'profiles', count(*) from public.profiles
union all select 'communication_preferences', count(*) from public.communication_preferences
union all select 'daily_study_stats', count(*) from public.daily_study_stats
union all select 'question_reviews', count(*) from public.question_reviews
union all select 'flagged_questions', count(*) from public.flagged_questions
union all select 'user_answers', count(*) from public.user_answers
union all select 'enchiridion_web.partners', count(*) from enchiridion_web.partners
union all select 'billing.subscriptions', count(*) from billing.subscriptions
union all select 'billing.entitlements', count(*) from billing.entitlements
union all select 'billing.payments', count(*) from billing.payments
union all select 'storage.objects/avatars', count(*) from storage.objects where bucket_id = 'avatars';
