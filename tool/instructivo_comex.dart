// Instructivo para el usuario COMEX (operadores / consignatarios), en PDF.
// Se regenera con:  dart run tool/instructivo_comex.dart
// Sale en docs/Instructivo_COMEX_usuario.pdf (usa el logo y las fuentes de assets/).
import 'dart:io';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

const urlWeb = 'https://cecochimpay-svg.github.io/comex/flutter/';

final verdeOscuro = PdfColor.fromInt(0xFF123F2C);
final verde = PdfColor.fromInt(0xFF1E6B4C);
final verdeSuave = PdfColor.fromInt(0xFFE8F2EC);
final oro = PdfColor.fromInt(0xFFC27C0E);
final oroSuave = PdfColor.fromInt(0xFFFBF1DF);
final azul = PdfColor.fromInt(0xFF2F6FDE);
final azulSuave = PdfColor.fromInt(0xFFE7EFFC);
final rojo = PdfColor.fromInt(0xFFC62828);
final rojoSuave = PdfColor.fromInt(0xFFFBE9E9);
final gris = PdfColor.fromInt(0xFF5A665E);
final grisClaro = PdfColor.fromInt(0xFFE3E8E4);
final tinta = PdfColor.fromInt(0xFF18201B);

Future<void> main() async {
  final regular = pw.Font.ttf(File('assets/fuentes/NotoSans-Regular.ttf').readAsBytesSync().buffer.asByteData());
  final negrita = pw.Font.ttf(File('assets/fuentes/NotoSans-Bold.ttf').readAsBytesSync().buffer.asByteData());
  final simbolos = pw.Font.ttf(File('assets/fuentes/DejaVuSans-Simbolos.ttf').readAsBytesSync().buffer.asByteData());
  final logo = pw.MemoryImage(File('assets/logo.png').readAsBytesSync());

  final doc = pw.Document(
    title: 'Instructivo COMEX — usuario',
    author: 'CECO S.A.',
    subject: 'Cómo ingresar, cargar e importar despachos en COMEX',
  );
  final tema = pw.ThemeData.withFont(base: regular, bold: negrita, fontFallback: [simbolos]);

  doc.addPage(
    pw.MultiPage(
      theme: tema,
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(40, 36, 40, 40),
      header: (c) => c.pageNumber == 1 ? pw.SizedBox() : _encabezadoChico(logo),
      footer: (c) => pw.Container(
        alignment: pw.Alignment.centerRight,
        margin: const pw.EdgeInsets.only(top: 10),
        child: pw.Text(
          'COMEX · Instructivo del usuario · página ${c.pageNumber} de ${c.pagesCount}',
          style: pw.TextStyle(fontSize: 8, color: gris),
        ),
      ),
      build: (c) => [
        _portada(logo),
        pw.SizedBox(height: 18),
        _indice(),

        // 1
        _titulo('1', 'Cómo ingresar'),
        _parrafo('COMEX se usa desde cualquier equipo. Elegí la forma que te quede cómoda:'),
        _tablaSimple([
          ['Equipo', 'Cómo se abre'],
          ['iPad / iPhone / celular', 'Safari (o Chrome en Android) en la dirección de abajo.'],
          ['PC o Mac', 'Cualquier navegador en la dirección de abajo, o la app COMEX instalada en Windows.'],
        ]),
        pw.SizedBox(height: 8),
        _recuadro(
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text('DIRECCIÓN', style: pw.TextStyle(fontSize: 8, color: gris, fontWeight: pw.FontWeight.bold, letterSpacing: 0.8)),
              pw.SizedBox(height: 2),
              pw.UrlLink(
                destination: urlWeb,
                child: pw.Text(urlWeb, style: pw.TextStyle(fontSize: 13, color: azul, fontWeight: pw.FontWeight.bold)),
              ),
            ],
          ),
          fondo: azulSuave,
          borde: azul,
        ),
        pw.SizedBox(height: 10),
        _pasos([
          'Abrí la dirección. Aparece la pantalla "Bienvenido — Ingresá con tu usuario de COMEX".',
          'En Usuario escribí el usuario que te dio CECO (normalmente tu correo, por ejemplo nombre@empresa.com).',
          'En Contraseña escribí tu clave. El ojito de la derecha la muestra u oculta.',
          'Tocá "Ingresar al sistema". Entrás directo a Programación de despachos.',
        ]),
        pw.SizedBox(height: 8),
        _maqueta(_maquetaLogin()),
        pw.SizedBox(height: 10),
        // Subtítulo y pasos juntos: que el título no quede solo al pie de una página.
        pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            _subtitulo('Dejarla como app en el iPad o iPhone'),
            _pasos([
              'Con COMEX abierto en Safari, tocá Compartir (el cuadrado con la flecha hacia arriba).',
              'Elegí "Agregar a pantalla de inicio" y confirmá con "Agregar".',
              'Queda el ícono de COMEX en la pantalla: se abre a pantalla completa, como cualquier app.',
            ]),
          ],
        ),
        pw.SizedBox(height: 8),
        _nota(
          'Para tener en cuenta',
          [
            'La sesión dura 12 horas; después te vuelve a pedir la clave.',
            'Con 5 intentos fallidos el usuario se bloquea 15 minutos.',
            'Sin internet sólo podés entrar en un equipo donde ya ingresaste con internet en los últimos 7 días.',
            'Para salir: tocá el círculo con tus iniciales (arriba a la derecha) y elegí "Cerrar sesión". Hacelo siempre en equipos compartidos.',
            '¿Olvidaste la clave o el usuario está inactivo? Pedile a CECO que te la cambie o lo active.',
          ],
        ),

        // 2
        _titulo('2', 'La pantalla de despachos'),
        _parrafo(
          'Ves solamente los despachos que cargaste vos (o que se importaron con tu usuario), con las '
          'mismas columnas de la planilla de logística:',
        ),
        _columnasPlanilla(),
        pw.SizedBox(height: 10),
        _tablaSimple([
          ['Parte de la pantalla', 'Para qué sirve'],
          ['WEEK 46, WEEK 47…', 'Elegí la semana. La semana sale sola de la ETD (si no hay ETD, del ingreso TCA). "Todas" muestra la temporada con una banda naranja por semana.'],
          ['Despachos · Tarimas · Destinos · Volados', 'Totales de la semana elegida.'],
          ['Buscador', 'Busca por AWB, vuelo, destino, CNNE, proforma o status.'],
          ['Botones de status', 'Filtran por status. "Limpiar" quita los filtros.'],
          ['Lápiz / tacho', 'Editar o eliminar ese despacho.'],
          ['PDF / Excel', 'Descargan lo que estás viendo (con los filtros aplicados).'],
        ]),

        // 3
        _titulo('3', 'Registrar un despacho a mano'),
        _pasos([
          'Tocá el botón verde "Registrar despacho".',
          'Completá Guía y vuelo (AWB, Vuelo, Conex — vacío si es directo —, Destino y Ruta).',
          'Cargá las fechas: Ingreso TCA requerido, ETD y ETA con su hora. La semana se calcula sola.',
          'En Carga poné Proforma, CNNE (consignatario), Tarimas, Peso (kg) y Tarifa (USD, por ejemplo 3,10).',
          'Encendé el status que corresponda y tocá "Guardar despacho".',
        ]),
        pw.SizedBox(height: 6),
        _parrafo('Son obligatorios Destino, Tarimas y Peso. La ETA no puede ser anterior a la ETD. Un despacho nuevo arranca en PROGRAMADO.'),

        // 4
        _titulo('4', 'Importar tu planilla de Excel'),
        _parrafo(
          'Si ya llevás tus despachos en una planilla, no hace falta cargarlos uno por uno: COMEX la lee, '
          'crea los que faltan y actualiza los que cambiaron. Podés subir la misma planilla todas las veces '
          'que quieras (por ejemplo, cada vez que cambia un vuelo o un status).',
        ),
        _subtitulo('Paso a paso'),
        _pasos([
          'Guardá la planilla como .xlsx. En Google Sheets: Archivo → Descargar → Microsoft Excel (.xlsx). '
              'En Excel: Guardar como → Libro de Excel (.xlsx).',
          'En COMEX tocá "Importar Excel" (al lado de "Registrar despacho") y elegí el archivo.',
          'COMEX muestra una vista previa, sin guardar nada todavía: cuántos son nuevos, cuántos cambian, cuántos quedan igual y si hay errores.',
          'Revisá el detalle: en cada fila que cambia se ve qué dato pasa de qué valor a cuál (por ejemplo Status: — → VOLADO).',
          'Si está todo bien tocá "Importar N despacho(s)". Si no, "Cancelar", corregí la planilla y volvé a subirla.',
        ]),
        pw.SizedBox(height: 8),
        _maqueta(_maquetaVistaPrevia()),
        pw.SizedBox(height: 10),
        _subtitulo('Cómo tiene que estar la planilla'),
        _vinetas([
          'Una fila de títulos (puede tener logo o filas vacías arriba, y bandas "WEEK 46 / 2026" en el medio: se saltean).',
          'Debajo, un despacho por fila. Las columnas pueden estar en cualquier orden: se reconocen por el título.',
          'Fechas como fecha de Excel o escritas 21/11/2026. Horas como 21:30. Tarifas como 2,48 o "USD 2,48".',
          'Las columnas que COMEX no usa (Semana, Día, Cajas, Fuel, SSC…) se ignoran.',
        ]),
        pw.SizedBox(height: 8),
        _tablaSimple(
          [
            ['Dato en COMEX', 'Títulos que reconoce'],
            ['AWB', 'AWB · MAWB · GUIA'],
            ['Ingreso TCA', 'INGRESO TCA REQUERIDO · INGRESO TCA · INGRESO'],
            ['Destino / Ruta', 'DESTINO · RUTA · ROUTING'],
            ['Vuelo / Conex', 'VUELO · CONEX · VUELO CNX'],
            ['ETD', 'ETD · FECHA ETD1 + HORA ETD1 (y FECHA ETD2 / HORA ETD2 de la conexión)'],
            ['ETA', 'ETA · FECHA ETA 1 + HORA ETA1 (y FECHA ETA 2 / HORA ETA2)'],
            ['Tarimas', 'TARIMAS · PALLETS'],
            ['Peso', 'PESO · KILOS'],
            ['Tarifa', 'TARIFA /KG (si está, gana sobre TARIFA) · TARIFA'],
            ['Fijos', 'FIJOS / AWB'],
            ['Proforma', 'PROFORMA · REF'],
            ['CNNE', 'CNNE · CONSIGNEE · CONSIGNATARIO'],
            ['Status', 'STATUS · ESTADO (también BOOKED, FLOWN, ARRIVED, CANCELLED)'],
            ['Otros', 'CLIENTE · LINEA AEREA'],
          ],
          anchoPrimera: 110,
        ),
        pw.SizedBox(height: 10),
        _nota(
          'Reglas de la importación',
          [
            'Cada fila se busca entre tus despachos por el AWB. Si el AWB se repite (varias filas de la misma guía), se emparejan en orden.',
            'Sin AWB, se busca por vuelo + ETD + destino.',
            'Una celda vacía NO borra lo que ya estaba cargado. Para borrar un dato, editá el despacho a mano.',
            'Nunca se elimina un despacho: si sacás una fila de la planilla, el despacho sigue en COMEX.',
            'Un despacho nuevo necesita Destino; si falta, esa fila sale con ERROR y no se importa.',
          ],
          color: azul,
          fondo: azulSuave,
        ),

        // 5
        _titulo('5', 'Status del despacho'),
        _parrafo('Cada despacho tiene un LED con su status. Así avanza la carga:'),
        _status(),

        // 6
        _titulo('6', 'Sin internet y sincronización'),
        _vinetas([
          'Si se corta internet podés seguir trabajando: lo que cargues queda en el equipo con un punto naranja.',
          'Arriba se ve "En línea" o "Modo local". Al volver la conexión tocá "Sincronizar" y se sube todo.',
          'Cuando dice "Todo sincronizado", lo cargado ya lo ve CECO.',
        ]),

        // 7
        _titulo('7', 'Problemas frecuentes'),
        _tablaSimple([
          ['Mensaje o problema', 'Qué hacer'],
          ['Usuario o contraseña incorrectos', 'Revisá mayúsculas y espacios. Te dice cuántos intentos quedan.'],
          ['Usuario bloqueado por intentos fallidos', 'Esperá 15 minutos o pedile a CECO que lo desbloquee.'],
          ['El usuario está inactivo', 'Pedile a CECO que lo active.'],
          ['Es un .xls viejo', 'Abrilo en Excel y guardalo como .xlsx (Libro de Excel).'],
          ['No encontré la fila de títulos', 'La planilla necesita una fila con títulos como AWB, DESTINO, VUELO, ETD, PALLETS, KILOS.'],
          ['No entiendo la fecha / la hora', 'Esa celda tiene un formato raro. Escribila como 21/11/2026 y 21:30.'],
          ['Importé y no veo los despachos', 'Revisá la semana elegida arriba: el despacho va a la semana de su ETD.'],
        ]),
        pw.SizedBox(height: 14),
        pw.Text('CECO S.A. · Comercio exterior', style: pw.TextStyle(fontSize: 9, color: gris)),
      ],
    ),
  );

  final salida = File('docs/Instructivo_COMEX_usuario.pdf');
  salida.parent.createSync(recursive: true);
  salida.writeAsBytesSync(await doc.save());
  stdout.writeln('Listo: ${salida.path}');
}

