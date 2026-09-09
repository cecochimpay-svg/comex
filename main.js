const { app, BrowserWindow, globalShortcut } = require('electron');
const path = require('path');

// Inicializar base de datos local
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

  // Bloquear atajos directos dentro de la ventana de Electron
  win.webContents.on('before-input-event', (event, input) => {
    const isCtrlOrCmd = input.control || input.meta;
    const key = (input.key || '').toUpperCase();

    // Bloquear F12, Ctrl+Shift+I/J/C, Ctrl+U, Ctrl+R, F5
    if (
      input.key === 'F12' ||
      input.key === 'F5' ||
      (isCtrlOrCmd && input.shift && ['I', 'J', 'C'].includes(key)) ||
      (isCtrlOrCmd && ['U', 'R', 'S'].includes(key))
    ) {
      event.preventDefault();
    }
  });
}

app.whenReady().then(() => {
  createWindow();

  // Registrar bloqueo de atajos globales si se requiere a nivel aplicación
  globalShortcut.register('CommandOrControl+Shift+I', () => false);
  globalShortcut.register('F12', () => false);
});

app.on('will-quit', () => {
  // Limpiar atajos globales al cerrar
  globalShortcut.unregisterAll();
});

app.on('window-all-closed', () => {
  if (process.platform !== 'darwin') app.quit();
});