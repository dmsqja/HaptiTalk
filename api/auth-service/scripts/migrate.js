const { sequelize } = require('../src/config/database');
const User = require('../src/models/user.model');
const logger = require('../src/utils/logger');

async function migrate() {
  try {
    // 스키마 존재하는지 확인하고 생성
    await sequelize.query(`
      CREATE SCHEMA IF NOT EXISTS auth;
    `);
    
    // 시퀄라이즈 모델에서 테이블 싱크
    await sequelize.sync({ alter: true });
    
    logger.info('Database migration completed successfully');
    console.log('Migration successful!');
    
    // 프로세스 종료
    process.exit(0);
  } catch (error) {
    logger.error('Migration failed:', error);
    console.error('Migration failed:', error);
    process.exit(1);
  }
}

// 직접 실행 시 마이그레이션 실행
if (require.main === module) {
  migrate();
}

module.exports = { migrate }; 