// ───────────────────────────── Piezas ─────────────────────────────

pw.Widget _portada(pw.MemoryImage logo) => pw.Container(
  padding: const pw.EdgeInsets.fromLTRB(22, 20, 22, 20),
  decoration: pw.BoxDecoration(
    gradient: pw.LinearGradient(colors: [verdeOscuro, verde]),
    borderRadius: pw.BorderRadius.circular(10),
  ),
  child: pw.Row(
    crossAxisAlignment: pw.CrossAxisAlignment.center,
    children: [
      pw.Container(
        width: 62,
        height: 62,
        padding: const pw.EdgeInsets.all(6),
        decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(10)),
        child: pw.Image(logo, fit: pw.BoxFit.contain),
      ),
      pw.SizedBox(width: 16),
      pw.Expanded(
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('COMEX · COMERCIO EXTERIOR',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromInt(0xFFF2C25C), fontWeight: pw.FontWeight.bold, letterSpacing: 1.2)),
            pw.SizedBox(height: 3),
            pw.Text('Instructivo del usuario',
                style: pw.TextStyle(fontSize: 24, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 3),
            pw.Text('Ingresar, cargar e importar la programación de despachos aéreos',
                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromInt(0xFFD6E8DE))),
          ],
        ),
      ),
    ],
  ),
);

