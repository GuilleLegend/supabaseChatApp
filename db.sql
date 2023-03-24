drop table if exists users;
drop table if exists groups;
drop table if exists messages;

create table users (
  id uuid not null primary key,
  email text
);

create table groups (
  id bigint generated by default as identity primary key,
  creator uuid references public.users not null default auth.uid(),
  title text not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

create table messages (
  id bigint generated by default as identity primary key,
  user_id uuid references public.users not null default auth.uid(),
  text text check (char_length(text) > 0),
  group_id bigint references groups on delete cascade not null,
  created_at timestamp with time zone default timezone('utc'::text, now()) not null
);

-- Secure tables
alter table users enable row level security;
alter table groups enable row level security;
alter table messages enable row level security;

-- User Policies
create policy "Users can read the user email." on users
  for select using (true);

-- Group Policies
create policy "Groups are viewable by everyone." on groups
  for select using (true);

create policy "Authenticated users can create groups." on groups for 
  insert with check (auth.role() = 'authenticated');

create policy "The owner can delete a group." on groups for
    delete using (auth.uid() = creator);

-- Message Policies
create policy "Authenticated users can read messages." on messages
  for select using (auth.role() = 'authenticated');

create policy "Authenticated users can create messages." on messages
  for insert with check (auth.role() = 'authenticated');

-- Function for handling new users
create or replace function public.handle_new_user() 
returns trigger as $$
begin
  insert into public.users (id, email)
  values (new.id, new.email);
  return new;
end;
$$ language plpgsql security definer;
 
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();


begin;
  -- remove the supabase_realtime publication
  drop publication if exists supabase_realtime;

  -- re-create the supabase_realtime publication with no tables and only for insert
  create publication supabase_realtime with (publish = 'insert');
commit;

-- add a table to the publication
alter publication supabase_realtime add table messages;