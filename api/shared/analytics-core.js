/**
 * HaptiTalk 공통 분석 로직
 * 실시간 분석과 최종 분석에서 동일한 계산 로직 사용
 */

class AnalyticsCore {
  /**
   * 시나리오별 실시간 지표 계산
   */
  static calculateRealtimeMetrics(speechData, scenario) {
    switch (scenario?.toLowerCase()) {
      case 'presentation':
        return this.calculatePresentationMetrics(speechData);
      case 'interview':
        return this.calculateInterviewMetrics(speechData);
      case 'dating':
      default:
        return this.calculateDatingMetrics(speechData);
    }
  }

  /**
   * 발표 시나리오 지표 계산
   */
  static calculatePresentationMetrics(speechData) {
    const confidence = this.calculateSpeakingConfidence(speechData);
    const persuasion = this.calculatePersuasion(speechData);
    const clarity = this.calculateClarity(speechData);
    
    return {
      confidence: Math.round(confidence),
      persuasion: Math.round(persuasion),
      clarity: Math.round(clarity),
      speakingSpeed: speechData.evaluation_wpm || 0
    };
  }

  /**
   * 면접 시나리오 지표 계산
   */
  static calculateInterviewMetrics(speechData) {
    const confidence = this.calculateSpeakingConfidence(speechData);
    const stability = this.calculateStability(speechData);
    const clarity = this.calculateClarity(speechData);
    
    return {
      confidence: Math.round(confidence),
      stability: Math.round(stability),
      clarity: Math.round(clarity),
      speakingSpeed: speechData.evaluation_wpm || 0
    };
  }

  /**
   * 소개팅 시나리오 지표 계산
   */
  static calculateDatingMetrics(speechData) {
    const likeability = this.calculateLikeability(speechData);
    const interest = this.calculateInterest(speechData);
    const emotion = this.calculateEmotion(speechData);
    
    return {
      likeability: Math.round(likeability),
      interest: Math.round(interest),
      emotion: emotion,
      speakingSpeed: speechData.evaluation_wpm || 0
    };
  }

  /**
   * 말하기 자신감 계산 (발표/면접용)
   */
  static calculateSpeakingConfidence(speechData) {
    // 발화 밀도와 말하기 속도를 기반으로 자신감 계산
    const speechDensity = speechData.speech_density || 0.5;
    const speechRate = speechData.evaluation_wpm || 120;
    const tonality = speechData.tonality || 0.7;
    
    // 기본 자신감 계산 (발화 밀도 기반)
    let baseConfidence;
    if (speechDensity <= 0.0) {
      baseConfidence = 10.0;
    } else if (speechDensity <= 0.3) {
      baseConfidence = 10.0 + (speechDensity / 0.3) * 30.0; // 10-40
    } else if (speechDensity <= 0.5) {
      baseConfidence = 40.0 + ((speechDensity - 0.3) / 0.2) * 20.0; // 40-60
    } else if (speechDensity <= 0.7) {
      baseConfidence = 60.0 + ((speechDensity - 0.5) / 0.2) * 15.0; // 60-75
    } else if (speechDensity <= 0.9) {
      baseConfidence = 75.0 + ((speechDensity - 0.7) / 0.2) * 10.0; // 75-85
    } else {
      baseConfidence = 85.0 + ((speechDensity - 0.9) / 0.1) * 10.0; // 85-95
    }
    
    // 말하기 속도 보정 (한국어 기준 개선)
    if (speechRate >= 100 && speechRate <= 180) {
      baseConfidence *= 1.1; // 한국어 적절한 속도일 때 10% 보너스
    } else if (speechRate > 200) {
      baseConfidence *= 0.85; // 너무 빠르면 15% 감소
    } else if (speechRate < 80) {
      baseConfidence *= 0.9; // 너무 느리면 10% 감소
    }
    
    // 톤 품질 보정
    baseConfidence *= (0.7 + tonality * 0.3);
    
    return Math.max(15, Math.min(95, baseConfidence));
  }

