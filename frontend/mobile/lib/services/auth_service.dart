import 'package:flutter/material.dart';
import 'package:haptitalk/models/user/user_model.dart';
import 'package:haptitalk/services/local_storage_service.dart';
import 'package:haptitalk/services/api_service.dart';
import 'dart:convert';

class AuthService {
  final ApiService _apiService;
  final LocalStorageService _storageService;

  // 싱글톤 패턴 구현
  static AuthService? _instance;
  
  AuthService._internal(this._apiService, this._storageService);
  
  factory AuthService.create(ApiService apiService, LocalStorageService storageService) {
    _instance ??= AuthService._internal(apiService, storageService);
    return _instance!;
  }
  
  factory AuthService() {
    if (_instance == null) {
      throw Exception('AuthService가 초기화되지 않았습니다. AuthService.create()를 먼저 호출하세요.');
    }
    return _instance!;
  }

  // 현재 로그인한 사용자 정보
  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  // JWT 토큰들
  String? _accessToken;
  String? _refreshToken;

  // API 서비스 인스턴스 getter 추가
  ApiService get apiService => _apiService;

  // 프로필 조회 재시도 횟수
  static const int _maxProfileFetchRetries = 2;

  // 로그인 메서드
  Future<bool> login(String email, String password) async {
    try {
      print('🔄 로그인 시도: $email');
      
      // 로그인 전에 기존 Authorization 헤더 제거 (보안 및 API 설계 원칙)
      _apiService.removeHeader('Authorization');
      print('🔄 로그인 전 기존 Authorization 헤더 제거');
      
      final response = await _apiService.post('/auth/login', body: {
        'email': email,
        'password': password,
      });

      print('🔄 로그인 API 응답 타입: ${response.runtimeType}');
      print('🔄 로그인 API 응답 내용: $response');

      if (response is Map<String, dynamic> && response['success'] == true && response['data'] != null) {
        final data = response['data'];
        print('🔄 응답 데이터: $data');

        // 토큰 저장
        _accessToken = data['access_token'];
        _refreshToken = data['refresh_token'];
        
        if (_accessToken == null || _refreshToken == null) {
          print('❌ 토큰이 응답에 포함되지 않음: access_token=${_accessToken != null}, refresh_token=${_refreshToken != null}');
          return false;
        }
        
        print('🔑 액세스 토큰 수신: ${_accessToken?.substring(0, 20)}...');
        print('🔑 리프레시 토큰 수신: ${_refreshToken?.substring(0, 20)}...');
        
        await _storageService.setItem('access_token', _accessToken!);
        await _storageService.setItem('refresh_token', _refreshToken!);
        
        // API 서비스에 토큰 추가
        _apiService.updateHeaders({
          'Authorization': 'Bearer $_accessToken',
        });
        print('🔄 API 서비스 헤더 업데이트 (로그인 시): Bearer ${_accessToken?.substring(0, 10)}... ');

        // 로그인 응답에서 기본 사용자 정보 저장 (이메일 포함)
        if (data['user'] != null) {
          final loginUserData = data['user'];
          _currentUser = UserModel.fromJson(loginUserData);
          print('🔄 로그인 응답에서 기본 사용자 정보 저장: ${_currentUser?.name} (${_currentUser?.email})');
        }

        // 사용자 정보 조회 (프로필 정보로 보완)
        await _fetchUserProfile(retryCount: 0);
        
        if (_currentUser != null && _currentUser!.id != 'unknown') {
          print('✅ 실제 API 로그인 성공: ${_currentUser?.name}');
          return true;
        } else {
          print('❌ 로그인 후 프로필 조회 실패. 폴백 상태.');
          // 로그인 자체는 성공했으나 프로필 조회가 최종 실패한 경우
          // 필요하다면 여기서 로그아웃 처리를 할 수도 있습니다.
          return false; // 프로필 조회 실패를 로그인 실패로 간주
        }
      } else {
        print('❌ 로그인 API 응답 오류: success=${response['success']}, data=${response['data']}');
        print('❌ 전체 응답: $response');
        return false;
      }
    } catch (e) {
      print('❌ 로그인 실패 (예외 발생): $e');
      print('❌ 예외 타입: ${e.runtimeType}');
      if (e.toString().contains('401') || e.toString().contains('Unauthorized')) {
        print('❌ 인증 실패: 이메일 또는 비밀번호가 올바르지 않습니다.');
      } else if (e.toString().contains('404')) {
        print('❌ API 엔드포인트를 찾을 수 없습니다.');
      } else if (e.toString().contains('500')) {
        print('❌ 서버 내부 오류가 발생했습니다.');
      } else {
        print('❌ 네트워크 또는 기타 오류: $e');
      }
      return false;
    }
  }