pw.Widget _encabezadoChico(pw.MemoryImage logo) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 12),
  padding: const pw.EdgeInsets.only(bottom: 6),
  decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: grisClaro))),
  child: pw.Row(
    children: [
      pw.SizedBox(width: 16, height: 16, child: pw.Image(logo)),
      pw.SizedBox(width: 6),
      pw.Text('COMEX · Instructivo del usuario', style: pw.TextStyle(fontSize: 8.5, color: gris, fontWeight: pw.FontWeight.bold)),
    ],
  ),
);

pw.Widget _indice() {
  const temas = [
    'Cómo ingresar',
    'La pantalla de despachos',
    'Registrar un despacho a mano',
    'Importar tu planilla de Excel',
    'Status del despacho',
    'Sin internet y sincronización',
    'Problemas frecuentes',
  ];
  return pw.Container(
    padding: const pw.EdgeInsets.all(12),
    decoration: pw.BoxDecoration(color: verdeSuave, borderRadius: pw.BorderRadius.circular(8)),
    child: pw.Wrap(
      spacing: 18,
      runSpacing: 4,
      children: [
        for (var i = 0; i < temas.length; i++)
          pw.Text('${i + 1}. ${temas[i]}', style: pw.TextStyle(fontSize: 10, color: verdeOscuro)),
      ],
    ),
  );
}

