import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';

// 환경 변수 로드
dotenv.config();

// Supabase 클라이언트 설정
// 환경 변수에서 URL과 API 키를 가져옵니다
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

// 유효한 URL과 키가 있는지 확인
if (!supabaseUrl || !supabaseKey) {
  console.error('Supabase URL 또는 API 키가 설정되지 않았습니다.');
  console.error('환경 변수 SUPABASE_URL과 SUPABASE_KEY를 설정해주세요.');
  throw new Error('Supabase URL 및 API 키가 필요합니다.');
}

// Supabase 클라이언트 생성
const supabase = createClient(supabaseUrl, supabaseKey);

export default supabase; 