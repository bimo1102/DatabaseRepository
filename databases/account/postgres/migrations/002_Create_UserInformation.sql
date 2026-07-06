-- Read Model: Adding full name to users_read flat table
ALTER TABLE public.users_read ADD COLUMN full_name VARCHAR(256);