pw.Widget _titulo(String n, String texto) => pw.Container(
  margin: const pw.EdgeInsets.only(top: 18, bottom: 8),
  child: pw.Row(
    children: [
      pw.Container(
        width: 22,
        height: 22,
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(color: verde, shape: pw.BoxShape.circle),
        child: pw.Text(n, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 11)),
      ),
      pw.SizedBox(width: 8),
      pw.Text(texto, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: verdeOscuro)),
    ],
  ),
);

pw.Widget _subtitulo(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(top: 4, bottom: 5),
  child: pw.Text(t, style: pw.TextStyle(fontSize: 11.5, fontWeight: pw.FontWeight.bold, color: verde)),
);

pw.Widget _parrafo(String t) => pw.Padding(
  padding: const pw.EdgeInsets.only(bottom: 6),
  child: pw.Text(t, style: pw.TextStyle(fontSize: 10, color: tinta, lineSpacing: 2)),
);

pw.Widget _pasos(List<String> pasos) => pw.Column(
  children: [
    for (var i = 0; i < pasos.length; i++)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 16,
              height: 16,
              margin: const pw.EdgeInsets.only(right: 8, top: 0.5),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(color: verdeSuave, border: pw.Border.all(color: verde, width: 0.8), shape: pw.BoxShape.circle),
              child: pw.Text('${i + 1}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: verde)),
            ),
            pw.Expanded(child: pw.Text(pasos[i], style: pw.TextStyle(fontSize: 10, color: tinta, lineSpacing: 2))),
          ],
        ),
      ),
  ],
);

