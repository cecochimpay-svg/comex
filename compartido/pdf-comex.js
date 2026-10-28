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

  // Encabezado y pie en todas las páginas, y descarga
  function guardar(doc, archivo) {
    const total = doc.getNumberOfPages();
    for (let i = 1; i <= total; i++) {
      doc.setPage(i);
      dibujarEncabezado(doc);
      dibujarPie(doc, i, total);
    }
    doc.save(archivo);
  }

  window.PDF_COMEX = { nuevo, fichas, tabla, totales, firmas, guardar, formatearFecha, colores: C };
})();
