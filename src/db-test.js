// Supabase 연결 테스트를 위한 예제 코드
import supabase from './supabase.js';

// 간단한 연결 테스트 함수
async function testBasicConnection() {
  try {
    console.log('Supabase 연결 테스트 중...');
    console.log(`Supabase URL: ${process.env.SUPABASE_URL}`);
    console.log('API 키: ' + '*'.repeat(10) + ' (보안을 위해 숨김)');
    
    // 기본 연결 테스트
    const { data, error } = await supabase.auth.getSession();
    
    if (error) {
      throw error;
    }
    
    console.log('Supabase 연결 성공!');
    console.log('데이터베이스 연결이 정상적으로 작동하고 있습니다.');
    console.log('세션 정보:', data);
    
    // 버전 확인 시도 (선택적)
    try {
      const { data: version } = await supabase.from('_version').select('*').limit(1);
      if (version) {
        console.log('Supabase 버전 정보:', version);
      }
    } catch (versionError) {
      // 버전 정보 가져오기 실패는 무시
    }
    
  } catch (error) {
    console.error('Supabase 연결 테스트 실패:', error.message);
    console.log('Supabase URL과 API 키를 확인하세요.');
  }
}

// 실행
testBasicConnection(); 