  /**
   * 설득력 계산 (발표용) - 피드백 서비스와 통합된 계산법
   */
  static calculatePersuasion(speechData) {
    const tonality = speechData.tonality || 0.7;
    const clarity = speechData.clarity || 0.7;
    const speechPattern = speechData.speech_pattern || 'normal';
    const evaluationWpm = speechData.evaluation_wpm || 120;
    const speechDensity = speechData.speech_density || 0.5;
    
    let totalScore = 0;
    let factorCount = 0;
    
    // 1. 발화 밀도 (35%) - 충분한 발화량이 설득력에 중요
    const densityScore = speechDensity <= 0.3 ? speechDensity / 0.3 * 0.6 :
                        speechDensity <= 0.7 ? 0.6 + (speechDensity - 0.3) / 0.4 * 0.4 : 1.0;
    totalScore += densityScore * 0.35;
    factorCount += 0.35;
    
    // 2. 톤 품질 (25%)
    totalScore += tonality * 0.25;
    factorCount += 0.25;
    
    // 3. 말하기 속도 안정성 (20%) - 설득력에는 안정적 전달이 중요
    const speedScore = evaluationWpm >= 110 && evaluationWpm <= 160 ? 1.0 :
                      evaluationWpm >= 90 && evaluationWpm <= 180 ? 0.8 : 0.6;
    totalScore += speedScore * 0.2;
    factorCount += 0.2;
    
    // 4. 음성 패턴 안정성 (15%)
    const patternScore = speechPattern === 'steady' ? 1.0 :
                        speechPattern === 'normal' ? 0.9 :
                        speechPattern === 'continuous' ? 0.8 : 0.6;
    totalScore += patternScore * 0.15;
    factorCount += 0.15;
    
    // 5. 명확성 기여도 (5%)
    totalScore += clarity * 0.05;
    factorCount += 0.05;
    
    const persuasionScore = factorCount > 0 ? (totalScore / factorCount) * 100 : 60; // 65→60 조정
    return Math.max(25, Math.min(95, persuasionScore));
  }

  /**
   * 명확성 계산 - 피드백 서비스와 통합된 계산법
   */
  static calculateClarity(speechData) {
    const clarity = speechData.clarity || 0.65; // 0.7→0.65 조정
    const speechRate = speechData.evaluation_wpm || 120;
    const speechPattern = speechData.speech_pattern || 'normal';
    const tonality = speechData.tonality || 0.65; // 0.7→0.65 조정
    
    let totalScore = 0;
    let factorCount = 0;
    
    // 1. 기본 명확성 지표 (40%)
    totalScore += clarity * 0.4;
    factorCount += 0.4;
    
    // 2. 말하기 속도 적절성 (25%) - 명확성에는 적당한 속도가 중요
    const speedScore = speechRate >= 100 && speechRate <= 150 ? 1.0 :
                      speechRate >= 80 && speechRate <= 170 ? 0.8 : 0.6;
    totalScore += speedScore * 0.25;
    factorCount += 0.25;
    
    // 3. 음성 패턴 일관성 (20%)
    const patternScore = speechPattern === 'normal' ? 1.0 : 
                        speechPattern === 'steady' ? 0.9 : 
                        speechPattern === 'continuous' ? 0.7 : 0.6;
    totalScore += patternScore * 0.2;
    factorCount += 0.2;
    
    // 4. 톤 품질 (15%) - 명확한 발음과 관련
    totalScore += tonality * 0.15;
    factorCount += 0.15;
    
    const clarityScore = factorCount > 0 ? (totalScore / factorCount) * 100 : 65;
    return Math.max(25, Math.min(95, clarityScore));
  }

  /**
   * 안정감 계산 (면접용)
   */
  static calculateStability(speechData) {
    const tonality = speechData.tonality || 0.7;
    const speechPattern = speechData.speech_pattern || 'normal';
    const speechRate = speechData.evaluation_wpm || 120;
    
    let stabilityScore = tonality * 100;
    
    // 말하기 패턴에 따른 안정감 조정
    const patternStability = {
      'steady': 15,
      'normal': 5,
      'continuous': 0,
      'variable': -10,
      'staccato': -15,
      'sparse': -20
    };
    
    stabilityScore += (patternStability[speechPattern] || 0);
    
    // 적절한 속도일 때 안정감 증가
    if (speechRate >= 110 && speechRate <= 150) {
      stabilityScore += 5;
    }
    
    return Math.max(25, Math.min(90, stabilityScore));
  }

