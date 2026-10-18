import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../models/consulta_model.dart';
import '../models/medico_model.dart';
import '../models/paciente_model.dart';

const _baseUrl =
    'urgenciascentrosalud-default-rtdb.europe-west1.firebasedatabase.app';

/// Estructura en Firebase (cada dato vive en un solo sitio):
///   /medicos/{id}            -> nombre, especialidad
///   /pacientes/{numHistoria} -> todos los datos del paciente
///   /consultas/{0,1,2}       -> medicoId, libre, numHistoria (si está ocupada)
///   /cola/{id de Firebase}   -> numHistoria del paciente que espera (el id va
///                               en orden de llegada, el más antiguo sale
///                               primero)
/// Consultas y cola solo guardan el numHistoria: los datos del paciente se
/// buscan siempre en /pacientes.
class FirebaseService {
  final Random _random = Random();

  // ---------------------------------------------------------------
  // Peticiones HTTP básicas
  // ---------------------------------------------------------------

  /// GET. Devuelve null si el nodo no existe (Firebase responde 'null')
  /// o si la respuesta no es un 200 (por ejemplo un 404).
  Future<dynamic> _get(String ruta) async {
    final respuesta = await http.get(Uri.https(_baseUrl, '$ruta.json'));
    dynamic datos;
    if (respuesta.statusCode == 200) {
      datos = jsonDecode(respuesta.body);
    }
    return datos;
  }

  Future<void> _put(String ruta, Map<String, dynamic> datos) async {
    await http.put(Uri.https(_baseUrl, '$ruta.json'), body: jsonEncode(datos));
  }

  /// POST: Firebase elige el id del nuevo nodo.
  Future<void> _post(String ruta, Map<String, dynamic> datos) async {
    await http.post(Uri.https(_baseUrl, '$ruta.json'), body: jsonEncode(datos));
  }

  Future<void> _delete(String ruta) async {
    await http.delete(Uri.https(_baseUrl, '$ruta.json'));
  }

  // ---------------------------------------------------------------
  // Arranque
  // ---------------------------------------------------------------

  Future<List<Medico>> getMedicos() async {
    final datos = await _get('/medicos');
    final List<Medico> medicos = [];

    if (datos != null) {
      final Map<String, dynamic> mapa = datos;
      final claves = mapa.keys.toList();
      claves.sort();
      for (final clave in claves) {
        medicos.add(Medico.fromJson(clave, mapa[clave]));
      }
    }
    return medicos;
  }

  /// Crea las consultas que falten (una por médico). Las que ya existen
  /// no se tocan: así, al reiniciar, todo sigue como estaba.
  /// Devuelve false si no hay médicos en Firebase.
  Future<bool> inicializarConsultas() async {
    final medicos = await getMedicos();
    final bool hayMedicos = medicos.length > 0;

    if (hayMedicos) {
      for (int i = 0; i < medicos.length; i++) {
        final existente = await _get('/consultas/$i');
        if (existente == null) {
          final consulta = Consulta(numero: i, medico: medicos[i]);
          await _put('/consultas/$i', consulta.toJson());
        }
      }
    }
    return hayMedicos;
  }

  // ---------------------------------------------------------------
  // Pacientes
  // ---------------------------------------------------------------

  /// Busca al paciente en /pacientes. Devuelve null si no existe.
  Future<Paciente?> getPaciente(int numHistoria) async {
    Paciente? paciente;
    final datos = await _get('/pacientes/$numHistoria');
    if (datos != null) {
      paciente = Paciente.fromJson(datos);
    }
    return paciente;
  }

  /// Aquí se garantiza que numHistoria no se repite: se sortea un número
  /// y se pregunta a Firebase si /pacientes/{n} existe. Si existe, se
  /// vuelve a sortear.
  Future<int> generarNumHistoria() async {
    int candidato = _random.nextInt(10000) + 1;
    while (await _get('/pacientes/$candidato') != null) {
      candidato = _random.nextInt(10000) + 1;
    }
    return candidato;
  }

  // ---------------------------------------------------------------
  // Consultas
  // ---------------------------------------------------------------

