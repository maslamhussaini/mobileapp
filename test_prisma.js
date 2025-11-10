const { PrismaClient } = require('./lib/generated/prisma');

const prisma = new PrismaClient();

async function testConnection() {
  try {
    await prisma.$connect();
    console.log('Prisma connected successfully to the database.');

    // Test a simple query
    const result = await prisma.tblUsers.findMany({ take: 1 });
    console.log('Test query successful, found', result.length, 'users.');

  } catch (error) {
    console.error('Prisma connection failed:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

testConnection();