  /**
   * 호감도 계산 (소개팅용)
   */
  static calculateLikeability(speechData) {
    const speechDensity = speechData.speech_density || 0.5;
    const emotionScore = speechData.emotion_score || 0.6;
    
    // 발화 밀도 기반 호감도
    let baseLikeability;
    if (speechDensity <= 0.0) {
      baseLikeability = 10.0;
    } else if (speechDensity <= 0.3) {
      baseLikeability = 10.0 + (speechDensity / 0.3) * 30.0;
    } else if (speechDensity <= 0.5) {
      baseLikeability = 40.0 + ((speechDensity - 0.3) / 0.2) * 20.0;
    } else if (speechDensity <= 0.7) {
      baseLikeability = 60.0 + ((speechDensity - 0.5) / 0.2) * 15.0;
    } else {
      baseLikeability = 75.0 + ((speechDensity - 0.7) / 0.3) * 15.0;
    }
    
    // 감정 점수 반영
    baseLikeability *= (0.6 + emotionScore * 0.4);
    
    return Math.max(15, Math.min(95, baseLikeability));
  }

  /**
   * 관심도 계산 (소개팅용)
   */
  static calculateInterest(speechData) {
    const speechPattern = speechData.speech_pattern || 'normal';
    const tonality = speechData.tonality || 0.7;
    
    // 말하기 패턴 기반 관심도
    const patternInterest = {
      'continuous': 85,
      'steady': 80,
      'variable': 75,
      'normal': 70,
      'staccato': 55,
      'sparse': 40,
      'very_sparse': 25
    };
    
    let baseInterest = patternInterest[speechPattern] || 50;
    
    // 톤 품질 반영
    baseInterest *= (0.7 + tonality * 0.3);
    
    return Math.max(20, Math.min(90, baseInterest));
  }

  /**
   * 감정 상태 계산
   */
  static calculateEmotion(speechData) {
    const speedCategory = speechData.speed_category || 'normal';
    
    const emotionMap = {
      'very_slow': '침착함',
      'slow': '안정적',
      'normal': '자연스러움',
      'fast': '활발함',
      'very_fast': '흥미로움'
    };
    
    return emotionMap[speedCategory] || '대기 중';
  }

  /**
   * 햅틱 피드백 조건 체크
   */
  static shouldSendHapticFeedback(currentMetrics, previousMetrics, scenario) {
    if (!previousMetrics) return false;
    
    switch (scenario?.toLowerCase()) {
      case 'presentation':
        return this.checkPresentationHapticConditions(currentMetrics, previousMetrics);
      case 'interview':
        return this.checkInterviewHapticConditions(currentMetrics, previousMetrics);
      case 'dating':
      default:
        return this.checkDatingHapticConditions(currentMetrics, previousMetrics);
    }
  }

