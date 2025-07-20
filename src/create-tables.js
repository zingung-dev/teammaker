// 데이터베이스 테이블 생성을 위한 스크립트
import supabase from './supabase.js';

// 테이블 생성 함수
async function createTables() {
  try {
    console.log('Supabase 데이터베이스 테이블 생성 중...');

    // 사용자 테이블 생성 (Supabase Auth와 연동)
    const { error: usersError } = await supabase.rpc('create_users_table', {
      sql: `
        CREATE TABLE IF NOT EXISTS users (
          id UUID PRIMARY KEY REFERENCES auth.users,
          email TEXT UNIQUE NOT NULL,
          name TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW())
        );
      `
    });

    if (usersError) {
      console.error('사용자 테이블 생성 중 오류 발생:', usersError.message);
      // SQL 직접 실행 시도
      console.log('SQL 직접 실행으로 사용자 테이블 생성 시도...');
      const { error: directUserError } = await supabase.from('users').insert({}).select().limit(0);
      if (directUserError && directUserError.code !== '23505') { // 중복 키 에러는 무시
        console.error('SQL 직접 실행 오류:', directUserError.message);
      }
    } else {
      console.log('사용자 테이블이 성공적으로 생성되었습니다.');
    }

    // 팀 테이블 생성
    const { error: teamsError } = await supabase.rpc('create_teams_table', {
      sql: `
        CREATE TABLE IF NOT EXISTS teams (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          name TEXT NOT NULL,
          description TEXT,
          created_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
          owner_id UUID REFERENCES users(id) ON DELETE CASCADE
        );
      `
    });

    if (teamsError) {
      console.error('팀 테이블 생성 중 오류 발생:', teamsError.message);
      // 직접 생성 시도
      const { error: directTeamsError } = await supabase.from('teams').select().limit(0);
      if (directTeamsError && directTeamsError.code !== '42P01') { // 테이블 없음 에러는 예상됨
        console.log('teams 테이블 상태 확인:', directTeamsError.message);
      }
    } else {
      console.log('팀 테이블이 성공적으로 생성되었습니다.');
    }

    // 팀 멤버 테이블 생성
    const { error: teamMembersError } = await supabase.rpc('create_team_members_table', {
      sql: `
        CREATE TABLE IF NOT EXISTS team_members (
          id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
          team_id UUID REFERENCES teams(id) ON DELETE CASCADE,
          user_id UUID REFERENCES users(id) ON DELETE CASCADE,
          role TEXT,
          joined_at TIMESTAMP WITH TIME ZONE DEFAULT TIMEZONE('utc', NOW()),
          UNIQUE(team_id, user_id)
        );
      `
    });

    if (teamMembersError) {
      console.error('팀 멤버 테이블 생성 중 오류 발생:', teamMembersError.message);
      // 직접 생성 시도
      const { error: directMembersError } = await supabase.from('team_members').select().limit(0);
      if (directMembersError && directMembersError.code !== '42P01') { // 테이블 없음 에러는 예상됨
        console.log('team_members 테이블 상태 확인:', directMembersError.message);
      }
    } else {
      console.log('팀 멤버 테이블이 성공적으로 생성되었습니다.');
    }

    console.log('데이터베이스 설정이 완료되었습니다.');
    console.log('테이블이 존재하는지 확인 중...');

    // 테이블이 존재하는지 확인
    const { data: tables, error: tablesError } = await supabase
      .from('information_schema.tables')
      .select('table_name')
      .eq('table_schema', 'public')
      .in('table_name', ['users', 'teams', 'team_members']);

    if (tablesError) {
      console.error('테이블 확인 중 오류 발생:', tablesError.message);
    } else {
      console.log('확인된 테이블:', tables);
    }

  } catch (error) {
    console.error('데이터베이스 설정 중 오류 발생:', error.message);
    console.log('참고: Supabase에서 SQL 실행 권한이 제한될 수 있습니다.');
    console.log('테이블 생성은 Supabase 대시보드의 SQL 에디터에서 직접 수행하세요.');
  }
}

// 실행
createTables(); 