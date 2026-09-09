const { app, BrowserWindow } = require('electron');
const path = require('path');

// Inicializar base SQLite al levantar la aplicación
require('./data/base.js');

function createWindow() {
  const win = new BrowserWindow({
    width: 1280,
    height: 840,
    minWidth: 1024,
    minHeight: 700,
    autoHideMenuBar: true,
    title: 'COMEX · CECO S.A.',
    webPreferences: {
      nodeIntegration: true,
      contextIsolation: false,
      devTools: false
    }
  });

  win.loadFile('loguer.html');

 // 🔒 Remover completamente el menú superior de la ventana
  win.removeMenu();

  // 🔒 Bloquear el menú contextual (clic derecho -> Inspeccionar)
  win.webContents.on('context-menu', (e) => {
    e.preventDefault();
  });

  // 🔒 Deshabilitar atajos de teclado específicos en la ventana activa (F12, DevTools, Recargar)
  win.webContents.on('before-input-event', (event, input) => {
    const isControlOrCmd = input.control || input.meta;
    const key = input.key.toLowerCase();

    // Bloquear F12
    if (input.key === 'F12') {
      event.preventDefault();
    }
    // Bloquear Ctrl+Shift+I / Cmd+Option+I (Abrir DevTools)
    if (isControlOrCmd && input.shift && key === 'i') {
      event.preventDefault();
    }
    // Bloquear Ctrl+Shift+J / Cmd+Option+J (Abrir Consola)
    if (isControlOrCmd && input.shift && key === 'j') {
      event.preventDefault();
    }
    // Bloquear Ctrl+Shift+C (Inspeccionar elemento)
    if (isControlOrCmd && input.shift && key === 'c') {
      event.preventDefault();
    }
    // Bloquear Ctrl+U (Ver código fuente HTML)
    if (isControlOrCmd && key === 'u') {
      event.preventDefault();
    }
    // Bloquear F5 o Ctrl+R (Refrescar la app)
    if (input.key === 'F5' || (isControlOrCmd && key === 'r')) {
      event.preventDefault();
    }
  });

  // 5. Bloquear navegación inesperada fuera de la app
  win.webContents.on('will-navigate', (event, navigationUrl) => {
    const parsedUrl = new URL(navigationUrl);
    if (parsedUrl.protocol !== 'file:') {
      event.preventDefault();
    }
  });

  // 6. Abrir enlaces externos siempre en el navegador del sistema
  win.webContents.setWindowOpenHandler(({ url }) => {
    if (url.startsWith('https:') || url.startsWith('http:')) {
      shell.openExternal(url);
    }
    return { action: 'deny' };
  });

  win.loadFile('loguer.html');
}

app.whenReady().then(createWindow);

// 🔒 Desregistrar atajos globales al cerrar la aplicación
app.on('will-quit', () => {
  globalShortcut.unregisterAll();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});
