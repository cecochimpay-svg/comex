const { app, BrowserWindow, Menu, powerMonitor, session } = require('electron');
const path = require('path');
const { pathToFileURL } = require('url');

// Impide capturas de pantalla, grabaciones y compartir la ventana (Teams/Zoom/recortes muestran un recuadro negro).
// Ponerlo en false si necesitan proyectar el sistema en una reunión.
const BLOQUEAR_CAPTURAS = true;

// Solo se navega dentro de los archivos de la app
const RAIZ_APP = pathToFileURL(__dirname + path.sep).href.toLowerCase();

// Inicializar base de datos local
require('./data/base.js');

// Una sola instancia abierta por equipo
if (!app.requestSingleInstanceLock()) {
  app.quit();
}

let win = null;

function createWindow() {
  win = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 1024,
    minHeight: 700,
    autoHideMenuBar: true,
    title: 'COMEX · CECO S.A.',
    icon: path.join(__dirname, 'icono.ico'), // <--- ÍCONO DE LA VENTANA / BARRA DE TAREAS
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      devTools: false,
      webviewTag: false,
      spellcheck: false,
      navigateOnDragDrop: false
    }
  });

  win.setContentProtection(BLOQUEAR_CAPTURAS);
  win.loadFile('loguer.html');

  // Bloquear atajos directos dentro de la ventana de Electron
  win.webContents.on('before-input-event', (event, input) => {
    const isCtrlOrCmd = input.control || input.meta;
    const key = (input.key || '').toUpperCase();

    // F12, F5, F7, Ctrl+Shift+I/J/C/R, Ctrl+U/R/S/P/O/N/T, Alt+flechas (atrás/adelante)
    if (
      ['F12', 'F5', 'F7'].includes(key) ||
      (isCtrlOrCmd && input.shift && ['I', 'J', 'C', 'R'].includes(key)) ||
      (isCtrlOrCmd && ['U', 'R', 'S', 'P', 'O', 'N', 'T'].includes(key)) ||
      (input.alt && ['ARROWLEFT', 'ARROWRIGHT'].includes(key))
    ) {
      event.preventDefault();
    }
  });

  // Nada de páginas externas ni ventanas nuevas dentro de la app
  win.webContents.on('will-navigate', (event, url) => {
    if (!url.toLowerCase().startsWith(RAIZ_APP)) event.preventDefault();
  });
  win.webContents.setWindowOpenHandler(() => ({ action: 'deny' }));
  win.webContents.on('will-attach-webview', event => event.preventDefault());
  win.webContents.on('devtools-opened', () => win.webContents.closeDevTools());

  win.on('closed', () => { win = null; });
}

// Bloquear la pantalla de la app cuando Windows se bloquea o la PC se suspende
function pedirBloqueo() {
  if (win && !win.isDestroyed()) win.webContents.send('comex:bloquear');
}

app.on('second-instance', () => {
  if (!win) return;
  if (win.isMinimized()) win.restore();
  win.focus();
});

app.whenReady().then(() => {
  // Sin menú: elimina los atajos de recarga y herramientas de desarrollo que trae por defecto
  Menu.setApplicationMenu(null);

  // La app no usa cámara, micrófono, ubicación ni notificaciones
  session.defaultSession.setPermissionRequestHandler((wc, permiso, responder) => {
    responder(permiso === 'clipboard-sanitized-write');
  });

  createWindow();

  powerMonitor.on('lock-screen', pedirBloqueo);
  powerMonitor.on('suspend', pedirBloqueo);
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
