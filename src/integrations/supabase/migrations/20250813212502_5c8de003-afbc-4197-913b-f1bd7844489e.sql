-- Create profiles table for user data including usernames
CREATE TABLE public.profiles (
                                 id UUID NOT NULL DEFAULT gen_random_uuid() PRIMARY KEY,
                                 user_id UUID NOT NULL UNIQUE REFERENCES auth.users(id) ON DELETE CASCADE,
                                 username TEXT UNIQUE,
                                 display_name TEXT,
                                 created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
                                 updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- Enable RLS
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Create policies
CREATE POLICY "Profiles are viewable by everyone"
ON public.profiles
FOR SELECT
               USING (true);

CREATE POLICY "Users can update their own profile"
ON public.profiles
FOR UPDATE
               USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own profile"
ON public.profiles
FOR INSERT
WITH CHECK (auth.uid() = user_id);

-- Create function to update timestamps
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger for automatic timestamp updates
CREATE TRIGGER update_profiles_updated_at
    BEFORE UPDATE ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.update_updated_at_column();

-- Create function to handle new user signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER SET search_path = ''
AS $$
BEGIN
INSERT INTO public.profiles (user_id, username, display_name)
VALUES (
           NEW.id,
           NEW.raw_user_meta_data ->> 'username',
           NEW.raw_user_meta_data ->> 'display_name'
       );
RETURN NEW;
END;
$$;

-- Trigger to create profile when user signs up
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();