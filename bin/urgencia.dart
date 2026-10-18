import 'dart:io';

import './models/consulta_model.dart';
import './models/paciente_model.dart';
import './service/firebase_service.dart';
import './utils/utils.dart';

final FirebaseService servicio = FirebaseService();

Future<void> main() async {
  bool conectado = false;
  try {
    conectado = await servicio.inicializarConsultas();
    if (!conectado) {
      stdout.write('No se han podido leer los médicos de Firebase.\n');
    }
  } catch (e) {
    stdout.write('No se pudo conectar con Firebase: $e\n');
  }

  if (conectado) {
    int opcion = 0;
    do {
      limpiarPantalla();
      mostrarMenu();
      opcion = leerEntero();

      try {
        switch (opcion) {
          case 1:
            await admitirPaciente();
            break;
          case 2:
            await liberarConsulta();
            break;
          case 3:
            await verCola();
            break;
          case 4:
            await verConsultas();
            break;
          case 5:
            stdout.write('Hasta pronto.\n');
            break;
          default:
            stdout.write('Opción no válida.\n');
        }
      } catch (e) {
        stdout.write('Ha ocurrido un error con Firebase: $e\n');
      }

      if (opcion != 5) {
        pulsaParaContinuar();
      }
    } while (opcion != 5);
  }
}

void mostrarMenu() {
  stdout.write('''
1. Admisión de un paciente
2. Liberar una consulta
3. Ver la cola de espera
4. Ver el estado actual de las consultas
5. Salir
Pulse opción: ''');
}

/// Lee un número del teclado. Si no es un número, devuelve -1.
int leerEntero() {
  int numero = -1;
  try {
    numero = int.parse(stdin.readLineSync()!);
  } catch (e) {
    numero = -1;
  }
  return numero;
}

String pedirTexto(String mensaje) {
  String texto = '';
  while (texto.length == 0) {
    stdout.write(mensaje);
    texto = stdin.readLineSync() ?? '';
    if (texto.length == 0) {
      stdout.write('Este dato no puede estar vacío.\n');
    }
  }
  return texto;
}

Future<void> admitirPaciente() async {
  final dni = pedirTexto('DNI: ');
  final nombre = pedirTexto('Nombre: ');
  final apellidos = pedirTexto('Apellidos: ');
  final sintomas = pedirTexto('Síntomas: ');

  final numHistoria = await servicio.generarNumHistoria();
  final paciente = Paciente(
    numHistoria: numHistoria,
    dni: dni,
    nombre: nombre,
    apellidos: apellidos,
    sintomas: sintomas,
  );

  final consulta = await servicio.admitirPaciente(paciente);
  stdout.write('Paciente registrado con número de historia $numHistoria\n');
  if (consulta == null) {
    // GET tras el POST: la cola tal y como está ahora en Firebase.
    final cola = await servicio.getCola();
    stdout.write(
      'No hay médicos libres. ${paciente.nombreCompleto} pasa a la cola de espera.\n'
      'Pacientes en la cola: ${cola.length}\n',
    );
  } else if (consulta.libre || consulta.paciente == null) {
    stdout.write('No se ha podido asignar la consulta. Inténtelo de nuevo.\n');
  } else {
    mostrarAsignacion(consulta);
  }
}

Future<void> liberarConsulta() async {
  stdout.write('Introduzca el número de consulta que ha quedado liberada: ');
  final numero = leerEntero();

  if (numero == -1) {
    stdout.write('Debe introducir un número.\n');
  } else {
    // El celador ve las consultas desde la 1; internamente empiezan en 0.
    final consulta = await servicio.getConsulta(numero - 1);

    if (consulta == null) {
      stdout.write('La consulta $numero no existe.\n');
    } else {
      final resultado = await servicio.liberarConsulta(consulta);
      if (resultado == null) {
        stdout.write('No se pudo leer la consulta $numero de Firebase.\n');
      } else if (resultado.libre) {
        stdout.write(
          'La consulta $numero está libre. No hay nadie esperando.\n',
        );
      } else {
        mostrarAsignacion(resultado);
      }
    }
  }
}

void mostrarAsignacion(Consulta consulta) {
  stdout.write('''
El paciente: ${consulta.paciente!.nombreCompleto} ya puede pasar
Se le ha asignado la consulta ${consulta.numeroMostrado} ya puede pasar
Le atenderá D. ${consulta.medico.nombre}
''');
}

Future<void> verCola() async {
  final cola = await servicio.getCola();

  if (cola.length == 0) {
    stdout.write('Ahora mismo no hay pacientes esperando\n');
  } else {
    stdout.write('Ahora mismo hay ${cola.length} pacientes esperando\n');
    for (int i = 0; i < cola.length; i++) {
      stdout.write('''
==== Paciente ${i + 1} en la cola ====
${cola[i]}
''');
    }
  }
}

Future<void> verConsultas() async {
  final consultas = await servicio.getConsultas();
  for (final consulta in consultas) {
    stdout.write('$consulta\n');
  }
}
