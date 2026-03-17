const admin = require('firebase-admin');

// Initialize with Application Default Credentials
admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  projectId: 'lunch-luckyvicky',
});
const db = admin.firestore();

async function deleteTestSessions() {
  // Get all groups
  const groupsSnap = await db.collection('groups').get();
  
  let totalDeleted = 0;
  
  for (const groupDoc of groupsSnap.docs) {
    const groupId = groupDoc.id;
    console.log(`\nChecking group: ${groupId} (${groupDoc.data().name || 'unnamed'})`);
    
    // Get all completed sessions
    const sessionsSnap = await db
      .collection('groups')
      .doc(groupId)
      .collection('sessions')
      .where('status', '==', 'completed')
      .get();
    
    let groupDeleted = 0;
    
    for (const sessionDoc of sessionsSnap.docs) {
      const data = sessionDoc.data();
      const menuSelections = data.menuSelections || {};
      
      // Delete if no menu selections
      if (Object.keys(menuSelections).length === 0) {
        console.log(`  Deleting session ${sessionDoc.id} (created: ${data.createdAt?.toDate?.() || 'unknown'}, restaurant: ${data.selectedRestaurantId || 'none'})`);
        await sessionDoc.ref.delete();
        groupDeleted++;
        totalDeleted++;
      }
    }
    
    console.log(`  Deleted ${groupDeleted}/${sessionsSnap.size} sessions from group ${groupId}`);
  }
  
  console.log(`\nTotal deleted: ${totalDeleted} test sessions`);
  process.exit(0);
}

deleteTestSessions().catch(err => {
  console.error('Error:', err);
  process.exit(1);
});
