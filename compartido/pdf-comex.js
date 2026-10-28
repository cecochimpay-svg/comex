// =====================================================================
// PDF COMEX · CECO S.A.
// Diseño común de los reportes: encabezado con logo y datos de la empresa,
// franja de datos, tabla, totales, firmas y pie con número de página.
// Cargar después de jsPDF y jsPDF-AutoTable:
//   <script src="../compartido/pdf-comex.js"></script>
// =====================================================================
(function () {
  const EMPRESA = { nombre: 'CECO S.A.', cuit: '30-68958736-0' };

  // Paleta: verdes suaves con acento intenso
  const C = {
    verdeOscuro: [16, 61, 42],
    verde: [30, 107, 76],
    verdeVivo: [46, 160, 104],
    menta: [229, 244, 235],
    mentaSuave: [244, 250, 246],
    linea: [200, 226, 211],
    texto: [27, 35, 29],
    gris: [104, 125, 112]
  };

  const MARGEN = 12;
  const ALTO_ENCABEZADO = 30;   // mm reservados arriba en todas las páginas
  const ALTO_PIE = 16;          // mm reservados abajo en todas las páginas

  const script = document.currentScript;
  const URL_LOGO = new URL('../logo.png', script.src).href;

  // ---------- Logo: se convierte a PNG liviano una sola vez al cargar la página ----------
  let logo = null;

  function origenLogo() {
    // En Electron se lee del disco y se pasa como blob (no "contamina" el canvas)
    if (typeof require === 'function') {
      try {
        const { fileURLToPath } = require('url');
        const bytes = require('fs').readFileSync(fileURLToPath(URL_LOGO));
        return URL.createObjectURL(new Blob([bytes]));
      } catch (e) {}
    }
    return URL_LOGO;
  }

  function cargarLogo() {
    const img = new Image();
    img.onload = () => {
      try {
        const ancho = Math.min(480, img.naturalWidth);
        const alto = Math.round(img.naturalHeight * ancho / img.naturalWidth);
        const canvas = document.createElement('canvas');
        canvas.width = ancho;
        canvas.height = alto;
        const ctx = canvas.getContext('2d');
        ctx.imageSmoothingQuality = 'high';
        ctx.fillStyle = '#FFFFFF';
        ctx.fillRect(0, 0, ancho, alto);
        ctx.drawImage(img, 0, 0, ancho, alto);
        // JPEG: el logo pesa ~30 KB en lugar de ~700 KB
        logo = { data: canvas.toDataURL('image/jpeg', 0.92), ancho, alto };
      } catch (e) {
        console.warn('No se pudo preparar el logo para el PDF:', e.message);
      }
    };
    img.onerror = () => console.warn('No se encontró el logo para el PDF.');
    img.src = origenLogo();
  }

  cargarLogo();

  // ---------- Utilidades ----------
  function formatearFecha(valor, conHora = false) {
    if (!valor) return '-';
    const s = String(valor).replace(' ', 'T');
    const [f, h] = s.split('T');
    const [y, m, d] = f.split('-');
    if (!y || !m || !d) return String(valor);
    const fecha = `${d.slice(0, 2)}/${m}/${y}`;
    return conHora && h ? `${fecha} ${h.slice(0, 5)}` : fecha;
  }

  function ancho(doc) { return doc.internal.pageSize.getWidth(); }
  function alto(doc) { return doc.internal.pageSize.getHeight(); }

  function recortar(doc, texto, anchoMax) {
    return doc.splitTextToSize(String(texto), anchoMax)[0] || '';
  }

  // ---------- Partes del documento ----------
  function dibujarEncabezado(doc) {
    const { titulo, subtitulo } = doc.__comex;
    const w = ancho(doc);

    // Franja superior
    doc.setFillColor(...C.verdeOscuro);
    doc.rect(0, 0, w, 2.4, 'F');
    doc.setFillColor(...C.verdeVivo);
    doc.rect(0, 2.4, w, 0.7, 'F');

    // Logo + empresa, arriba a la izquierda
    let x = MARGEN;
    if (logo) {
      const altoLogo = 15;
      const anchoLogo = Math.min(30, altoLogo * logo.ancho / logo.alto);
      const altoReal = anchoLogo * logo.alto / logo.ancho;
      doc.addImage(logo.data, 'JPEG', x, 6.5 + (altoLogo - altoReal) / 2, anchoLogo, altoReal, 'logo-ceco');
      x += anchoLogo + 4;
      doc.setDrawColor(...C.linea);
      doc.setLineWidth(0.3);
      doc.line(x, 8, x, 21);
      x += 4;
    }

    doc.setFont('helvetica', 'bold');
    doc.setFontSize(13);
    doc.setTextColor(...C.verdeOscuro);
    doc.text(EMPRESA.nombre, x, 13.2);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(8.5);
    doc.setTextColor(...C.gris);
    doc.text(`CUIT: ${EMPRESA.cuit}`, x, 18.2);

    // Título del reporte, a la derecha
    doc.setFont('helvetica', 'bold');
    doc.setFontSize(14);
    doc.setTextColor(...C.verdeOscuro);
    doc.text(titulo, w - MARGEN, 13.2, { align: 'right' });

    if (subtitulo) {
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(8.5);
      doc.setTextColor(...C.gris);
      doc.text(subtitulo, w - MARGEN, 18.2, { align: 'right' });
    }

    // Divisor con acento
    doc.setDrawColor(...C.linea);
    doc.setLineWidth(0.3);
    doc.line(MARGEN, 25, w - MARGEN, 25);
    doc.setDrawColor(...C.verdeVivo);
    doc.setLineWidth(1.1);
    doc.line(MARGEN, 25, MARGEN + 38, 25);
  }

  function dibujarPie(doc, pagina, total) {
    const w = ancho(doc);
    const y = alto(doc) - 8;
    const sesion = window.COMEX_SEG && window.COMEX_SEG.sesion ? window.COMEX_SEG.sesion() : null;
    const emision = new Date().toLocaleString('es-AR', { day: '2-digit', month: '2-digit', year: 'numeric', hour: '2-digit', minute: '2-digit' });

    doc.setDrawColor(...C.linea);
    doc.setLineWidth(0.3);
    doc.line(MARGEN, y - 4.5, w - MARGEN, y - 4.5);

    doc.setFont('helvetica', 'normal');
    doc.setFontSize(7.5);
    doc.setTextColor(...C.gris);
    doc.text(`${EMPRESA.nombre} · CUIT ${EMPRESA.cuit} · Sistema COMEX`, MARGEN, y);
    doc.text(`Emitido el ${emision}${sesion ? ` por ${sesion.usuario}` : ''}`, w / 2, y, { align: 'center' });

    doc.setFont('helvetica', 'bold');
    doc.setTextColor(...C.verde);
    doc.text(`Página ${pagina} de ${total}`, w - MARGEN, y, { align: 'right' });
  }

  // Franja de datos clave del reporte: [['Etiqueta', 'Valor'], ...]
  function fichas(doc, datos, y = ALTO_ENCABEZADO + 1) {
    const anchoTotal = ancho(doc) - MARGEN * 2;
    const altoFicha = 14;
    const anchoCelda = anchoTotal / datos.length;

    doc.setFillColor(...C.menta);
    doc.roundedRect(MARGEN, y, anchoTotal, altoFicha, 2.5, 2.5, 'F');

    datos.forEach(([etiqueta, valor], i) => {
      const x = MARGEN + i * anchoCelda;
      if (i > 0) {
        doc.setDrawColor(...C.linea);
        doc.setLineWidth(0.3);
        doc.line(x, y + 3, x, y + altoFicha - 3);
      }
      doc.setFont('helvetica', 'bold');
      doc.setFontSize(6.8);
      doc.setTextColor(...C.gris);
      doc.text(String(etiqueta).toUpperCase(), x + 5, y + 5.4);

      doc.setFontSize(10.5);
      doc.setTextColor(...C.verdeOscuro);
      doc.text(recortar(doc, valor == null || valor === '' ? '-' : valor, anchoCelda - 9), x + 5, y + 10.9);
    });

    return y + altoFicha + 5;
  }

  function tabla(doc, opciones) {
    doc.autoTable({
      theme: 'grid',
      margin: { top: ALTO_ENCABEZADO + 1, left: MARGEN, right: MARGEN, bottom: ALTO_PIE },
      headStyles: {
        fillColor: C.verde, textColor: 255, fontStyle: 'bold', fontSize: 7.8,
        halign: 'center', valign: 'middle', cellPadding: 2.8, lineColor: C.verde, lineWidth: 0.2
      },
      styles: {
        font: 'helvetica', fontSize: 7.8, cellPadding: 2.4, halign: 'center', valign: 'middle',
        textColor: C.texto, lineColor: C.linea, lineWidth: 0.2, overflow: 'linebreak'
      },
      alternateRowStyles: { fillColor: C.mentaSuave },
      ...opciones
    });
    return doc.lastAutoTable.finalY;
  }

  function asegurarEspacio(doc, y, necesario) {
    if (y + necesario <= alto(doc) - ALTO_PIE - 2) return y;
    doc.addPage();
    return ALTO_ENCABEZADO + 3;
  }

  // Totales destacados: [['Etiqueta', 'Valor'], ...]
  function totales(doc, datos, y) {
    const altoCaja = 17;
    const anchoCaja = 62;
    y = asegurarEspacio(doc, y + 6, altoCaja);

    datos.forEach(([etiqueta, valor], i) => {
      const x = MARGEN + i * (anchoCaja + 5);
      doc.setFillColor(...C.menta);
      doc.roundedRect(x, y, anchoCaja, altoCaja, 2.5, 2.5, 'F');
      doc.setFillColor(...C.verdeVivo);
      doc.roundedRect(x, y, 2.2, altoCaja, 1.1, 1.1, 'F');

      doc.setFont('helvetica', 'bold');
      doc.setFontSize(6.8);
      doc.setTextColor(...C.gris);
      doc.text(String(etiqueta).toUpperCase(), x + 7, y + 6);

      doc.setFontSize(14);
      doc.setTextColor(...C.verdeOscuro);
      doc.text(String(valor), x + 7, y + 13.2);
    });

    return y + altoCaja;
  }

  // Líneas de firma al pie del contenido
  function firmas(doc, etiquetas, y) {
    y = asegurarEspacio(doc, y + 22, 10);
    const anchoTotal = ancho(doc) - MARGEN * 2;
    const anchoFirma = (anchoTotal - (etiquetas.length - 1) * 14) / etiquetas.length;

    etiquetas.forEach((etiqueta, i) => {
      const x = MARGEN + i * (anchoFirma + 14);
      doc.setDrawColor(...C.verde);
      doc.setLineWidth(0.4);
      doc.line(x, y, x + anchoFirma, y);
      doc.setFont('helvetica', 'normal');
      doc.setFontSize(7.8);
      doc.setTextColor(...C.gris);
      doc.text(etiqueta, x + anchoFirma / 2, y + 4.5, { align: 'center' });
    });

    return y + 6;
  }

  function nuevo({ titulo, subtitulo, orientacion = 'l' }) {
    const doc = new window.jspdf.jsPDF(orientacion, 'mm', 'a4');
    doc.__comex = { titulo, subtitulo };
    doc.setProperties({ title: titulo, author: EMPRESA.nombre, creator: 'Sistema COMEX · CECO S.A.' });
    return doc;
  }

  // Encabezado y pie en todas las páginas
  function finalizar(doc) {
    const total = doc.getNumberOfPages();
    for (let i = 1; i <= total; i++) {
      doc.setPage(i);
      dibujarEncabezado(doc);
      dibujarPie(doc, i, total);
    }
  }

  function guardar(doc, archivo) {
    finalizar(doc);
    doc.save(archivo);
  }

  // ---------- Compartir / imprimir ----------
  function shellElectron() {
    try { return typeof require === 'function' ? require('electron').shell : null; } catch (e) { return null; }
  }

  function escribirArchivo(doc, carpeta, archivo) {
    const fs = require('fs');
    const path = require('path');
    fs.mkdirSync(carpeta, { recursive: true });
    const destino = path.join(carpeta, archivo);
    fs.writeFileSync(destino, Buffer.from(doc.output('arraybuffer')));
    return destino;
  }

  // Menú nativo de compartir si existe; si no, queda en Descargas\COMEX con la carpeta abierta
  async function compartir(doc, archivo) {
    const pdf = new File([doc.output('blob')], archivo, { type: 'application/pdf' });
    if (navigator.canShare && navigator.canShare({ files: [pdf] })) {
      try {
        await navigator.share({ files: [pdf], title: doc.__comex.titulo });
        return { modo: 'nativo' };
      } catch (e) {
        if (e.name === 'AbortError') return { modo: 'cancelado' };
      }
    }
    const shell = shellElectron();
    if (shell) {
      const destino = escribirArchivo(doc, require('path').join(require('os').homedir(), 'Downloads', 'COMEX'), archivo);
      shell.showItemInFolder(destino);
      return { modo: 'carpeta', ruta: destino };
    }
    doc.save(archivo);
    return { modo: 'descarga' };
  }

  // Abre el PDF en el visor del sistema con el cuadro de impresión
  async function imprimir(doc, archivo) {
    doc.autoPrint();
    const shell = shellElectron();
    if (shell) {
      const destino = escribirArchivo(doc, require('path').join(require('os').tmpdir(), 'COMEX'), archivo);
      const error = await shell.openPath(destino);
      if (error) throw new Error(error);
      return { modo: 'visor' };
    }
    window.open(URL.createObjectURL(doc.output('blob')));
    return { modo: 'navegador' };
  }

  const ESTILOS_ACCIONES = `
    #pdfAcciones { position: fixed; inset: 0; z-index: 2147483000; display: flex; align-items: center; justify-content: center;
      background: rgba(16, 26, 21, 0.45); backdrop-filter: blur(3px); font-family: 'Inter', -apple-system, 'Segoe UI', sans-serif; }
    #pdfAcciones .pa-card { width: 400px; max-width: calc(100% - 32px); background: #FFFFFF; border-radius: 18px; padding: 22px;
      box-shadow: 0 30px 60px -20px rgba(16, 26, 21, 0.45); }
    #pdfAcciones .pa-head { display: flex; align-items: center; gap: 12px; margin-bottom: 16px; }
    #pdfAcciones .pa-ico { width: 40px; height: 40px; flex-shrink: 0; border-radius: 12px; background: #E5F4EB; color: #1E6B4C;
      display: flex; align-items: center; justify-content: center; }
    #pdfAcciones .pa-titulo { font-size: 15px; font-weight: 700; color: #103D2A; }
    #pdfAcciones .pa-archivo { font-size: 12px; color: #687D70; margin-top: 2px; word-break: break-all; }
    #pdfAcciones .pa-opciones { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
    #pdfAcciones .pa-op { display: flex; flex-direction: column; align-items: flex-start; gap: 8px; padding: 14px; text-align: left;
      border: 1px solid #C8E2D3; border-radius: 14px; background: #F4FAF6; cursor: pointer; font-family: inherit; transition: all .15s ease; }
    #pdfAcciones .pa-op:hover { border-color: #2EA068; background: #E5F4EB; transform: translateY(-1px); }
    #pdfAcciones .pa-op:focus-visible { outline: none; box-shadow: 0 0 0 3px rgba(46, 160, 104, 0.3); }
    #pdfAcciones .pa-op:disabled { opacity: .6; cursor: wait; transform: none; }
    #pdfAcciones .pa-op-ico { width: 34px; height: 34px; border-radius: 10px; background: #1E6B4C; color: #FFFFFF;
      display: flex; align-items: center; justify-content: center; }
    #pdfAcciones .pa-op b { font-size: 13.5px; color: #103D2A; }
    #pdfAcciones .pa-op span { font-size: 11.5px; line-height: 1.35; color: #687D70; }
    #pdfAcciones .pa-msg { margin-top: 12px; font-size: 12px; line-height: 1.45; color: #103D2A; background: #E5F4EB;
      border-radius: 10px; padding: 10px 12px; display: none; }
    #pdfAcciones .pa-msg.error { color: #991B1B; background: #FEF2F2; }
    #pdfAcciones .pa-pie { display: flex; justify-content: flex-end; margin-top: 14px; }
    #pdfAcciones .pa-cerrar { border: none; background: none; font-family: inherit; font-size: 12.5px; font-weight: 600;
      color: #687D70; cursor: pointer; padding: 6px 4px; }
    #pdfAcciones .pa-cerrar:hover { color: #103D2A; }
  `;

  const ICONO_PDF = '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/></svg>';
  const ICONO_COMPARTIR = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><line x1="8.6" y1="13.5" x2="15.4" y2="17.5"/><line x1="15.4" y1="6.5" x2="8.6" y2="10.5"/></svg>';
  const ICONO_IMPRIMIR = '<svg width="17" height="17" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 6 2 18 2 18 9"/><path d="M6 18H4a2 2 0 0 1-2-2v-5a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v5a2 2 0 0 1-2 2h-2"/><rect x="6" y="14" width="12" height="8"/></svg>';

  // Mini modal: el operario elige compartir o imprimir el PDF
  function ofrecer(doc, archivo) {
    finalizar(doc);

    if (!document.getElementById('pdfAccionesEstilos')) {
      const st = document.createElement('style');
      st.id = 'pdfAccionesEstilos';
      st.textContent = ESTILOS_ACCIONES;
      document.head.appendChild(st);
    }
    const previo = document.getElementById('pdfAcciones');
    if (previo) previo.remove();

    const capa = document.createElement('div');
    capa.id = 'pdfAcciones';
    capa.innerHTML = `
      <div class="pa-card" role="dialog" aria-modal="true" aria-labelledby="paTitulo">
        <div class="pa-head">
          <div class="pa-ico">${ICONO_PDF}</div>
          <div>
            <div class="pa-titulo" id="paTitulo">PDF listo</div>
            <div class="pa-archivo"></div>
          </div>
        </div>
        <div class="pa-opciones">
          <button type="button" class="pa-op" data-accion="compartir">
            <div class="pa-op-ico">${ICONO_COMPARTIR}</div>
            <b>Compartir PDF</b>
            <span>Para enviarlo por WhatsApp o correo</span>
          </button>
          <button type="button" class="pa-op" data-accion="imprimir">
            <div class="pa-op-ico">${ICONO_IMPRIMIR}</div>
            <b>Imprimir PDF</b>
            <span>Abre el PDF con el cuadro de impresión</span>
          </button>
        </div>
        <div class="pa-msg"></div>
        <div class="pa-pie"><button type="button" class="pa-cerrar">Cerrar</button></div>
      </div>`;
    capa.querySelector('.pa-archivo').textContent = archivo;
    document.body.appendChild(capa);

    const msg = capa.querySelector('.pa-msg');
    const botones = [...capa.querySelectorAll('.pa-op')];
    const cerrar = () => { capa.remove(); document.removeEventListener('keydown', alEscape, true); };
    const alEscape = e => { if (e.key === 'Escape') { e.stopPropagation(); cerrar(); } };
    const mostrar = (texto, error) => {
      msg.textContent = texto;
      msg.className = 'pa-msg' + (error ? ' error' : '');
      msg.style.display = 'block';
    };

    document.addEventListener('keydown', alEscape, true);
    capa.addEventListener('mousedown', e => { if (e.target === capa) cerrar(); });
    capa.querySelector('.pa-cerrar').onclick = cerrar;

    botones.forEach(btn => {
      btn.onclick = async () => {
        botones.forEach(b => { b.disabled = true; });
        try {
          if (btn.dataset.accion === 'imprimir') {
            await imprimir(doc, archivo);
            return cerrar();
          }
          const r = await compartir(doc, archivo);
          if (r.modo === 'carpeta') {
            mostrar(`Guardado en Descargas › COMEX. Se abrió la carpeta con el archivo seleccionado: arrastralo a WhatsApp o adjuntalo en el correo.`);
            capa.querySelector('.pa-cerrar').textContent = 'Listo';
            btn.disabled = false;
            return;
          }
          if (r.modo !== 'cancelado') return cerrar();
          botones.forEach(b => { b.disabled = false; });
        } catch (e) {
          mostrar('No se pudo completar: ' + e.message, true);
          // Imprimir agrega una orden de impresión al PDF: si falló imprimir, solo se ofrece reintentarlo
          botones.forEach(b => { b.disabled = btn.dataset.accion === 'imprimir' && b.dataset.accion !== 'imprimir'; });
        }
      };
    });

    botones[0].focus();
  }

  window.PDF_COMEX = { nuevo, fichas, tabla, totales, firmas, guardar, ofrecer, formatearFecha, colores: C };
})();