pw.Widget _vinetas(List<String> items, {PdfColor? color}) => pw.Column(
  crossAxisAlignment: pw.CrossAxisAlignment.start,
  children: [
    for (final t in items)
      pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 3.5),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Container(
              width: 4,
              height: 4,
              margin: const pw.EdgeInsets.only(top: 5, right: 7, left: 2),
              decoration: pw.BoxDecoration(color: color ?? verde, shape: pw.BoxShape.circle),
            ),
            pw.Expanded(child: pw.Text(t, style: pw.TextStyle(fontSize: 10, color: tinta, lineSpacing: 2))),
          ],
        ),
      ),
  ],
);

pw.Widget _recuadro(pw.Widget hijo, {required PdfColor fondo, required PdfColor borde}) => pw.Container(
  width: double.infinity,
  padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 9),
  decoration: pw.BoxDecoration(
    color: fondo,
    borderRadius: pw.BorderRadius.circular(7),
    border: pw.Border(left: pw.BorderSide(color: borde, width: 3)),
  ),
  child: hijo,
);

pw.Widget _nota(String titulo, List<String> items, {PdfColor? color, PdfColor? fondo}) => _recuadro(
  pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(titulo.toUpperCase(),
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: color ?? oro, letterSpacing: 0.8)),
      pw.SizedBox(height: 5),
      _vinetas(items, color: color ?? oro),
    ],
  ),
  fondo: fondo ?? oroSuave,
  borde: color ?? oro,
);

