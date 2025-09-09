const {DataTypes} = require('sequelize');
const {sequelize} = require('../config/database');

const Profile = sequelize.define('profile', {
    id: {
        type: DataTypes.UUID,
        primaryKey: true,
        allowNull: false,
        comment: '사용자 ID (auth.users.id 참조)'
    },
    username: {
        type: DataTypes.STRING(50),
        unique: true,
        allowNull: true,
        comment: '사용자명'
    },
    name: {
        type: DataTypes.STRING(100),
        allowNull: true,
        comment: '전체 이름 (한국식)'
    },
    first_name: {
        type: DataTypes.STRING(100),
        allowNull: true,
        comment: '이름 (서구식 - 호환성용)'
    },
    last_name: {
        type: DataTypes.STRING(100),
        allowNull: true,
        comment: '성 (서구식 - 호환성용)'
    },
    birth_date: {
        type: DataTypes.DATEONLY,
        allowNull: true,
        comment: '생년월일'
    },
    gender: {
        type: DataTypes.STRING(20),
        allowNull: true,
        comment: '성별'
    },
    profile_image_url: {
        type: DataTypes.STRING(255),
        allowNull: true,
        comment: '프로필 이미지 URL'
    },
    bio: {
        type: DataTypes.TEXT,
        allowNull: true,
        comment: '자기소개'
    },
    created_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
        comment: '프로필 생성 시간'
    },
    updated_at: {
        type: DataTypes.DATE,
        allowNull: false,
        defaultValue: DataTypes.NOW,
        comment: '프로필 업데이트 시간'
    }
}, {
    tableName: 'profiles',
    schema: 'users',
    timestamps: true,
    createdAt: 'created_at',
    updatedAt: 'updated_at'
});

module.exports = Profile;