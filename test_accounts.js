const { PrismaClient } = require('./lib/generated/prisma');

async function testAccounts() {
  const prisma = new PrismaClient();

  try {
    console.log('Testing V_AccountsList...');
    const accounts = await prisma.v_AccountsList.findMany({
      take: 10
    });
    console.log('First 10 accounts:', accounts);

    // Test search for accounts containing '17'
    const searchResults = await prisma.v_AccountsList.findMany({
      where: {
        OR: [
          { AccountCode: { contains: '17' } },
          { Names: { contains: '17' } }
        ]
      },
      take: 10
    });
    console.log('Accounts containing "17":', searchResults);

  } catch (error) {
    console.error('Error:', error.message);
  } finally {
    await prisma.$disconnect();
  }
}

testAccounts();