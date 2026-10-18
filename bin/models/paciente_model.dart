class Paciente {
  final String apellidos;
  final String dni;
  final String nombre;
  final int numHistoria;
  final String sintomas;

  Paciente({
    required this.apellidos,
    required this.dni,
    required this.nombre,
    required this.numHistoria,
    required this.sintomas,
  });

  String get nombreCompleto => '$nombre $apellidos';

  factory Paciente.fromJson(Map<String, dynamic> json) => Paciente(
    apellidos: json["apellidos"],
    dni: json["dni"],
    nombre: json["nombre"],
    numHistoria: json["numHistoria"],
    sintomas: json["sintomas"],
  );

  Map<String, dynamic> toJson() => {
    "apellidos": apellidos,
    "dni": dni,
    "nombre": nombre,
    "numHistoria": numHistoria,
    "sintomas": sintomas,
  };

  @override
  String toString() {
    return '****** Datos de paciente ******\n'
        'Nombre del paciente: $nombreCompleto\n'
        'Historia del paciente: $numHistoria\n'
        'Síntomas del paciente: $sintomas\n';
  }
}
