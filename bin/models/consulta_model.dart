import 'medico_model.dart';
import 'paciente_model.dart';

// Quicktype generó: libre, medicoId, paciente.
// Cambios sobre lo generado:
//  - En Firebase la consulta guarda solo el numHistoria del paciente
//    (los datos del paciente viven únicamente en /pacientes).
//  - El servicio busca el Paciente y el Medico y se los pasa a fromJson,
//    así que aquí paciente y medico son objetos, no ids.
//  - paciente es nullable: una consulta libre no trae numHistoria.
//  - numero es la clave del nodo en Firebase (0, 1, 2), no un campo.
class Consulta {
  final int numero;
  final Medico medico;
  Paciente? paciente;
  bool libre;

  Consulta({
    required this.numero,
    required this.medico,
    this.paciente,
    this.libre = true,
  });

  /// Internamente las consultas empiezan en 0 (así están en Firebase),
  /// pero al celador se le muestran empezando en 1.
  int get numeroMostrado => numero + 1;

  void asignar(Paciente nuevoPaciente) {
    paciente = nuevoPaciente;
    libre = false;
  }

  void liberar() {
    paciente = null;
    libre = true;
  }

  factory Consulta.fromJson(
    int numero,
    Map<String, dynamic> json,
    Medico medico,
    Paciente? paciente,
  ) => Consulta(
    numero: numero,
    medico: medico,
    libre: json["libre"],
    paciente: paciente,
  );

  Map<String, dynamic> toJson() => {
    "libre": libre,
    "medicoId": medico.id,
    "numHistoria": paciente?.numHistoria,
  };

  @override
  String toString() {
    String texto =
        '***** Consulta: $numeroMostrado ***********\n'
        '$medico\n';
    if (libre) {
      texto += 'Consulta libre';
    } else if (paciente == null) {
      texto += 'Paciente: no encontrado en /pacientes\n';
    } else {
      texto +=
          'Paciente: ${paciente!.nombreCompleto}\n'
          'Num_historia: ${paciente!.numHistoria}\n';
    }
    return texto;
  }
}