  // 회원가입 메서드
  Future<bool> register(String email, String password, String name) async {
    try {
      final response = await _apiService.post('/auth/register', body: {
        'email': email,
        'password': password,
        'username': name,
      });

      if (response['success'] == true) {
        print('✅ 회원가입 성공, 자동 로그인 시도 중...');
        // 회원가입 후 자동 로그인
        return await login(email, password);
      }
      
      return false;
    } catch (e) {
      print('회원가입 실패: $e');
    return false;
  }
  }

  // JWT 액세스 토큰 가져오기
  Future<String?> getAccessToken() async {
    try {
      // 메모리에 있는 토큰 먼저 확인
      if (_accessToken != null) {
        return _accessToken;
      }
      
      // 로컬 스토리지에서 토큰 조회
      _accessToken = await _storageService.getItem('access_token');
      
      if (_accessToken != null) {
        return _accessToken;
      }
      
      return null;
    } catch (e) {
      print('❌ 액세스 토큰 조회 실패: $e');
      return null;
    }
  }

  // 로그인 상태 확인
  bool isLoggedIn() {
    return _currentUser != null;
  }

  // 사용자 프로필 조회
  Future<void> _fetchUserProfile({int retryCount = 0}) async {
    print('🔄 프로필 조회 시도 (재시도 횟수: $retryCount)');
    if (_accessToken == null) {
      print('❌ 프로필 조회 불가: 액세스 토큰 없음.');
      // 이 경우, 자동 로그인 로직 등에서 먼저 토큰을 가져오거나 리프레시해야 함
      if (retryCount < _maxProfileFetchRetries) {
        print('🔄 액세스 토큰 없으므로 리프레시 시도...');
        bool refreshed = await refreshToken();
        if (refreshed) {
          await _fetchUserProfile(retryCount: retryCount + 1);
        } else {
          print('❌ 리프레시 실패. 프로필 조회 중단.');
          await _handleProfileFetchFailure();
        }
      } else {
        print('❌ 최대 재시도 도달. 프로필 조회 중단.');
        await _handleProfileFetchFailure();
      }
      return;
    }
    
    // API 서비스 헤더에 현재 토큰이 올바르게 설정되어 있는지 다시 한번 확인/설정
    // refreshToken 함수 내에서도 헤더를 업데이트 하지만, 여기서도 확실히 해줍니다.
    _apiService.updateHeaders({'Authorization': 'Bearer $_accessToken'});
    print('🔄 API 서비스 헤더 업데이트 (프로필 조회 시): Bearer ${_accessToken?.substring(0, 10)}...');

    try {
      // user-service의 프로필 API 호출
      final response = await _apiService.get('/users/profile');
      
      if (response['success'] == true && response['data'] != null) {
        // 기존 사용자 정보가 있다면 이메일 등 기본 정보를 보존
        String? existingEmail = _currentUser?.email;
        String? existingId = _currentUser?.id;
        
        // 프로필 정보로 사용자 모델 생성
        final profileData = Map<String, dynamic>.from(response['data']);
        
        // 이메일과 ID 정보 보완
        if (existingEmail != null && !profileData.containsKey('email')) {
          profileData['email'] = existingEmail;
        }
        if (existingId != null && (profileData['id'] == null || profileData['id'].toString().isEmpty)) {
          profileData['id'] = existingId;
        }
        
        _currentUser = UserModel.fromJson(profileData);
        await LocalStorageService.setObject('user_profile', _currentUser!.toJson());
        print('✅ 프로필 조회 성공: ${_currentUser?.name}');
      } else {
        // API는 성공(2xx)했으나, success:false 또는 data:null인 경우 (서버 로직에 따라)
        print('❌ 프로필 API 응답 형식 오류 또는 데이터 없음: $response');
        if (retryCount < _maxProfileFetchRetries) {
            print('🔄 응답 형식 오류로 인한 프로필 조회 실패. 리프레시 후 재시도...');
            bool refreshed = await refreshToken();
            if (refreshed) {
                await _fetchUserProfile(retryCount: retryCount + 1);
            } else {
                await _handleProfileFetchFailure();
            }
        } else {
            await _handleProfileFetchFailure();
        }
      }
    } catch (e) {
      print('❌ 사용자 프로필 조회 실패: $e');
      if (e.toString().contains('401 Unauthorized')) {
        print('🔄 토큰 만료 또는 무효로 인한 프로필 조회 실패. (재시도 $retryCount / $_maxProfileFetchRetries)');
        if (retryCount < _maxProfileFetchRetries) {
          bool refreshed = await refreshToken();
          if (refreshed) {
            print('🔄 토큰 리프레시 성공. 프로필 재조회 시도...');
            await _fetchUserProfile(retryCount: retryCount + 1); 
          } else {
            print('❌ 토큰 리프레시 실패. 프로필 조회 중단.');
            await _handleProfileFetchFailure();
          }
        } else {
          print('❌ 최대 재시도 도달. 프로필 조회 중단.');
          await _handleProfileFetchFailure();
        }
      } else {
        // 401 이외의 다른 오류 (네트워크 오류 등)
        print('❌ 기타 오류로 프로필 조회 실패. (재시도 $retryCount / $_maxProfileFetchRetries)');
        if (retryCount < _maxProfileFetchRetries) {
           // 단순 네트워크 오류일 수 있으므로 짧은 지연 후 재시도 고려 가능
           // 여기서는 바로 리프레시를 시도하거나, 재시도 로직을 더 정교하게 만들 수 있음
           // 지금은 리프레시 없이 바로 실패 처리 또는 다음 재시도(만약 있다면)로 넘어감
           // 필요시 이 부분에 대한 재시도 로직 추가
          await _fetchUserProfile(retryCount: retryCount + 1); // 예: 네트워크 오류도 재시도
        } else {
            await _handleProfileFetchFailure();
        }
      }
    }
  }

