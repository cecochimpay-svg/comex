const fs = require('fs');
const path = require('path');

const dbFile = path.join(__dirname, 'comex_local_data.json');

let store = {
  local_comex_usuarios: [],
  local_logistitcas_temporada: [],
  local_eliminados: [],
  local_vista_pallet_stock_general: []
};

if (fs.existsSync(dbFile)) {
  try {
    store = JSON.parse(fs.readFileSync(dbFile, 'utf-8'));
  } catch (e) {
    console.warn('Iniciando base de datos JSON local limpia.');
  }
}

function persistir() {
  try {
    fs.writeFileSync(dbFile, JSON.stringify(store, null, 2), 'utf-8');
  } catch (err) {
    console.error('Error guardando en disco:', err.message);
  }
}

const db = {
  prepare: (sql) => {
    const query = sql.trim().toUpperCase();

    return {
      run: (...params) => {
        let payload = params[0] || {};

        // 1. INSERT / UPDATE en local_logistitcas_temporada
        if (query.includes('INTO LOCAL_LOGISTITCAS_TEMPORADA')) {
          const regId = String(payload.registro);
          const index = store.local_logistitcas_temporada.findIndex(x => String(x.registro) === regId);
          const registroLimpio = {
            ...payload,
            usuario: payload.usuario || null,
            sincronizado: payload.sincronizado !== undefined ? payload.sincronizado : 0,
            updated_at: new Date().toISOString()
          };

          if (index >= 0) {
            store.local_logistitcas_temporada[index] = { ...store.local_logistitcas_temporada[index], ...registroLimpio };
          } else {
            store.local_logistitcas_temporada.push(registroLimpio);
          }
          persistir();
          return { changes: 1 };
        }

        // 2. DELETE en local_logistitcas_temporada
        if (query.includes('DELETE FROM LOCAL_LOGISTITCAS_TEMPORADA')) {
          const regId = String(params[0]);
          store.local_logistitcas_temporada = store.local_logistitcas_temporada.filter(x => String(x.registro) !== regId);

          store.local_eliminados.push({
            id: Date.now() + Math.floor(Math.random() * 1000),
            tabla: 'logistitcas_temporada',
            registro_id: regId,
            fecha_baja: new Date().toISOString()
          });

          persistir();
          return { changes: 1 };
        }

        // 3. UPDATE sincronizado = 1
        if (query.includes('UPDATE LOCAL_LOGISTITCAS_TEMPORADA SET SINCRONIZADO')) {
          const regId = String(params[0]);
          const item = store.local_logistitcas_temporada.find(x => String(x.registro) === regId);
          if (item) item.sincronizado = 1;
          persistir();
          return { changes: 1 };
        }

        // 4. DELETE en local_eliminados
        if (query.includes('DELETE FROM LOCAL_ELIMINADOS')) {
          const idsABorrar = params.map(String);
          store.local_eliminados = store.local_eliminados.filter(x => !idsABorrar.includes(String(x.id)));
          persistir();
          return { changes: 1 };
        }

        // 5. INSERT usuarios locales
        if (query.includes('INTO LOCAL_COMEX_USUARIOS')) {
          const uIndex = store.local_comex_usuarios.findIndex(x => String(x.id) === String(payload.id));
          if (uIndex >= 0) {
            store.local_comex_usuarios[uIndex] = { ...store.local_comex_usuarios[uIndex], ...payload };
          } else {
            store.local_comex_usuarios.push(payload);
          }
          persistir();
          return { changes: 1 };
        }

        persistir();
        return { changes: 0 };
      },

      get: (...params) => {
        if (query.includes('FROM LOCAL_LOGISTITCAS_TEMPORADA')) {
          const id = String(params[0]);
          return store.local_logistitcas_temporada.find(x => String(x.registro) === id) || null;
        }
        return null;
      },

      all: () => {
        if (query.includes('FROM LOCAL_ELIMINADOS')) {
          return store.local_eliminados || [];
        }
        if (query.includes('FROM LOCAL_LOGISTITCAS_TEMPORADA WHERE SINCRONIZADO = 0')) {
          return store.local_logistitcas_temporada.filter(x => x.sincronizado === 0);
        }
        if (query.includes('FROM LOCAL_LOGISTITCAS_TEMPORADA')) {
          return store.local_logistitcas_temporada || [];
        }
        return [];
      }
    };
  },

  transaction: (fn) => (data) => {
    fn(data);
    persistir();
  }
};

module.exports = { db, modoSQLite: true };