// =====================================================================
// SEGURIDAD COMEX · CECO S.A.
// Validación de ingreso, sesión, bloqueo de pantalla por inactividad y bloqueo de teclas.
// Cargar en el <head> de cada página, antes de los demás scripts:
//   <script src="seguridad/seguridad.js" data-pagina="login"></script>        (ingreso)
//   <script src="../seguridad/seguridad.js" data-pagina="protegida"></script> (resto)
// =====================================================================
(function () {
  const SUPABASE_URL = 'https://veqpyhifwubcdxocckmf.supabase.co';
  const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZlcXB5aGlmd3ViY2R4b2Nja21mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NzI5NzAsImV4cCI6MjA5MTQ0ODk3MH0.mIRsPLLoHn9jQtvCCwxG3aNFWtXIdcV12kLTC_MqybY';

  const MINUTOS_INACTIVIDAD = 10;     // Bloquea la pantalla tras este tiempo sin uso
  const HORAS_SESION = 12;            // Duración máxima de una sesión
  const DIAS_INGRESO_OFFLINE = 7;     // Validez de la credencial guardada para ingresar sin conexión
  const MAX_INTENTOS_LOGIN = 5;       // Al superarlos se espera antes de reintentar en este equipo

  const CLAVE_SESION = 'comex_sesion';
  const CLAVE_INTENTOS = 'comex_intentos_login';

  const script = document.currentScript;
  const pagina = (script && script.dataset.pagina) || 'protegida';
  const URL_LOGIN = new URL('../loguer.html', script.src).href;

  // ---------- Acceso a Node (solo dentro de Electron) ----------
  let crypto = null, os = null, ipc = null, dbLocal = null;
  if (typeof require === 'function') {
    try { crypto = require('crypto'); os = require('os'); } catch (e) {}
    try { ipc = require('electron').ipcRenderer; } catch (e) {}
    try {
      const { fileURLToPath } = require('url');
      dbLocal = require(fileURLToPath(new URL('../data/base.js', script.src))).db;
    } catch (e) {}
  }

  // ---------- Versión web (iPhone / Mac): app instalable ----------
  if (location.protocol === 'https:' && 'serviceWorker' in navigator) {
    navigator.serviceWorker.register(new URL('../sw.js', script.src).href).catch(() => {});
  }

  function nombreEquipo() {
    try { return os ? `${os.hostname()} / ${os.userInfo().username}` : navigator.userAgent.slice(0, 120); }
    catch (e) { return null; }
  }

  // ---------- Sesión (sessionStorage: se borra al cerrar la app) ----------
  function leerSesion() {
    try { return JSON.parse(sessionStorage.getItem(CLAVE_SESION)); } catch (e) { return null; }
  }

  function guardarSesion(s) {
    sessionStorage.setItem(CLAVE_SESION, JSON.stringify(s));
  }

  function sesionVigente(s) {
    return !!(s && s.usuario && Date.now() < s.expira);
  }

  function crearSesion(u) {
    const ahora = Date.now();
    guardarSesion({
      id: u.id,
      usuario: u.usuario,
      rol: String(u.rol || 'COMEX').toUpperCase(),
      offline: !!u.offline,
      inicio: ahora,
      expira: ahora + HORAS_SESION * 3600e3,
      actividad: ahora,
      bloqueada: false
    });
  }

  function cerrarSesion(motivo) {
    sessionStorage.removeItem(CLAVE_SESION);
    try { localStorage.removeItem(CLAVE_SESION); } catch (e) {}
    location.replace(URL_LOGIN + (motivo ? `?motivo=${encodeURIComponent(motivo)}` : ''));
  }

  // ---------- Validación de credenciales ----------
  async function verificarEnNube(usuario, clave) {
    const resp = await fetch(`${SUPABASE_URL}/rest/v1/rpc/comex_login`, {
      method: 'POST',
      headers: {
        apikey: SUPABASE_KEY,
        Authorization: `Bearer ${SUPABASE_KEY}`,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ p_usuario: usuario, p_clave: clave, p_equipo: nombreEquipo() })
    });
    if (resp.status === 404) return { ok: false, motivo: 'servidor_sin_configurar' };
    if (!resp.ok) throw new Error(`Supabase respondió ${resp.status}`);
    return resp.json();
  }

  function huella(clave, salt) {
    return crypto.pbkdf2Sync(clave, salt, 150000, 32, 'sha256').toString('hex');
  }

  function recordarCredencial(u, clave) {
    if (!dbLocal || !crypto) return;
    const salt = crypto.randomBytes(16).toString('hex');
    dbLocal.prepare('INSERT INTO local_comex_credenciales').run({
      usuario: u.usuario,
      nombre: u.usuario,
      id: u.id,
      rol: u.rol,
      salt: salt,
      hash: huella(clave, salt),
      validado: new Date().toISOString()
    });
  }

  function verificarLocal(usuario, clave) {
    if (!dbLocal || !crypto) return { ok: false, motivo: 'sin_conexion' };
    const c = dbLocal.prepare('SELECT * FROM local_comex_credenciales WHERE usuario = ?').get(usuario);
    if (!c) return { ok: false, motivo: 'sin_conexion' };
    if (Date.now() - Date.parse(c.validado) > DIAS_INGRESO_OFFLINE * 864e5) {
      return { ok: false, motivo: 'offline_vencido' };
    }
    const iguales = crypto.timingSafeEqual(Buffer.from(huella(clave, c.salt), 'hex'), Buffer.from(c.hash, 'hex'));
    if (!iguales) return { ok: false, motivo: 'credenciales' };
    return { ok: true, id: c.id, usuario: c.nombre, rol: c.rol, offline: true };
  }

  // Valida contra Supabase; sin conexión usa la credencial cifrada del último ingreso en este equipo
  async function verificarCredenciales(usuario, clave) {
    usuario = String(usuario || '').trim();
    clave = String(clave || '').trim();
    if (!usuario || !clave) return { ok: false, motivo: 'credenciales' };

    if (navigator.onLine) {
      try {
        const r = await verificarEnNube(usuario, clave);
        if (r.ok) recordarCredencial(r, clave);
        return r;
      } catch (e) {
        console.warn('Validación en la nube no disponible, se usa la local:', e.message);
      }
    }
    return verificarLocal(usuario, clave);
  }

  function mensajeError(r) {
    switch (r.motivo) {
      case 'bloqueado': {
        const hasta = r.hasta ? new Date(r.hasta).toLocaleTimeString('es-AR', { hour: '2-digit', minute: '2-digit' }) : '';
        return `Usuario bloqueado por intentos fallidos${hasta ? ` hasta las ${hasta}` : ''}.`;
      }
      case 'inactivo': return 'El usuario está inactivo. Consultá con el administrador.';
      case 'sin_conexion': return 'Sin conexión. Solo pueden ingresar usuarios que ya ingresaron en este equipo.';
      case 'offline_vencido': return 'Sin conexión y hace más de 7 días que no ingresás con internet en este equipo.';
      case 'servidor_sin_configurar': return 'El servidor no tiene configurado el acceso seguro. Avisá al administrador.';
      default:
        return r.restantes != null
          ? `Usuario o contraseña incorrectos. Quedan ${r.restantes} intento(s).`
          : 'Usuario o contraseña incorrectos.';
    }
  }

  // ---------- Límite de intentos en este equipo (además del bloqueo del servidor) ----------
  function leerIntentos() {
    try { return JSON.parse(localStorage.getItem(CLAVE_INTENTOS)) || { n: 0, hasta: 0 }; }
    catch (e) { return { n: 0, hasta: 0 }; }
  }

  function segundosDeEspera() {
    return Math.max(0, Math.ceil((leerIntentos().hasta - Date.now()) / 1000));
  }

  function registrarIntento(exito) {
    try {
      if (exito) return localStorage.removeItem(CLAVE_INTENTOS);
      const i = leerIntentos();
      i.n += 1;
      if (i.n >= MAX_INTENTOS_LOGIN) {
        // 30 s, 60 s, 120 s... hasta 15 minutos
        i.hasta = Date.now() + Math.min(900, 30 * 2 ** (i.n - MAX_INTENTOS_LOGIN)) * 1000;
      }
      localStorage.setItem(CLAVE_INTENTOS, JSON.stringify(i));
    } catch (e) {}
  }

  async function ingresar(usuario, clave) {
    const espera = segundosDeEspera();
    if (espera > 0) return { ok: false, mensaje: `Demasiados intentos. Esperá ${espera} segundos.` };

    const r = await verificarCredenciales(usuario, clave);
    if (!r.ok) {
      if (r.motivo === 'credenciales') registrarIntento(false);
      return { ok: false, mensaje: mensajeError(r) };
    }
    registrarIntento(true);
    crearSesion(r);
    return { ok: true, offline: !!r.offline, usuario: r.usuario };
  }

  // ---------- Bloqueo de teclas, menú contextual y arrastre de archivos ----------
  function teclaBloqueada(e) {
    const k = (e.key || '').toLowerCase();
    const ctrl = e.ctrlKey || e.metaKey;
    return (
      ['f12', 'f5', 'f7'].includes(k) ||
      (ctrl && e.shiftKey && ['i', 'j', 'c', 'r', 'delete'].includes(k)) ||
      (ctrl && ['u', 's', 'p', 'o', 'r', 'n', 't', 'g', 'h', 'j'].includes(k)) ||
      (e.altKey && ['arrowleft', 'arrowright'].includes(k))
    );
  }

  window.addEventListener('keydown', e => {
    if (teclaBloqueada(e)) {
      e.preventDefault();
      e.stopImmediatePropagation();
      return;
    }
    if (pagina === 'protegida' && (e.ctrlKey || e.metaKey) && (e.key || '').toLowerCase() === 'l') {
      e.preventDefault();
      bloquearPantalla();
    }
  }, true);

  window.addEventListener('contextmenu', e => {
    if (!e.target.closest || !e.target.closest('input, textarea')) e.preventDefault();
  }, true);

  ['dragover', 'drop'].forEach(ev => window.addEventListener(ev, e => {
    if (e.dataTransfer && [...e.dataTransfer.types].includes('Files')) e.preventDefault();
  }, true));

  // ---------- Página de ingreso ----------
  if (pagina === 'login') {
    sessionStorage.removeItem(CLAVE_SESION);
    try { localStorage.removeItem(CLAVE_SESION); } catch (e) {}
    window.COMEX_SEG = { ingresar, segundosDeEspera };
    return;
  }

  // ---------- Páginas protegidas ----------
  const sesionInicial = leerSesion();
  if (!sesionVigente(sesionInicial)) {
    document.documentElement.style.visibility = 'hidden';
    cerrarSesion(sesionInicial ? 'expirada' : null);
    window.COMEX_SEG = { sesion: () => null, cerrarSesion, bloquearPantalla: () => {} };
    return;
  }

  let bloqueada = false;
  let ultimaActividad = sesionInicial.actividad || Date.now();

  function registrarActividad() {
    if (bloqueada) return;
    const ahora = Date.now();
    ultimaActividad = ahora;
    const s = leerSesion();
    if (s && ahora - (s.actividad || 0) > 15000) {
      s.actividad = ahora;
      guardarSesion(s);
    }
  }

  ['mousemove', 'mousedown', 'keydown', 'wheel', 'touchstart', 'scroll'].forEach(ev =>
    window.addEventListener(ev, registrarActividad, { capture: true, passive: true })
  );

  setInterval(() => {
    const s = leerSesion();
    if (!sesionVigente(s)) return cerrarSesion('expirada');
    if (!bloqueada && Date.now() - Math.max(ultimaActividad, s.actividad || 0) > MINUTOS_INACTIVIDAD * 60e3) {
      bloquearPantalla();
    }
  }, 15000);

  // La ventana principal avisa cuando Windows se bloquea o la PC entra en suspensión
  if (ipc) ipc.on('comex:bloquear', () => bloquearPantalla());

  const ESTILOS_BLOQUEO = `
    #comexBloqueo { position: fixed; inset: 0; z-index: 2147483647; display: flex; align-items: center; justify-content: center;
      background: rgba(18, 38, 29, 0.94); backdrop-filter: blur(18px); font-family: 'Inter', -apple-system, 'Segoe UI', sans-serif; }
    #comexBloqueo .bq-card { width: 360px; max-width: calc(100% - 32px); background: #FFFFFF; border-radius: 20px; padding: 32px 28px 22px;
      text-align: center; box-shadow: 0 30px 60px -20px rgba(0, 0, 0, 0.45); }
    #comexBloqueo .bq-ico { width: 52px; height: 52px; margin: 0 auto 14px; border-radius: 50%; background: rgba(30, 107, 76, 0.10);
      color: #1E6B4C; display: flex; align-items: center; justify-content: center; }
    #comexBloqueo h2 { margin: 0 0 6px; font-family: 'Montserrat', sans-serif; font-size: 18px; font-weight: 800; color: #123F2C; }
    #comexBloqueo .bq-sub { margin: 0 0 22px; font-size: 13px; line-height: 1.45; color: #6B7280; }
    #comexBloqueo .bq-sub b { color: #1B231D; }
    #comexBloqueo .bq-btn { width: 100%; padding: 13px; border: none; border-radius: 12px; background: #1E6B4C; color: #FFFFFF;
      font-size: 14px; font-weight: 600; font-family: inherit; cursor: pointer; }
    #comexBloqueo .bq-btn:hover { background: #123F2C; }
    #comexBloqueo .bq-btn:focus-visible { outline: none; box-shadow: 0 0 0 4px rgba(30, 107, 76, 0.25); }
    #comexBloqueo .bq-salir { margin-top: 10px; background: none; border: none; color: #6B7280; font-size: 12.5px; font-weight: 500; font-family: inherit;
      cursor: pointer; text-decoration: underline; }
  `;

  function bloquearPantalla() {
    if (bloqueada) return;
    bloqueada = true;
    const s = leerSesion();
    if (s) { s.bloqueada = true; guardarSesion(s); }
    if (document.body) mostrarBloqueo();
    else document.addEventListener('DOMContentLoaded', mostrarBloqueo, { once: true });
  }

  // Pausa por inactividad: oculta los datos pero recuerda la sesión (no pide contraseña)
  function mostrarBloqueo() {
    if (document.getElementById('comexBloqueo')) return;
    const s = leerSesion() || {};

    if (!document.getElementById('comexBloqueoEstilos')) {
      const st = document.createElement('style');
      st.id = 'comexBloqueoEstilos';
      st.textContent = ESTILOS_BLOQUEO;
      document.head.appendChild(st);
    }

    // Todo lo que está detrás queda inaccesible (sin foco, sin clics, sin lector de pantalla)
    [...document.body.children].forEach(el => el.setAttribute('inert', ''));
    document.querySelectorAll('dialog[open]').forEach(d => d.close());

    const capa = document.createElement('div');
    capa.id = 'comexBloqueo';
    capa.innerHTML = `
      <div class="bq-card" role="dialog" aria-modal="true" aria-labelledby="bqTitulo">
        <div class="bq-ico">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
            <circle cx="12" cy="12" r="9"></circle><line x1="10" y1="9" x2="10" y2="15"></line><line x1="14" y1="9" x2="14" y2="15"></line>
          </svg>
        </div>
        <h2 id="bqTitulo">Sesión en pausa</h2>
        <p class="bq-sub">Ocultamos la pantalla por inactividad.<br>La sesión de <b></b> sigue abierta.</p>
        <button type="button" class="bq-btn">Volver a ingresar</button>
        <button type="button" class="bq-salir">Cerrar sesión</button>
      </div>`;
    capa.querySelector('.bq-sub b').textContent = s.usuario || '';
    document.body.appendChild(capa);

    const btn = capa.querySelector('.bq-btn');
    btn.onclick = () => {
      if (!sesionVigente(leerSesion())) return cerrarSesion('expirada');
      desbloquear();
    };
    capa.querySelector('.bq-salir').onclick = () => cerrarSesion();
    btn.focus();
  }

  function desbloquear() {
    const s = leerSesion();
    if (s) {
      s.bloqueada = false;
      s.actividad = Date.now();
      guardarSesion(s);
    }
    bloqueada = false;
    ultimaActividad = Date.now();
    const capa = document.getElementById('comexBloqueo');
    if (capa) capa.remove();
    [...document.body.children].forEach(el => el.removeAttribute('inert'));
  }

  // Si la pantalla quedó bloqueada (o pasó el tiempo) se mantiene bloqueada al cambiar de página
  if (sesionInicial.bloqueada || Date.now() - ultimaActividad > MINUTOS_INACTIVIDAD * 60e3) {
    bloquearPantalla();
  }

  window.COMEX_SEG = {
    sesion: () => leerSesion(),
    cerrarSesion: () => cerrarSesion(),
    bloquearPantalla
  };
})();