  Future<void> _handleProfileFetchFailure() async {
    print('🔄 프로필 조회 최종 실패. 기본 사용자 정보로 폴백 및 로그아웃 고려.');
    if (_currentUser == null || _currentUser!.id == 'unknown') {
       _currentUser = UserModel(
        id: 'unknown',
        email: 'unknown@example.com',
        name: '테스트 사용자 (폴백)',
      );
      print('🔄 기본 사용자 정보로 폴백됨.');
    }
    // 필요시 여기서 강제 로그아웃 처리:
    // await logout(); 
    // print('🔒 프로필 조회 최종 실패로 자동 로그아웃됨.');
  }

  // 로그아웃 메서드
  Future<void> logout() async {
    try {
      // 서버에 로그아웃 요청 (선택사항)
      if (_accessToken != null) {
        try {
          await _apiService.post('/auth/logout');
        } catch (e) {
          print('⚠️ 서버 로그아웃 요청 실패: $e');
        }
      }
      
      // 로컬 데이터 정리
      _accessToken = null;
      _refreshToken = null;
      _currentUser = null;
      
      // 로컬 스토리지에서 토큰 제거
      await _storageService.removeItem('access_token');
      await _storageService.removeItem('refresh_token');
      await _storageService.removeItem('user_profile');
      
      // API 서비스에서 Authorization 헤더 제거
      _apiService.removeHeader('Authorization');
      
      print('✅ 로그아웃 완료');
    } catch (e) {
      print('❌ 로그아웃 실패: $e');
    }
  }

  // 자동 로그인 체크 (앱 시작 시 호출)
  Future<bool> checkAutoLogin() async {
    try {
      // 저장된 토큰 조회
      _accessToken = await _storageService.getItem('access_token');
      _refreshToken = await _storageService.getItem('refresh_token');
      
      if (_accessToken == null) {
        print('ⓘ 자동 로그인: 저장된 액세스 토큰 없음.');
        return false;
      }
      
      // API 서비스에 토큰 설정
      _apiService.updateHeaders({
        'Authorization': 'Bearer $_accessToken',
      });
      print('🔄 API 서비스 헤더 업데이트 (자동 로그인 시): Bearer ${_accessToken?.substring(0, 10)}...');
      
      // 저장된 사용자 정보 조회 (초기값으로 사용)
      final userJson = await LocalStorageService.getObject('user_profile');
      if (userJson != null) {
        _currentUser = UserModel.fromJson(userJson);
        print('ⓘ 자동 로그인: 로컬 프로필 정보 로드 - ${_currentUser?.name}');
      }
      
      // 토큰 유효성 검증 및 최신 프로필 정보 동기화를 위해 프로필 조회
      await _fetchUserProfile(retryCount: 0);
      
      if (_currentUser != null && _currentUser!.id != 'unknown') {
        print('✅ 자동 로그인 성공: ${_currentUser?.name}');
        return true;
      } else {
        print('❌ 자동 로그인 실패 또는 프로필 조회 최종 실패.');
        await logout(); // 프로필 조회 실패 시 로그아웃 처리
        return false;
      }
    } catch (e) {
      print('❌ 자동 로그인 중 예외 발생: $e');
      await logout(); // 예외 발생 시 안전하게 로그아웃
      return false;
    }
  }

