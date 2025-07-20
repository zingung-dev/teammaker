-- 팀메이커 프로젝트를 위한 데이터베이스 스키마

-- 사용자 테이블 (Supabase Auth와 연동)
CREATE TABLE IF NOT EXISTS public.users (
  id UUID PRIMARY KEY REFERENCES auth.users,
  email TEXT UNIQUE NOT NULL,
  name TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
);

-- 테이블에 대한 RLS(Row Level Security) 정책 설정
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 정보만 읽을 수 있음
CREATE POLICY "사용자 자신의 정보 읽기" ON public.users
  FOR SELECT USING (auth.uid() = id);
  
-- 사용자는 자신의 정보만 업데이트할 수 있음
CREATE POLICY "사용자 자신의 정보 업데이트" ON public.users
  FOR UPDATE USING (auth.uid() = id);

-- 새 사용자가 등록되면 자동으로 users 테이블에 추가하기 위한 트리거
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.users (id, email, name)
  VALUES (new.id, new.email, new.raw_user_meta_data->>'name');
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 트리거 설정 (이미 존재하는 경우 드롭)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 팀 테이블
CREATE TABLE IF NOT EXISTS public.teams (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  owner_id UUID REFERENCES public.users(id) ON DELETE CASCADE
);

-- 팀 테이블에 대한 RLS 정책 설정
ALTER TABLE public.teams ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 팀 정보를 볼 수 있음
CREATE POLICY "팀 정보 조회" ON public.teams
  FOR SELECT USING (true);
  
-- 팀 소유자만 팀 정보를 수정할 수 있음
CREATE POLICY "팀 소유자 정보 수정" ON public.teams
  FOR UPDATE USING (auth.uid() = owner_id);
  
-- 팀 소유자만 팀을 삭제할 수 있음
CREATE POLICY "팀 소유자 팀 삭제" ON public.teams
  FOR DELETE USING (auth.uid() = owner_id);
  
-- 모든 사용자가 팀을 생성할 수 있음
CREATE POLICY "팀 생성" ON public.teams
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- 팀 멤버 테이블
CREATE TABLE IF NOT EXISTS public.team_members (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  role TEXT,
  joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(team_id, user_id)
);

-- 팀 멤버 테이블에 대한 RLS 정책 설정
ALTER TABLE public.team_members ENABLE ROW LEVEL SECURITY;

-- 모든 사용자가 팀 멤버 정보를 볼 수 있음
CREATE POLICY "팀 멤버 정보 조회" ON public.team_members
  FOR SELECT USING (true);
  
-- 팀 소유자만 팀 멤버를 추가할 수 있음
CREATE POLICY "팀 소유자 멤버 추가" ON public.team_members
  FOR INSERT USING (
    EXISTS (
      SELECT 1 FROM public.teams 
      WHERE id = team_members.team_id AND owner_id = auth.uid()
    )
  );
  
-- 팀 소유자만 팀 멤버를 삭제할 수 있음
CREATE POLICY "팀 소유자 멤버 삭제" ON public.team_members
  FOR DELETE USING (
    EXISTS (
      SELECT 1 FROM public.teams 
      WHERE id = team_members.team_id AND owner_id = auth.uid()
    )
  );

-- 사용자가 팀에 가입할 수 있는 요청 테이블
CREATE TABLE IF NOT EXISTS public.team_join_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  team_id UUID REFERENCES public.teams(id) ON DELETE CASCADE,
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  message TEXT,
  status TEXT DEFAULT 'pending', -- pending, accepted, rejected
  created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
  UNIQUE(team_id, user_id, status)
);

-- 팀 가입 요청 테이블에 대한 RLS 정책 설정
ALTER TABLE public.team_join_requests ENABLE ROW LEVEL SECURITY;

-- 사용자는 자신의 가입 요청을 볼 수 있음
CREATE POLICY "사용자 자신의 가입 요청 조회" ON public.team_join_requests
  FOR SELECT USING (auth.uid() = user_id);
  
-- 팀 소유자는 해당 팀의 모든 가입 요청을 볼 수 있음
CREATE POLICY "팀 소유자 가입 요청 조회" ON public.team_join_requests
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.teams 
      WHERE id = team_join_requests.team_id AND owner_id = auth.uid()
    )
  );
  
-- 사용자는 가입 요청을 생성할 수 있음
CREATE POLICY "사용자 가입 요청 생성" ON public.team_join_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id AND status = 'pending');
  
-- 팀 소유자는 가입 요청 상태를 변경할 수 있음
CREATE POLICY "팀 소유자 가입 요청 상태 변경" ON public.team_join_requests
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.teams 
      WHERE id = team_join_requests.team_id AND owner_id = auth.uid()
    )
  );

-- 가입 요청이 수락되면 팀 멤버로 자동 추가하는 함수
CREATE OR REPLACE FUNCTION public.handle_accepted_join_request()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' AND OLD.status = 'pending' THEN
    INSERT INTO public.team_members (team_id, user_id, role)
    VALUES (NEW.team_id, NEW.user_id, 'member')
    ON CONFLICT (team_id, user_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 가입 요청 상태 변경 트리거 설정
DROP TRIGGER IF EXISTS on_join_request_accepted ON public.team_join_requests;
CREATE TRIGGER on_join_request_accepted
  AFTER UPDATE ON public.team_join_requests
  FOR EACH ROW EXECUTE FUNCTION public.handle_accepted_join_request(); 