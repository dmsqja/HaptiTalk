-- 인증 관련 테이블
CREATE TABLE IF NOT EXISTS auth.users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    salt VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    last_login TIMESTAMP WITH TIME ZONE,
    is_active BOOLEAN NOT NULL DEFAULT true,
    is_verified BOOLEAN NOT NULL DEFAULT false,
    verification_token VARCHAR(255),
    reset_token VARCHAR(255),
    reset_token_expires_at TIMESTAMP WITH TIME ZONE,
    login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMP WITH TIME ZONE
);

-- 사용자 프로필 테이블
CREATE TABLE IF NOT EXISTS users.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username VARCHAR(50) UNIQUE,
    name VARCHAR(100),           -- 한국어 이름용 통합 필드
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birth_date DATE,
    gender VARCHAR(20),
    profile_image_url VARCHAR(255),
    bio TEXT,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 사용자 설정 테이블
CREATE TABLE IF NOT EXISTS users.settings (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    notification_enabled BOOLEAN NOT NULL DEFAULT true,
    haptic_strength INTEGER NOT NULL DEFAULT 5 CHECK (haptic_strength BETWEEN 1 AND 10),
    analysis_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    audio_retention_days INTEGER NOT NULL DEFAULT 7,
    data_anonymization_level VARCHAR(20) NOT NULL DEFAULT 'standard',
    default_mode VARCHAR(20) NOT NULL DEFAULT 'dating',
    theme VARCHAR(20) NOT NULL DEFAULT 'system',
    language VARCHAR(10) NOT NULL DEFAULT 'ko',
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 사용자 기기 정보 테이블
CREATE TABLE IF NOT EXISTS users.devices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    device_type VARCHAR(50) NOT NULL,
    device_token VARCHAR(255),
    device_name VARCHAR(100),
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    is_watch BOOLEAN NOT NULL DEFAULT false,
    paired_device_id UUID REFERENCES users.devices(id),
    last_active TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    UNIQUE(user_id, device_token)
);

-- 세션 테이블
CREATE TABLE IF NOT EXISTS users.sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    session_type VARCHAR(50) NOT NULL, -- 'dating', 'interview', 'business', 'coaching'
    start_time TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    end_time TIMESTAMP WITH TIME ZONE,
    duration INTEGER, -- 초 단위
    device_id UUID REFERENCES users.devices(id),
    settings JSONB, -- 세션별 설정
    tags TEXT[], -- 사용자 지정 태그
    custom_name VARCHAR(100),
    status VARCHAR(20) NOT NULL DEFAULT 'active', -- 'active', 'completed', 'interrupted'
    mongo_analysis_id VARCHAR(50), -- MongoDB의 분석 결과 ID 참조
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);

-- 앱 설정 테이블
CREATE TABLE IF NOT EXISTS config.app_settings (
    id SERIAL PRIMARY KEY,
    key VARCHAR(100) NOT NULL UNIQUE,
    value TEXT NOT NULL,
    description TEXT,
    is_public BOOLEAN NOT NULL DEFAULT false,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_by UUID
);

-- 햅틱 패턴 정의 테이블
CREATE TABLE IF NOT EXISTS config.haptic_patterns (
    id VARCHAR(50) PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    pattern_data JSONB NOT NULL,
    category VARCHAR(50) NOT NULL, -- 'pace', 'emotion', 'alert', 'etc'
    intensity_default INTEGER NOT NULL DEFAULT 5,
    duration_ms INTEGER NOT NULL DEFAULT 300,
    version INTEGER NOT NULL DEFAULT 1,
    is_active BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now(),
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT now()
);