  /**
   * 발표 시나리오 햅틱 조건 체크
   */
  static checkPresentationHapticConditions(current, previous) {
    const conditions = [];
    
    // 🎉 발표 자신감 우수 (높을 때 격려)
    if (current.confidence >= 80) {
      conditions.push({
        type: 'confidence_excellent',
        priority: 'medium',
        message: '🎉 훌륭한 발표 자신감이에요!',
        pattern: 'confidence_excellent'
      });
    }
    
    // 자신감 부족 (낮을 때 개선 메시지)
    else if (current.confidence < 50) {
      conditions.push({
        type: 'confidence_low',
        priority: 'high',
        message: '💪 더 자신감 있게 말해보세요!',
        pattern: 'confidence_boost'
      });
    }
    
    // 자신감 급하락
    if (previous.confidence - current.confidence >= 20) {
      conditions.push({
        type: 'confidence_down',
        priority: 'high',
        message: '😮‍💨 심호흡하고 천천히 말해보세요',
        pattern: 'confidence_down'
      });
    }
    
    // 🎉 설득력 우수 (높을 때 격려)
    if (current.persuasion >= 75) {
      conditions.push({
        type: 'persuasion_excellent',
        priority: 'medium',
        message: '🎯 설득력이 뛰어나요!',
        pattern: 'persuasion_excellent'
      });
    }
    
    // 설득력 저조
    else if (current.persuasion < 40) {
      conditions.push({
        type: 'persuasion_low',
        priority: 'medium',
        message: '🎯 핵심 포인트를 강조해보세요',
        pattern: 'persuasion_guide'
      });
    }
    
    // 말하기 속도 과속
    if (current.speakingSpeed > 180) {
      conditions.push({
        type: 'speed_fast',
        priority: 'high',
        message: '🚀 조금 천천히 말해보세요',
        pattern: 'speed_control'
      });
    }
    
    return conditions;
  }

  /**
   * 면접 시나리오 햅틱 조건 체크
   */
  static checkInterviewHapticConditions(current, previous) {
    const conditions = [];
    
    // 🎉 면접 자신감 우수 (높을 때 격려)
    if (current.confidence >= 75) {
      conditions.push({
        type: 'confidence_excellent',
        priority: 'medium',
        message: '👔 면접 자신감이 훌륭해요!',
        pattern: 'confidence_excellent'
      });
    }
    
    // 자신감 부족 (낮을 때 개선 메시지)
    else if (current.confidence < 45) {
      conditions.push({
        type: 'confidence_low',
        priority: 'high',
        message: '👔 자신감을 가지고 답변해보세요!',
        pattern: 'confidence_boost'
      });
    }
    
    // 🎉 안정감 우수 (높을 때 격려)
    if (current.stability >= 80) {
      conditions.push({
        type: 'stability_excellent',
        priority: 'medium',
        message: '🧘‍♂️ 매우 안정적인 답변이에요!',
        pattern: 'stability_excellent'
      });
    }
    
    // 안정감 부족
    else if (current.stability < 45) {
      conditions.push({
        type: 'stability_low',
        priority: 'medium',
        message: '🧘‍♂️ 더 차분하게 답변해보세요',
        pattern: 'stability_guide'
      });
    }
    
    return conditions;
  }

  /**
   * 소개팅 시나리오 햅틱 조건 체크
   */
  static checkDatingHapticConditions(current, previous) {
    const conditions = [];
    
    // 🎉 호감도 우수 (높을 때 격려)
    if (current.likeability >= 80) {
      conditions.push({
        type: 'likeability_excellent',
        priority: 'medium',
        message: '💕 상대방이 매우 좋아해요!',
        pattern: 'likeability_excellent'
      });
    }
    
    // 호감도 부족 (낮을 때 개선 메시지)
    else if (current.likeability < 50) {
      conditions.push({
        type: 'likeability_low',
        priority: 'medium',
        message: '💕 더 밝고 긍정적으로 대화해보세요!',
        pattern: 'likeability_boost'
      });
    }
    
    // 🎉 관심도 우수 (높을 때 격려)
    if (current.interest >= 75) {
      conditions.push({
        type: 'interest_excellent',
        priority: 'medium',
        message: '🗣️ 흥미로운 대화가 이어지고 있어요!',
        pattern: 'interest_excellent'
      });
    }
    
    // 관심도 하락
    else if (previous.interest - current.interest >= 20) {
      conditions.push({
        type: 'interest_down',
        priority: 'high',
        message: '⚠️ 주제를 바꿔보세요',
        pattern: 'topic_change'
      });
    }
    
    // 관심도 부족 (낮을 때 개선 메시지)
    else if (current.interest < 45) {
      conditions.push({
        type: 'interest_low',
        priority: 'medium',
        message: '🗣️ 더 흥미로운 대화를 시도해보세요!',
        pattern: 'topic_change'
      });
    }
    
    return conditions;
  }
}

module.exports = AnalyticsCore; 