-- ============================================
-- 实时资产记账App - Supabase 后端初始化脚本
-- ============================================

-- 启用 Realtime
begin;
  -- 为 transactions 表启用实时推送
  alter publication supabase_realtime add table transactions;
  alter publication supabase_realtime add table accounts;
commit;

-- ============================================
-- 1. 交易记录表
-- ============================================
create table if not exists public.transactions (
  id text primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  account_id text not null,
  to_account_id text,
  amount numeric(15,2) not null,
  type text not null check (type in ('expense', 'income', 'transfer')),
  category_id text,
  merchant text,
  description text,
  source text default 'manual',
  transaction_date timestamptz not null,
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  version int default 1,
  is_deleted boolean default false
);

-- 创建索引
create index idx_transactions_user_id on public.transactions(user_id);
create index idx_transactions_account_id on public.transactions(account_id);
create index idx_transactions_date on public.transactions(transaction_date desc);
create index idx_transactions_sync on public.transactions(user_id, updated_at desc);

-- 更新时间戳函数
create or replace function public.handle_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

-- 自动更新 updated_at
create trigger on_transaction_updated
  before update on public.transactions
  for each row execute function public.handle_updated_at();

-- ============================================
-- 2. 账户表
-- ============================================
create table if not exists public.accounts (
  id text primary key,
  user_id uuid references auth.users(id) on delete cascade not null,
  name text not null,
  type text not null check (type in ('cash', 'debit', 'credit', 'ewallet', 'investment', 'other')),
  current_balance numeric(15,2) default 0,
  currency text default 'CNY',
  icon text,
  sort_order int default 0,
  updated_at timestamptz default now(),
  is_archived boolean default false
);

create index idx_accounts_user_id on public.accounts(user_id);

create trigger on_account_updated
  before update on public.accounts
  for each row execute function public.handle_updated_at();

-- ============================================
-- 3. 分类表（可选云端同步）
-- ============================================
create table if not exists public.categories (
  id text primary key,
  user_id uuid references auth.users(id) on delete cascade,
  name text not null,
  parent_id text,
  type text not null check (type in ('expense', 'income')),
  icon text,
  color int,
  sort_order int default 0
);

create index idx_categories_user_id on public.categories(user_id);

-- ============================================
-- Row Level Security (RLS) 策略
-- 确保用户只能访问自己的数据
-- ============================================

-- 交易记录 RLS
alter table public.transactions enable row level security;

create policy "Users can only access their own transactions"
  on public.transactions
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 账户 RLS
alter table public.accounts enable row level security;

create policy "Users can only access their own accounts"
  on public.accounts
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- 分类 RLS
alter table public.categories enable row level security;

create policy "Users can only access their own categories"
  on public.categories
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

-- ============================================
-- 4. 触发器：自动同步账户余额（服务端计算）
-- ============================================
create or replace function public.update_account_balance_on_tx()
returns trigger as $$
begin
  if new.type = 'expense' then
    update public.accounts 
    set current_balance = current_balance - new.amount,
        updated_at = now()
    where id = new.account_id and user_id = auth.uid();
  elsif new.type = 'income' then
    update public.accounts 
    set current_balance = current_balance + new.amount,
        updated_at = now()
    where id = new.account_id and user_id = auth.uid();
  elsif new.type = 'transfer' and new.to_account_id is not null then
    update public.accounts 
    set current_balance = current_balance - new.amount,
        updated_at = now()
    where id = new.account_id and user_id = auth.uid();

    update public.accounts 
    set current_balance = current_balance + new.amount,
        updated_at = now()
    where id = new.to_account_id and user_id = auth.uid();
  end if;
  return new;
end;
$$ language plpgsql security definer;

create trigger on_transaction_inserted
  after insert on public.transactions
  for each row execute function public.update_account_balance_on_tx();

-- ============================================
-- 5. 统计视图
-- ============================================
create or replace view public.monthly_stats as
select 
  user_id,
  date_trunc('month', transaction_date) as month,
  type,
  sum(abs(amount)) as total,
  count(*) as count
from public.transactions
where is_deleted = false
group by user_id, date_trunc('month', transaction_date), type;

-- ============================================
-- 6. 默认分类数据（全局共享）
-- ============================================
insert into public.categories (id, name, type, icon, color, sort_order) values
('cat_food', '餐饮', 'expense', '🍔', 0xFFFF6B6B, 1),
('cat_transport', '交通', 'expense', '🚗', 0xFF4ECDC4, 2),
('cat_shopping', '购物', 'expense', '🛍️', 0xFFFFE66D, 3),
('cat_entertainment', '娱乐', 'expense', '🎮', 0xFF9B59B6, 4),
('cat_housing', '居住', 'expense', '🏠', 0xFF3498DB, 5),
('cat_medical', '医疗', 'expense', '💊', 0xFFE74C3C, 6),
('cat_education', '教育', 'expense', '📚', 0xFF2ECC71, 7),
('cat_salary', '工资', 'income', '💰', 0xFF27AE60, 1),
('cat_investment', '理财收益', 'income', '📈', 0xFFF39C12, 2),
('cat_other_in', '其他收入', 'income', '💵', 0xFF95A5A6, 3)
on conflict (id) do nothing;
