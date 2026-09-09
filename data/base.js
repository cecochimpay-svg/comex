const fs = require('fs');
const path = require('path');

const dbFile = path.join(__dirname, 'comex_local_data.json');

// Estructura de almacenamiento local ampliada
let store = {
  local_comex_usuarios: [],
  local_logistitcas_temporada: [],
  local_eliminados: [],
  local_vista_pallet_stock_general: [],
  local_comex_proyeccion_dias: [],       // Proyección a 11 días (Captura 1)
  local_comex_programa_trabajo: [],      // Programa de trabajo por calibre (Captura 2)
  local_agronet_clientes: [],            // Catálogo Clientes de Agronet
  local_agronet_marcas: []               // Catálogo Marcas de Agronet
};

// Cargar archivo JSON si ya existe en disco
if (fs.existsSync(dbFile)) {
  try {
    const dataGuardada = JSON.parse(fs.readFileSync(dbFile, 'utf-8'));
    store = { ...store, ...dataGuardada };
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

// Adaptador compatible con la interfaz SQLite (prepare, run, get, all, transaction)
const db = {
  prepare: (sql) => {
    const query = sql.trim().toUpperCase();

    return {
      run: (...params) => {
        let payload = params[0] || {};

        // 1. LOGÍSTICA / VUELOS
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

        // 2. BORRADO LOGÍSTICA (Trigger a eliminados)
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

        // 3. PROYECCIÓN A 11 DÍAS (Captura 1)
        if (query.includes('INTO LOCAL_COMEX_PROYECCION_DIAS')) {
          const clave = `${payload.fecha}_${payload.usuario}`;
          const index = store.local_comex_proyeccion_dias.findIndex(x => `${x.fecha}_${x.usuario}` === clave);
          const proyLimpia = {
            ...payload,
            updated_at: new Date().toISOString()
          };

          if (index >= 0) {
            store.local_comex_proyeccion_dias[index] = { ...store.local_comex_proyeccion_dias[index], ...proyLimpia };
          } else {
            store.local_comex_proyeccion_dias.push(proyLimpia);
          }
          persistir();
          return { changes: 1 };
        }

        // 4. PROGRAMA DE TRABAJO (Captura 2)
        if (query.includes('INTO LOCAL_COMEX_PROGRAMA_TRABAJO')) {
          const regId = payload.id ? String(payload.id) : `PROG-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
          payload.id = regId;
          store.local_comex_programa_trabajo.push(payload);
          persistir();
          return { changes: 1 };
        }

        // 5. CLIENTES AGRONET
        if (query.includes('INTO LOCAL_AGRONET_CLIENTES')) {
          const index = store.local_agronet_clientes.findIndex(x => x.id_cliente === payload.id_cliente);
          if (index >= 0) store.local_agronet_clientes[index] = payload;
          else store.local_agronet_clientes.push(payload);
          persistir();
          return { changes: 1 };
        }

        // 6. MARCAS AGRONET
        if (query.includes('INTO LOCAL_AGRONET_MARCAS')) {
          const index = store.local_agronet_marcas.findIndex(x => x.id_marca === payload.id_marca);
          if (index >= 0) store.local_agronet_marcas[index] = payload;
          else store.local_agronet_marcas.push(payload);
          persistir();
          return { changes: 1 };
        }

        // 7. LIMPIAR ELIMINADOS PROCESADOS
        if (query.includes('DELETE FROM LOCAL_ELIMINADOS')) {
          const idsABorrar = params.map(String);
          store.local_eliminados = store.local_eliminados.filter(x => !idsABorrar.includes(String(x.id)));
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
        if (query.includes('FROM LOCAL_COMEX_USUARIOS')) {
          const userParam = String(params[0] || '').toLowerCase();
          const passParam = String(params[1] || '');
          return store.local_comex_usuarios.find(
            u => String(u.usuario || '').toLowerCase() === userParam &&
                 String(u.clave || '') === passParam &&
                 u.estado === 'ACTI'
          ) || null;
        }
        return null;
      },

      all: (...params) => {
        if (query.includes('FROM LOCAL_COMEX_PROYECCION_DIAS')) {
          return store.local_comex_proyeccion_dias || [];
        }
        if (query.includes('FROM LOCAL_COMEX_PROGRAMA_TRABAJO')) {
          return store.local_comex_programa_trabajo || [];
        }
        if (query.includes('FROM LOCAL_AGRONET_CLIENTES')) {
          return store.local_agronet_clientes || [];
        }
        if (query.includes('FROM LOCAL_AGRONET_MARCAS')) {
          return store.local_agronet_marcas || [];
        }
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

console.log('✅ Base de datos local: soporte completo para Vuelos, Proyecciones, Programas y Agronet activo.');

module.exports = { db, modoSQLite: true };