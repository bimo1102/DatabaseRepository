-- Read Model: Denormalized User Table
CREATE TABLE public.users_read (
  id UUID PRIMARY KEY,
  username VARCHAR(256) NOT NULL,
  email VARCHAR(256)
);