pw.Widget _tablaSimple(List<List<String>> filas, {double anchoPrimera = 150}) => pw.Table(
  columnWidths: {0: pw.FixedColumnWidth(anchoPrimera), 1: const pw.FlexColumnWidth()},
  border: pw.TableBorder(
    horizontalInside: pw.BorderSide(color: grisClaro, width: 0.6),
    bottom: pw.BorderSide(color: grisClaro, width: 0.6),
  ),
  children: [
    for (var i = 0; i < filas.length; i++)
      pw.TableRow(
        decoration: i == 0 ? pw.BoxDecoration(color: verdeOscuro) : (i.isEven ? pw.BoxDecoration(color: PdfColor.fromInt(0xFFF8FAF9)) : null),
        children: [
          for (var c = 0; c < filas[i].length; c++)
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(horizontal: 7, vertical: 5),
              child: pw.Text(
                filas[i][c],
                style: pw.TextStyle(
                  fontSize: i == 0 ? 8.5 : 9.5,
                  fontWeight: i == 0 || c == 0 ? pw.FontWeight.bold : pw.FontWeight.normal,
                  color: i == 0 ? PdfColors.white : tinta,
                  letterSpacing: i == 0 ? 0.5 : 0,
                ),
              ),
            ),
        ],
      ),
  ],
);

/// Las 14 columnas de la planilla de logística, como encabezado de tabla.
pw.Widget _columnasPlanilla() {
  const cols = ['AWB', 'INGRESO TCA', 'DESTINO', 'RUTA', 'VUELO', 'PROFORMA', 'ETD', 'CONEX', 'ETA', 'TARIMAS', 'PESO', 'TARIFA', 'STATUS', 'CNNE'];
  return pw.Wrap(
    spacing: 4,
    runSpacing: 4,
    children: [
      for (final c in cols)
        pw.Container(
          padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: pw.BoxDecoration(color: azulSuave, borderRadius: pw.BorderRadius.circular(4)),
          child: pw.Text(c, style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: azul)),
        ),
    ],
  );
}

pw.Widget _status() {
  const estados = [
    ('PROGRAMADO', 0xFF3B82F6, 'Cargado, todavía sin reserva confirmada.'),
    ('CONFIRMADO', 0xFF8B5CF6, 'La aerolínea confirmó el espacio.'),
    ('EN TCA', 0xFFF59E0B, 'La carga ingresó a la terminal (TCA).'),
    ('VOLADO', 0xFF10B981, 'Salió el vuelo.'),
    ('ARRIBADO', 0xFF0F766E, 'Llegó a destino.'),
    ('CANCELADO', 0xFFEF4444, 'Se canceló el despacho.'),
  ];
  return pw.Column(
    children: [
      for (final (nombre, color, texto) in estados)
        pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 4),
          child: pw.Row(
            children: [
              pw.Container(
                width: 9,
                height: 9,
                decoration: pw.BoxDecoration(color: PdfColor.fromInt(color), shape: pw.BoxShape.circle),
              ),
              pw.SizedBox(width: 8),
              pw.SizedBox(
                width: 90,
                child: pw.Text(nombre, style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, letterSpacing: 0.4)),
              ),
              pw.Expanded(child: pw.Text(texto, style: pw.TextStyle(fontSize: 9.5, color: gris))),
            ],
          ),
        ),
    ],
  );
}

// ───────────────────────────── Maquetas de pantalla ─────────────────────────────

pw.Widget _maqueta(pw.Widget hijo) => pw.Center(
  child: pw.Container(
    width: 380,
    padding: const pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      color: PdfColor.fromInt(0xFFF3F5F4),
      borderRadius: pw.BorderRadius.circular(8),
      border: pw.Border.all(color: grisClaro),
    ),
    child: hijo,
  ),
);

pw.Widget _campo(String etiqueta, String valor) => pw.Container(
  margin: const pw.EdgeInsets.only(bottom: 6),
  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  decoration: pw.BoxDecoration(
    color: PdfColors.white,
    borderRadius: pw.BorderRadius.circular(5),
    border: pw.Border.all(color: PdfColor.fromInt(0xFFD3DAD5)),
  ),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(etiqueta, style: pw.TextStyle(fontSize: 7, color: gris)),
      pw.Text(valor, style: pw.TextStyle(fontSize: 9.5)),
    ],
  ),
);

