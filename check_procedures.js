const { PrismaClient } = require('./lib/generated/prisma');

async function checkProcedures() {
  const prisma = new PrismaClient();

  try {
    const procedures = await prisma.$queryRaw`
      SELECT name FROM sys.procedures WHERE type = 'P'
    `;
    console.log('Available stored procedures:');
    console.log(procedures);
  } catch (error) {
    console.error('Error fetching procedures:', error);
  } finally {
    await prisma.$disconnect();
  }
}

checkProcedures();