const { initializeApp, cert } = require('firebase-admin/app');
const { getFirestore } = require('firebase-admin/firestore');

initializeApp({
  credential: cert(
    require('C:/Users/josev/Downloads/csjb-4a224-firebase-adminsdk-fbsvc-018e551d29.json')
  )
});

const db = getFirestore();

async function verificar() {
  const colecciones = ['triajes', 'chats_ia', 'recordatorios'];
  let totalCon = 0;
  let totalSin = 0;

  for (const col of colecciones) {
    console.log(`\n${'─'.repeat(60)}`);
    console.log(`Colección: ${col}`);
    console.log('─'.repeat(60));
    const snap = await db.collection(col).get();
    if (snap.empty) {
      console.log('  (vacía)');
      continue;
    }
    for (const doc of snap.docs) {
      const uid = doc.data().uid;
      const tieneUid = uid !== undefined && uid !== null && uid !== '';
      if (tieneUid) totalCon++; else totalSin++;
      console.log(`  ID: ${doc.id.padEnd(30)} uid: ${tieneUid ? 'SÍ  valor: ' + uid : 'NO'}`);
    }
  }

  console.log(`\n${'═'.repeat(60)}`);
  console.log('RESUMEN TOTAL');
  console.log(`  Documentos con uid   : ${totalCon}`);
  console.log(`  Documentos sin uid   : ${totalSin}`);
  if (totalSin > 0) console.log('  ⚠  Hay documentos sin uid. Las Firestore Rules los bloquearán.');
  else console.log('  ✅ Todos los documentos tienen uid. Safe to deploy.');
  process.exit(0);
}

verificar().catch(e => { console.error(e); process.exit(1); });