pw.Widget _boton(String t, PdfColor color) => pw.Container(
  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
  alignment: pw.Alignment.center,
  decoration: pw.BoxDecoration(color: color, borderRadius: pw.BorderRadius.circular(5)),
  child: pw.Text(t, style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 9)),
);

pw.Widget _maquetaLogin() => pw.Container(
  padding: const pw.EdgeInsets.all(12),
  decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(6)),
  child: pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Text('Bienvenido', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: verdeOscuro)),
      pw.Text('Ingresá con tu usuario de COMEX.', style: pw.TextStyle(fontSize: 8.5, color: gris)),
      pw.SizedBox(height: 8),
      _campo('Usuario', 'nombre@empresa.com'),
      _campo('Contraseña', '••••••••'),
      pw.SizedBox(height: 2),
      _boton('Ingresar al sistema', verde),
    ],
  ),
);

pw.Widget _maquetaVistaPrevia() {
  pw.Widget dato(String rotulo, String n, PdfColor c) => pw.Expanded(
    child: pw.Container(
      margin: const pw.EdgeInsets.symmetric(horizontal: 2),
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(5)),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(rotulo, style: pw.TextStyle(fontSize: 6.5, color: gris, fontWeight: pw.FontWeight.bold)),
          pw.Text(n, style: pw.TextStyle(fontSize: 13, color: c, fontWeight: pw.FontWeight.bold)),
        ],
      ),
    ),
  );
  pw.Widget fila(String tipo, PdfColor c, PdfColor fondo, String texto, [String? detalle]) => pw.Container(
    margin: const pw.EdgeInsets.only(top: 4),
    padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: pw.BoxDecoration(color: PdfColors.white, borderRadius: pw.BorderRadius.circular(5)),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          children: [
            pw.Container(
              width: 44,
              padding: const pw.EdgeInsets.symmetric(vertical: 1),
              alignment: pw.Alignment.center,
              decoration: pw.BoxDecoration(color: fondo, borderRadius: pw.BorderRadius.circular(6)),
              child: pw.Text(tipo, style: pw.TextStyle(fontSize: 6.5, color: c, fontWeight: pw.FontWeight.bold)),
            ),
            pw.SizedBox(width: 6),
            pw.Expanded(child: pw.Text(texto, style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold))),
          ],
        ),
        if (detalle != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(left: 50, top: 2),
            child: pw.Text(detalle, style: pw.TextStyle(fontSize: 7, color: tinta)),
          ),
      ],
    ),
  );

  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.stretch,
    children: [
      pw.Container(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: pw.BoxDecoration(color: azul, borderRadius: pw.BorderRadius.circular(5)),
        child: pw.Text('Importar planilla · despachos.xlsx',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
      ),
      pw.SizedBox(height: 6),
      pw.Row(children: [
        dato('NUEVOS', '1', PdfColor.fromInt(0xFF1F9D55)),
        dato('SE ACTUALIZAN', '2', azul),
        dato('SIN CAMBIOS', '9', gris),
        dato('CON ERROR', '0', gris),
      ]),
      fila('NUEVO', PdfColor.fromInt(0xFF1F9D55), verdeSuave, 'Fila 14 · AWB 020-04387655 · LH511 · PVG · ETD 23/11 16:45 · 5 tarimas'),
      fila('CAMBIA', azul, azulSuave, 'Fila 7 · AWB 071-63266814 · ET507 · CAN · 5 tarimas', 'Status: — → VOLADO'),
      fila('CAMBIA', azul, azulSuave, 'Fila 9 · AWB 176-69302763 · EK248 · CAN', 'Tarifa: USD 3,00 → USD 3,16'),
      pw.SizedBox(height: 6),
      pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.end,
        children: [
          pw.Text('Cancelar', style: pw.TextStyle(fontSize: 8.5, color: verde)),
          pw.SizedBox(width: 10),
          _boton('Importar 3 despacho(s)', verde),
        ],
      ),
    ],
  );
}
