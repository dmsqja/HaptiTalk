const { validationResult } = require('express-validator');
const profileService = require('../services/profile.service');
const logger = require('../utils/logger');

/**
 * 프로필 생성 (서비스 간 통신용)
 * @param {Object} req - 요청 객체
 * @param {Object} res - 응답 객체
 * @param {Function} next - 다음 미들웨어 함수
 */
const createProfile = async (req, res, next) => {
    try {
        // 유효성 검사 결과 확인
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(422).json({
                success: false,
                message: '유효성 검사 오류가 발생했습니다.',
                errors: errors.array().map(error => ({
                    code: 'validation_error',
                    field: error.param,
                    message: error.msg
                }))
            });
        }

        const { userId, email, username } = req.body;

        // 프로필 직접 조회 (자동 생성 방지)
        const Profile = require('../models/profile.model');
        let existingProfile = await Profile.findByPk(userId);
        
        if (existingProfile) {
            // 프로필이 이미 존재하면 JSON 형태로 반환
            return res.status(200).json({
                success: true,
                data: existingProfile.toJSON(),
                message: '프로필이 이미 존재합니다.'
            });
        }

        // 새 프로필 생성
        const newProfile = await profileService.createDefaultProfile(userId, username);

        logger.info(`서비스 간 프로필 생성 성공: ${userId} (${email})`);

        return res.status(201).json({
            success: true,
            data: newProfile,
            message: '프로필이 성공적으로 생성되었습니다.'
        });
    } catch (error) {
        logger.error('Error in createProfile controller:', error);
        next(error);
    }
};

/**
 * 프로필 조회
 * @param {Object} req - 요청 객체
 * @param {Object} res - 응답 객체
 * @param {Function} next - 다음 미들웨어 함수
 */
const getProfile = async (req, res, next) => {
    try {
        const userId = req.user.id;

        const profile = await profileService.getProfile(userId);

        return res.status(200).json({
            success: true,
            data: profile
        });
    } catch (error) {
        logger.error('Error in getProfile controller:', error);
        next(error);
    }
};

/**
 * 프로필 업데이트
 * @param {Object} req - 요청 객체
 * @param {Object} res - 응답 객체
 * @param {Function} next - 다음 미들웨어 함수
 */
const updateProfile = async (req, res, next) => {
    try {
        // 유효성 검사 결과 확인
        const errors = validationResult(req);
        if (!errors.isEmpty()) {
            return res.status(422).json({
                success: false,
                message: '유효성 검사 오류가 발생했습니다.',
                errors: errors.array().map(error => ({
                    code: 'validation_error',
                    field: error.param,
                    message: error.msg
                }))
            });
        }

        const userId = req.user.id;
        const profileData = req.body;

        const updatedProfile = await profileService.updateProfile(userId, profileData);

        return res.status(200).json({
            success: true,
            data: updatedProfile,
            message: '프로필이 업데이트되었습니다.'
        });
    } catch (error) {
        logger.error('Error in updateProfile controller:', error);
        next(error);
    }
};

module.exports = {
    createProfile,
    getProfile,
    updateProfile
};