  // 토큰 리프레시
  Future<bool> refreshToken() async {
    print('🔄 토큰 리프레시 시도...');
    if (_refreshToken == null) {
      _refreshToken = await _storageService.getItem('refresh_token');
      if (_refreshToken == null) {
        print('❌ 토큰 리프레시 실패: 리프레시 토큰 없음.');
        return false;
      }
    }
    
    try {
      // 리프레시 API는 일반적으로 인증 헤더 없이 호출되거나, 별도의 API 키 등을 사용할 수 있음
      // 현재 _apiService는 기본적으로 Authorization 헤더를 포함하므로, 
      // 리프레시 전용 ApiService 인스턴스를 사용하거나, 헤더를 일시적으로 제거 후 복구하는 방식 고려 가능
      // 여기서는 현재 _apiService를 그대로 사용한다고 가정 (서버가 Bearer 토큰을 무시하거나 다른 방식으로 처리)
      // 만약 리프레시 API가 Authorization 헤더를 받으면 안된다면, 이 부분을 수정해야 함.
      
      // 임시로 기존 Authorization 헤더를 제거하고 리프레시 요청
      String? tempAuthHeader = _apiService.headers['Authorization'];
      _apiService.removeHeader('Authorization');
      print('ⓘ 리프레시 요청 전 임시로 Authorization 헤더 제거');

      final response = await _apiService.post('/auth/refresh', body: {
        'refresh_token': _refreshToken,
      });

      // 원래 헤더 복구 (다음 요청들을 위해)
      if (tempAuthHeader != null) {
        _apiService.updateHeaders({'Authorization': tempAuthHeader});
        print('ⓘ 리프레시 요청 후 Authorization 헤더 복구');
      } else {
        // 만약 원래 액세스 토큰이 없었다면 (예: _accessToken이 null), 
        // 리프레시 성공 후 새로 받은 토큰으로 헤더를 설정해야 함.
        // 이 부분은 아래 성공 로직에서 처리됨.
      }
      
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];
        
        String? newAccessToken = data['access_token'];
        String? newRefreshToken = data['refresh_token']; // 서버가 새 리프레시 토큰을 줄 수도 있음

        if (newAccessToken == null) {
          print('❌ 토큰 리프레시 실패: 응답에 새 액세스 토큰 없음.');
          return false;
        }
        
        _accessToken = newAccessToken;
        print('🔑 새 액세스 토큰 수신: ${_accessToken?.substring(0,10)}...');
        
        if (newRefreshToken != null) {
          _refreshToken = newRefreshToken;
          print('🔑 새 리프레시 토큰 수신: ${_refreshToken?.substring(0,10)}...');
        }
        
        // 새 토큰 저장
        await _storageService.setItem('access_token', _accessToken!);
        if (_refreshToken != null) {
          await _storageService.setItem('refresh_token', _refreshToken!);
        }
        
        // API 서비스에 새 토큰 설정
        _apiService.updateHeaders({
          'Authorization': 'Bearer $_accessToken',
        });
        print('🔄 API 서비스 헤더 업데이트 (리프레시 성공 시): Bearer ${_accessToken?.substring(0, 10)}...');
        
        print('✅ 토큰 리프레시 성공');
        return true;
      } else {
        print('❌ 토큰 리프레시 실패: API 응답 오류 또는 success:false. 응답: $response');
        // 리프레시 실패 시, 현재 토큰(만료된 토큰)을 계속 사용하면 안되므로 로그아웃 처리
        await logout();
        return false;
      }
    } catch (e) {
      print('❌ 토큰 리프레시 중 예외 발생: $e');
      // 예외 발생 시에도 안전하게 로그아웃 처리
      await logout();
      return false;
    }
  }

  // 사용자 정보 업데이트
  Future<bool> updateUserProfile(Map<String, dynamic> updates) async {
    try {
      final response = await _apiService.patch('/users/profile', body: updates);
      
      if (response['success'] == true && response['data'] != null) {
        _currentUser = UserModel.fromJson(response['data']);
        await LocalStorageService.setObject('user_profile', _currentUser!.toJson());
        print('✅ 사용자 정보 업데이트 성공');
        return true;
      }
      
      return false;
    } catch (e) {
      print('❌ 사용자 정보 업데이트 실패: $e');
      return false;
    }
  }
}