  /// Monta la consulta: busca en /pacientes al paciente que tenga asignado.
  Future<Consulta> _armarConsulta(
    int numero,
    Map<String, dynamic> json,
    Medico medico,
  ) async {
    Paciente? paciente;
    if (json['numHistoria'] != null) {
      paciente = await getPaciente(json['numHistoria']);
    }
    return Consulta.fromJson(numero, json, medico, paciente);
  }

  /// Se lee cada consulta por su número (/consultas/0, /consultas/1...)
  /// porque con claves 0,1,2 Firebase devolvería una lista en vez de un mapa.
  Future<List<Consulta>> getConsultas() async {
    final medicos = await getMedicos();
    final List<Consulta> consultas = [];

    for (int i = 0; i < medicos.length; i++) {
      final json = await _get('/consultas/$i');
      if (json != null) {
        for (final medico in medicos) {
          if (medico.id == json['medicoId']) {
            consultas.add(await _armarConsulta(i, json, medico));
          }
        }
      }
    }
    return consultas;
  }

  /// Lee una sola consulta, su médico y su paciente.
  /// Devuelve null si la consulta o su médico no existen.
  Future<Consulta?> getConsulta(int numero) async {
    Consulta? encontrada;
    final json = await _get('/consultas/$numero');

    if (json != null) {
      final String medicoId = json['medicoId'];
      final datosMedico = await _get('/medicos/$medicoId');
      if (datosMedico != null) {
        final medico = Medico.fromJson(medicoId, datosMedico);
        encontrada = await _armarConsulta(numero, json, medico);
      }
    }
    return encontrada;
  }

  // ---------------------------------------------------------------
  // Admisión, cola y liberación
  // ---------------------------------------------------------------

  /// Registra al paciente en /pacientes. Si hay consulta libre se la asigna;
  /// si no, su numHistoria entra en la cola. Tras escribir se vuelve a leer de
  /// Firebase: devuelve la consulta tal y como ha quedado allí, o null si el
  /// paciente fue a la cola.
  Future<Consulta?> admitirPaciente(Paciente paciente) async {
    await _put('/pacientes/${paciente.numHistoria}', paciente.toJson());

    Consulta? resultado;
    bool asignada = false;
    final consultas = await getConsultas();
    for (final consulta in consultas) {
      if (consulta.libre && !asignada) {
        consulta.asignar(paciente);
        await _put('/consultas/${consulta.numero}', consulta.toJson());
        resultado = await getConsulta(consulta.numero); // GET tras el PUT
        asignada = true;
      }
    }

    if (!asignada) {
      await _post('/cola', {'numHistoria': paciente.numHistoria});
    }
    return resultado;
  }

  /// Si la consulta ya estaba libre, también se le asigna el primero de la
  /// cola (si lo hay), sin dar error.
  /// Deja libre la consulta. Si hay alguien esperando, se la asigna al
  /// primero de la cola. Primero se guarda la consulta y después se borra
  /// de la cola: si el programa se apaga entre medias, el paciente no se
  /// pierde. Al final se vuelve a leer la consulta de Firebase y se devuelve
  /// tal y como ha quedado allí (null si no se puede leer).
  Future<Consulta?> liberarConsulta(Consulta consulta) async {
    consulta.liberar();

    String? primera;
    final datos = await _get('/cola');
    if (datos != null) {
      final Map<String, dynamic> cola = datos;
      final claves = cola.keys.toList();
      claves.sort();
      primera = claves[0];
      final siguiente = await getPaciente(cola[primera]['numHistoria']);
      if (siguiente != null) {
        consulta.asignar(siguiente);
      }
    }

    await _put('/consultas/${consulta.numero}', consulta.toJson());
    if (primera != null) {
      await _delete('/cola/$primera');
    }
    return await getConsulta(consulta.numero); // GET tras el PUT y el DELETE
  }

  /// Pacientes que esperan, en orden de llegada. Sus datos se buscan en
  /// /pacientes.
  Future<List<Paciente>> getCola() async {
    final datos = await _get('/cola');
    final List<Paciente> pacientes = [];

    if (datos != null) {
      final Map<String, dynamic> mapa = datos;
      final claves = mapa.keys.toList();
      claves.sort();
      for (final clave in claves) {
        final paciente = await getPaciente(mapa[clave]['numHistoria']);
        if (paciente != null) {
          pacientes.add(paciente);
        }
      }
    }
    return pacientes;
  }
}
